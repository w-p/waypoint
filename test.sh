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

# The standing-rules region of a file, markers included.
region_of() {
	awk '/<!-- standing-rules:begin -->/{f=1} f{print} /<!-- standing-rules:end -->/{f=0}' "$1"
}

# Assert a shipped surface (everything outside the OPORD and CONOPS) does not
# use one of the OPORD's format terms.
no_leak() {
	if grep -rqF "$1" "$ROOT/skills" "$ROOT/templates/project.md" "$ROOT/templates/memory.md" "$ROOT/templates/conops.md" "$ROOT/adapters" 2>/dev/null; then
		no "'$1' stays out of shipped surfaces"
	else
		ok "'$1' stays out of shipped surfaces"
	fi
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

# ─── Standing rules composition ──────────────────────────────────────────────

start "the adapter rule file carries the OPORD's standing rules"
p="$(project rules)"
run install-claude "$p"
r_opord="$(region_of "$p/.waypoint/opord.md")"
r_rule="$(region_of "$p/.claude/rules/waypoint.md")"
if [ -n "$r_opord" ] && [ "$r_opord" = "$r_rule" ]; then ok "rule file region matches the OPORD"; else no "rule file region matches the OPORD"; fi
awk '{ if ($0 == "<!-- standing-rules:end -->") print "- **Extra** — a project rule."; print }' "$p/.waypoint/opord.md" >"$p/.waypoint/opord.md.new"
mv "$p/.waypoint/opord.md.new" "$p/.waypoint/opord.md"
run install-claude "$p"
holds "$p/.claude/rules/waypoint.md" "a project rule." "an extended region propagates on reinstall"
r_opord="$(region_of "$p/.waypoint/opord.md")"
r_rule="$(region_of "$p/.claude/rules/waypoint.md")"
if [ "$r_opord" = "$r_rule" ]; then ok "copies stay identical after the extension"; else no "copies stay identical after the extension"; fi

start "the cursor rule file carries the standing rules too"
p="$(project rulescursor)"
run install-cursor "$p"
r_opord="$(region_of "$p/.waypoint/opord.md")"
r_rule="$(region_of "$p/.cursor/rules/session-briefing.mdc")"
if [ -n "$r_opord" ] && [ "$r_opord" = "$r_rule" ]; then ok "mdc region matches the OPORD"; else no "mdc region matches the OPORD"; fi

start "an OPORD without the region gets a pointer, not a broken rule file"
p="$(project noregion)"
run install-core "$p"
grep -v 'standing-rules' "$p/.waypoint/opord.md" >"$p/.waypoint/opord.md.new"
mv "$p/.waypoint/opord.md.new" "$p/.waypoint/opord.md"
run install-claude "$p"
said "no standing-rules region" "the gap is reported"
holds "$p/.claude/rules/waypoint.md" "update-waypoint" "the rule file points at the merge skill"

# ─── Adapter hooks: install and wiring ───────────────────────────────────────

start "claude hooks are installed and wired"
p="$(project hooks)"
run install-claude "$p"
for h in session-start user-prompt phase-gate shell-gate memory-backstop question-gate; do
	if [ -x "$p/.claude/hooks/waypoint-$h.sh" ]; then ok "waypoint-$h.sh installed executable"; else no "waypoint-$h.sh installed executable"; fi
done
exists "$p/.claude/settings.json" "settings.json created"
holds "$p/.claude/settings.json" "waypoint-session-start.sh" "session-start wired"
if grep -qF "question-gate" "$p/.claude/settings.json"; then no "question gate stays unwired by default"; else ok "question gate stays unwired by default"; fi
n1="$(grep -c 'waypoint-session-start.sh' "$p/.claude/settings.json")"
run install-claude "$p"
n2="$(grep -c 'waypoint-session-start.sh' "$p/.claude/settings.json")"
if [ "$n1" = "$n2" ]; then ok "re-wiring is idempotent"; else no "re-wiring is idempotent — $n1 then $n2 entries"; fi

start "hook wiring merges into existing settings without clobbering"
p="$(project hookmerge)"
mkdir -p "$p/.claude"
printf '{"permissions":{"allow":["Bash(ls *)"]},"hooks":{"Stop":[{"hooks":[{"type":"command","command":"echo mine"}]}]}}' >"$p/.claude/settings.json"
run install-claude "$p"
if command -v jq >/dev/null 2>&1; then
	holds "$p/.claude/settings.json" "echo mine" "the project's own Stop hook survives"
	holds "$p/.claude/settings.json" "waypoint-memory-backstop.sh" "the waypoint Stop hook is added"
	holds "$p/.claude/settings.json" "Bash(ls *)" "permissions untouched"
	if jq -e . "$p/.claude/settings.json" >/dev/null 2>&1; then ok "result is valid JSON"; else no "result is valid JSON"; fi
else
	holds "$p/.claude/settings.json" "echo mine" "without jq the file is not modified"
	if grep -qF "waypoint-" "$p/.claude/settings.json"; then no "without jq nothing is written into it"; else ok "without jq nothing is written into it"; fi
	said "by hand" "the fragment is printed for manual wiring"
	ok "skipped — jq not available for merge assertion"
fi

# ─── Adapter hooks: behavior ─────────────────────────────────────────────────

start "the session-start hook delivers rules, phase, and boot instruction"
p="$(project hookrun)"
run install-claude "$p"
out="$(CLAUDE_PROJECT_DIR="$p" sh "$p/.claude/hooks/waypoint-session-start.sh")"
case "$out" in *"Standing rules"*) ok "standing rules delivered";; *) no "standing rules delivered";; esac
case "$out" in *"**Phase:**"*) ok "phase line delivered";; *) no "phase line delivered";; esac
case "$out" in *"boot checklist"*) ok "boot instruction delivered";; *) no "boot instruction delivered";; esac
out="$(CLAUDE_PROJECT_DIR="$p" sh "$p/.claude/hooks/waypoint-session-start.sh" compact)"
case "$out" in *"compacted"*) ok "compact variant delivers the recovery instruction";; *) no "compact variant delivers the recovery instruction";; esac

start "the user-prompt hook emits additionalContext JSON"
out="$(CLAUDE_PROJECT_DIR="$p" sh "$p/.claude/hooks/waypoint-user-prompt.sh")"
case "$out" in *'"hookSpecificOutput"'*'"additionalContext"'*) ok "shape present";; *) no "shape present";; esac
if command -v jq >/dev/null 2>&1; then
	if printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext | length > 0' >/dev/null 2>&1; then ok "valid JSON with content"; else no "valid JSON with content"; fi
else
	ok "skipped — jq not available"
fi

start "the phase gate denies, allows, overrides, and fails open"
printf '# P\n\n**Phase:** Ideation — gate test\n' >"$p/.waypoint/project.md"
out="$(printf '{"tool_input":{"file_path":"%s/src/main.go"}}' "$p" | CLAUDE_PROJECT_DIR="$p" sh "$p/.claude/hooks/waypoint-phase-gate.sh")"
case "$out" in *'"permissionDecision":"deny"'*) ok "denies a production write in Ideation";; *) no "denies a production write in Ideation";; esac
out="$(printf '{"tool_input":{"file_path":"%s/.waypoint/design/d.md"}}' "$p" | CLAUDE_PROJECT_DIR="$p" sh "$p/.claude/hooks/waypoint-phase-gate.sh")"
if [ -z "$out" ]; then ok ".waypoint/ writes always pass"; else no ".waypoint/ writes always pass"; fi
out="$(printf '{"tool_input":{"file_path":"%s/src/main.go"}}' "$p" | WAYPOINT_PHASE_GATE=off CLAUDE_PROJECT_DIR="$p" sh "$p/.claude/hooks/waypoint-phase-gate.sh")"
if [ -z "$out" ]; then ok "the override lifts the gate"; else no "the override lifts the gate"; fi
printf '# P\n\n**Phase:** Execution — building\n' >"$p/.waypoint/project.md"
out="$(printf '{"tool_input":{"file_path":"%s/src/main.go"}}' "$p" | CLAUDE_PROJECT_DIR="$p" sh "$p/.claude/hooks/waypoint-phase-gate.sh")"
if [ -z "$out" ]; then ok "Execution passes"; else no "Execution passes"; fi
printf 'no phase line here\n' >"$p/.waypoint/project.md"
out="$(printf '{"tool_input":{"file_path":"%s/src/main.go"}}' "$p" | CLAUDE_PROJECT_DIR="$p" sh "$p/.claude/hooks/waypoint-phase-gate.sh" 2>/dev/null)"
if [ -z "$out" ]; then ok "an unreadable phase fails open"; else no "an unreadable phase fails open"; fi

start "the shell gate closes the write path the edit gate cannot see"
printf '# P\n\n**Phase:** Ideation — gate test\n' >"$p/.waypoint/project.md"
out="$(printf '{"tool_input":{"command":"echo hi > src/out.txt"}}' | CLAUDE_PROJECT_DIR="$p" sh "$p/.claude/hooks/waypoint-shell-gate.sh")"
case "$out" in *'"permissionDecision":"deny"'*) ok "denies a shell write in Ideation";; *) no "denies a shell write in Ideation";; esac
out="$(printf '{"tool_input":{"command":"mkdir -p .waypoint/design"}}' | CLAUDE_PROJECT_DIR="$p" sh "$p/.claude/hooks/waypoint-shell-gate.sh")"
if [ -z "$out" ]; then ok "writes into .waypoint/ pass"; else no "writes into .waypoint/ pass"; fi
out="$(printf '{"tool_input":{"command":"git log --oneline"}}' | CLAUDE_PROJECT_DIR="$p" sh "$p/.claude/hooks/waypoint-shell-gate.sh")"
if [ -z "$out" ]; then ok "read commands pass"; else no "read commands pass"; fi
printf '# P\n\n**Phase:** Execution — building\n' >"$p/.waypoint/project.md"
out="$(printf '{"tool_input":{"command":"rm -rf build"}}' | CLAUDE_PROJECT_DIR="$p" sh "$p/.claude/hooks/waypoint-shell-gate.sh")"
if [ -z "$out" ]; then ok "Execution passes"; else no "Execution passes"; fi

start "the memory backstop blocks once, then lets go"
p="$(project backstop)"
run install-claude "$p"
git -C "$p" init -q
echo hi >"$p/app.txt"
out="$(printf '{"stop_hook_active":false}' | CLAUDE_PROJECT_DIR="$p" sh "$p/.claude/hooks/waypoint-memory-backstop.sh")"
case "$out" in *'"decision":"block"'*) ok "blocks when the tree changed and memory is silent";; *) no "blocks when the tree changed and memory is silent";; esac
out="$(printf '{"stop_hook_active":true}' | CLAUDE_PROJECT_DIR="$p" sh "$p/.claude/hooks/waypoint-memory-backstop.sh")"
if [ -z "$out" ]; then ok "never blocks twice"; else no "never blocks twice"; fi
touch "$p/.waypoint/memory/$(date +%Y-%m-%d)-entry.md"
out="$(printf '{"stop_hook_active":false}' | CLAUDE_PROJECT_DIR="$p" sh "$p/.claude/hooks/waypoint-memory-backstop.sh")"
if [ -z "$out" ]; then ok "a dated memory entry satisfies it"; else no "a dated memory entry satisfies it"; fi

start "the question gate answers in prose and ships unwired"
out="$(sh "$ROOT/adapters/claude/hooks/waypoint-question-gate.sh" </dev/null)"
case "$out" in *prose*) ok "denies with the prose instruction";; *) no "denies with the prose instruction";; esac

start "cursor hooks are installed and behave"
p="$(project cursorhooks)"
run install-cursor "$p"
exists "$p/.cursor/hooks.json" "hooks.json created"
for h in session-start shell-gate edit-watch stop; do
	if [ -x "$p/.cursor/hooks/waypoint-$h.sh" ]; then ok "waypoint-$h.sh installed executable"; else no "waypoint-$h.sh installed executable"; fi
done
out="$(cd "$p" && sh .cursor/hooks/waypoint-session-start.sh)"
case "$out" in *'"additional_context"'*'Standing rules'*) ok "session start injects the standing rules";; *) no "session start injects the standing rules";; esac
printf '# P\n\n**Phase:** Ideation — gate test\n' >"$p/.waypoint/project.md"
out="$(printf '{"command":"rm -rf build","cwd":"/x"}' | (cd "$p" && sh .cursor/hooks/waypoint-shell-gate.sh))"
case "$out" in *'"permission":"deny"'*) ok "shell gate denies a write in Ideation";; *) no "shell gate denies a write in Ideation";; esac
out="$(printf '{"command":"mkdir -p .waypoint/design","cwd":"/x"}' | (cd "$p" && sh .cursor/hooks/waypoint-shell-gate.sh))"
case "$out" in *'"permission":"allow"'*) ok "writes into .waypoint/ pass";; *) no "writes into .waypoint/ pass";; esac
out="$(printf '{"command":"git log --oneline","cwd":"/x"}' | (cd "$p" && sh .cursor/hooks/waypoint-shell-gate.sh))"
case "$out" in *'"permission":"allow"'*) ok "read commands pass";; *) no "read commands pass";; esac
printf '{"file_path":"src/a.ts","edits":[]}' | (cd "$p" && sh .cursor/hooks/waypoint-edit-watch.sh)
holds "$p/.cursor/waypoint-out-of-phase-edits" "src/a.ts" "edit watch records an out-of-phase edit"
out="$(printf '{"status":"completed","loop_count":0}' | (cd "$p" && sh .cursor/hooks/waypoint-stop.sh))"
case "$out" in *followup_message*src/a.ts*) ok "stop sends the agent back to correct it";; *) no "stop sends the agent back to correct it";; esac
out="$(printf '{"status":"completed","loop_count":1}' | (cd "$p" && sh .cursor/hooks/waypoint-stop.sh))"
if [ "$out" = "{}" ]; then ok "loop guard holds"; else no "loop guard holds"; fi

# ─── Dogfooding invariant ────────────────────────────────────────────────────

# Waypoint tracks its own development, so its .waypoint/ is a live install of the
# templates it ships. Those pairs must stay byte-identical — editing one copy and
# forgetting the other is exactly the drift this catches.
start "the dogfooded .waypoint/ matches the shipped templates"
same "$ROOT/templates/opord.md" "$ROOT/.waypoint/opord.md" "OPORD matches its template"
same "$ROOT/templates/memory.md" "$ROOT/.waypoint/memory/README.md" "memory README matches its template"

start "the shipped OPORD carries a standing-rules region"
r="$(region_of "$ROOT/templates/opord.md")"
if [ -n "$r" ]; then ok "region present in templates/opord.md"; else no "region present in templates/opord.md"; fi

# ─── Register boundary ───────────────────────────────────────────────────────

# The OPORD and CONOPS keep their format terms; nothing else the framework
# ships uses them. This is what keeps the register from creeping back.
start "the OPORD's format terms stay inside the OPORD"
no_leak "SUSTAINMENT"
no_leak "COMMAND & SIGNAL"
no_leak "Issuing HQ"
no_leak "SITUATION"
no_leak "logistics line"
no_leak "rules of engagement"

# ─── Phase grammar ───────────────────────────────────────────────────────────

start "the dogfooded project.md parses for the phase gate"
n="$(grep -c '^\*\*Phase:\*\*' "$ROOT/.waypoint/project.md")"
if [ "$n" = "1" ]; then ok "exactly one Phase line"; else no "exactly one Phase line — found $n"; fi
ph="$(grep -m1 '^\*\*Phase:\*\*' "$ROOT/.waypoint/project.md" | grep -oE 'Ideation|Planning|Execution' | head -1)"
if [ -n "$ph" ]; then ok "phase name readable ($ph)"; else no "phase name readable"; fi

# ─── Result ──────────────────────────────────────────────────────────────────

echo ""
echo "────────────────────────────────"
echo "  $PASS passed, $FAIL failed"
echo ""

if [ "$FAIL" -gt 0 ]; then
	exit 1
fi
