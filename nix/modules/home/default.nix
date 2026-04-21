{ flake, inputs, ... }:
{ config, lib, pkgs, ... }:
let
  cfg = config.programs.agent-skills;

  mkSkillsDir = flake.lib.mkSkillsDir;

  # Agent configuration: path under $HOME, and whether to flatten remote skills.
  #   flatten = false → workmux/coordinator/SKILL.md  (recursive discovery)
  #   flatten = true  → workmux__coordinator/SKILL.md  (single-level only)
  agents = {
    pi = {
      path = ".agents/skills";
      flatten = false;
      description = "Pi agent skills (~/.agents/skills/)";
    };
    codex = {
      path = ".agents/skills";
      flatten = false;
      description = "Codex agent skills (~/.agents/skills/)";
    };
    claude = {
      path = ".claude/skills";
      flatten = true;
      description = "Claude Code skills (~/.claude/skills/)";
    };
    gemini = {
      path = ".agents/skills";
      flatten = false;
      description = "Gemini CLI skills (~/.agents/skills/)";
    };
  };

  mkDir = flatten: mkSkillsDir { inherit pkgs flatten; skills = cfg.skills; };

  # Shell-escape a path for safe embedding in the activation script.
  esc = s: "'" + lib.replaceStrings [ "'" ] [ "'\\''" ] s + "'";

  # Eval-time validation of localSkills sources. We classify each entry as
  # "missing", "wrong-kind" (md suffix but not a regular file, or no md suffix
  # but not a directory), or "ok". Any non-ok entry produces an assertion that
  # makes `home-manager switch` / `nix build` fail *before* the activation
  # script runs, so the system never gets into a half-applied state.
  localSkillChecks = lib.mapAttrsToList (skillName: skillPath:
    let
      pathStr = toString skillPath;
      isMarkdownFile = lib.hasSuffix ".md" pathStr;
      exists = builtins.pathExists pathStr;
      kind =
        if !exists then "missing"
        else if isMarkdownFile && builtins.pathExists "${pathStr}/."
        then "expected-file"   # path ends in .md but is a directory
        else if !isMarkdownFile && !(builtins.pathExists "${pathStr}/.")
        then "expected-dir"    # no .md suffix but path is not a directory
        else "ok";
    in {
      inherit skillName pathStr kind;
    }
  ) cfg.localSkills;

  localSkillAssertions = map (c: {
    assertion = c.kind == "ok";
    message =
      if c.kind == "missing" then
        "programs.agent-skills.localSkills.${c.skillName}: source path does not exist: ${c.pathStr}"
      else if c.kind == "expected-file" then
        "programs.agent-skills.localSkills.${c.skillName}: path ends with .md but is a directory, not a file: ${c.pathStr}"
      else if c.kind == "expected-dir" then
        "programs.agent-skills.localSkills.${c.skillName}: path is not a directory (and does not end in .md): ${c.pathStr}"
      else "programs.agent-skills.localSkills.${c.skillName}: unknown validation error for ${c.pathStr}";
  }) localSkillChecks;

  # Build an activation script that (re)creates direct symlinks for all
  # localSkills under a given agent's skills directory.
  #
  # We intentionally bypass home.file here so that:
  #   - symlinks point straight at the real source (updates propagate instantly),
  #   - deleted skills get restored on the next `home-manager switch`
  #     (home.file only reconciles tracked paths at activation, and if nothing
  #     in the Nix store changed it would not touch user-deleted paths reliably),
  #   - we don't collide with the `recursive = true` tree used for packaged skills.
  #
  # Accepts either:
  #   - a directory (linked as-is at <agent>/<skillName>), or
  #   - any Markdown file (linked at <agent>/<skillName>/SKILL.md, with the
  #     containing directory created automatically).
  #
  # Activation-time defense in depth: even though we validate sources at eval
  # time (see localSkillAssertions above), the activation script still guards
  # against destroying the source file when a stale symlink from a prior
  # config causes the link path to resolve back into the source tree.
  mkLocalSkillActivation = agent:
    let
      agentRoot = "${config.home.homeDirectory}/${agent.path}";
      lines = lib.mapAttrsToList (skillName: skillPath:
        let
          pathStr = toString skillPath;
          isMarkdownFile = lib.hasSuffix ".md" pathStr;
          skillDir = "${agentRoot}/${skillName}";
          linkPath =
            if isMarkdownFile
            then "${skillDir}/SKILL.md"
            else skillDir;
        in
          if isMarkdownFile then ''
            # --- localSkill: ${skillName} (markdown file) ---
            src=${esc pathStr}
            dst=${esc linkPath}
            sdir=${esc skillDir}
            if [ ! -e "$src" ]; then
              echo "localSkills: source missing for '${skillName}': $src" >&2
            else
              # If skillDir exists as a symlink (leftover from a prior config
              # that symlinked the whole dir), remove it so we can own a real
              # directory here and never traverse back into the source tree.
              if [ -L "$sdir" ]; then
                $DRY_RUN_CMD rm -f "$sdir"
              fi
              $DRY_RUN_CMD mkdir -p "$sdir"
              # Refuse to overwrite the source with a self-link: if dst already
              # resolves to the same inode as src, do nothing.
              if [ -e "$dst" ] && [ "$(readlink -f -- "$dst" 2>/dev/null)" = "$(readlink -f -- "$src")" ] && [ ! -L "$dst" ]; then
                : # dst is the source file itself, leave it alone
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
      ) cfg.localSkills;
    in
      lib.concatStrings lines;
in
{
  options.programs.agent-skills = {
    enable = lib.mkEnableOption "agent skills from skills.nix";

    skills = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "List of skill derivations to install.";
      example = lib.literalExpression ''
        with inputs.skills-nix.packages.''${pkgs.stdenv.hostPlatform.system}; [
          workmux
          kagi-search
          context7
        ]
      '';
    };

    localSkills = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = { };
      description = ''
        Local (non-git, non-nix-store) skills to symlink directly.
        Keys are skill names, values are absolute paths to either:
          - a directory containing SKILL.md (symlinked as <agent>/<skillName>), or
          - any Markdown (.md) file (symlinked as <agent>/<skillName>/SKILL.md,
            so a containing directory is created automatically).
        These are symlinked as-is (mutable), so changes take effect immediately
        without rebuilding. Useful for private or unpublished skills.
      '';
      example = lib.literalExpression ''
        {
          air-workflow = /home/user/my-skills/air-workflow;
          my-private-skill = /home/user/my-skills/private;
          # Also accepted: any .md file — symlinked as <skillName>/SKILL.md
          chronoa = /home/user/Coding/chronoa/SKILL.md;
          notes    = /home/user/notes/some-skill.md;
        }
      '';
    };
  } // lib.mapAttrs (_: agent: {
    enable = lib.mkEnableOption agent.description;
  }) agents;

  config = lib.mkIf cfg.enable {
    home.file = lib.mkMerge (
      # Generate home.file entries for each enabled agent (packaged skills)
      lib.mapAttrsToList (name: agent:
        lib.mkIf cfg.${name}.enable {
          ${agent.path} = {
            source = mkDir agent.flatten;
            recursive = true;
          };
        }
      ) agents

    );

    # Fail fast at eval time if any localSkills source is missing or has the
    # wrong kind (e.g. .md suffix pointing at a directory).
    assertions = localSkillAssertions;

    # Install local skills via an activation script (out-of-store symlinks)
    # so that edits to the underlying files are reflected immediately and
    # user-deleted entries are restored on the next activation.
    home.activation = lib.mkMerge (lib.mapAttrsToList (name: agent:
      lib.mkIf (cfg.${name}.enable && cfg.localSkills != { }) {
        "localSkills-${name}" = lib.hm.dag.entryAfter [ "writeBoundary" ] (
          mkLocalSkillActivation agent
        );
      }
    ) agents);
  };
}
