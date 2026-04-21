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
            $DRY_RUN_CMD mkdir -p ${esc skillDir}
            $DRY_RUN_CMD ln -sfn ${esc pathStr} ${esc linkPath}
          '' else ''
            $DRY_RUN_CMD mkdir -p ${esc agentRoot}
            if [ -L ${esc linkPath} ] || [ -f ${esc linkPath} ]; then
              $DRY_RUN_CMD rm -f ${esc linkPath}
            fi
            $DRY_RUN_CMD ln -sfn ${esc pathStr} ${esc linkPath}
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
