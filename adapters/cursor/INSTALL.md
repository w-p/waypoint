# Waypoint — Cursor Adapter

## What this does

Installs a Cursor rule that runs the Waypoint session briefing automatically at the start of every agent session. The agent reads `.waypoint/opord.md` (and the documents it references) before processing any request.

## Installation

Copy `rules/session-briefing.mdc` into your project's `.cursor/rules/` directory:

```bash
mkdir -p .cursor/rules
cp path/to/waypoint/adapters/cursor/rules/session-briefing.mdc .cursor/rules/
```

That is all. Cursor picks up rules automatically on next session start.

## Verification

Open a new Cursor agent session with no request. The first response should be **"Ready."** with no other content. (If you open with a question instead, the agent briefly notes it's coming up to speed and then answers it.) If the agent adds unrelated commentary before reading the Waypoint documents, the rule is not active — check that the file is in `.cursor/rules/` and restart Cursor.

## Updating

If the rule file changes in a future Waypoint release, re-copy it to replace the old version.
