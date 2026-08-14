#!/usr/bin/env bash
#
# test.sh — regression tests for the waypoint installer.
#
# The installer copies, moves, and deletes files inside other people's projects,
# and reinstalling makes promises about what it will not touch: an OPORD you
# extended, your own skills, a CONOPS you have written. These tests pin those
# promises down.
#
# Everything runs against throwaway directories under a temp root. Nothing here
# touches your checkout — WAYPOINT_NO_PULL keeps install from pulling it.
#
#   ./test.sh          run everything
#   ./test.sh -v       also echo installer output for failing cases

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WAYPOINT="$ROOT/waypoint"
TMP="$(mktemp -d)"
VERBOSE="${1:-}"

export WAYPOINT_NO_PULL=1

PASS=0
FAIL=0
CASE="(none)"
OUTPUT=""

trap 'rm -rf "$TMP"' EXIT

# ─── Harness ─────────────────────────────────────────────────────────────────

start() {
	CASE="$1"
	echo ""
	echo "── $CASE"
}

# Run the installer against a project, capturing output for later inspection.
run() {
	OUTPUT="$("$WAYPOINT" "$@" 2>&1)"
	return $?
}

ok() {
	PASS=$((PASS + 1))
	echo "  ✓ $1"
}

no() {
	FAIL=$((FAIL + 1))
	echo "  ✗ $1"
	if [ "$VERBOSE" = "-v" ]; then
		echo "$OUTPUT" | sed 's/^/      | /'
	fi
}

exists() {
	if [ -f "$1" ]; then ok "$2"; else no "$2 — missing $1"; fi
}

absent() {
	if [ ! -e "$1" ]; then ok "$2"; else no "$2 — $1 should not exist"; fi
}

# Assert a file contains a fixed string.
holds() {
	if grep -qF "$2" "$1" 2>/dev/null; then ok "$3"; else no "$3"; fi
}

# Assert two files are byte-identical. Used for the dogfooding invariant: the
# framework's own .waypoint/ must match the templates it ships.
same() {
	if diff -q "$1" "$2" >/dev/null 2>&1; then ok "$3"; else no "$3 — $1 and $2 differ"; fi
}

# Assert the last captured output contains a fixed string.
said() {
	if echo "$OUTPUT" | grep -qF "$1"; then ok "$2"; else no "$2"; fi
}

# A fresh empty project directory.
project() {
	local d="$TMP/$1"
	rm -rf "$d"
	mkdir -p "$d"
	echo "$d"
}

# An older commit of templates/opord.md from this repo's real history, for the
# fast-forward tests. Empty when the checkout has no history to offer.
old_baseline_rev() {
	git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 || return 0
	git -C "$ROOT" log --format=%h --skip=1 -1 -- templates/opord.md 2>/dev/null
}

# ─── Install ─────────────────────────────────────────────────────────────────

start "fresh install lays down the full structure"
p="$(project fresh)"
run install-claude "$p"
exists "$p/.waypoint/opord.md" "OPORD installed"
exists "$p/.waypoint/project.md" "project.md installed"
exists "$p/.waypoint/memory/README.md" "memory convention installed"
exists "$p/.waypoint/conops-template.md" "CONOPS scaffold installed"
exists "$p/.waypoint/skills/new-project.md" "core skills installed"
exists "$p/.waypoint/skills/update-waypoint.md" "update skill installed"
exists "$p/.claude/rules/waypoint.md" "Claude adapter installed"
exists "$p/.waypoint/VERSION" "source revision stamped"
for d in design plan features skills memory; do
	if [ -d "$p/.waypoint/$d" ]; then ok "$d/ created"; else no "$d/ created"; fi
done

start "cursor install writes the cursor adapter and no claude rule"
p="$(project cursor)"
run install-cursor "$p"
exists "$p/.cursor/rules/session-briefing.mdc" "Cursor adapter installed"
absent "$p/.claude" "no Claude adapter"

start "install-core writes no adapter at all"
p="$(project core)"
run install-core "$p"
exists "$p/.waypoint/opord.md" "core content installed"
absent "$p/.claude" "no Claude adapter"
absent "$p/.cursor" "no Cursor adapter"

start "bare install refuses to guess an editor"
p="$(project guess)"
if run install "$p"; then
	no "exits non-zero"
else
	ok "exits non-zero"
fi
said "install-cursor" "names the explicit alternatives"
absent "$p/.waypoint" "installs nothing"

start "install refuses to target the waypoint checkout itself"
if run install-core "$ROOT"; then
	no "exits non-zero"
else
	ok "exits non-zero"
fi
said "inside the waypoint checkout" "explains why"

start "install refuses a destination that does not exist"
if run install-core "$TMP/definitely-not-here"; then
	no "exits non-zero"
else
	ok "exits non-zero"
fi

# ─── update: the mechanical half, and the bootstrap for the skill ────────────

start "update refuses a project that was never installed into"
p="$(project noinstall)"
if run update "$p"; then
	no "exits non-zero"
else
	ok "exits non-zero"
fi
said "Run install first" "says what to do instead"

start "update reinstalls, which installs the update skill itself"
p="$(project updcmd)"
run install-claude "$p"
rm "$p/.waypoint/skills/update-waypoint.md"
echo "local scribble" >"$p/.waypoint/skills/debug.md"
run update "$p"
exists "$p/.waypoint/skills/update-waypoint.md" "a pre-skill project gets the skill from update"
holds "$p/.waypoint/skills/debug.md" "# Skill: Debug" "core skill refreshed"
said "Read .waypoint/skills/update-waypoint.md" "points at the skill for the rest"

start "update detects the adapter and stays in its lane"
p="$(project updcursor)"
run install-cursor "$p"
run update "$p"
exists "$p/.cursor/rules/session-briefing.mdc" "cursor adapter refreshed"
absent "$p/.claude" "no Claude adapter appears"

start "update-skills and migrate are stubs"
if run update-skills; then no "update-skills exits non-zero"; else ok "update-skills exits non-zero"; fi
said "waypoint update" "update-skills points at update"
if run migrate; then no "migrate exits non-zero"; else ok "migrate exits non-zero"; fi
said "folded into install" "migrate says install migrates now"

# ─── Ownership guarantees ────────────────────────────────────────────────────

start "reinstall leaves an extended OPORD alone"
p="$(project opord)"
run install-claude "$p"
echo "PROJECT-SPECIFIC RULE" >>"$p/.waypoint/opord.md"
run install-claude "$p"
holds "$p/.waypoint/opord.md" "PROJECT-SPECIFIC RULE" "extension survives reinstall"
said "differs from the shipped baseline" "drift is reported"
said "To merge the new baseline" "points at the merge skill"

start "reinstall leaves skills you wrote alone"
p="$(project userskills)"
run install-claude "$p"
echo "MY DEPLOY PROCEDURE" >"$p/.waypoint/skills/deploy.md"
run install-claude "$p"
holds "$p/.waypoint/skills/deploy.md" "MY DEPLOY PROCEDURE" "user skill survives reinstall"

start "reinstall restores core skills you have edited"
p="$(project coreskills)"
run install-claude "$p"
echo "local scribble" >"$p/.waypoint/skills/debug.md"
run install-claude "$p"
holds "$p/.waypoint/skills/debug.md" "# Skill: Debug" "core skill refreshed"

start "reinstall does not clobber project.md"
p="$(project reinstall)"
run install-claude "$p"
echo "REAL PROJECT STATE" >"$p/.waypoint/project.md"
run install-claude "$p"
holds "$p/.waypoint/project.md" "REAL PROJECT STATE" "project.md preserved"
said "(exists, skipped)" "says it skipped it"

# ─── OPORD fast-forward ──────────────────────────────────────────────────────

oldrev="$(old_baseline_rev)"

start "an unextended OPORD is fast-forwarded when the baseline moved"
if [ -n "$oldrev" ]; then
	p="$(project pristine)"
	run install-claude "$p"
	git -C "$ROOT" show "$oldrev:templates/opord.md" >"$p/.waypoint/opord.md"
	printf 'revision: %s\nupdated:  2020-01-01\n' "$oldrev" >"$p/.waypoint/VERSION"
	run install-claude "$p"
	same "$p/.waypoint/opord.md" "$ROOT/templates/opord.md" "fast-forwarded to the current baseline"
	said "fast-forwarded" "says so"
else
	ok "skipped — no prior baseline in history"
	ok "skipped — no prior baseline in history"
fi

start "an extended OPORD is never fast-forwarded, even from a known baseline"
if [ -n "$oldrev" ]; then
	p="$(project extended)"
	run install-claude "$p"
	{
		git -C "$ROOT" show "$oldrev:templates/opord.md"
		echo "PROJECT-SPECIFIC RULE"
	} >"$p/.waypoint/opord.md"
	printf 'revision: %s\nupdated:  2020-01-01\n' "$oldrev" >"$p/.waypoint/VERSION"
	run install-claude "$p"
	holds "$p/.waypoint/opord.md" "PROJECT-SPECIFIC RULE" "extension survives"
	said "left alone" "reports it was left alone"
else
	ok "skipped — no prior baseline in history"
	ok "skipped — no prior baseline in history"
fi

start "an unknown stamped revision skips the fast-forward safely"
p="$(project badrev)"
run install-claude "$p"
echo "PROJECT-SPECIFIC RULE" >>"$p/.waypoint/opord.md"
printf 'revision: 0000000\nupdated:  2020-01-01\n' >"$p/.waypoint/VERSION"
if run install-claude "$p"; then ok "reinstall still succeeds"; else no "reinstall still succeeds"; fi
holds "$p/.waypoint/opord.md" "PROJECT-SPECIFIC RULE" "OPORD preserved"

# ─── CONOPS scaffold lifecycle ───────────────────────────────────────────────

start "the CONOPS scaffold is removed once a CONOPS is written"
p="$(project conops)"
run install-claude "$p"
exists "$p/.waypoint/conops-template.md" "scaffold present before a CONOPS exists"
echo "# CONOPS: Test" >"$p/.waypoint/conops.md"
run install-claude "$p"
absent "$p/.waypoint/conops-template.md" "scaffold removed after conops.md appears"
holds "$p/.waypoint/conops.md" "# CONOPS: Test" "written CONOPS untouched"

start "a written CONOPS keeps the scaffold from coming back"
run install-claude "$p"
absent "$p/.waypoint/conops-template.md" "scaffold stays gone on reinstall"
said "CONOPS already written" "does not tell you to write one again"

# ─── Legacy layouts ──────────────────────────────────────────────────────────

start "a legacy memory.md is moved into memory/ by install"
p="$(project legacymem)"
mkdir -p "$p/.waypoint"
echo "OLD MEMORY CONTENT" >"$p/.waypoint/memory.md"
run install-core "$p"
absent "$p/.waypoint/memory.md" "old file no longer at the old path"
found="$(grep -rlF "OLD MEMORY CONTENT" "$p/.waypoint/memory/" 2>/dev/null | head -1)"
if [ -n "$found" ]; then ok "content preserved in memory/"; else no "content preserved in memory/"; fi
exists "$p/.waypoint/memory/README.md" "convention README installed"

start "a briefing embedded in CLAUDE.md is relocated and reported"
p="$(project legacyblock)"
mkdir -p "$p/.waypoint"
printf '# My Project\n\nSome rules.\n\n# Waypoint Session Briefing\nold block\n' >"$p/CLAUDE.md"
run install-core "$p"
exists "$p/.claude/rules/waypoint.md" "standalone rule file adopted"
holds "$p/CLAUDE.md" "Some rules." "your CLAUDE.md is not rewritten"
holds "$p/CLAUDE.md" "# Waypoint Session Briefing" "stale block left for you to remove"
said "Legacy briefing block" "stale block is reported"

start "reinstall is idempotent"
p="$(project idem)"
run install-claude "$p"
before="$(find "$p" -type f | sort)"
run install-claude "$p"
run install-claude "$p"
after="$(find "$p" -type f | sort)"
if [ "$before" = "$after" ]; then ok "file set unchanged"; else no "file set unchanged"; fi

# ─── Revision stamp ──────────────────────────────────────────────────────────

start "the revision stamp records the source commit and origin"
p="$(project version)"
run install-claude "$p"
if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
	rev="$(git -C "$ROOT" rev-parse --short HEAD)"
	holds "$p/.waypoint/VERSION" "revision: $rev" "stamp matches the checkout"
	url="$(git -C "$ROOT" remote get-url origin 2>/dev/null || true)"
	if [ -n "$url" ]; then
		holds "$p/.waypoint/VERSION" "origin:   $url" "stamp records the origin remote"
	else
		ok "skipped — checkout has no origin remote"
	fi
else
	ok "skipped — not a git checkout"
	ok "skipped — not a git checkout"
fi

# ─── Guards ──────────────────────────────────────────────────────────────────

start "paths containing spaces work"
p="$(project "spaced out")"
run install-claude "$p"
exists "$p/.waypoint/opord.md" "installs into a spaced path"
run install-claude "$p"
exists "$p/.waypoint/skills/debug.md" "reinstalls into a spaced path"

# ─── Dogfooding invariant ────────────────────────────────────────────────────

# Waypoint tracks its own development, so its .waypoint/ is a live install of the
# templates it ships. Those pairs must stay byte-identical — editing one copy and
# forgetting the other is exactly the drift this catches.
start "the dogfooded .waypoint/ matches the shipped templates"
same "$ROOT/templates/opord.md" "$ROOT/.waypoint/opord.md" "OPORD matches its template"
same "$ROOT/templates/memory.md" "$ROOT/.waypoint/memory/README.md" "memory README matches its template"

# ─── Result ──────────────────────────────────────────────────────────────────

echo ""
echo "────────────────────────────────"
echo "  $PASS passed, $FAIL failed"
echo ""

if [ "$FAIL" -gt 0 ]; then
	exit 1
fi
