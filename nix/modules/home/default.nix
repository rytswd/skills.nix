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

  # Generate home.file entries for localSkills for a specific agent.
  # Each local skill gets a direct symlink (mutable, no nix store copy).
  # Accepts either:
  #   - a directory (symlinked as-is at <agent>/<skillName>), or
  #   - any Markdown file (symlinked at <agent>/<skillName>/SKILL.md so the
  #     skill still lives in its own directory).
  mkLocalSkillEntries = agentName: agent:
    lib.mapAttrs' (skillName: skillPath:
      let
        pathStr = toString skillPath;
        isMarkdownFile = lib.hasSuffix ".md" pathStr;
        linkPath =
          if isMarkdownFile
          then "${agent.path}/${skillName}/SKILL.md"
          else "${agent.path}/${skillName}";
      in
      lib.nameValuePair linkPath {
        source = config.lib.file.mkOutOfStoreSymlink pathStr;
      }
    ) cfg.localSkills;
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

      # Generate home.file entries for each enabled agent (local skills)
      ++ lib.mapAttrsToList (name: agent:
        lib.mkIf (cfg.${name}.enable && cfg.localSkills != { }) (
          mkLocalSkillEntries name agent
        )
      ) agents
    );
  };
}
