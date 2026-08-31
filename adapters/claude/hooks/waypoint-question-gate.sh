#!/bin/sh
# Waypoint question gate — OPT-IN, not wired by default. The baseline orders
# want real options surfaced, so blocking interactive prompts is a per-project
# choice. To enable, add a PreToolUse entry matching AskUserQuestion to
# .claude/settings.json pointing at this script (the README shows the entry).

printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"This project raises questions and options in prose, not interactive prompts. State the options and your recommendation in your reply, then proceed or wait as the decision requires."}}'
exit 0
