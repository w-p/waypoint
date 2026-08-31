#!/bin/sh
# Waypoint: if the working tree changed this session and nothing was recorded
# in memory today, remind once before the session ends. Never blocks twice —
# stop_hook_active means we already reminded, so the second attempt passes.
# Installed by the Waypoint installer; wired to Stop in .claude/settings.json.

root="${CLAUDE_PROJECT_DIR:-.}"
wp="$root/.waypoint"
[ -d "$wp/memory" ] || exit 0

input="$(cat)"
case "$input" in
	*'"stop_hook_active":true'* | *'"stop_hook_active": true'*) exit 0 ;;
esac

git -C "$root" rev-parse --git-dir >/dev/null 2>&1 || exit 0

changed="$(git -C "$root" status --porcelain -uall 2>/dev/null | grep -v '\.waypoint/' || true)"
[ -n "$changed" ] || exit 0

today="$(date +%Y-%m-%d)"
recorded="$(git -C "$root" status --porcelain -uall -- "$wp/memory/" 2>/dev/null | grep -F "$today" || true)"
[ -n "$recorded" ] && exit 0

printf '{"decision":"block","reason":"Waypoint: the working tree changed this session but no memory file dated %s was written. Record the session in .waypoint/memory/ (%s-<subject>.md, first line a standalone summary), then finish."}' "$today" "$today"
exit 0
