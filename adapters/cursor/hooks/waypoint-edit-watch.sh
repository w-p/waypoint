#!/bin/sh
# Waypoint phase gate, edit side: Cursor's afterFileEdit hook cannot block, so
# during Ideation and Planning this records edits that land outside .waypoint/.
# The stop hook reads the record and sends the agent back to correct them.
# Installed by the Waypoint installer; wired to afterFileEdit.

[ "${WAYPOINT_PHASE_GATE:-}" = "off" ] && exit 0

proj=".waypoint/project.md"
[ -f "$proj" ] || exit 0

phase="$(grep -m1 '^\*\*Phase:\*\*' "$proj" | grep -oE 'Ideation|Planning|Execution' | head -1)"
case "$phase" in
	Ideation|Planning) ;;
	*) exit 0 ;;
esac

input="$(cat)"
path="$(printf '%s' "$input" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
[ -n "$path" ] || exit 0

case "$path" in
	*/.waypoint/*|.waypoint/*) exit 0 ;;
esac

mkdir -p .cursor
printf '%s\n' "$path" >>".cursor/waypoint-out-of-phase-edits"
exit 0
