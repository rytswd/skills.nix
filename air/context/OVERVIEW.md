# Project Overview

## Description

**skills.nix** is a Nix-packaged collection of agent skills following the [Agent Skills standard](https://agentskills.io/specification), along with the infrastructure to package and distribute any skill via Nix. Think of it as an "awesome-list" of agent skills with one-command Nix installation.

## Core Principles

- **Nix-first distribution** - All skills installable via Nix flake, with reproducible builds
- **Multi-agent support** - Skills target Pi, Claude Code, OpenCode, Gemini, and Codex
- **Agent Skills standard** - Every skill follows the agentskills.io specification
- **Catalog approach** - Curated collection of useful skills, easy to discover and install
- **Planning-first methodology** - [Air](https://github.com/withre/air) documents drive all design and implementation

## Technology Stack

- **Package Manager**: Nix (flakes)
- **Skill Format**: Agent Skills standard (SKILL.md + optional scripts/references/assets)
- **Target Agents**: Pi, Claude Code, OpenCode, Gemini CLI, Codex
- **Planning**: [Air](https://github.com/withre/air) planning-first workflow
- **Languages**: Nix (packaging), Bash/TypeScript/Python (skill scripts)

## Project Structure

```
skills.nix/
├── flake.nix              # Nix flake - main entry point
├── lib/
│   └── mkSkill.nix        # Skill builder function
├── skills/                # Individual skills
│   ├── air-workflow/
│   │   └── SKILL.md
│   ├── workmux/
│   │   └── SKILL.md
│   ├── kagi-search/
│   │   ├── SKILL.md
│   │   └── scripts/
│   └── context7/
│       ├── SKILL.md
│       └── scripts/
├── air/                   # Air planning documents
│   ├── v0.1/              # Current milestone
│   └── context/           # Generated context files
├── AGENTS.md              # Agent context
└── README.org             # Project documentation
```

## v0.1 Skills Catalog

| Skill | Description | Status |
|-------|-------------|--------|
| air-workflow | Air planning-first methodology | Draft |
| workmux | Workmux parallel development workflows | Draft |
| kagi-search | Web search via Kagi API | Draft |
| context7 | Context7 library documentation lookup | Draft |

## Target Agent Priority

1. **Pi** - Primary target, native Agent Skills support
2. **Claude Code** - `.claude/skills/` directory
3. **OpenCode** - OpenCode skill configuration
4. **Gemini CLI** - Gemini skill setup
5. **Codex** - Codex skill integration

Each agent is handled separately due to different configuration mechanisms.

## Document States (Air Workflow)

- `draft` - Initial planning phase
- `ready` - Specification complete, ready for execution
- `work-in-progress` - Currently being executed
- `complete` - Execution finished
- `dropped` - No longer needed
- `unknown` - State cannot be determined

## Current Focus

Use `airctl status --state work-in-progress,ready` to see current priorities.
