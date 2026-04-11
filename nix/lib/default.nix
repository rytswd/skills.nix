# nix/lib/default.nix
{ inputs, flake, ... }:
{
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
