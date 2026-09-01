#!/bin/sh
# Waypoint phase gate, shell side: the edit gate covers the editor's file
# tools, but a shell command can write files too. During Ideation and Planning,
# deny write-shaped commands unless they target .waypoint/. The developer lifts
# the gate for a session with WAYPOINT_PHASE_GATE=off.
# Installed by the Waypoint installer; wired to PreToolUse on Bash.

[ "${WAYPOINT_PHASE_GATE:-}" = "off" ] && exit 0

root="${CLAUDE_PROJECT_DIR:-.}"
proj="$root/.waypoint/project.md"
[ -f "$proj" ] || exit 0

phase="$(grep -m1 '^\*\*Phase:\*\*' "$proj" | grep -oE 'Ideation|Planning|Execution' | head -1)"
case "$phase" in
	Ideation|Planning) ;;
	*) exit 0 ;;
esac

input="$(cat)"
if command -v jq >/dev/null 2>&1; then
	cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)"
else
	cmd="$(printf '%s' "$input" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
fi
[ -n "$cmd" ] || exit 0

# Writes aimed at .waypoint/ are the legitimate output of gated phases. The
# command is judged segment by segment (split on ;, |, &) so that mentioning
# .waypoint/ in one segment does not wave through a write elsewhere on the
# same line. This deters a cooperating agent; it is not a security boundary.
if printf '%s' "$cmd" | tr ';|&' '\n' \
	| grep -E '(^|[[:space:]])(rm|mv|cp|tee|touch|mkdir)([[:space:]]|$)|>|sed[[:space:]].*-i' \
	| grep -qv '\.waypoint/'; then
	printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Waypoint phase gate: the project is in %s (.waypoint/project.md), so file-writing shell commands are blocked outside .waypoint/. Designs, plans, and memory in .waypoint/ are always writable. Ways forward: finish the phase and have the developer approve moving it, or the developer sets WAYPOINT_PHASE_GATE=off for this session."}}' "$phase"
	exit 0
fi

exit 0
