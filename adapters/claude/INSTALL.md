# Waypoint — Claude Code Adapter

## What this does

Installs a project rule at `.claude/rules/waypoint.md` that Claude Code loads
automatically at the start of every session. It instructs Claude to run the
Waypoint session briefing before acting on a request.

Claude Code loads every `.md` file in `.claude/rules/` (without `paths`
frontmatter) into context each session, at the same priority as a project
`CLAUDE.md`. Using a dedicated rule file keeps the briefing separate from — and
never disturbs — your own `CLAUDE.md`.

## Installation

```bash
mkdir -p .claude/rules
cp path/to/waypoint/adapters/claude/rules/waypoint.md .claude/rules/waypoint.md
```

This is purely additive: it creates one file and touches nothing else, so it is
safe alongside an existing `CLAUDE.md` or other rules.

## What else the installer adds

Run through `waypoint install-claude`, the adapter also installs:

- **Hooks** in `.claude/hooks/`, wired through `.claude/settings.json`: standing-rule
  delivery, the phase gate, the memory reminder, and the session-events hook
  (`waypoint-events.sh` with `waypoint_events.py`). The events hook needs `python3`; without
  it, it does nothing and the session is unaffected.
- **The session runner** in `.claude/runner/`: `run_chain.sh`, which chains a runbook's units
  as fresh scripted sessions, and `run-notify.yml`, an optional GitHub workflow for its
  notifications. The runner refuses to start until `.waypoint/automation.md` exists; see the
  `run-setup` and `run` skills.
- **`.waypoint/events/.gitignore`**, so the event record is never committed.

The stub tests for the runner and the hook live in this repository (`adapters/claude/tests/`)
and are run by `./test.sh`; they are not installed into projects.

## Verification

Open a new Claude Code session in the project directory. If you open with no
request, the first response should be **"Ready."** with no other content. If you
open with a question, the agent briefly notes it's coming up to speed and then
answers it directly.

## Updating

Re-copy `rules/waypoint.md` to replace the old version. If you previously used an
older Waypoint version that embedded the briefing directly in `CLAUDE.md`, remove
that block once the standalone rule file is in place.
