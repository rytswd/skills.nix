---
name: workmux-workflow
description: Orchestration patterns for coordinating parallel AI agents using workmux. Use when delegating tasks to multiple agents, planning parallel work, spawning workmux agents, or managing multi-agent workflows with git worktrees.
compatibility: Requires workmux, git, and tmux.
metadata:
  version: "0.1"
  author: skills-nix
---

# Workmux Workflow

Patterns and best practices for orchestrating parallel AI agents using [workmux](https://github.com/raine/workmux). This skill covers the orchestrator's role — planning, spawning, monitoring, and merging agent work.

## Core Principle

Split work into **independent tasks with non-overlapping file scopes**, run them in parallel, then merge sequentially.

```
[agent-a: skills/]  ───────┐
                            ├──→ merge → [agent-c: README.org]
[agent-b: nix/packages/] ──┘
```

## Workflow

### 1. Plan — Define Non-Overlapping Scopes

Before spawning agents, identify tasks that write to completely separate paths:

| Agent | File Scope | Why Independent |
|-------|-----------|-----------------|
| `research` | `research/` | Read-only exploration, no code changes |
| `nix-infra` | `nix/packages/`, `nix/lib/` | Infrastructure only |
| `write-skills` | `skills/` | Content only |

**Rule**: Two agents must never write to the same file. This guarantees clean merges.

### 2. Commit Orchestrator Changes First

Main branch must be clean before any merge. Always commit your own work first:

```bash
git add -A && git commit -m "docs: update plan before spawning agents"
```

### 3. Spawn Independent Agents

```bash
workmux add agent-a --background --prompt "
You are implementing X.

## Context
Read ./path/to/spec.md for full requirements.

## File Scope
ONLY modify files in: nix/packages/
Do NOT touch: skills/, README.org, flake.nix

## When Done
git add -A && git commit -m 'feat: description of work'
"

workmux add agent-b --background --prompt "..."
```

**Prompt checklist**:
- [ ] Context file references (what to read first)
- [ ] Explicit file scope (what they CAN modify)
- [ ] Negative scope (what they must NOT touch)
- [ ] Build/test commands to verify their work
- [ ] Commit instructions with message template

### 4. Monitor Progress

```bash
# Check all agents
workmux list

# Read agent terminal output
tmux capture-pane -t 0:<window> -p | tail -15

# Check if agent committed
cd $(workmux path agent-a) && git log --oneline -3

# Check deliverables exist
ls $(workmux path agent-a)/expected/output/path
```

### 5. Review and Merge

Review each agent's work before merging:

```bash
# Review changes
cd $(workmux path agent-a) && git diff HEAD~1

# If agent didn't commit, do it for them
cd $(workmux path agent-a) && git add -A && git commit -m "feat: ..."

# Merge into main (must be on main with clean working tree)
workmux merge agent-a
```

Merge one at a time. After each merge, main has the new changes available for the next merge.

### 6. Spawn Dependent Agents

After independent agents merge, spawn agents that depend on their output:

```bash
workmux add agent-c --background --prompt "
Read the output from the previous agents:
- ./research/FINDINGS.md (merged from research agent)
- ./nix/packages/ (merged from infra agent)

Now implement: ...
"
```

### 7. Clean Up

```bash
workmux list
# Should only show main — all worktrees cleaned up after merge
```

## Anti-Patterns

### ❌ Overlapping File Scopes

Never let two agents modify the same files. This guarantees merge conflicts.

**Bad**: Two agents both writing to `README.org`

**Good**: One agent writes `nix/`, another writes `skills/`, a third updates `README.org` after both merge.

### ❌ Missing File Scope in Prompts

Without explicit constraints, agents may helpfully modify README, AGENTS.md, or other shared files. Always include:

```
## File Scope
ONLY modify: nix/packages/new-skill/
Do NOT touch: flake.nix, skills/, README.org
```

### ❌ Forgetting to Commit Before Merge

`workmux merge` requires a clean main branch. If you have uncommitted changes, commit them first.

### ❌ Too Many Parallel Agents

More than 3–4 parallel agents becomes hard to monitor. Each needs review, possible manual commits, and sequential merging.

### ❌ Large Tasks Without Checkpoints

If an agent runs 10+ minutes with no output, you can't tell if it's stuck. Break large tasks into smaller sequential steps, or include intermediate deliverables.

## Prompt Template

```
You are implementing [TASK DESCRIPTION].

## Context — Read FIRST
- ./path/to/spec (the design specification)
- ./path/to/reference (relevant existing code)

## Tasks
1. [Specific deliverable]
2. [Specific deliverable]
3. Test: [exact commands to run]

## File Scope
ONLY create/modify files in: [paths]
Do NOT modify: [paths]

## Commit
git add -A && git commit -m '[type]: [description]'
```

## Tips

- **Use `$(workmux path <name>)`** to reference files in a worktree from the orchestrator
- **Include test commands** in prompts — agents that verify their own work produce better results
- **Commit orchestrator state before spawning** — Air doc updates, plan notes, etc.
- **Review diffs before merging** — `cd $(workmux path agent) && git diff HEAD~1`
- **Sequential dependencies are fine** — not everything needs to be parallel; the value is parallelizing what can be parallelized
