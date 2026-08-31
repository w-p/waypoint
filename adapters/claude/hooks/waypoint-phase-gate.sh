#!/bin/sh
# Waypoint phase gate: during Ideation and Planning, production files are not
# edited — designs, plans, and memory inside .waypoint/ always are. The
# developer lifts the gate for a session with WAYPOINT_PHASE_GATE=off.
# Installed by the Waypoint installer; wired to PreToolUse on Edit|Write|NotebookEdit.

[ "${WAYPOINT_PHASE_GATE:-}" = "off" ] && exit 0

root="${CLAUDE_PROJECT_DIR:-.}"
proj="$root/.waypoint/project.md"
[ -f "$proj" ] || exit 0

phase="$(grep -m1 '^\*\*Phase:\*\*' "$proj" | grep -oE 'Ideation|Planning|Execution' | head -1)"
case "$phase" in
	Ideation|Planning) ;;
	Execution) exit 0 ;;
	*)
		# A broken project.md must not brick editing: fail open, but say so.
		echo "Waypoint: no readable **Phase:** line in .waypoint/project.md — phase gate skipped." >&2
		exit 0
		;;
esac

input="$(cat)"
if command -v jq >/dev/null 2>&1; then
	path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null)"
else
	path="$(printf '%s' "$input" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
fi
[ -n "$path" ] || exit 0

case "$path" in
	*/.waypoint/*|.waypoint/*) exit 0 ;;
esac

printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Waypoint phase gate: the project is in %s (.waypoint/project.md), so production files are not edited yet. Designs, plans, and memory in .waypoint/ are always writable. Ways forward: finish the phase and have the developer approve moving it, or the developer sets WAYPOINT_PHASE_GATE=off for this session."}}' "$phase"
exit 0
