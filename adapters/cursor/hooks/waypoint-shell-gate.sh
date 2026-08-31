#!/bin/sh
# Waypoint phase gate, shell side: during Ideation and Planning, deny shell
# commands that write files, unless they target .waypoint/. Cursor cannot block
# the agent's own file edits before they land (afterFileEdit is observational),
# so this closes the shell-side write path; the edit-watch and stop hooks
# handle the rest. WAYPOINT_PHASE_GATE=off lifts the gate for a session.
# Installed by the Waypoint installer; wired to beforeShellExecution.

[ "${WAYPOINT_PHASE_GATE:-}" = "off" ] && { printf '{"permission":"allow"}'; exit 0; }

proj=".waypoint/project.md"
[ -f "$proj" ] || { printf '{"permission":"allow"}'; exit 0; }

phase="$(grep -m1 '^\*\*Phase:\*\*' "$proj" | grep -oE 'Ideation|Planning|Execution' | head -1)"
case "$phase" in
	Ideation|Planning) ;;
	*) printf '{"permission":"allow"}'; exit 0 ;;
esac

input="$(cat)"
cmd="$(printf '%s' "$input" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\(.*\)","cwd".*/\1/p')"
if [ -z "$cmd" ]; then
	cmd="$(printf '%s' "$input" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
fi

# Writes aimed at .waypoint/ are the legitimate output of gated phases.
case "$cmd" in
	*.waypoint/*) printf '{"permission":"allow"}'; exit 0 ;;
esac

if printf '%s' "$cmd" | grep -qE '(^|[;&|[:space:]])(rm|mv|cp|tee|touch|mkdir)([[:space:]]|$)|>|sed[[:space:]].*-i'; then
	printf '{"permission":"deny","user_message":"Waypoint phase gate: the project is in %s, so file-writing shell commands are blocked outside .waypoint/.","agent_message":"Waypoint phase gate: the project is in %s (.waypoint/project.md), so production files are not written yet. Designs, plans, and memory in .waypoint/ are always writable. Ways forward: finish the phase and have the developer approve moving it, or the developer sets WAYPOINT_PHASE_GATE=off for this session."}' "$phase" "$phase"
	exit 0
fi

printf '{"permission":"allow"}'
exit 0
