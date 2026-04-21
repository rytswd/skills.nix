{ flake, inputs, ... }:
{ config, lib, pkgs, ... }:
let
  cfg = config.programs.agent-skills;

  inherit (flake.lib) mkSkillsDir mkLocalSkillsPreflight mkLocalSkillsActivation;

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
    # Packaged skills: build a store tree and let home-manager install it
    # recursively as individual symlinks under each enabled agent's dir.
    home.file = lib.mkMerge (lib.mapAttrsToList (name: agent:
      lib.mkIf cfg.${name}.enable {
        ${agent.path} = {
          source = mkDir agent.flatten;
          recursive = true;
        };
      }
    ) agents);

    # Local skills: installed via activation scripts (out-of-store symlinks)
    # so that edits to the underlying files are reflected immediately and
    # user-deleted entries are restored on the next activation.
    #
    # A pre-flight validation runs before `writeBoundary` so any bad
    # configuration aborts the switch *before* any file mutation occurs.
    home.activation = lib.mkMerge (
      [
        (lib.mkIf (cfg.localSkills != { }) {
          localSkills-preflight = lib.hm.dag.entryBefore [ "writeBoundary" ] (
            mkLocalSkillsPreflight { localSkills = cfg.localSkills; }
          );
        })
      ]
      ++ lib.mapAttrsToList (name: agent:
        lib.mkIf (cfg.${name}.enable && cfg.localSkills != { }) {
          "localSkills-${name}" = lib.hm.dag.entryAfter [ "writeBoundary" ] (
            mkLocalSkillsActivation {
              agentRoot = "${config.home.homeDirectory}/${agent.path}";
              localSkills = cfg.localSkills;
            }
          );
        }
      ) agents
    );
  };
}
