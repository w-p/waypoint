#!/usr/bin/env bash
# Session runner: chain the units of a runbook, one fresh scripted Claude Code session each,
# with no supervising session in between. Run mode is described in .waypoint/skills/run.md;
# what a chain may do in this project is the policy, .waypoint/automation.md, written by the
# setup interview (.waypoint/skills/run-setup.md). Without a policy the runner refuses to start.
#
#   .claude/runner/run_chain.sh RUNBOOK UNIT [UNIT...] [--wait-for CMD] [--may-push UNIT]
#                               [--cap N] [--out DIR]
#
#   RUNBOOK      .waypoint/plan/runs/<run>.md; <run> names the memory file units append to
#   UNIT...      unit ids in order, as the runbook's # column has them
#   --wait-for   a shell command polled until it exits 0 before the first unit (a CI run ending)
#   --may-push   a unit allowed to move the protected branch on origin (repeatable); any other
#                unit that does halts the chain
#   --cap        most sessions this chain may start (default: one per unit, no retries)
#   --out        the run folder: events, logs, each session's JSON, the `done` file
#                (default .waypoint/events/runs/<run>-<YYYYMMDD-HHMMSS>, where readers look)
#
# Before every unit it reads the policy and stops, starting no session, on: the environment
# check failing (ENV), the daily session or token cap (CAP), a runbook deadline for that unit
# passed (DEADLINE; a runbook line `**Deadline:** unit <id> starts by YYYY-MM-DD HH:MM`), or,
# when the policy asks for it, an open issue not labelled run-mode (CI). It waits, without
# spending tokens, while the policy's quiet window or pause command holds.
# After every unit it:
#   - reads the session's status line; anything but DONE or WAITING ends the chain (STOPPED)
#   - checks the unit wrote its memory entry and committed its work
#   - halts (HALT) on a hard-stop sign: a file that governs the run changed while the unit ran
#     (the policy, the runbook, .claude's settings, hooks, rules or runner), the protected
#     branch on origin moved by a unit not named in --may-push, or, when the policy asks for
#     it, a workflow_dispatch run created during the chain
#   - appends a ledger line (session id, times, turns, tokens) to the memory file and commits it
#   - stops if the unit passed the per-unit token cap (CAP)
#   - waits on a job the unit launched (`WAITING pid <N>`) until that process is gone
# It stops at the next boundary if OUT/HOLD exists (`touch` it to say "hold": HELD).
# Every end notifies as the policy says. It writes its pid to OUT/pid and, at the end, OUT/done:
# one line, "<OUTCOME> <detail>". Exit 0 only when every unit is DONE.
# Session events (contracts/session-events.md in the Waypoint repository) go to OUT/events.jsonl.
# Each unit runs under a session id chosen here (--session-id) and carries WAYPOINT_RUN, so its
# own hooks tag it a unit.
#
# Needs bash, git, python3 (3.9 or later) and GNU coreutils (timeout, date -d, stat -c): Linux
# and WSL. `gh` only when the policy uses GitHub (issue notifications, the CI-issue stop, the
# dispatch halt).
set -uo pipefail

REPO="${RUNNER_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CLAUDE_BIN="${RUNNER_CLAUDE:-claude}"
GH_BIN="${RUNNER_GH:-gh}"
POLL="${RUNNER_POLL_SECS:-600}"
MAX_WAIT="${RUNNER_MAX_WAIT_SECS:-259200}"      # three days on any one wait
POLICY="${RUNNER_POLICY:-$REPO/.waypoint/automation.md}"

ARGS=("$@")
RUNBOOK="${1:?usage: run_chain.sh RUNBOOK UNIT [UNIT...] [options]}"; shift
UNITS=(); MAY_PUSH=" "; WAIT_FOR=""; CAP=""; OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --wait-for) WAIT_FOR="$2"; shift 2 ;;
    --may-push) MAY_PUSH+="$2 "; shift 2 ;;
    --cap) CAP="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --*) echo "run_chain.sh: unknown option $1" >&2; exit 2 ;;
    *) UNITS+=("$1"); shift ;;
  esac
done
[ ${#UNITS[@]} -gt 0 ] || { echo "run_chain.sh: no units" >&2; exit 2; }
[ -f "$REPO/$RUNBOOK" ] || { echo "run_chain.sh: no runbook $REPO/$RUNBOOK" >&2; exit 2; }
RUN="$(basename "$RUNBOOK" .md)"
OUT="${OUT:-$REPO/.waypoint/events/runs/$RUN-$(date +%Y%m%d-%H%M%S)}"
CAP="${CAP:-${#UNITS[@]}}"
mkdir -p "$OUT"
cd "$REPO" || exit 2

# Policy: the fenced `automation` block of .waypoint/automation.md, a JSON object. Read fresh at
# every use, so an edit takes effect at the next unit.
policy() {   # policy KEY [DEFAULT]: print the value (true/false for booleans); exit 1 if absent with no default
  python3 - "$POLICY" "$@" <<'PY'
import json, re, sys
try:
    m = re.search(r"^```automation\n(.*?)^```", open(sys.argv[1]).read(), re.M | re.S)
    p = json.loads(m.group(1))
except Exception:
    p = None
key = sys.argv[2]
if p is None or key not in p:
    if len(sys.argv) > 3 and p is not None:
        print(sys.argv[3]); sys.exit(0)
    sys.exit(1)
v = p[key]
print(str(v).lower() if isinstance(v, bool) else v if isinstance(v, str) else json.dumps(v))
PY
}
PTZ="$(policy tz "" 2>/dev/null)"                # the project's time zone; empty = this machine's
now() { if [ -n "$PTZ" ]; then TZ="$PTZ" date "$@"; else date "$@"; fi; }

log() { echo "$(now '+%m-%d %I:%M %p') $*" | tee -a "$OUT/runner.log"; }
notify() {   # notify OUTCOME DETAIL: tell the developer, by the policy's channel; never fatal
  [ "${RUNNER_NOTIFY:-1}" = 0 ] && return 0
  local mode close=false body mem title="Run $RUN: $1"
  mode="$(policy notify none 2>/dev/null)" || mode=none
  [ "$mode" = none ] && return 0
  [ "$1" = DONE ] && close=true
  mem="$(ls -t "$REPO"/.waypoint/memory/*-"$RUN".md 2>/dev/null | head -1)"
  body="$(printf 'Run **%s** ended **%s**: %s\n\nRun folder: `%s`\nMemory file: `%s`\n\nRunner log, last lines:\n```\n%s\n```\n' \
    "$RUN" "$1" "$2" "${OUT#"$REPO"/}" "${mem#"$REPO"/}" "$(tail -15 "$OUT/runner.log" 2>/dev/null)")"
  case "$mode" in
    github-issue)
      # A repository_dispatch the `run notify` workflow turns into an issue opened by the Actions
      # bot: an issue opened under the developer's own login would notify nobody.
      "$GH_BIN" api "repos/{owner}/{repo}/dispatches" -f event_type=run-mode \
        -f "client_payload[title]=$title" -f "client_payload[body]=$body" \
        -F "client_payload[close]=$close" >/dev/null 2>>"$OUT/runner.log" ;;
    command)
      WAYPOINT_NOTIFY_RUN="$RUN" WAYPOINT_NOTIFY_OUTCOME="$1" WAYPOINT_NOTIFY_DETAIL="$2" \
        WAYPOINT_NOTIFY_TITLE="$title" WAYPOINT_NOTIFY_BODY="$body" \
        bash -c "$(policy notify_cmd false 2>/dev/null)" >/dev/null 2>>"$OUT/runner.log" ;;
    *) false ;;
  esac && log "notified ($mode): $1" || log "NOTIFY FAILED ($mode): no message went out for $1"
}
finish() {   # finish OUTCOME RC DETAIL
  echo "$1 $3" > "$OUT/done"
  declare -F emit >/dev/null && emit run.finished outcome="$1" detail="$3"
  log "END $1: $3"
  notify "$1" "$3"
  exit "$2"
}
[ -e "$OUT/done" ] && { echo "run_chain.sh: $OUT/done exists (a finished chain); move it first" >&2; exit 2; }
# Run from a private copy: bash reads a script as it executes, so editing run_chain.sh under a
# live chain would make the waiting runner resume at the wrong byte.
if [ "${RUN_CHAIN_COPY:-}" != 1 ]; then
  cp "${BASH_SOURCE[0]}" "$OUT/run_chain.sh"
  RUN_CHAIN_COPY=1 RUNNER_REPO="$REPO" exec bash "$OUT/run_chain.sh" "${ARGS[@]}"
fi
# Watchers use the pid file; a `pgrep -f` pattern also matches the watcher's own command line.
echo $$ > "$OUT/pid"; echo "$REPO" > "$OUT/repo"

# Session events. A failed write never stops the chain.
EV="$OUT/events.jsonl"
EMIT="${RUNNER_EMIT:-$REPO/.claude/hooks/waypoint_events.py}"
export WAYPOINT_RUN="$(basename "$OUT")" WAYPOINT_PROJECT="$(basename "$REPO")"
WAYPOINT_TOOL_VERSION="$("$CLAUDE_BIN" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
export WAYPOINT_TOOL_VERSION
emit() { python3 "$EMIT" runner "$EV" "$@" 2>>"$OUT/runner.log" || true; }
sess() { printf '{"id":"%s","kind":"unit","parent":"%s"}' "$1" "$WAYPOINT_RUN"; }
# Event files are never committed, whatever the project's own .gitignore says.
[ -d "$REPO/.waypoint/events" ] && [ ! -e "$REPO/.waypoint/events/.gitignore" ] && echo '*' > "$REPO/.waypoint/events/.gitignore"
# Retention: this writer's kind, run folders under .waypoint/events/runs, older than 30 days.
find "$REPO/.waypoint/events/runs" -mindepth 1 -maxdepth 1 -type d -mtime +30 -exec rm -rf {} + 2>/dev/null || true

[ -f "$POLICY" ] || finish NOPOLICY 2 "no policy file $POLICY: run the setup interview (.waypoint/skills/run-setup.md)"
for k in sessions_per_day tokens_per_unit tokens_per_day unit_timeout_s stop_on_ci_issue env_check; do
  policy "$k" >/dev/null 2>&1 || finish NOPOLICY 2 "policy $POLICY lacks '$k' or its automation block does not parse"
done

# Quiet windows and pauses. `quiet` is a list of weekly windows ("Fri 17:00-Sat 03:00") or daily
# ones ("22:00-06:00") in the policy's time zone; `held_cmd` is a command that exits 0 while no
# session may start (a project's own build pauser). RUNNER_NOW ("YYYY-MM-DD HH:MM") is a fake
# clock for the quiet-window drill.
in_quiet_window() {   # exit 0 inside a window, 1 outside; 2, with the reason printed, when it cannot tell
  python3 - "$POLICY" "${RUNNER_NOW:-}" <<'PY'
import datetime, json, re, sys

def refuse(why):
    print(why)
    sys.exit(2)

def main():
    try:
        block = re.search(r"^```automation\n(.*?)^```", open(sys.argv[1]).read(), re.M | re.S)
        p = json.loads(block.group(1))
    except Exception:
        refuse("its automation block does not parse")
    # The zone is checked even when the clock is faked or no window is set: `date` falls back
    # to UTC without a word for a name it does not know, and so would every time in the log.
    zone = None
    if p.get("tz"):
        try:
            import zoneinfo
            zone = zoneinfo.ZoneInfo(p["tz"])
        except Exception:
            refuse(f"'tz' does not name a time zone this machine knows ({p['tz']!r}; want a name like \"America/New_York\")")
    if sys.argv[2]:
        t = datetime.datetime.strptime(sys.argv[2], "%Y-%m-%d %H:%M")
    else:
        t = datetime.datetime.now(zone)
    days = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
    hit = False
    for w in p.get("quiet") or []:
        unparsed = f"a 'quiet' entry does not parse ({w!r}; want \"Fri 17:00-Sat 03:00\" or \"22:00-06:00\")"
        m = re.fullmatch(r"\s*(?:(\w{3}) )?(\d{1,2}):(\d\d)\s*-\s*(?:(\w{3}) )?(\d{1,2}):(\d\d)\s*", str(w))
        if not m or bool(m.group(1)) != bool(m.group(4)):
            refuse(unparsed)
        if max(int(m.group(2)), int(m.group(5))) > 23 or max(int(m.group(3)), int(m.group(6))) > 59:
            refuse(unparsed)
        start = int(m.group(2)) * 60 + int(m.group(3))
        end = int(m.group(5)) * 60 + int(m.group(6))
        at = t.hour * 60 + t.minute
        if m.group(1):                      # a weekly window: minutes since Monday 00:00
            if m.group(1).lower() not in days or m.group(4).lower() not in days:
                refuse(unparsed)
            start += days.index(m.group(1).lower()) * 1440
            end += days.index(m.group(4).lower()) * 1440
            at += t.weekday() * 1440
        # A window whose end is not after its start wraps (past midnight, or past Sunday).
        hit = hit or (start <= at < end if start < end else at >= start or at < end)
    sys.exit(0 if hit else 1)

try:
    main()
except Exception as e:      # never let a crash exit 1: that reads as "outside every window"
    refuse(f"its quiet windows could not be read ({type(e).__name__})")
PY
}
quiet() {   # exit 0 inside a quiet window, 1 outside; ends the chain when it cannot tell which
  local why rc
  why="$(in_quiet_window)"; rc=$?
  [ "$rc" -le 1 ] && return "$rc"
  finish NOPOLICY 2 "policy $POLICY: ${why:-its quiet windows could not be read}"
}
quiet   # refuse now, before any session, if the windows or the zone cannot be read
held() {   # exit 0 while no session may start
  local cmd="${RUNNER_HELD_CMD-$(policy held_cmd "")}"
  if [ -n "$cmd" ] && ( eval "$cmd" ) >/dev/null 2>&1; then return 0; fi
  quiet
}
not_held() { ! held; }

# Environment. A scripted session has no interactive profile; `env_setup` is shell the policy
# gives to put the project's toolchain in place (a PATH line), run once here so every unit
# inherits it. `env_check` is then judged before each unit.
eval "$(policy env_setup "")" >/dev/null 2>>"$OUT/runner.log" || true
for tool in git python3 timeout "$CLAUDE_BIN"; do
  command -v "$tool" >/dev/null 2>&1 || finish ENV 7 "the runner needs '$tool' on PATH and did not find it"
done

# A job a unit launched is not the runner's child, so its exit status is known only when the
# job's wrapper recorded it: a file <job_exit_dir>/<pid> holding the code, written when it ends.
JOB_EXIT_DIR="${RUNNER_JOB_EXIT_DIR-$(policy job_exit_dir "")}"
JOB_EXIT_DIR="${JOB_EXIT_DIR/#\~/$HOME}"

# The branch whose movement on origin is a push: the policy's, else origin's default, else main.
PBRANCH="$(policy protected_branch "")"
[ -n "$PBRANCH" ] || PBRANCH="$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"
PBRANCH="${PBRANCH:-main}"

FROZEN_S=0
wait_until() {   # wait_until REASON DESCRIPTION CMD...: poll CMD until it exits 0; honors HOLD
  # REASON is the contract's run.waiting reason: wait_for, window or job. While waiting on a job,
  # polls that find the quiet window or a pause in force add to FROZEN_S.
  local reason="$1" desc="$2"; shift 2
  local t0=$SECONDS said=0
  FROZEN_S=0
  until "$@"; do
    [ -e "$OUT/HOLD" ] && finish HELD 5 "hold file present while waiting for $desc"
    (( SECONDS - t0 > MAX_WAIT )) && finish TIMEOUT 6 "waited ${MAX_WAIT}s for $desc"
    [ $said = 0 ] && { log "waiting: $desc"; emit run.waiting reason="$reason" detail="$desc"; said=1; }
    sleep "$POLL"
    check_ci "while waiting for $desc"
    [ "$reason" = job ] && held && FROZEN_S=$((FROZEN_S + POLL))
  done
  [ $said = 1 ] && { log "done waiting: $desc"; emit run.resumed reason="$reason"; }
  return 0
}
# What governs a run: the policy, the runbook, and the adapter files that decide what a session
# may do and what runs around it. The developer approved the run under these, so a unit changes
# none of them, tracked or not. The developer may change them between units (during a wait); the
# policy is read fresh at every use for that reason.
GOVERNING_FILES=("$POLICY" "$REPO/$RUNBOOK" "$REPO/.claude/settings.json" "$REPO/.claude/settings.local.json")
GOVERNING_DIRS=("$REPO/.claude/hooks" "$REPO/.claude/rules" "$REPO/.claude/runner")
governing() {   # one line per governing file that exists: "<sha256>  <path>"
  local f
  for f in "${GOVERNING_FILES[@]}"; do [ -f "$f" ] && sha256sum "$f"; done
  find "${GOVERNING_DIRS[@]}" -type f -exec sha256sum {} + 2>/dev/null
  return 0
}
governing_changes() {   # governing_changes BEFORE: the files added, removed or changed since, on one line
  local path
  comm -3 <(sort <<<"$1") <(governing | sort) | sed 's/^\t//; s/^[0-9a-f]*  //' | sort -u \
    | while read -r path; do printf '%s ' "${path#"$REPO"/}"; done
}
entries() {   # entries UNIT FILE...: how many memory entries for UNIT the files hold (missing files hold none)
  cat "${@:2}" 2>/dev/null | grep -c -- "-- unit $1:"
}
pid_gone() { ! kill -0 "$1" 2>/dev/null; }
origin_branch() { git ls-remote origin "refs/heads/$PBRANCH" 2>/dev/null | cut -f1; }
dispatches_since() {   # count workflow_dispatch runs created at or after $1 (ISO, UTC); "?" if gh fails 3 times
  local n try
  for try in 1 2 3; do
    n="$("$GH_BIN" run list --event workflow_dispatch --limit 50 --json createdAt \
          -q "[.[] | select(.createdAt >= \"$1\")] | length" 2>/dev/null)" && [[ "$n" =~ ^[0-9]+$ ]] && { echo "$n"; return; }
    sleep $(( try * ${RUNNER_GH_RETRY_SECS:-20} ))
  done
  echo "?"
}
ci_issues() {   # open issues not labelled run-mode, as "#N title; ..."; "?" if gh fails 3 times
  local out try
  for try in 1 2 3; do
    out="$("$GH_BIN" issue list --state open --limit 50 --json number,title,labels \
            -q '[.[] | select(all(.labels[]; .name != "run-mode"))] | map("#\(.number) \(.title)") | join("; ")' 2>/dev/null)" \
      && { echo "$out"; return; }
    sleep $(( try * ${RUNNER_GH_RETRY_SECS:-20} ))
  done
  echo "?"
}
check_ci() {   # check_ci WHEN: stop on an open issue the runner did not open, when the policy says to
  [ "$(policy stop_on_ci_issue)" = true ] || return 0
  local open; open="$(ci_issues)"
  [ -z "$open" ] && return 0
  finish CI 8 "$1: open issue(s) not from the runner ('?' = gh unreachable): $open"
}

# The daily tally, per day in the policy's time zone, across all runs: "start RUN UNIT" and
# "tokens RUN UNIT N" lines.
DAILY_DIR="${RUNNER_DAILY_DIR:-$REPO/.waypoint/events/daily}"
mkdir -p "$DAILY_DIR"
today_file() { echo "$DAILY_DIR/$(now +%F).tsv"; }
today_sessions() { local n; n="$(grep -c '^start' "$(today_file)" 2>/dev/null)"; echo "${n:-0}"; }
today_tokens() { awk '$1 == "tokens" { s += $4 } END { print s + 0 }' "$(today_file)" 2>/dev/null || echo 0; }
deadline() {   # deadline UNIT: the runbook's "starts by" time for UNIT as epoch seconds, or nothing
  local t; t="$(sed -n "s/^\*\*Deadline:\*\* unit $1 starts by \([0-9-]* [0-9:]*\).*/\1/p" "$REPO/$RUNBOOK" | head -1)"
  [ -n "$t" ] && now -d "$t" +%s
}

CHAIN_START_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
log "START run $RUN units ${UNITS[*]} cap $CAP may-push [${MAY_PUSH# }] out $OUT"
names="$(python3 - "$REPO/$RUNBOOK" "${UNITS[@]}" <<'PY'
import json, re, sys
book, units = open(sys.argv[1]).read(), set(sys.argv[2:])
print(json.dumps({m.group(1): m.group(2).strip()
                  for m in re.finditer(r"^\| *(\w+) *\| *([^|]+?) *\|", book, re.M) if m.group(1) in units}))
PY
)"
[ -n "$names" ] || names='{}'
units_json="$(printf '%s\n' "${UNITS[@]}" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().split()))')"
may_json="$(printf '%s\n' $MAY_PUSH | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().split()))')"
emit run.started runbook="$RUNBOOK" units:="$units_json" names:="$names" cap:="$CAP" \
  may_push:="$may_json" wait_for="$WAIT_FOR"

[ -n "$WAIT_FOR" ] && wait_until wait_for "--wait-for: $WAIT_FOR" bash -c "$WAIT_FOR"

sessions=0; n_units=${#UNITS[@]}; i=0
for u in "${UNITS[@]}"; do
  i=$((i + 1))
  [ -e "$OUT/HOLD" ] && finish HELD 5 "hold file present before unit $u"
  wait_until window "the quiet window or a pause to end" not_held
  (( sessions >= CAP )) && finish CAP 3 "session cap $CAP reached before unit $u"
  dl="$(deadline "$u")"
  [ -n "$dl" ] && (( $(date +%s) > dl )) \
    && finish DEADLINE 9 "unit $u was to start by $(now -d "@$dl" '+%a %m-%d %I:%M %p %Z') (runbook Deadline line)"
  check_ci "before unit $u"
  n_today="$(today_sessions)"; cap_today="$(policy sessions_per_day)"
  (( n_today >= cap_today )) && finish CAP 3 "daily session cap: $n_today of $cap_today sessions already started today, before unit $u"
  t_today="$(today_tokens)"; tcap_today="$(policy tokens_per_day)"
  (( t_today >= tcap_today )) && finish CAP 3 "daily token cap: $t_today of $tcap_today tokens used today, before unit $u"
  env_check="$(policy env_check)"
  ( cd "$REPO" && eval "$env_check" ) >/dev/null 2>&1 \
    || finish ENV 7 "environment check failed before unit $u: $env_check"
  sessions=$((sessions + 1))
  printf 'start\t%s\t%s\n' "$RUN" "$u" >> "$(today_file)"
  UNIT_TIMEOUT="${RUNNER_UNIT_TIMEOUT_SECS:-$(policy unit_timeout_s)}"
  suffix="$(policy commit_suffix "")"
  rules="$(policy unit_rules "")"

  day0="$(date +%F)"; start="$(now '+%I:%M %p')"
  head0="$(git rev-parse HEAD)"; origin0="$(origin_branch)"; governing0="$(governing)"
  entries0="$(entries "$u" .waypoint/memory/*-"$RUN".md)"
  next_note="the runner starts unit ${UNITS[$i]:-<none: last unit>} next, only on DONE or WAITING pid <N>"
  prompt="You are unit $u of the run .waypoint/plan/runs/$RUN.md ($i of $n_units in this chain), a fresh scripted session in run mode (.waypoint/skills/run.md). The runner .claude/runner/run_chain.sh spawned you; no one reviews between units, and $next_note. The developer approved this run's scope as the runbook's header records it.

First boot per .waypoint/opord.md section 3a, including the most recent memory files for this run (.waypoint/memory/*-$RUN.md) and sop.md. Read any skill the unit names and follow it.

Then do unit $u only: confirm its Entry against artifacts, do its Do column, run its Exit check. Do nothing outside this unit. If anything is unexpected, a check fails, a gate is outside its limit, or a decision is needed that the runbook and its sources do not settle, stop without improvising. Never do anything the policy (.waypoint/automation.md) names as a hard stop: no release, deploy or publication. Push only where the unit says to.${suffix:+ Every commit you make carries $suffix in its subject.}${rules:+ $rules}

Before finishing, append to the memory file dated today, .waypoint/memory/YYYY-MM-DD-$RUN.md (create it if missing, first line a standalone summary of the run): a heading '## <local time> -- unit $u: <unit name>', then one line holding exactly one status (DONE, WAITING pid <N> <job>, BLOCKED <reason>, or FAILED <reason>; a reason is one plain line a person can act on, e.g. 'FAILED integration tests: the staging database refused connections'), then a short note a cold reader can act on (what you verified, with commands and results). The runner adds the ledger line. Commit that entry with the unit's other changes, leaving no tracked file modified. End your reply with the same status line, alone on the last line. The runner reads only that line, and DONE stands by itself: if anything is left to say about the result, the status is not DONE."

  log "unit $u: session $sessions starting"
  json="$OUT/unit-$u.json"
  usid="$(python3 -c 'import uuid; print(uuid.uuid4())')"
  utx="$HOME/.claude/projects/$(printf '%s' "$REPO" | sed 's#[^A-Za-z0-9]#-#g')/$usid.jsonl"
  emit unit.started unit="$u" session:="$(sess "$usid")" \
    transcript:="{\"path\":\"$utx\",\"format\":\"claude-code-jsonl\"}"
  t_unit=$SECONDS
  timeout "$UNIT_TIMEOUT" "$CLAUDE_BIN" -p --session-id "$usid" --permission-mode "$(policy permission_mode auto)" \
    --output-format json "$prompt" < /dev/null > "$json" 2> "$OUT/unit-$u.stderr"
  rc=$?
  dur_unit=$((SECONDS - t_unit))
  end="$(now '+%I:%M %p %Z')"; day1="$(date +%F)"

  # Status line and token use from the session's JSON result.
  read -r status sid turns secs tin tcw tcr tout denials < <(python3 - "$json" <<'PY'
import json, re, sys
try:
    raw = open(sys.argv[1]).read()
    d = json.loads(raw[raw.index("{"):])
except Exception:
    print("NO_JSON - 0 0 0 0 0 0 0"); sys.exit()
# Only the reply's last line is judged, as the unit was told to end on its status. A status
# word further up is the unit talking about its work, and a DONE that goes on to say more
# ("DONE except the exit check") is not a DONE.
status = "NO_STATUS"
lines = (d.get("result") or "").strip().splitlines()
last = lines[-1].strip().strip("*`_ ") if lines else ""
m = re.match(r"(DONE|WAITING|BLOCKED|FAILED)\b(.*)", last)
if m and m.group(1) == "DONE":
    if not m.group(2).strip(" .!"):
        status = "DONE"
elif m:
    status = (m.group(1) + m.group(2)).replace(" ", "_")
u = d.get("usage") or {}
print(status, d.get("session_id", "-"), d.get("num_turns", 0), round(d.get("duration_ms", 0) / 1000),
      u.get("input_tokens", 0), u.get("cache_creation_input_tokens", 0),
      u.get("cache_read_input_tokens", 0), u.get("output_tokens", 0),
      len(d.get("permission_denials") or []))
PY
)
  status_words="${status//_/ }"
  log "unit $u: exit $rc, status: $status_words"
  [ "$sid" = - ] && sid="$usid"
  ustat="${status%%_*}"; ureason="${status_words#"$ustat"}"; ureason="${ureason# }"
  case "$ustat" in DONE|WAITING|BLOCKED|FAILED) ;; *) ustat=NO_STATUS ;; esac
  emit unit.ended unit="$u" session:="$(sess "$sid")" status="$ustat" reason="$ureason" exit_code:="$rc" \
    duration_s:="$dur_unit" turns:="${turns:-0}" permission_denials:="${denials:-0}" \
    tokens:="{\"input\":${tin:-0},\"cache_write\":${tcw:-0},\"cache_read\":${tcr:-0},\"output\":${tout:-0}}" \
    transcript:="{\"path\":\"$utx\",\"format\":\"claude-code-jsonl\"}"

  # The memory entry, and the ledger line under it. The entry must be new: a chain run again
  # after a stop finds the earlier attempt's entry for the same unit already in the file.
  mem=""
  if (( $(entries "$u" .waypoint/memory/*-"$RUN".md) > entries0 )); then
    for d in "$day1" "$day0"; do
      f=".waypoint/memory/$d-$RUN.md"
      (( $(entries "$u" "$f") > 0 )) && { mem="$f"; break; }
    done
  fi
  ledger="Ledger (runner): unit $u session $sid, $start to $end, exit $rc, $turns turns, ${secs}s; tokens: input $tin, cache write $tcw, cache read $tcr, output $tout; permission denials $denials."
  if [ -n "$mem" ]; then
    if git ls-files --error-unmatch "$mem" >/dev/null 2>&1 && git diff --quiet -- "$mem" && git diff --cached --quiet -- "$mem"; then
      printf '%s\n' "$ledger" >> "$mem"
      git commit -q -m "Run $RUN: unit $u ledger${suffix:+ $suffix}" -- "$mem" \
        || finish STOPPED 3 "unit $u: the ledger commit failed"
    else
      finish STOPPED 3 "unit $u left its memory entry uncommitted ($mem); ledger: $ledger"
    fi
  fi

  used=$(( ${tin:-0} + ${tcw:-0} + ${tcr:-0} + ${tout:-0} ))
  printf 'tokens\t%s\t%s\t%s\n' "$RUN" "$u" "$used" >> "$(today_file)"

  # Hard-stop signs, checked before anything else is judged.
  governed="$(governing_changes "$governing0")"
  [ -n "$governed" ] && finish HALT 4 "unit $u: files that govern the run changed while it ran: ${governed% } (the policy, the runbook and .claude's settings, hooks, rules and runner change only between units, by the developer); ledger: $ledger"
  if [ "$(policy halt_on_dispatch false)" = true ]; then
    dsp="$(dispatches_since "$CHAIN_START_UTC")"
    [ "$dsp" != 0 ] && finish HALT 4 "unit $u: $dsp workflow_dispatch run(s) created since $CHAIN_START_UTC (or gh failed: '$dsp'); ledger: $ledger"
  fi
  origin1="$(origin_branch)"
  if [ "$origin1" != "$origin0" ] && [[ "$MAY_PUSH" != *" $u "* ]]; then
    finish HALT 4 "unit $u moved origin/$PBRANCH ${origin0:0:7} -> ${origin1:0:7} and may not push; ledger: $ledger"
  fi

  [ -z "$mem" ] && finish STOPPED 3 "unit $u wrote no new memory entry under '-- unit $u:' (status: $status_words); ledger: $ledger"
  git diff --quiet && git diff --cached --quiet \
    || finish STOPPED 3 "unit $u left tracked files modified: $(git diff --name-only HEAD | tr '\n' ' ')"
  tcap_unit="$(policy tokens_per_unit)"
  (( used > tcap_unit )) && finish CAP 3 "unit $u used $used tokens, over the per-unit cap of $tcap_unit (status: $status_words)"
  [ "$rc" = 0 ] || finish STOPPED 3 "unit $u: claude exited $rc (124 = the ${UNIT_TIMEOUT}s timeout); status: $status_words"

  case "$status" in
    DONE*) : ;;
    WAITING_pid_*)
      pid="$(echo "$status" | cut -d_ -f3)"
      [[ "$pid" =~ ^[0-9]+$ ]] || finish STOPPED 3 "unit $u: WAITING without a numeric pid ($status_words)"
      jlog="$(readlink "/proc/$pid/fd/1" 2>/dev/null)"
      emit job.started unit="$u" pid:="$pid" ${jlog:+log="$jlog"}
      t_job=$SECONDS; job_epoch=$(( $(date +%s) - 1 ))
      wait_until job "unit $u's job, pid $pid, to exit" pid_gone "$pid"
      jrc=""; jf="$JOB_EXIT_DIR/$pid"
      # Only a file written after the job started: a pid can be reused.
      [ -n "$JOB_EXIT_DIR" ] && [ -f "$jf" ] && [ "$(stat -c %Y "$jf")" -ge "$job_epoch" ] && jrc="$(tr -dc 0-9 < "$jf")"
      emit job.ended unit="$u" duration_s:="$((SECONDS - t_job))" frozen_s:="$FROZEN_S" ${jrc:+exit_code:="$jrc"}
      [ -n "$jrc" ] && log "unit $u's job exited $jrc" ;;
    NO_STATUS) finish STOPPED 3 "unit $u: NO STATUS: the reply's last line is not DONE alone or a status with its reason (reply in ${json#"$REPO"/}; memory $mem)" ;;
    *) finish STOPPED 3 "unit $u: $status_words (memory $mem)" ;;
  esac
  log "unit $u: commits ${head0:0:7}..$(git rev-parse --short HEAD)"
done
finish DONE 0 "all ${#UNITS[@]} units done, $sessions sessions"
