#!/bin/sh
# Waypoint: if the working tree changed this session and no memory file dated
# today exists — committed or not — remind once before the session ends. Never
# blocks twice: stop_hook_active means we already reminded, so the second
# attempt passes.
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

# A session that commits its memory entry mid-session must not be nagged, so
# the check is file existence, not git status — status only shows uncommitted
# files.
today="$(date +%Y-%m-%d)"
for f in "$wp/memory/$today"-*.md; do
	[ -e "$f" ] && exit 0
done

printf '{"decision":"block","reason":"Waypoint: the working tree changed this session but no memory file dated %s was written. Record the session in .waypoint/memory/ (%s-<subject>.md, first line a standalone summary), then finish."}' "$today" "$today"
exit 0
