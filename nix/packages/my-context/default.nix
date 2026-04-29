# `my-context` CLI: seed the user-context skill templates (my-env,
# my-tools, my-style, my-workflow) into a target directory so the user
# can fill them in and mount them via `programs.agent-skills.localSkills`.
#
# Usage (after `nix flake update`):
#   nix run github:rytswd/skills.nix#my-context
#   nix run github:rytswd/skills.nix#my-context -- -o ~/dotfiles/skills
#   nix run github:rytswd/skills.nix#my-context -- -o ~/skills my-env my-tools
#   nix run github:rytswd/skills.nix#my-context -- --force -o ~/skills
{ pkgs, perSystem, ... }:

let
  templates = {
    my-env      = perSystem.self.my-env;
    my-tools    = perSystem.self.my-tools;
    my-style    = perSystem.self.my-style;
    my-workflow = perSystem.self.my-workflow;
  };
in
pkgs.writeShellApplication {
  name = "my-context";
  runtimeInputs = [ pkgs.coreutils ];
  text = ''
    set -euo pipefail

    usage() {
      cat <<'EOF'
    Seed the user-context skill templates into a target directory.

    Usage:
      my-context [-o DIR] [--force] [SKILLS...]
      my-context -h | --help

    Options:
      -o, --output DIR   Directory to write into (default: current directory).
      --force            Overwrite existing files (default: skip).
      -h, --help         Show this help.

    Positional args are skill names from {my-env, my-tools, my-style,
    my-workflow}. With none given, all four are seeded.

    Examples:
      my-context                                    # all four → ./
      my-context -o ~/dotfiles/skills               # all four → ~/dotfiles/skills
      my-context -o ~/dotfiles/skills my-env        # only my-env
      my-context my-env my-tools                    # subset → ./
      my-context --force -o ~/dotfiles/skills       # overwrite existing

    After seeding, edit each file with concrete facts about your
    machine and mount them via programs.agent-skills.localSkills.
    See: https://github.com/rytswd/skills.nix#user-context-templates
    EOF
    }

    force=0
    target="."
    skills=()

    while [ $# -gt 0 ]; do
      case "$1" in
        -h|--help) usage; exit 0 ;;
        --force) force=1; shift ;;
        -o|--output)
          if [ $# -lt 2 ]; then
            echo "my-context: $1 requires a directory argument" >&2
            exit 2
          fi
          target="$2"; shift 2
          ;;
        --output=*) target="''${1#--output=}"; shift ;;
        -o=*)       target="''${1#-o=}"; shift ;;
        --) shift; while [ $# -gt 0 ]; do skills+=("$1"); shift; done ;;
        -*) echo "my-context: unknown flag: $1" >&2; usage >&2; exit 2 ;;
        *)  skills+=("$1"); shift ;;
      esac
    done
    if [ ''${#skills[@]} -eq 0 ]; then
      skills=(my-env my-tools my-style my-workflow)
    fi

    mkdir -p "$target"

    declare -A SOURCES=(
      [my-env]="${templates.my-env}/share/agent-skills/my-env/SKILL.md"
      [my-tools]="${templates.my-tools}/share/agent-skills/my-tools/SKILL.md"
      [my-style]="${templates.my-style}/share/agent-skills/my-style/SKILL.md"
      [my-workflow]="${templates.my-workflow}/share/agent-skills/my-workflow/SKILL.md"
    )

    created=0
    skipped=0
    written_skills=()

    for s in "''${skills[@]}"; do
      if [ -z "''${SOURCES[$s]:-}" ]; then
        echo "my-context: unknown skill: $s" >&2
        echo "  must be one of: my-env, my-tools, my-style, my-workflow" >&2
        exit 2
      fi
      dst="$target/$s.md"
      if [ -e "$dst" ] && [ "$force" -eq 0 ]; then
        echo "skip:  $dst (exists; use --force to overwrite)"
        skipped=$((skipped + 1))
        continue
      fi
      cp "''${SOURCES[$s]}" "$dst"
      chmod u+w "$dst"   # nix store files are read-only
      echo "wrote: $dst"
      created=$((created + 1))
      written_skills+=("$s")
    done

    echo ""
    echo "Done: $created written, $skipped skipped."

    if [ $created -gt 0 ]; then
      cat <<EOF

    Next:
      1. Edit each file with concrete facts about your machine.
         An empty / unfilled section is worse than no skill at all —
         delete sections you don't care about.
      2. Mount only the ones you actually filled in via
         programs.agent-skills.localSkills:

           localSkills = {
    EOF
      for s in "''${written_skills[@]}"; do
        printf '         %-12s = "%s/%s.md";\n' "$s" "$(realpath "$target")" "$s"
      done
      cat <<'EOF'
           };
    EOF
    fi
  '';

  meta = {
    description = "Seed the user-context skill templates (my-env / my-tools / my-style / my-workflow) into a target directory";
    license = pkgs.lib.licenses.mit;
    platforms = pkgs.lib.platforms.all;
    mainProgram = "my-context";
  };
}
