#!/bin/sh
# Waypoint: deliver the standing rules and boot instruction when a session
# starts, via Cursor's additional_context. Project hooks run from the project
# root. Installed by the Waypoint installer; wired in .cursor/hooks.json.

wp=".waypoint"
[ -f "$wp/opord.md" ] || { printf '{}'; exit 0; }

rules="$(awk '/<!-- standing-rules:begin -->/{f=1;next} /<!-- standing-rules:end -->/{f=0} f' "$wp/opord.md")"
phase=""
if [ -f "$wp/project.md" ]; then
	phase="$(grep -m1 '^\*\*Phase:\*\*' "$wp/project.md")"
fi
boot="New session: follow the boot checklist in .waypoint/opord.md (section 3a) before acting on the first request."

ctx="$(printf '%s\n%s\n\n%s' "$rules" "$phase" "$boot")"

# JSON-escape backslashes, quotes, and newlines.
esc="$(printf '%s' "$ctx" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | awk '{printf "%s\\n", $0}')"
printf '{"additional_context":"%s"}' "$esc"
exit 0
