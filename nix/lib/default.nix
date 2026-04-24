# nix/lib/default.nix
{ inputs, flake, ... }:
let
  # Shell-escape a path for safe embedding in an activation script.
  esc = s:
    "'" + builtins.replaceStrings [ "'" ] [ "'\\''" ] s + "'";
in
{
  # Expose `esc` so the home-manager module and tests share one escaper.
  inherit esc;

  # Pre-flight validation of localSkills sources, emitted as a shell script.
  # Runs as the first activation step (before writeBoundary) so bad config
  # aborts `home-manager switch` before any file mutation occurs.
  #
  # Why a shell check instead of an eval-time assertion:
  # Flake evaluation runs in pure mode, where `builtins.pathExists` on
  # absolute paths outside the flake/store silently returns `false`, which
  # would produce false-positive failures for every local skill. The shell
  # preflight runs with a real $HOME and can see the actual filesystem.
  #
  # Arguments:
  #   localSkills :: attrsOf (path | string)
  #     Attribute set of skillName → source path. A path ending in ".md" is
  #     treated as a single-file skill; anything else is treated as a skill
  #     directory.
  mkLocalSkillsPreflight =
    { localSkills }:
    let
      checks = builtins.concatStringsSep "" (inputs.nixpkgs.lib.mapAttrsToList
        (skillName: skillPath:
          let
            pathStr = toString skillPath;
            expectedKind =
              if inputs.nixpkgs.lib.hasSuffix ".md" pathStr then "file" else "dir";
          in
            "_localSkills_check ${esc skillName} ${esc pathStr} ${expectedKind}\n"
        )
        localSkills);
    in ''
      _localSkills_errors=""

      # Validate the SKILL.md frontmatter required by the Agent Skills spec
      # (https://agentskills.io/specification). We enforce the two fields
      # that pi/codex/claude all treat as mandatory for loading:
      #   - name        (required)
      #   - description (required; pi refuses to load skills without it)
      # Other fields (license, compatibility, allowed-tools, …) are optional
      # and we don't enforce them here.
      _localSkills_check_frontmatter() {
        local name="$1" md="$2"
        # Extract the first frontmatter block (between leading '---' and the
        # next '---'). If the file doesn't start with '---', fm stays empty.
        local fm
        fm="$(awk '
          NR==1 && $0=="---" { inFm=1; next }
          inFm && $0=="---" { exit }
          inFm
        ' "$md")"
        if [ -z "$fm" ]; then
          _localSkills_errors+="  - localSkills.$name: missing YAML frontmatter block (expected '---' as first line) in $md"$'\n'
          return
        fi
        local fmName fmDesc
        fmName="$(printf '%s\n' "$fm" | sed -n 's/^name:[[:space:]]*//p' | head -1 | sed 's/[[:space:]]*$//')"
        fmDesc="$(printf '%s\n' "$fm" | sed -n 's/^description:[[:space:]]*//p' | head -1 | sed 's/[[:space:]]*$//')"
        if [ -z "$fmName" ]; then
          _localSkills_errors+="  - localSkills.$name: required frontmatter field 'name' missing or empty in $md"$'\n'
        fi
        if [ -z "$fmDesc" ]; then
          _localSkills_errors+="  - localSkills.$name: required frontmatter field 'description' missing or empty in $md"$'\n'
        fi
        # Non-fatal: warn if frontmatter name disagrees with the mount key,
        # since pi warns and may de-duplicate on collision.
        if [ -n "$fmName" ] && [ "$fmName" != "$name" ]; then
          echo "localSkills: warning: '$md' declares name='$fmName' but is mounted as localSkills.$name" >&2
        fi
      }

      _localSkills_check() {
        # $1 = skillName, $2 = pathStr, $3 = expected kind ("file" or "dir")
        local name="$1" path="$2" kind="$3"
        if [ ! -e "$path" ]; then
          _localSkills_errors+="  - localSkills.$name: source does not exist: $path"$'\n'
          return
        fi
        if [ "$kind" = "file" ]; then
          if [ ! -f "$path" ]; then
            _localSkills_errors+="  - localSkills.$name: expected a file (.md suffix) but found a directory or special file: $path"$'\n'
            return
          fi
          _localSkills_check_frontmatter "$name" "$path"
        else
          if [ ! -d "$path" ]; then
            _localSkills_errors+="  - localSkills.$name: expected a directory (no .md suffix) but found a file: $path"$'\n'
            return
          fi
          if [ ! -f "$path/SKILL.md" ]; then
            _localSkills_errors+="  - localSkills.$name: directory is missing SKILL.md: $path/SKILL.md"$'\n'
            return
          fi
          _localSkills_check_frontmatter "$name" "$path/SKILL.md"
        fi
      }
      ${checks}
      if [ -n "$_localSkills_errors" ]; then
        echo "programs.agent-skills.localSkills: invalid configuration:" >&2
        printf '%s' "$_localSkills_errors" >&2
        exit 1
      fi
    '';

  # Build an activation script that (re)creates direct out-of-store symlinks
  # for all localSkills under a given agent's skills directory.
  #
  # Semantics:
  #   - A source ending in ".md" is linked at <agentRoot>/<skillName>/SKILL.md
  #     with the containing directory created if needed.
  #   - Any other (directory) source is linked directly at <agentRoot>/<skillName>.
  #   - The script is idempotent and heals user-deleted links on every run.
  #   - It refuses to overwrite the source with a self-link (defense against
  #     stale symlinks from prior configs resolving back into the source).
  #
  # Arguments:
  #   agentRoot   :: string   Absolute path to the agent's skills directory.
  #   localSkills :: attrsOf (path | string)
  mkLocalSkillsActivation =
    { agentRoot, localSkills }:
    let
      lines = inputs.nixpkgs.lib.mapAttrsToList (skillName: skillPath:
        let
          pathStr = toString skillPath;
          isMarkdownFile = inputs.nixpkgs.lib.hasSuffix ".md" pathStr;
          skillDir = "${agentRoot}/${skillName}";
          linkPath =
            if isMarkdownFile then "${skillDir}/SKILL.md" else skillDir;
        in
          if isMarkdownFile then ''
            # --- localSkill: ${skillName} (markdown file) ---
            src=${esc pathStr}
            dst=${esc linkPath}
            sdir=${esc skillDir}
            if [ ! -e "$src" ]; then
              echo "localSkills: source missing for '${skillName}': $src" >&2
            else
              # If skillDir exists as a symlink or as a non-directory regular
              # file, remove it so we can own a real directory here without
              # traversing back into the source tree.
              if [ -L "$sdir" ] || { [ -e "$sdir" ] && [ ! -d "$sdir" ]; }; then
                $DRY_RUN_CMD rm -f "$sdir"
              fi
              $DRY_RUN_CMD mkdir -p "$sdir"
              # Refuse to overwrite the source with a self-link: if dst is a
              # real file (not a symlink) and resolves to the same inode as
              # src, leave it alone.
              if [ -e "$dst" ] && [ ! -L "$dst" ] \
                 && [ "$(readlink -f -- "$dst" 2>/dev/null)" = "$(readlink -f -- "$src")" ]; then
                : # dst is the source file itself; do not touch it
              else
                $DRY_RUN_CMD ln -sfn "$src" "$dst"
              fi
            fi
          '' else ''
            # --- localSkill: ${skillName} (directory) ---
            src=${esc pathStr}
            dst=${esc linkPath}
            if [ ! -d "$src" ]; then
              echo "localSkills: source directory missing for '${skillName}': $src" >&2
            else
              $DRY_RUN_CMD mkdir -p ${esc agentRoot}
              # Remove any existing symlink or regular file at the link path.
              # Leave a real directory alone (user may have stored other data).
              if [ -L "$dst" ] || [ -f "$dst" ]; then
                $DRY_RUN_CMD rm -f "$dst"
              fi
              if [ ! -e "$dst" ]; then
                $DRY_RUN_CMD ln -sfn "$src" "$dst"
              fi
            fi
          ''
      ) localSkills;
    in
      builtins.concatStringsSep "" lines;

  # Build a combined directory of skills from a list of skill derivations.
  # Each skill derivation installs to $out/share/agent-skills/<name>/ (local)
  # or $out/share/agent-skills/<source>/<name>/ (remote).
  #
  # flatten: if true, nested dirs become <source>__<name>/ (for agents
  #          that don't support recursive SKILL.md discovery, e.g. Claude Code)
  mkSkillsDir =
    { pkgs
    , skills ? [ ]
    , flatten ? false
    }:
    pkgs.runCommand "agent-skills" { } ''
      mkdir -p $out
      ${pkgs.lib.concatMapStringsSep "\n" (skill: ''
        for entry in ${skill}/share/agent-skills/*/; do
          entry_name="$(basename "$entry")"
          if [ -f "$entry/SKILL.md" ]; then
            # Direct skill (local): <name>/SKILL.md
            ln -s "$entry" "$out/$entry_name"
          else
            # Grouped source (remote): <source>/<skill>/SKILL.md
            ${if flatten then ''
              # Flatten: <source>/<skill>/ → <source>__<skill>/
              for nested in "$entry"/*/; do
                nested_name="$(basename "$nested")"
                if [ -f "$nested/SKILL.md" ]; then
                  ln -s "$nested" "$out/''${entry_name}__''${nested_name}"
                fi
              done
            '' else ''
              # Preserve nesting
              ln -s "$entry" "$out/$entry_name"
            ''}
          fi
        done
      '') skills}
    '';

  # Build a team-play skill package with optional extra role directories merged in.
  # The base team-play provides engineer/, reviewer/, security/, ux-designer/,
  # and orchestrator/ roles. Users can add their own roles (or extend existing
  # categories) by providing extra directories.
  #
  # Usage:
  #   skills-nix.lib.mkTeamPlay {
  #     inherit pkgs;
  #     extraRoles = [
  #       ./my-roles       # my-roles/engineer/python.md, my-roles/dba/postgres.md
  #     ];
  #   }
  #
  # Or with a flake input:
  #   skills-nix.lib.mkTeamPlay {
  #     inherit pkgs;
  #     extraRoles = [
  #       ./my-roles
  #       inputs.company-roles   # from another flake
  #     ];
  #   }
  #
  # Each entry in extraRoles is a directory whose contents are merged into
  # the team-play tree. Files at the same path override the base (user wins).
  # New directories are added alongside the built-in ones.
  #
  # Produces: $out/share/agent-skills/team-play/
  mkTeamPlay =
    { pkgs
    , extraRoles ? [ ]   # List of paths/derivations containing role directories
    , basePackage ? null  # Override the base team-play package (advanced)
    }:
    let
      base =
        if basePackage != null
        then basePackage
        else
          (import ../../nix/packages/team-play/default.nix {
            inherit pkgs;
            pname = "team-play";
          });
      basePath = "${base}/share/agent-skills/team-play";
    in
    if extraRoles == [ ] then base
    else
      pkgs.runCommand "team-play" { } ''
        mkdir -p $out/share/agent-skills/team-play

        # Copy base team-play (writable so extras can overlay)
        cp -r --no-preserve=mode ${basePath}/. $out/share/agent-skills/team-play/

        # Merge each extra roles directory on top (user files win)
        ${pkgs.lib.concatMapStringsSep "\n" (extra: ''
          if [ -d "${extra}" ]; then
            cp -r --no-preserve=mode "${extra}"/. $out/share/agent-skills/team-play/
          else
            echo "Warning: extraRoles entry '${extra}' is not a directory" >&2
          fi
        '') extraRoles}

        # Ensure SKILL.md still exists after merge
        if [ ! -f $out/share/agent-skills/team-play/SKILL.md ]; then
          echo "ERROR: SKILL.md missing after merge — an extraRoles entry may have overwritten it" >&2
          exit 1
        fi
      '';

  # Package skills from any remote source (git repo, fetchurl, etc.).
  # Scans src for SKILL.md files and packages them under a grouped directory.
  #
  # Usage in user's config:
  #   skills-nix.lib.mkRemoteSkills {
  #     inherit pkgs;
  #     name = "cool-skills";
  #     src = builtins.fetchGit { url = "https://github.com/someone/cool-skills"; };
  #   }
  #
  # Or with a flake input (flake = false):
  #   skills-nix.lib.mkRemoteSkills {
  #     inherit pkgs;
  #     name = "cool-skills";
  #     src = inputs.cool-skills-src;
  #   }
  #
  # Produces: $out/share/agent-skills/<name>/<skill>/SKILL.md
  mkRemoteSkills =
    { pkgs
    , name           # Source name (e.g., "workmux", "cool-skills")
    , src            # Source path/derivation containing skill directories with SKILL.md
    , skillsDir ? "" # Subdirectory within src containing skills (e.g., "skills"). Empty = root.
    }:
    pkgs.runCommand "${name}-skills" { } ''
      src_dir="${src}${if skillsDir != "" then "/${skillsDir}" else ""}"

      if [ ! -d "$src_dir" ]; then
        echo "Error: Source directory '$src_dir' not found" >&2
        exit 1
      fi

      mkdir -p $out/share/agent-skills/${name}

      # Find all directories containing SKILL.md
      found=0
      for skill_dir in "$src_dir"/*/; do
        skill_name="$(basename "$skill_dir")"
        if [ -f "$skill_dir/SKILL.md" ]; then
          mkdir -p "$out/share/agent-skills/${name}/$skill_name"
          cp -r "$skill_dir"/. "$out/share/agent-skills/${name}/$skill_name/"
          found=$((found + 1))
        fi
      done

      if [ "$found" -eq 0 ]; then
        # Maybe src itself is a single skill
        if [ -f "$src_dir/SKILL.md" ]; then
          mkdir -p "$out/share/agent-skills/${name}"
          cp -r "$src_dir"/. "$out/share/agent-skills/${name}/"
        else
          echo "Warning: No SKILL.md files found in '$src_dir'" >&2
        fi
      fi
    '';
}
