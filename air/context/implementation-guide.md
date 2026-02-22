# Implementation Guide

## Development Environment

### Prerequisites
- **Nix** with flakes enabled (`experimental-features = nix-command flakes`)
- **airctl** CLI for Air planning workflow
- **workmux** for parallel agent coordination (optional)
- **git** + **tmux** for workmux workflows

### Quick Start
```bash
# Build all skills
nix build .#all

# Build a specific skill
nix build .#air-workflow

# Check everything
nix flake check

# Show available outputs
nix flake show
```

## Coding Standards

### Nix Code (Blueprint Packages)

#### Local skill package

Each local skill in `nix/packages/<name>/default.nix` installs to a flat path:

```nix
{ pkgs, lib, pname, ... }:

pkgs.stdenvNoCC.mkDerivation {
  inherit pname;
  version = "0.1.0";
  src = ../../../skills/<name>;  # Relative path to skill source

  dontBuild = true;
  dontConfigure = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/agent-skills/${pname}
    cp -r . $out/share/agent-skills/${pname}/
    runHook postInstall
  '';

  meta = {
    description = "Agent skill: ${pname}";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
```

#### Remote skill package

Remote skill packages group all skills under a source directory. This is the standard pattern for any upstream integration:

```nix
{ pkgs, inputs, ... }:

pkgs.stdenvNoCC.mkDerivation {
  name = "<source>-skills";
  version = "<pinned-version>";
  src = "${inputs.<source>-src}/skills";  # Flake input with flake=false

  dontBuild = true;
  dontConfigure = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    for skill in */; do
      skill_name="''${skill%/}"
      if [ -f "$skill_name/SKILL.md" ]; then
        mkdir -p $out/share/agent-skills/<source>/$skill_name
        cp -r "$skill_name"/. $out/share/agent-skills/<source>/$skill_name/
      fi
    done
    runHook postInstall
  '';

  meta = {
    description = "Agent skills from upstream <source>";
    license = pkgs.lib.licenses.mit;
    platforms = pkgs.lib.platforms.all;
  };
}
```

Key convention: **remote skills always nest under `share/agent-skills/<source-name>/`** — this groups skills by origin and prevents name collisions between different upstreams.

### Skill Content (SKILL.md)

Follow the [Agent Skills specification](https://agentskills.io/specification):
- **Required frontmatter**: `name` (lowercase, hyphens, matches directory) and `description`
- **Name rules**: 1-64 chars, `[a-z0-9-]`, no leading/trailing/consecutive hyphens
- **Description**: Be specific about what AND when to use the skill
- **Body**: Keep under 500 lines; move detailed reference to separate files
- **Scripts**: Use relative paths from skill directory, include shebang and `set -euo pipefail`

### Bash Scripts (Skill Scripts)

```bash
#!/usr/bin/env bash
set -euo pipefail

# Validate dependencies
for cmd in curl jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: '$cmd' is required but not installed." >&2
    exit 1
  fi
done

# Validate required env vars
if [ -z "${API_KEY:-}" ]; then
  echo "Error: API_KEY environment variable is not set." >&2
  exit 1
fi
```

## Air Workflow

### Document State Management

**Always use `airctl update` to change document states** — never edit `#+state:` manually:

```bash
# Check current status
airctl status
airctl status --state ready
airctl status --state work-in-progress

# Update state
airctl update air/v0.1/feature.org --state work-in-progress --force
airctl update air/v0.1/feature.org --state complete --force

# Add/remove tags
airctl update air/v0.1/feature.org --add-tag nix,blueprint
airctl update air/v0.1/feature.org --remove-tag draft-only

# Preview changes
airctl update air/v0.1/feature.org --state ready --dry-run
```

### State Transitions

```
draft → ready → work-in-progress → complete
  │       │              │             │
  ├───────┴──────────────┘             │
  │                                    │
  ▼                                    ▼
dropped                             archive/
```

- **draft → ready**: Spec is complete, all sections filled, approach confirmed
- **ready → work-in-progress**: Implementation starting, update immediately
- **work-in-progress → complete**: All tests pass, history updated
- **draft/ready/work-in-progress → dropped**: No longer needed or viable
- **complete → archive/**: Moved to archive directory for reference

### Always Update History

When changing state, add an Implementation History entry explaining why:
```
* History
- 2026-02-21: Initial draft created
- 2026-02-21: Moved to ready after review
- 2026-02-21: Reverted to draft — Nix infra migrating to blueprint
```

## Workmux Parallel Development

### When to Use Workmux

Use workmux when you have **independent tasks that can run in parallel** with non-overlapping file scopes.

### Key Patterns

**Spawning agents:**
```bash
workmux add <branch-name> --background --prompt "..."
```

**Monitoring:**
```bash
workmux list                           # See all worktrees
tmux capture-pane -t 0:<window> -p | tail -15  # Check agent output
ls $(workmux path <name>)/expected-output/     # Check deliverables
```

**Merging (orchestrator must commit first!):**
```bash
git add -A && git commit -m "orchestrator work"  # Clean main first
cd $(workmux path <name>) && git add -A && git commit -m "..."
workmux merge <name>
```

### Rules for Agent Prompts

1. **Explicit file scope**: "Only modify files in ./nix/ directory"
2. **Clear deliverables**: "Create nix/packages/air-workflow/default.nix"
3. **Context references**: "Read ./air/v0.1/skill-installation-for-nix.org"
4. **Commit instructions**: "When done, run: git add -A && git commit -m '...'"
5. **Negative scope**: "Do NOT modify air/, skills/, README.org"

### Anti-Patterns

- ❌ Overlapping file scopes between agents
- ❌ Forgetting to commit orchestrator changes before `workmux merge`
- ❌ No file scope constraints in prompts
- ❌ Spawning more than 3-4 parallel agents

## Testing

### Nix Builds
```bash
# Individual skill
nix build .#air-workflow
find -L result/ -type f  # Verify output structure

# All skills
nix build .#all

# Full check (blueprint auto-generates checks from packages)
nix flake check
```

### Skill Validation
- Verify SKILL.md has valid `name` and `description` frontmatter
- Verify name matches parent directory
- Verify scripts are executable and have shebangs
- Test scripts with missing env vars (should error gracefully)

## Git Conventions

### Commit Message Prefixes
- `feat:` — New skill or feature
- `refactor:` — Restructuring (e.g., blueprint migration)
- `docs:` — Air docs, README, context files
- `fix:` — Bug fixes
- `chore:` — Maintenance, CI, gitignore
