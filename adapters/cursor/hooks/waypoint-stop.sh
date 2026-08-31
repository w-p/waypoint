#!/bin/sh
# Waypoint stop hook: two checks before a session ends, each corrected at most
# once (loop_count 0 only, and loop_limit caps it in .cursor/hooks.json).
# 1. Out-of-phase edits recorded by the edit-watch hook: send the agent back
#    to revert them or get the phase changed.
# 2. Memory backstop: the tree changed but nothing was recorded in memory today.
# Installed by the Waypoint installer; wired to stop.

input="$(cat)"
case "$input" in
	*'"loop_count":0'* | *'"loop_count": 0'*) ;;
	*) printf '{}'; exit 0 ;;
esac

flag=".cursor/waypoint-out-of-phase-edits"
if [ -s "$flag" ]; then
	paths="$(sort -u "$flag" | head -5 | tr '\n' ' ' | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"
	: >"$flag"
	printf '{"followup_message":"Waypoint phase gate: files outside .waypoint/ were edited while the project is in Ideation or Planning: %s. Revert them, or ask the developer to approve a phase change in .waypoint/project.md."}' "$paths"
	exit 0
fi

wp=".waypoint"
[ -d "$wp/memory" ] || { printf '{}'; exit 0; }
git rev-parse --git-dir >/dev/null 2>&1 || { printf '{}'; exit 0; }

changed="$(git status --porcelain -uall 2>/dev/null | grep -v '\.waypoint/' || true)"
if [ -n "$changed" ]; then
	today="$(date +%Y-%m-%d)"
	recorded="$(git status --porcelain -uall -- "$wp/memory/" 2>/dev/null | grep -F "$today" || true)"
	if [ -z "$recorded" ]; then
		printf '{"followup_message":"Waypoint: the working tree changed this session but no memory file dated %s was written. Record the session in .waypoint/memory/ (%s-<subject>.md, first line a standalone summary), then finish."}' "$today" "$today"
		exit 0
	fi
fi

printf '{}'
exit 0
