# Interface Design

## Overview

skills.nix is primarily a Nix flake — users interact through standard Nix CLI commands. The "interface" is the flake output structure and the skill content format.

## User-Facing Interface

### Nix CLI (Primary)

```bash
# Discover what's available
nix flake show github:rytswd/skills.nix

# Try / build a skill
nix build github:rytswd/skills.nix#air-workflow

# Build locally
nix build .#kagi-search

# Add to system config (recommended, like numtide/llm-agents.nix)
# inputs.skills-nix.url = "github:rytswd/skills.nix";
# environment.systemPackages = [ inputs.skills-nix.packages.${system}.air-workflow ];
```

### Skill Invocation (Agent-Side)

Once installed, skills are invoked by the agent:
```
/skill:air-workflow          # Pi command
/skill:kagi-search query     # Pi with arguments
```

Or auto-invoked when the agent detects a matching task from the skill description.

## Skill Content Design

### SKILL.md Structure

Skills follow progressive disclosure:
1. **Frontmatter** (~100 tokens): Loaded at startup for all skills
2. **Body** (< 500 lines): Loaded when skill is activated
3. **Referenced files**: Loaded only when needed

### Description Quality

The description is the most important field — it determines when the agent loads the skill.

**Good** (specific triggers):
```yaml
description: Web search via Kagi Search API. Use when you need to search the web,
  look up current information, find documentation, or verify facts.
```

**Bad** (vague):
```yaml
description: Helps with searching.
```

### Script Output Format

Skill scripts should output human-readable text that agents can parse:
- Use numbered results with clear structure
- Include error messages on stderr
- Return non-zero exit codes on failure
- Show usage on invalid arguments

## README.org Conventions

The README follows the style of [rytswd/pi-agent-extensions](https://github.com/rytswd/pi-agent-extensions):
- Org-mode format with `#+TITLE:`, `#+AUTHOR:`, `#+OPTIONS:`
- Centered badges in `#+html:` blocks
- Collapsible `#+html:<details>` sections for installation methods and skill details
- Tables for catalog overview
- Code blocks with `#+begin_src` / `#+end_src`
- Structure section with `#+begin_example` tree diagram
