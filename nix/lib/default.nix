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
