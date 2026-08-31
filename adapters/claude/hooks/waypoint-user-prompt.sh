#!/bin/sh
# Waypoint: keep the phase and the most drift-prone standing rules at the fresh
# end of context on every prompt. The lines come from the standing-rules region
# of the project's OPORD, so project extensions to those rules ride along.
# Installed by the Waypoint installer; wired in .claude/settings.json.

wp="${CLAUDE_PROJECT_DIR:-.}/.waypoint"
[ -f "$wp/opord.md" ] || exit 0

phase=""
if [ -f "$wp/project.md" ]; then
	phase="$(grep -m1 '^\*\*Phase:\*\*' "$wp/project.md")"
fi
rules="$(awk '/<!-- standing-rules:begin -->/{f=1;next} /<!-- standing-rules:end -->/{f=0} f' "$wp/opord.md" \
	| grep -E '^- \*\*(Questions|Voice)\*\*')"

ctx="$(printf '%s\n%s' "$phase" "$rules")"
[ -n "$ctx" ] || exit 0

# JSON-escape backslashes, quotes, and newlines.
esc="$(printf '%s' "$ctx" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | awk '{printf "%s\\n", $0}')"
printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"%s"}}' "$esc"
exit 0
