# Waypoint — Claude Code Adapter

## What this does

Provides a `CLAUDE.md` file that Claude Code reads automatically at session start. It instructs Claude to run the Waypoint session briefing before processing any request.

## Installation

Copy `CLAUDE.md` to your project root:

```bash
cp path/to/waypoint/adapters/claude/CLAUDE.md .
```

If your project already has a `CLAUDE.md`, append the contents of this file to it rather than replacing it.

## Verification

Open a new Claude Code session in the project directory. The first response should be **"Ready."** with no other content.

## Updating

If the file changes in a future Waypoint release, re-copy or merge the updated content.
