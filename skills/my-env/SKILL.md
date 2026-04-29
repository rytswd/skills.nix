---
name: my-env
description: >-
  The user's machine and shell environment on this host: OS, distro,
  window manager, hardware notes, default shell, and how local
  secret-storage tools are reached. Load before suggesting commands
  that depend on the shell, terminal, OS, or that need to retrieve
  credentials from the user's secret store.
metadata:
  version: "0.1"
  author: skills-nix
  template: "true"
---

# My Environment

> **Template skill.** This file ships empty by design. Replace each
> section below with concrete, short facts about *your* machine.
> Delete sections you don't care about; empty sections waste context
> tokens and dilute the description's trigger.
>
> See `programs.agent-skills.localSkills` in skills.nix for how to
> mount your own copy.

## Machine / OS
<!-- e.g. "NixOS 25.05 on X1 Carbon Gen 11; Linux 6.x." -->

## Window manager / desktop
<!-- e.g. "niri (scrollable WM); no floating windows." -->

## Shell / prompt / direnv
<!-- e.g. "fish + starship; direnv auto-loads devshells on `cd`." -->

## Terminal
<!-- e.g. "WezTerm with tmux; truecolor + Nerd Fonts." -->

## Secret storage
<!-- e.g. "`pass` for everything; e.g. `pass kagi/key`. No 1Password." -->
