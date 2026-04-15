---
name: jj-workmux
description: Workarounds for using workmux with jj (Jujutsu) repositories. Use when spawning workmux agents in a jj-managed repo, whether colocated with git or native jj.
compatibility: Requires workmux, jj, and tmux. Git required for colocated repos.
metadata:
  version: "0.1"
  author: skills-nix
---

# jj + Workmux Integration

Workmux uses git worktrees internally. jj repos need workarounds because workmux expects a standard git layout.

This skill supplements the `workmux-workflow` skill — read that first for the general workflow.

## Colocated Repos (jj + git)

In a jj+git colocated repo, `.git/HEAD` points to `refs/jj/root` instead of a real branch. This breaks workmux's main worktree detection.

### Spawn Workaround

Fix `HEAD` before every `workmux add`, and avoid running any `jj` command in between (jj operations reset HEAD):

```bash
git symbolic-ref HEAD refs/heads/main && \
workmux add <name> --base main --background --prompt-file /tmp/prompts/<name>.md
```

- `git symbolic-ref HEAD refs/heads/main` — points HEAD at the real branch so workmux can create worktrees
- `--base main` — explicit base branch since jj's working copy (`@`) has no bookmark
- **No `jj` commands between these two** — any jj operation resets HEAD back to `refs/jj/root`

### Batch Spawning

When spawning multiple agents, run the `git symbolic-ref` once and chain all `workmux add` calls without jj in between:

```bash
git symbolic-ref HEAD refs/heads/main && \
workmux add agent-a --base main --background --prompt-file /tmp/prompts/agent-a.md && \
workmux add agent-b --base main --background --prompt-file /tmp/prompts/agent-b.md && \
workmux add agent-c --base main --background --prompt-file /tmp/prompts/agent-c.md
```

### Agent Git Issues

Agents in worktrees may encounter git configuration issues because jj's colocated setup has non-standard git config. Common problems:

- **Detached HEAD in worktree** — agent can't commit. Fix: `cd $(workmux path <name>) && git checkout -b temp-branch`
- **Agent runs `git init`** — corrupts the worktree link. If this happens, copy changed files manually instead of merging:

```bash
diff -rq $(workmux path <name>)/src ./src --exclude=target
cp $(workmux path <name>)/src/changed_file.rs ./src/changed_file.rs
```

### Merging Back to jj

After `workmux merge`, the changes appear in git. jj picks them up automatically on the next jj operation. Run `jj status` to see the merged changes in jj's working copy.

## Native jj Repos (no git colocate)

Without `.git/`, workmux cannot function — it depends on git worktrees. Options:

1. **Temporarily enable colocating** — `jj git init --colocate` (if the repo supports it)
2. **Don't use workmux** — use manual parallel workflows instead (multiple checkouts, tmux panes)

## Quick Reference

```bash
# Spawn (colocated)
git symbolic-ref HEAD refs/heads/main && \
workmux add <name> --base main --background --prompt-file /tmp/prompts/<name>.md

# Check agent status
workmux list

# Review agent work
cd $(workmux path <name>) && git diff HEAD~1

# Merge
workmux merge <name>

# Clean up broken worktree
workmux remove --force <name>

# After all merges, verify jj sees the changes
jj status
jj log --limit 5
```
