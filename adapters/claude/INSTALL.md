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

## Verification

Open a new Claude Code session in the project directory. If you open with no
request, the first response should be **"Ready."** with no other content. If you
open with a question, the agent briefly notes it's coming up to speed and then
answers it directly.

## Updating

Re-copy `rules/waypoint.md` to replace the old version. If you previously used an
older Waypoint version that embedded the briefing directly in `CLAUDE.md`, remove
that block once the standalone rule file is in place.
