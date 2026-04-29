---
name: my-tools
description: >-
  The user's package-manager, build-tool, editor, and local-path
  preferences on this machine. Load before suggesting `install`,
  `add`, `fetch`, build commands, or invoking an editor / formatter /
  LSP; describes which tools are allowed, which are banned, how to
  invoke one-off tools, and where repos and scratch dirs live.
metadata:
  version: "0.1"
  author: skills-nix
  template: "true"
---

# My Tools

> **Template skill.** This file ships empty by design. Replace each
> section below with concrete, short facts about *your* setup.
> Delete sections you don't care about; empty sections waste context
> tokens and dilute the description's trigger.
>
> See `programs.agent-skills.localSkills` in skills.nix for how to
> mount your own copy.

## Package managers in use
<!-- e.g. "Nixpkgs via flakes; home-manager for user packages." -->

## Banned / avoid
<!-- e.g. "Never `nix profile install`, `apt`, `brew`, `npm install -g`." -->

## Preferred one-off invocation
<!-- e.g. "`nix run nixpkgs#<pkg>` or `nix shell nixpkgs#<pkg>` for throwaway tools." -->

## Build / test commands
<!-- e.g. "`just test`, `nix flake check`, `cargo test --workspace`." -->

## Editor / LSP / formatter
<!-- e.g. "Helix everywhere; rustfmt on save; no LSP restart on save." -->

## Stable local paths
<!-- e.g. "Repos live under `~/Coding/github.com/<owner>/<repo>`." -->
