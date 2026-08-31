#!/bin/sh
# Waypoint: deliver the standing rules at session start so the session never
# depends on the model choosing to read them. With "compact" as the first
# argument (wired to the compact matcher), it also delivers the recovery
# instruction — the automatic resume after a context compaction.
# Installed by the Waypoint installer; wired in .claude/settings.json.

wp="${CLAUDE_PROJECT_DIR:-.}/.waypoint"
[ -f "$wp/opord.md" ] || exit 0

awk '/<!-- standing-rules:begin -->/{f=1;next} /<!-- standing-rules:end -->/{f=0} f' "$wp/opord.md"
if [ -f "$wp/project.md" ]; then
	grep -m1 '^\*\*Phase:\*\*' "$wp/project.md"
fi
echo ""
if [ "${1:-}" = "compact" ]; then
	echo "Context was just compacted. Recover before continuing: re-read .waypoint/project.md and the most recent file in .waypoint/memory/."
else
	echo "New session: follow the boot checklist in .waypoint/opord.md (section 3a) before acting on the first request."
fi
exit 0
