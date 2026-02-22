# Project Context for Claude

This project uses Air for planning-first workflow.
Please review these context files to understand the project:

## Essential Context
Review these files for project understanding:
- ./air/context/OVERVIEW.md — Project description, skills catalog, target agents
- ./air/context/architecture.md — Directory structure, blueprint integration, package patterns
- ./air/context/implementation-guide.md — Dev environment, coding standards, airctl/workmux usage
- ./air/context/interface-design.md — Nix CLI interface, skill content design, README conventions

## Air Workflow

### Checking Status
```bash
airctl status                              # Full status
airctl status --state ready                # Work ready for implementation
airctl status --state work-in-progress     # Currently active work
airctl status --state draft                # Work still being planned
```

### Updating Documents
**Always use `airctl update` — never edit `#+state:` manually:**
```bash
airctl update air/v0.1/doc.org --state work-in-progress --force
airctl update air/v0.1/doc.org --state complete --force
airctl update air/v0.1/doc.org --add-tag blueprint --force
```

### Before Implementation
1. Check current status: `airctl status --state work-in-progress,ready`
2. Read the relevant Air document in `./air/v0.1/`
3. Update state to `work-in-progress` via `airctl update` before starting
4. Follow conventions in `./air/context/implementation-guide.md`
5. Update History section in the Air doc after completing work
6. Update state to `complete` via `airctl update` when done

## Nix Development

This project uses [numtide/blueprint](https://github.com/numtide/blueprint) with `prefix = "nix"`:
- Packages defined in `nix/packages/<name>/default.nix`
- `flake.nix` is minimal — blueprint handles everything
- Test with: `nix build .#<name>`, `nix flake check`

## Workmux Coordination

When delegating to parallel agents, follow `./WORKMUX_WORKFLOW.md`:
- Define non-overlapping file scopes per agent
- Include explicit commit instructions in prompts
- Commit orchestrator changes before `workmux merge`
- Monitor with `tmux capture-pane` or `workmux status`

## Creating New Features
For features without Air docs:
1. Create an Air document: `airctl new` or manually in `./air/v0.1/`
2. Set initial state to `draft` via frontmatter
3. Get approval before moving to `ready` via `airctl update`
4. Follow the workflow described in context files

## Important Notes
- Always check existing Air docs before implementing
- Update document state with `airctl update` when work completes
- Keep History sections current in Air docs
- Follow the Agent Skills standard for all skills
