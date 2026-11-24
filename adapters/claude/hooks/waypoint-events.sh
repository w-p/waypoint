#!/usr/bin/env bash
# Session events from Claude Code hooks (contract: contracts/session-events.md in the Waypoint
# repository). Needs python3; without it the hook does nothing and the session is unaffected.
#   waypoint-events.sh start|stop|permission|prompt|active|post|end    (hook JSON on stdin)
# Tool calls (post) are throttled here, in shell, before Python starts: a session that wrote
# session.active under a minute ago, and is not writing a memory file or committing, costs one
# file read.
# A prompt always runs Python, because it reports the session's condition record. Always exits 0;
# the only output is that record, as the hook's JSON reply (prompt, and post when the ask rises).
kind="${1:-}"
input="$(cat)"
if [ "$kind" = post ]; then
  # A memory write or a commit always reaches Python: both change the session's condition.
  # Take the session id before the commit test: every =~ overwrites BASH_REMATCH.
  sid=""
  if [[ "$input" =~ \"session_id\":\ *\"([^\"]+)\" ]]; then sid="${BASH_REMATCH[1]}"; fi
  if [ -n "$sid" ] && [[ "$input" != *.waypoint/memory/* ]] \
     && ! [[ "$input" =~ git[^\"]{0,40}commit ]]; then
    state="${CLAUDE_PROJECT_DIR:-.}/.waypoint/events/sessions/.state/$sid"
    if { read -r last at _ < "$state"; } 2>/dev/null && [ "$last" = session.active ] \
       && [ $(( $(date +%s) - at )) -lt 60 ]; then
      exit 0
    fi
  fi
fi
writer="$(dirname "${BASH_SOURCE[0]}")/waypoint_events.py"
if [ "$kind" = prompt ] || [ "$kind" = post ]; then
  printf '%s' "$input" | python3 "$writer" hook "$kind" 2>/dev/null
else
  printf '%s' "$input" | python3 "$writer" hook "$kind" >/dev/null 2>&1
fi
exit 0
