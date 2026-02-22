# System Architecture

## Core Philosophy

skills.nix is a **catalog of agent skills** packaged with Nix, following the [Agent Skills standard](https://agentskills.io/specification). The architecture separates skill content from packaging infrastructure.

## Design Principles

### Skill Content is Independent of Packaging
- Skills live in `skills/<name>/` as standard Agent Skills directories
- Each skill is self-contained with `SKILL.md` + optional `scripts/`, `references/`, `assets/`
- Skills work without Nix — Nix is the distribution mechanism, not a requirement

### Blueprint Convention over Configuration
- Uses [numtide/blueprint](https://github.com/numtide/blueprint) with `prefix = "nix"`
- Folder structure drives flake outputs: `nix/packages/<name>/default.nix` → `packages.*.<name>`
- Zero boilerplate in `flake.nix` — blueprint handles multi-system, checks, formatter

### Catalog Approach
- Curated collection, not a framework
- Each skill is independently installable (`nix build .#<name>`)
- Meta-package `all` bundles everything via `symlinkJoin`

## Directory Structure

```
skills.nix/
├── flake.nix                         # Minimal blueprint entry (< 15 lines)
├── nix/
│   ├── lib/default.nix               # mkSkillsDir helper
│   ├── modules/home/default.nix      # Home-Manager module
│   └── packages/                     # Blueprint package definitions
│       ├── air-workflow/default.nix   # Local skill packages
│       ├── workmux/default.nix        # Remote skill package (grouped)
│       ├── kagi-search/default.nix
│       ├── context7/default.nix
│       ├── all/default.nix            # Meta-package (symlinkJoin)
│       ├── pi-skills/default.nix      # Per-agent bundles
│       ├── claude-skills/default.nix  #   (for local testing)
│       └── gemini-skills/default.nix
├── skills/                            # Local skill source content
│   ├── air-workflow/SKILL.md
│   ├── kagi-search/
│   │   ├── SKILL.md
│   │   └── scripts/search.sh
│   └── context7/
│       ├── SKILL.md
│       └── scripts/query.sh
├── air/                               # Air planning documents
├── research/FINDINGS.md
├── AGENTS.md
├── README.org
└── WORKMUX_WORKFLOW.md
```

## Package Output Structure

### Local skills (self-contained in this repo)

Each local skill derivation produces a single skill directory:
```
$out/share/agent-skills/<skill-name>/
├── SKILL.md
├── scripts/       # Optional
├── references/    # Optional
└── assets/        # Optional
```

### Remote skills (fetched from upstream repos)

Remote skill packages group all skills under a source directory named after the upstream project. This keeps skills organized and avoids name collisions between different sources:
```
$out/share/agent-skills/<source-name>/
├── <skill-a>/SKILL.md
├── <skill-b>/SKILL.md
└── <skill-c>/SKILL.md
```

Example — workmux (from `raine/workmux`):
```
$out/share/agent-skills/workmux/
├── coordinator/SKILL.md
├── merge/SKILL.md
├── open-pr/SKILL.md
├── rebase/SKILL.md
└── worktree/SKILL.md
```

### Combined output (via mkSkillsDir / home-manager module)

Per-agent packages and the home-manager module combine all skills into a flat directory that preserves grouping:
```
~/.agents/skills/          # (or ~/.claude/skills/, etc.)
├── air-workflow/SKILL.md  # Local skill (flat)
├── context7/SKILL.md      # Local skill (flat)
├── kagi-search/SKILL.md   # Local skill (flat)
└── workmux/               # Remote source (grouped)
    ├── coordinator/SKILL.md
    └── ...
```

Agents that support recursive SKILL.md discovery (e.g., Pi) find everything. The grouping is a convention — any future remote skill integration follows the same pattern.

## Blueprint Integration

### How Blueprint Maps This Project

| Path | Flake Output |
|------|-------------|
| `nix/packages/<name>/default.nix` | `packages.<system>.<name>` |
| `nix/lib/default.nix` | `lib` (mkSkillsDir) |
| `nix/modules/home/default.nix` | `homeModules.default` |
| (auto) | `checks.<system>.*` (from packages) |
| (auto) | `formatter.<system>` (nixfmt-tree) |

### Package Definition Pattern

Each package receives from blueprint's scope:
- `pkgs` — nixpkgs for the current system
- `lib` — nixpkgs.lib
- `pname` — derived from folder name
- `perSystem` — access to sibling packages (e.g., `perSystem.self.air-workflow`)
- `inputs`, `flake`, `system`

### Adding a New Local Skill

1. Create `skills/<name>/SKILL.md` with valid Agent Skills frontmatter
2. Create `nix/packages/<name>/default.nix` pointing to the skill source
3. Add the package to `nix/packages/all/default.nix`'s paths list
4. Output: `$out/share/agent-skills/<name>/SKILL.md`
5. Test: `nix build .#<name>` and `nix flake check`

### Adding a Remote Skill Source

Remote skill sources get a flake input + a single package that groups all skills under a source directory:

1. Add flake input: `<source>-src = { url = "github:org/repo/tag"; flake = false; }`
2. Create `nix/packages/<source>/default.nix` that installs to `$out/share/agent-skills/<source>/<skill>/`
3. Output: all skills nested under the source name (e.g., `workmux/coordinator/`, `workmux/merge/`)
4. Add to `nix/packages/all/default.nix` and per-agent packages
5. Test: `nix build .#<source>` and verify nested structure

## Target Agent Support

The home-manager module (`homeModules.default`) is the primary installation interface. It symlinks skills into agent-specific directories:

| Agent | Enable Flag | Directory | Discovery |
|-------|-------------|-----------|-----------|
| Pi | `pi.enable = true` | `~/.agents/skills/` | Recursive SKILL.md (confirmed) |
| Claude Code | `claude.enable = true` | `~/.claude/skills/` | `<name>/SKILL.md` pattern |
| Gemini CLI | `gemini.enable = true` | `~/.gemini/extensions/skills-nix/` | Extension with manifest |

Per-agent packages (`pi-skills`, `claude-skills`, `gemini-skills`) exist for local testing without home-manager.

## Technology Stack

- **Package Manager**: Nix flakes + numtide/blueprint
- **Skill Format**: Agent Skills standard (SKILL.md + YAML frontmatter)
- **Planning**: Air (airctl CLI)
- **Parallel Dev**: workmux (git worktrees + tmux)
- **Script Languages**: Bash (skill scripts use curl + jq)
