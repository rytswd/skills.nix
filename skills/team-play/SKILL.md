---
name: team-play
description: Distinguished / staff+ level team role prompts for AI agents. Use when an agent needs to adopt a specific professional role — code reviewer, engineer, security analyst, UX designer, orchestrator, etc. Each role prompt sets expectations, criteria, and output format appropriate for a senior specialist.
compatibility: Any agent that supports SKILL.md. Role prompts are language/framework-specific where noted.
metadata:
  version: "0.1"
  author: skills-nix
---

# Team Play

A collection of role prompts that shape an agent into a distinguished-level specialist. Each prompt establishes:

- **Identity** — Who the agent is (e.g., "You are a distinguished Zig engineer reviewing a CLI refactor")
- **Standards** — Non-negotiable quality bars (e.g., "No function > 40 lines")
- **Criteria** — What to evaluate or produce, with concrete checklists
- **Verification** — How to confirm you're on track at every step, not just at the end
- **Output format** — How to deliver results (e.g., categorized findings, structured code)

All prompts target **distinguished / staff+ level** performance — the kind of work where no reviewer could find fault.

Every role includes a **verification loop** — concrete steps to test your work continuously. Engineers build and run after every function, not just before committing. Reviewers reproduce issues before filing them. Security analysts prove exploitability, not just pattern-match. Designers use the actual interface, not just inspect the code.

A core principle across all roles: **fix the root cause, not the symptom**. When you find a bug, a vulnerability, or a UX problem, ask "why did this happen?" — and keep asking until you reach the structural issue. A patched symptom means the same class of problem shows up elsewhere next week. A fixed root cause means it can't.

- An engineer who finds a memory leak doesn't just add a `defer` — they ask why the allocation pattern made it easy to forget, and restructure so forgetting is impossible.
- A reviewer who spots a missing null check doesn't just flag that one instance — they identify why the API allows null in the first place and suggest a type-level fix.
- A security analyst who finds an injection doesn't just escape that one input — they identify the missing validation layer and propose a systemic boundary.
- A designer who sees a confusing error message doesn't just rewrite the text — they ask why the user reached an error state at all and redesign the flow to prevent it.

## Roles

### `reviewer/`

Code review specialists. They read code, identify issues, and produce structured review findings. They do NOT modify source files.

| File | Focus |
|------|-------|
| `zig.md` | Zig idioms, memory safety, error sets, allocator discipline |
| `rust.md` | Ownership, lifetimes, error handling, trait design, unsafe audit |
| `go.md` | Error handling, goroutine safety, interface design, stdlib usage |
| `svelte.md` | Reactivity, component structure, accessibility, Svelte 5 runes |

### `engineer/`

Implementation specialists. They write production code to a self-review standard — code ships without needing external review.

| File | Focus |
|------|-------|
| `zig.md` | Systems-level Zig — modules, tests, allocator hygiene, build.zig |
| `rust.md` | Idiomatic Rust — ownership-first design, error types, async patterns |
| `go.md` | Production Go — error wrapping, context propagation, testable design |
| `svelte.md` | Svelte 5 — runes, components, SSR, SvelteKit patterns |

### `security/`

Security-focused analysis. They audit code and architecture for vulnerabilities, misconfigurations, and supply chain risks.

| File | Focus |
|------|-------|
| `code-audit.md` | Source-level vulnerability analysis — injection, auth, crypto, secrets |
| `infra.md` | Infrastructure review — cloud config, network, IAM, container security |
| `supply-chain.md` | Dependency audit — known CVEs, typosquatting, pinning, SBOM |

### `orchestrator/`

Coordination specialists. They decompose work, delegate to specialist agents with precise prompts, monitor progress, and spin up follow-up agents. They do NOT write code themselves.

| File | Focus |
|------|-------|
| `manager.md` | Work decomposition, agent prompting, monitoring, integration verification |

### `ux-designer/`

UX design specialists. They evaluate and design user experiences with platform-appropriate patterns and accessibility standards.

| File | Focus |
|------|-------|
| `cli.md` | CLI UX — flag design, help text, error messages, progressive disclosure |
| `tui.md` | TUI UX — layout, keybindings, focus management, terminal compatibility |
| `web-frontend.md` | Web UX — responsive design, accessibility (WCAG), performance, navigation |
| `mobile.md` | Mobile UX — touch targets, gestures, platform conventions (iOS/Android) |
| `tablet.md` | Tablet UX — adaptive layouts, multitasking, stylus support, split views |

## How to Use These

These are **reference templates, not drop-in system prompts**. Each role doc captures the standards and verification practices of a distinguished specialist. An agent should read the relevant doc, internalize the principles, and then apply them to the specific project — adapting language, thresholds, and criteria to the codebase at hand.

### What "reference" means

- **Read and adapt** — read `reviewer/rust.md` to understand what a distinguished Rust reviewer cares about, then write your own review criteria that fits this project's specific patterns, dependencies, and conventions
- **Don't copy-paste verbatim** — a prompt that says "No function > 40 lines" might need to be "No function > 60 lines" for your project, or irrelevant entirely. The point is the *principle* (functions do one thing), not the specific number
- **Combine and specialise** — a security-focused Rust engineer reads both `engineer/rust.md` and `security/code-audit.md`, takes the relevant parts from each, and produces a role prompt tailored to the project

### Referencing a role

In a workmux prompt or agent setup:

```
Read team-play/reviewer/zig.md as reference for review standards.
Apply those standards to the code in src/ — adapt the criteria
to this project's build system and conventions.
```

Or compose roles:

```
Read team-play/engineer/rust.md and team-play/security/code-audit.md.
You are an engineer who writes secure-by-default code. Use the
engineer standards for code quality, and the security audit criteria
as your self-review checklist for every function that handles input.
```

### Adapting to a project

When generating a project-specific role prompt from these references:

1. **Fill in the Project Context section** — every role file has a placeholder section for project-specific details (files to read, build commands, conventions)
2. **Adjust thresholds** — function length limits, test count expectations, performance budgets
3. **Set output targets** — where to write findings, commit message format, branch strategy
4. **Drop irrelevant sections** — a CLI project doesn't need the async/SSR criteria from Svelte
5. **Add project-specific criteria** — your linter config, your error handling conventions, your naming patterns

Note: this directory may contain additional role definitions beyond the built-in ones listed above. Check the directory listing for the full set of available roles.
