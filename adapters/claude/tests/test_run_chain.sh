#!/usr/bin/env bash
# Every stop in run_chain.sh, seen to fire, with stub sessions in a throwaway repository.
#   adapters/claude/tests/test_run_chain.sh   (about a minute; nothing outside a temp dir is touched)
# Lives in the Waypoint repository and is run by ./test.sh; it is not installed into projects.
# Stub `claude`: reads its unit from the prompt and follows $STUBS/unit-<id>, lines of
#   status <line>   the status it reports      mem no     write no memory entry
#   nocommit        leave the entry uncommitted push      move origin/main
#   job <secs>      launch a detached sleep and report WAITING pid <N>
#   sh <command>    run a shell command in the repository before the memory entry
#   after <line>    a line the reply carries after its status line
# It records its prompt in $STUBS/prompt-<id> and its --permission-mode in $STUBS/perm.
# Stub `gh`: reports $GH_DISPATCHES workflow_dispatch runs (or fails if it is "fail"); lists the open
#   non-runner issues written in $STUBS/issues; records each notification's dispatch in $STUBS/notify.
# Each test's policy is $d/policy.md (POLICY below, or a test's own), its daily tally $d/daily.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADAPTER="$(cd "$HERE/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "${T:?}"' EXIT
BIN="$T/bin"; mkdir -p "$BIN"

cat > "$BIN/claude" <<'STUB'
#!/usr/bin/env bash
[ "$1" = --version ] && { echo "2.1.0 (Claude Code)"; exit 0; }
prompt="${!#}"
sid=""; args=("$@"); for i in "${!args[@]}"; do [ "${args[$i]}" = --session-id ] && sid="${args[$((i+1))]}"; done
echo "$sid" >> "$STUBS/session-ids"
for i in "${!args[@]}"; do [ "${args[$i]}" = --permission-mode ] && echo "${args[$((i+1))]}" >> "$STUBS/perm"; done
u="$(sed -n 's/^You are unit \([^ ]*\) of the run.*/\1/p' <<<"$prompt" | head -1)"
printf '%s\n' "$prompt" > "$STUBS/prompt-$u"
run="$(sed -n 's/.*of the run \.waypoint\/plan\/runs\/\([^ ]*\)\.md.*/\1/p' <<<"$prompt" | head -1)"
spec="$STUBS/unit-$u"; status="DONE"
grep -q '^status ' "$spec" && status="$(sed -n 's/^status //p' "$spec")"
if grep -q '^job ' "$spec"; then
  setsid nohup sleep "$(sed -n 's/^job //p' "$spec")" >/dev/null 2>&1 &
  status="WAITING pid $! sleep"
fi
if grep -q '^jobrc ' "$spec"; then   # jobrc <secs> <rc>: a job whose wrapper records its exit code in the job exit folder
  read -r _ secs code < <(grep '^jobrc ' "$spec")
  setsid nohup bash -c 'sleep "$1"; mkdir -p "$3"; echo "$2" > "$3/$$"; exit "$2"' _ "$secs" "$code" "$STUB_EXIT_DIR" >/dev/null 2>&1 &
  status="WAITING pid $! build"
fi
grep -q '^sh ' "$spec" && eval "$(sed -n 's/^sh //p' "$spec")"
mem=".waypoint/memory/$(date +%F)-$run.md"
if ! grep -q '^mem no' "$spec"; then
  mkdir -p .waypoint/memory
  [ -f "$mem" ] || echo "Test run." > "$mem"
  printf '\n## now -- unit %s: stub\n%s\nnote\n' "$u" "$status" >> "$mem"
  grep -q '^nocommit' "$spec" || { git add "$mem"; git commit -q -m "unit $u [skip ci]"; }
fi
grep -q '^push' "$spec" && git push -q origin HEAD:main
grep -q '^after ' "$spec" && status="$status
$(sed -n 's/^after //p' "$spec")"
python3 -c 'import json,sys; print(json.dumps({"result": "work\n" + sys.argv[1],"session_id": sys.argv[3] or "s-" + sys.argv[2], "num_turns": 3, "duration_ms": 1000, "usage": {"input_tokens": 5, "cache_creation_input_tokens": 10, "cache_read_input_tokens": 100, "output_tokens": 7}, "permission_denials": []}))' "$status" "$u" "$sid"
STUB
cat > "$BIN/gh" <<'STUB'
#!/usr/bin/env bash
case "$1 $2" in
  "run list") [ "${GH_DISPATCHES:-0}" = fail ] && exit 1; echo "${GH_DISPATCHES:-0}" ;;
  "issue list") [ "${GH_ISSUES:-}" = fail ] && exit 1; cat "$STUBS/issues" 2>/dev/null; exit 0 ;;
  "api repos/{owner}/{repo}/dispatches") printf '%s\n' "$*" >> "$STUBS/notify"; [ "${GH_NOTIFY:-}" = fail ] && exit 1; exit 0 ;;
  *) exit 0 ;;
esac
STUB
chmod +x "$BIN/claude" "$BIN/gh"

pass=0; fail=0
check() {   # check NAME WANT_RC WANT_OUTCOME RC OUTDIR [GREP_IN_LOG]
  local got; got="$(cut -d' ' -f1 "$5/done" 2>/dev/null)"
  if [ "$4" = "$2" ] && [ "$got" = "$3" ] && { [ -z "${6:-}" ] || grep -q -- "$6" "$5/runner.log"; }; then
    echo "PASS $1"; pass=$((pass + 1))
  else
    echo "FAIL $1: rc $4 (want $2), outcome '$got' (want $3)"; cat "$5/runner.log" 2>/dev/null | sed 's/^/    /'; fail=$((fail + 1))
  fi
}
fresh() {   # fresh NAME: a repo with a bare origin, a runbook, and empty stub specs
  local d="$T/$1"
  git init -q --bare "$d/origin.git"
  git init -q -b main "$d/repo"
  ( cd "$d/repo" && git config user.email t@t && git config user.name t \
    && mkdir -p .waypoint/plan/runs && echo "# test run" > .waypoint/plan/runs/trun.md \
    && git add . && git commit -q -m init && git remote add origin "$d/origin.git" && git push -q origin main )
  mkdir -p "$d/stubs"
  policy_file "$d/policy.md"
  echo "$d"
}
policy_file() {   # policy_file PATH [KEY=JSONVALUE...]: the test policy, with overrides
  python3 - "$@" <<'PY'
import json, sys
p = {"sessions_per_day": 12, "tokens_per_unit": 3000000, "tokens_per_day": 15000000,
     "unit_timeout_s": 7200, "stop_on_ci_issue": True, "env_check": "true",
     "notify": "github-issue", "halt_on_dispatch": True}
for kv in sys.argv[2:]:
    k, v = kv.split("=", 1); p[k] = json.loads(v)
open(sys.argv[1], "w").write("# test policy\n\n```automation\n" + json.dumps(p, indent=1) + "\n```\n")
PY
}
go() {   # go DIR [ARGS...]: run the chain there; prints the exit code
  local d="$1"; shift
  ( [ -n "${HELD+x}" ] && export RUNNER_HELD_CMD="$HELD"; [ -n "${NOW+x}" ] && export RUNNER_NOW="$NOW"
    cd "$d/repo" && PATH="$BIN:$PATH" STUBS="$d/stubs" RUNNER_REPO="$d/repo" RUNNER_POLL_SECS=1 \
      RUNNER_GH_RETRY_SECS=0 RUNNER_POLICY="${POL:-$d/policy.md}" RUNNER_DAILY_DIR="$d/daily" RUNNER_EMIT="$ADAPTER/hooks/waypoint_events.py" STUB_EXIT_DIR="$d/exit" \
      bash "$ADAPTER/runner/run_chain.sh" .waypoint/plan/runs/trun.md "$@" --out "$d/out" >/dev/null 2>&1 )
  echo $?
}

d=$(fresh ok); touch "$d/stubs/unit-1" "$d/stubs/unit-2"
rc=$(go "$d" 1 2); check "two DONE units chain, exit 0" 0 DONE "$rc" "$d/out"
n=$(grep -c "^Ledger (runner): unit" "$d/repo/.waypoint/memory/$(date +%F)-trun.md")
[ "$n" = 2 ] && [ -z "$(git -C "$d/repo" status --porcelain)" ] && { echo "PASS ledger lines committed for both units"; pass=$((pass+1)); } \
  || { echo "FAIL ledger: $n lines, status '$(git -C "$d/repo" status --porcelain)'"; fail=$((fail+1)); }

events() {   # events NAME DIR EXPECTED_SEQUENCE: every line valid; event names in order equal the sequence
  local r; r="$(python3 - "$2/out/events.jsonl" "$3" "$2/stubs/session-ids" <<'PY'
import datetime, json, sys
path, want, ids = sys.argv[1], sys.argv[2].split(), (open(sys.argv[3]).read().split() if __import__("os").path.exists(sys.argv[3]) else [])
try:
    lines = [json.loads(l) for l in open(path)]
except Exception as e:
    print(f"unreadable: {e}"); sys.exit()
bad = []
for e in lines:
    for k in ("v", "ts", "event", "project", "tool", "writer", "run"):
        if not e.get(k) and e.get(k) != 0: bad.append(f"{e.get('event')} lacks {k}")
    if e.get("v") != 1 or e.get("writer") != "runner" or e.get("tool", {}).get("name") != "claude-code": bad.append(f"{e.get('event')} common fields")
    datetime.datetime.fromisoformat(e["ts"])
    if e["event"].startswith("unit.") and e["session"]["kind"] != "unit": bad.append("unit session kind")
    if e["event"] == "unit.started" and e["session"]["id"] not in ids: bad.append("unit.started id was not the one passed to claude")
    if e["event"] == "unit.ended" and not e.get("status"): bad.append("unit.ended status")
got = [e["event"] for e in lines]
if got != want: bad.append(f"sequence {got}")
print("; ".join(bad) or "ok")
PY
)"
  [ "$r" = ok ] && { echo "PASS events: $1"; pass=$((pass+1)); } || { echo "FAIL events: $1: $r"; fail=$((fail+1)); }
}
events "two DONE units" "$d" "run.started unit.started unit.ended unit.started unit.ended run.finished"
python3 -c "import json,sys; e=[json.loads(l) for l in open(sys.argv[1])]; assert e[-1]['outcome']=='DONE' and e[0]['units']==['1','2'] and e[0]['names']=={} and e[2]['tokens']['cache_read']==100 and e[2]['status']=='DONE'" "$d/out/events.jsonl" \
  && { echo "PASS events carry outcome, units, tokens, status"; pass=$((pass+1)); } || { echo "FAIL event fields"; fail=$((fail+1)); }

d=$(fresh blocked); echo "status BLOCKED gate X over its limit" > "$d/stubs/unit-1"; touch "$d/stubs/unit-2"
rc=$(go "$d" 1 2); check "BLOCKED stops the chain" 3 STOPPED "$rc" "$d/out" "unit 1: BLOCKED gate X"
events "BLOCKED" "$d" "run.started unit.started unit.ended run.finished"
python3 -c "import json,sys; e=[json.loads(l) for l in open(sys.argv[1])]; assert e[2]['status']=='BLOCKED' and e[2]['reason']=='gate X over its limit' and e[3]['outcome']=='STOPPED'" "$d/out/events.jsonl" \
  && { echo "PASS BLOCKED status, reason and outcome"; pass=$((pass+1)); } || { echo "FAIL BLOCKED event fields"; fail=$((fail+1)); }
grep -q "unit 2: session" "$d/out/runner.log" && { echo "FAIL unit 2 ran after a BLOCKED unit 1"; fail=$((fail+1)); } || { echo "PASS unit 2 never started"; pass=$((pass+1)); }

d=$(fresh nostatus); echo "status I think it went fine" > "$d/stubs/unit-1"
rc=$(go "$d" 1); check "no status line stops the chain" 3 STOPPED "$rc" "$d/out" "NO STATUS"

d=$(fresh nomem); echo "mem no" > "$d/stubs/unit-1"
rc=$(go "$d" 1); check "a missing memory entry stops the chain" 3 STOPPED "$rc" "$d/out" "wrote no new memory entry"

# Only the reply's last line is a status, and a DONE says nothing more.
d=$(fresh above); printf 'status DONE with step one\nafter Then the exit check failed and I could not finish.\n' > "$d/stubs/unit-1"; touch "$d/stubs/unit-2"
rc=$(go "$d" 1 2); check "a DONE above a last line that is not a status stops the chain" 3 STOPPED "$rc" "$d/out" "unit 1: NO STATUS"
d=$(fresh donebut); echo "status DONE except the exit check, which failed" > "$d/stubs/unit-1"; touch "$d/stubs/unit-2"
rc=$(go "$d" 1 2); check "a last line that says more than DONE stops the chain" 3 STOPPED "$rc" "$d/out" "unit 1: NO STATUS"
python3 -c "import json,sys; e=[json.loads(l) for l in open(sys.argv[1])]; assert e[2]['status']=='NO_STATUS' and len(e)==4" "$d/out/events.jsonl" \
  && { echo "PASS it is recorded NO_STATUS and unit 2 never starts"; pass=$((pass+1)); } || { echo "FAIL the DONE-with-more event"; fail=$((fail+1)); }
d=$(fresh dressed); echo 'status **DONE.**' > "$d/stubs/unit-1"; touch "$d/stubs/unit-2"
rc=$(go "$d" 1 2); check "a DONE in bold with a full stop is still DONE (control)" 0 DONE "$rc" "$d/out"

# A chain run again the same day finds the first chain's entries in the memory file.
d=$(fresh again); touch "$d/stubs/unit-1"
rc=$(go "$d" 1); mv "$d/out" "$d/out1"; echo "mem no" > "$d/stubs/unit-1"
rc=$(go "$d" 1); check "an earlier chain's entry does not stand in for this unit's" 3 STOPPED "$rc" "$d/out" "wrote no new memory entry"
d=$(fresh again2); touch "$d/stubs/unit-1"
rc=$(go "$d" 1); mv "$d/out" "$d/out1"
rc=$(go "$d" 1); check "a unit run again that writes its entry passes (control)" 0 DONE "$rc" "$d/out"
n=$(grep -c "^Ledger (runner): unit 1" "$d/repo/.waypoint/memory/$(date +%F)-trun.md")
[ "$n" = 2 ] && { echo "PASS both attempts have their ledger line"; pass=$((pass+1)); } || { echo "FAIL $n ledger lines after two attempts"; fail=$((fail+1)); }

d=$(fresh nocommit); echo "nocommit" > "$d/stubs/unit-1"
rc=$(go "$d" 1); check "an uncommitted entry stops the chain" 3 STOPPED "$rc" "$d/out" "uncommitted"

d=$(fresh wait); echo "job 4" > "$d/stubs/unit-1"; touch "$d/stubs/unit-2"
t0=$SECONDS; rc=$(go "$d" 1 2); el=$((SECONDS - t0))
check "WAITING pid waits for the job, then the next unit runs" 0 DONE "$rc" "$d/out" "done waiting: unit 1's job"
[ $el -ge 4 ] && { echo "PASS the wait lasted the job (${el}s)"; pass=$((pass+1)); } || { echo "FAIL the wait took ${el}s, job was 4s"; fail=$((fail+1)); }
events "job wait" "$d" "run.started unit.started unit.ended job.started run.waiting run.resumed job.ended unit.started unit.ended run.finished"
python3 -c "import json,sys; e=[json.loads(l) for l in open(sys.argv[1])]; j=[x for x in e if x['event']=='job.started'][0]; w=[x for x in e if x['event']=='run.waiting'][0]; x=[x for x in e if x['event']=='job.ended'][0]; assert j['pid']>0 and w['reason']=='job' and x['duration_s']>=4 and 'frozen_s' in x" "$d/out/events.jsonl" \
  && { echo "PASS job events carry pid, reason, duration"; pass=$((pass+1)); } || { echo "FAIL job event fields"; fail=$((fail+1)); }

d=$(fresh jobrc); echo "jobrc 2 3" > "$d/stubs/unit-1"; policy_file "$d/policy.md" "job_exit_dir=\"$d/exit\""
rc=$(go "$d" 1); check "a job's recorded exit code is read" 0 DONE "$rc" "$d/out" "job exited 3"
python3 -c "import json,sys; e=[json.loads(l) for l in open(sys.argv[1])]; x=[x for x in e if x['event']=='job.ended'][0]; assert x['exit_code']==3" "$d/out/events.jsonl" \
  && { echo "PASS job.ended carries exit_code 3"; pass=$((pass+1)); } || { echo "FAIL job.ended exit_code"; fail=$((fail+1)); }
d=$(fresh jobnodir); echo "jobrc 2 3" > "$d/stubs/unit-1"
rc=$(go "$d" 1)
python3 -c "import json,sys; e=[json.loads(l) for l in open(sys.argv[1])]; x=[x for x in e if x['event']=='job.ended'][0]; assert 'exit_code' not in x" "$d/out/events.jsonl" \
  && { echo "PASS without job_exit_dir in the policy (control) no exit code is claimed"; pass=$((pass+1)); } || { echo "FAIL exit code read with no job_exit_dir"; fail=$((fail+1)); }
d=$(fresh jobstale); echo "job 2" > "$d/stubs/unit-1"; mkdir -p "$d/exit"; policy_file "$d/policy.md" "job_exit_dir=\"$d/exit\""
# control: a stale exit file for every pid the job could get must be ignored
for p in $(seq $(( $(cat /proc/sys/kernel/ns_last_pid) + 1 )) $(( $(cat /proc/sys/kernel/ns_last_pid) + 3000 ))); do echo 9 > "$d/exit/$p"; done
touch -d '1 hour ago' "$d/exit/"*
rc=$(go "$d" 1)
python3 -c "import json,sys; e=[json.loads(l) for l in open(sys.argv[1])]; x=[x for x in e if x['event']=='job.ended'][0]; j=[x for x in e if x['event']=='job.started'][0]; import os; assert os.path.exists(sys.argv[2]+'/'+str(j['pid'])), 'job pid outside the stale range'; assert 'exit_code' not in x" "$d/out/events.jsonl" "$d/exit" \
  && { echo "PASS a stale exit file is ignored (control)"; pass=$((pass+1)); } || { echo "FAIL a stale exit file was read"; fail=$((fail+1)); }

d=$(fresh window); touch "$d/stubs/unit-1"; policy_file "$d/policy.md" 'quiet=["Fri 17:00-Sat 03:00"]'
rc=$(NOW='2026-11-20 18:00' RUNNER_MAX_WAIT_SECS=3 go "$d" 1)
check "inside a weekly quiet window (a Friday 6 PM) no session starts" 6 TIMEOUT "$rc" "$d/out" "waiting: the quiet window"
events "window wait" "$d" "run.started run.waiting run.finished"
grep -q "unit 1: session" "$d/out/runner.log" && { echo "FAIL a session started in the window"; fail=$((fail+1)); } || { echo "PASS no session in the window"; pass=$((pass+1)); }
d=$(fresh window2); touch "$d/stubs/unit-1"; policy_file "$d/policy.md" 'quiet=["Fri 17:00-Sat 03:00"]'
rc=$(NOW='2026-11-22 10:00' go "$d" 1)
check "outside the window, a Sunday (control), the session starts" 0 DONE "$rc" "$d/out"
d=$(fresh window3); touch "$d/stubs/unit-1"; policy_file "$d/policy.md" 'quiet=["Fri 17:00-Sat 03:00"]'
rc=$(NOW='2026-11-21 02:59' RUNNER_MAX_WAIT_SECS=3 go "$d" 1)
check "the window's last minute (Saturday 2:59 AM) still holds" 6 TIMEOUT "$rc" "$d/out"
d=$(fresh window4); touch "$d/stubs/unit-1"; policy_file "$d/policy.md" 'quiet=["Fri 17:00-Sat 03:00"]'
rc=$(NOW='2026-11-21 03:00' go "$d" 1)
check "the minute it ends (Saturday 3:00 AM, control) the session starts" 0 DONE "$rc" "$d/out"
d=$(fresh daily); touch "$d/stubs/unit-1"; policy_file "$d/policy.md" 'quiet=["22:00-06:00"]'
rc=$(NOW='2026-11-24 23:30' RUNNER_MAX_WAIT_SECS=3 go "$d" 1)
check "inside a daily window that wraps midnight no session starts" 6 TIMEOUT "$rc" "$d/out"
d=$(fresh daily2); touch "$d/stubs/unit-1"; policy_file "$d/policy.md" 'quiet=["22:00-06:00"]'
rc=$(NOW='2026-11-24 12:00' go "$d" 1)
check "outside the daily window (control) the session starts" 0 DONE "$rc" "$d/out"
d=$(fresh badquiet); touch "$d/stubs/unit-1"; policy_file "$d/policy.md" 'quiet=["weekends"]'
rc=$(go "$d" 1); check "a quiet entry that does not parse: the runner refuses" 2 NOPOLICY "$rc" "$d/out" "does not parse"
d=$(fresh badhour); touch "$d/stubs/unit-1"; policy_file "$d/policy.md" 'quiet=["22:00-26:00"]'
rc=$(go "$d" 1); check "a quiet entry with an hour past 23: the runner refuses" 2 NOPOLICY "$rc" "$d/out" "does not parse"
# A zone the machine does not know must not read as "outside every window".
d=$(fresh badtz); touch "$d/stubs/unit-1"; policy_file "$d/policy.md" 'quiet=["00:00-23:59"]' 'tz="America/New York"'
rc=$(go "$d" 1); check "a misspelt tz with an all-day window: the runner refuses" 2 NOPOLICY "$rc" "$d/out" "does not name a time zone"
[ -e "$d/stubs/session-ids" ] && { echo "FAIL a session started under a zone nobody could read"; fail=$((fail+1)); } || { echo "PASS and no session started"; pass=$((pass+1)); }
d=$(fresh badtz2); touch "$d/stubs/unit-1"; policy_file "$d/policy.md" 'tz="Eastern"'
rc=$(go "$d" 1); check "a misspelt tz with no window set: the runner still refuses" 2 NOPOLICY "$rc" "$d/out" "does not name a time zone"
d=$(fresh goodtz); touch "$d/stubs/unit-1"; policy_file "$d/policy.md" 'quiet=["00:00-23:59"]' 'tz="America/New_York"'
rc=$(RUNNER_MAX_WAIT_SECS=3 go "$d" 1)
check "the same window with the zone spelt right holds the session (control)" 6 TIMEOUT "$rc" "$d/out" "waiting: the quiet window"
d=$(fresh midrun); echo "job 3" > "$d/stubs/unit-1"; touch "$d/stubs/unit-2"
( sleep 1.5; policy_file "$d/policy.md" 'quiet=["weekends"]' ) &
rc=$(go "$d" 1 2); wait
check "a window made unreadable during a wait ends the chain before the next unit" 2 NOPOLICY "$rc" "$d/out" "does not parse"
d=$(fresh heldcmd); touch "$d/stubs/unit-1" "$d/paused"; policy_file "$d/policy.md" "held_cmd=\"test -e $d/paused\""
rc=$(RUNNER_MAX_WAIT_SECS=3 go "$d" 1)
check "the policy's pause command holding: no session starts" 6 TIMEOUT "$rc" "$d/out" "waiting: the quiet window"
d=$(fresh heldcmd2); touch "$d/stubs/unit-1"; policy_file "$d/policy.md" "held_cmd=\"test -e $d/paused\""
rc=$(go "$d" 1); check "the pause command not holding (control): the session starts" 0 DONE "$rc" "$d/out"

d=$(fresh hold); touch "$d/stubs/unit-1" "$d/stubs/unit-2"; mkdir -p "$d/out"; touch "$d/out/HOLD"
rc=$(go "$d" 1 2); check "a HOLD file stops before the next unit" 5 HELD "$rc" "$d/out"

d=$(fresh dispatch); touch "$d/stubs/unit-1" "$d/stubs/unit-2"
rc=$(GH_DISPATCHES=1 go "$d" 1 2); check "a workflow_dispatch during the chain halts it" 4 HALT "$rc" "$d/out" "workflow_dispatch"
d=$(fresh ghfail); touch "$d/stubs/unit-1"
rc=$(GH_DISPATCHES=fail go "$d" 1); check "gh unreachable halts (cannot rule out a dispatch)" 4 HALT "$rc" "$d/out"

d=$(fresh push); echo push > "$d/stubs/unit-1"
rc=$(go "$d" 1); check "a push by a unit not named in --may-push halts" 4 HALT "$rc" "$d/out" "may not push"
d=$(fresh push2); echo push > "$d/stubs/unit-1"
rc=$(go "$d" 1 --may-push 1); check "the same push by a --may-push unit is allowed (control)" 0 DONE "$rc" "$d/out"

# A unit changes none of the files that govern the run. Each case reports DONE and leaves the
# tree clean, so nothing but this check would stop the chain.
never_started() {   # never_started NAME DIR UNIT
  grep -q "unit $3: session" "$2/out/runner.log" && { echo "FAIL $1"; fail=$((fail+1)); } || { echo "PASS $1"; pass=$((pass+1)); }
}
d=$(fresh govpolicy); touch "$d/stubs/unit-2"; policy_file "$d/policy.md" sessions_per_day=1
echo "sh sed -i 's/\"sessions_per_day\": 1,/\"sessions_per_day\": 99,/' \"\$RUNNER_POLICY\"" > "$d/stubs/unit-1"
rc=$(go "$d" 1 2); check "a unit that raises its own cap in the policy halts" 4 HALT "$rc" "$d/out" "govern the run changed while it ran: $d/policy.md"
never_started "unit 2 never started under the policy unit 1 wrote" "$d" 2
d=$(fresh govbook); touch "$d/stubs/unit-2"
echo "sh echo '| 2 | rewritten |' >> .waypoint/plan/runs/trun.md; git commit -q -m book .waypoint/plan/runs/trun.md" > "$d/stubs/unit-1"
rc=$(go "$d" 1 2); check "a unit that edits and commits the runbook halts" 4 HALT "$rc" "$d/out" "changed while it ran: .waypoint/plan/runs/trun.md"
never_started "unit 2 never started from the runbook unit 1 wrote" "$d" 2
d=$(fresh govlocal); touch "$d/stubs/unit-2"; mkdir -p "$d/repo/.claude"; echo '*.local.json' > "$d/repo/.claude/.gitignore"
git -C "$d/repo" add .claude/.gitignore; git -C "$d/repo" commit -q -m ignore
echo "sh echo '{\"permissions\":{\"allow\":[\"Bash\"]}}' > .claude/settings.local.json" > "$d/stubs/unit-1"
rc=$(go "$d" 1 2); check "a unit that writes a settings file git ignores halts" 4 HALT "$rc" "$d/out" "changed while it ran: .claude/settings.local.json"
d=$(fresh govhook); mkdir -p "$d/repo/.claude/hooks"; echo 'exit 0' > "$d/repo/.claude/hooks/waypoint-phase-gate.sh"
git -C "$d/repo" add .claude; git -C "$d/repo" commit -q -m hooks
echo "sh git rm -q .claude/hooks/waypoint-phase-gate.sh; git commit -q -m gate" > "$d/stubs/unit-1"
rc=$(go "$d" 1); check "a unit that removes a hook halts" 4 HALT "$rc" "$d/out" "changed while it ran: .claude/hooks/waypoint-phase-gate.sh"
d=$(fresh govother); mkdir -p "$d/repo/.claude/hooks"; echo 'exit 0' > "$d/repo/.claude/hooks/waypoint-phase-gate.sh"
git -C "$d/repo" add .claude; git -C "$d/repo" commit -q -m hooks
echo "sh echo work >> app.txt; git add app.txt; git commit -q -m work" > "$d/stubs/unit-1"; touch "$d/stubs/unit-2"
rc=$(go "$d" 1 2); check "a unit that changes only its own work passes (control)" 0 DONE "$rc" "$d/out"
d=$(fresh govwait); echo "job 3" > "$d/stubs/unit-1"; touch "$d/stubs/unit-2"; policy_file "$d/policy.md" sessions_per_day=1
( sleep 1.5; policy_file "$d/policy.md" sessions_per_day=5 ) &
rc=$(go "$d" 1 2); wait
check "the developer's policy edit during a wait takes effect and halts nothing (control)" 0 DONE "$rc" "$d/out"

d=$(fresh cap); touch "$d/stubs/unit-1" "$d/stubs/unit-2"
rc=$(go "$d" 1 2 --cap 1); check "the session cap stops the chain" 3 CAP "$rc" "$d/out"

# Policy: each stop, then its control.
d=$(fresh nopolicy); touch "$d/stubs/unit-1"
rc=$(POL="$d/none.md" go "$d" 1); check "no policy file: the runner refuses" 2 NOPOLICY "$rc" "$d/out"
grep -q "unit 1: session" "$d/out/runner.log" && { echo "FAIL a session started without a policy"; fail=$((fail+1)); } || { echo "PASS no session without a policy"; pass=$((pass+1)); }

d=$(fresh env); touch "$d/stubs/unit-1"; policy_file "$d/policy.md" 'env_check="node --version | grep -q ^v999"'
rc=$(go "$d" 1); check "a failing environment check stops before the unit" 7 ENV "$rc" "$d/out" "environment check failed"
grep -q "unit 1: session" "$d/out/runner.log" && { echo "FAIL a session started with a broken environment"; fail=$((fail+1)); } || { echo "PASS no session with a broken environment"; pass=$((pass+1)); }
d=$(fresh env2); touch "$d/stubs/unit-1"; policy_file "$d/policy.md" 'env_check="bash --version | grep -q bash"'
rc=$(go "$d" 1); check "a passing environment check lets the unit start (control)" 0 DONE "$rc" "$d/out"

today="$(date +%F)"
d=$(fresh daycap); touch "$d/stubs/unit-1"; mkdir -p "$d/daily"; for i in $(seq 12); do printf 'start\tother\tx\n'; done > "$d/daily/$today.tsv"
rc=$(go "$d" 1); check "12 sessions already today: the daily cap refuses" 3 CAP "$rc" "$d/out" "daily session cap"
d=$(fresh daycap2); touch "$d/stubs/unit-1"; mkdir -p "$d/daily"; for i in $(seq 11); do printf 'start\tother\tx\n'; done > "$d/daily/$today.tsv"
rc=$(go "$d" 1); check "11 sessions today: the twelfth starts (control)" 0 DONE "$rc" "$d/out"
[ "$(grep -c '^start' "$d/daily/$today.tsv")" = 12 ] && grep -q "^tokens	trun	1	122$" "$d/daily/$today.tsv" \
  && { echo "PASS the tally records the start and the unit's 122 tokens"; pass=$((pass+1)); } || { echo "FAIL tally: $(cat "$d/daily/$today.tsv")"; fail=$((fail+1)); }

d=$(fresh unitcap); touch "$d/stubs/unit-1" "$d/stubs/unit-2"; policy_file "$d/policy.md" 'tokens_per_unit=100'
rc=$(go "$d" 1 2); check "a unit over the per-unit token cap stops the chain" 3 CAP "$rc" "$d/out" "over the per-unit cap"
grep -q "unit 2: session" "$d/out/runner.log" && { echo "FAIL unit 2 ran after the token cap"; fail=$((fail+1)); } || { echo "PASS unit 2 never started after the token cap"; pass=$((pass+1)); }
d=$(fresh unitcap2); touch "$d/stubs/unit-1" "$d/stubs/unit-2"; policy_file "$d/policy.md" 'tokens_per_unit=122'
rc=$(go "$d" 1 2); check "a unit at the per-unit cap is allowed (control)" 0 DONE "$rc" "$d/out"

d=$(fresh daytok); touch "$d/stubs/unit-1" "$d/stubs/unit-2"; policy_file "$d/policy.md" 'tokens_per_day=200'
mkdir -p "$d/daily"; printf 'tokens\tother\tx\t100\n' > "$d/daily/$today.tsv"
rc=$(go "$d" 1 2); check "the day's token cap stops before the unit that would start past it" 3 CAP "$rc" "$d/out" "daily token cap: 222 of 200"
grep -q "unit 1: session" "$d/out/runner.log" && ! grep -q "unit 2: session" "$d/out/runner.log" \
  && { echo "PASS unit 1 ran under the day's cap, unit 2 did not"; pass=$((pass+1)); } || { echo "FAIL daily token cap order"; fail=$((fail+1)); }

d=$(fresh ciopen); touch "$d/stubs/unit-1"; echo "#9 Gate controls: a gate is blind" > "$d/stubs/issues"
rc=$(go "$d" 1); check "an open CI issue stops the chain before a unit" 8 CI "$rc" "$d/out" "#9 Gate controls"
d=$(fresh ciopen2); touch "$d/stubs/unit-1"; : > "$d/stubs/issues"
rc=$(go "$d" 1); check "no open CI issue: the unit starts (control)" 0 DONE "$rc" "$d/out"
d=$(fresh ciwait); echo "job 6" > "$d/stubs/unit-1"; touch "$d/stubs/unit-2"
( sleep 3; echo "#10 Live audit: findings" > "$d/stubs/issues" ) &
rc=$(go "$d" 1 2); wait; check "a CI issue opened during a job wait stops the chain" 8 CI "$rc" "$d/out" "while waiting for unit 1's job"
d=$(fresh ghissuefail); touch "$d/stubs/unit-1"
rc=$(GH_ISSUES=fail go "$d" 1); check "gh unreachable for issues stops (cannot rule out a CI failure)" 8 CI "$rc" "$d/out"

d=$(fresh deadline); touch "$d/stubs/unit-1" "$d/stubs/unit-2"
printf '# test run\n\n**Deadline:** unit 2 starts by 2026-01-01 12:00\n' > "$d/repo/.waypoint/plan/runs/trun.md"; git -C "$d/repo" commit -qam deadline
rc=$(go "$d" 1 2); check "a passed deadline stops before that unit" 9 DEADLINE "$rc" "$d/out" "unit 2 was to start by"
grep -q "unit 1: session" "$d/out/runner.log" && { echo "PASS the unit without a deadline ran first"; pass=$((pass+1)); } || { echo "FAIL unit 1 did not run"; fail=$((fail+1)); }
d=$(fresh deadline2); touch "$d/stubs/unit-1" "$d/stubs/unit-2"
printf '# test run\n\n**Deadline:** unit 2 starts by 2099-01-01 12:00\n' > "$d/repo/.waypoint/plan/runs/trun.md"; git -C "$d/repo" commit -qam deadline
rc=$(go "$d" 1 2); check "a future deadline lets the unit start (control)" 0 DONE "$rc" "$d/out"

# Notifications: every end sends one dispatch; DONE closes its issue, a stop leaves it open.
d=$(fresh notify); touch "$d/stubs/unit-1"
rc=$(go "$d" 1)
[ "$(grep -c "event_type=run-mode" "$d/stubs/notify")" = 1 ] && grep -q "client_payload\[title\]=Run trun: DONE" "$d/stubs/notify" && grep -q "client_payload\[close\]=true" "$d/stubs/notify" \
  && { echo "PASS DONE notifies once and closes its issue"; pass=$((pass+1)); } || { echo "FAIL DONE notification: $(cat "$d/stubs/notify" 2>/dev/null)"; fail=$((fail+1)); }
d=$(fresh notify2); echo "status FAILED tide gate over its limit" > "$d/stubs/unit-1"
rc=$(go "$d" 1)
grep -q "client_payload\[title\]=Run trun: STOPPED" "$d/stubs/notify" && grep -q "client_payload\[close\]=false" "$d/stubs/notify" && grep -q "FAILED tide gate" "$d/stubs/notify" \
  && { echo "PASS a stop notifies with its reason and leaves the issue open"; pass=$((pass+1)); } || { echo "FAIL stop notification: $(cat "$d/stubs/notify" 2>/dev/null)"; fail=$((fail+1)); }
d=$(fresh notify3); touch "$d/stubs/unit-1"
rc=$(GH_NOTIFY=fail go "$d" 1); check "a refused notification is logged, the outcome stands" 0 DONE "$rc" "$d/out" "NOTIFY FAILED"

# Optional policy keys: each one seen to change what the runner does, with its control.
d=$(fresh nodispatch); touch "$d/stubs/unit-1"; policy_file "$d/policy.md" 'halt_on_dispatch=false'
rc=$(GH_DISPATCHES=1 go "$d" 1); check "halt_on_dispatch false (control): a dispatch does not halt" 0 DONE "$rc" "$d/out"

d=$(fresh branch); echo push > "$d/stubs/unit-1"; policy_file "$d/policy.md" 'protected_branch="release"'
rc=$(go "$d" 1); check "protected_branch release: a push to main is not a halt" 0 DONE "$rc" "$d/out"

d=$(fresh notifynone); touch "$d/stubs/unit-1"; policy_file "$d/policy.md" 'notify="none"'
rc=$(go "$d" 1)
[ "$rc" = 0 ] && [ ! -e "$d/stubs/notify" ] && ! grep -q "notified" "$d/out/runner.log" \
  && { echo "PASS notify none: nothing is sent"; pass=$((pass+1)); } || { echo "FAIL notify none sent something"; fail=$((fail+1)); }
d=$(fresh notifycmd); echo "status FAILED gate Y over its limit" > "$d/stubs/unit-1"
policy_file "$d/policy.md" 'notify="command"' "notify_cmd=\"printf '%s|%s|%s' \\\"\$WAYPOINT_NOTIFY_OUTCOME\\\" \\\"\$WAYPOINT_NOTIFY_TITLE\\\" \\\"\$WAYPOINT_NOTIFY_DETAIL\\\" > $d/sent\""
rc=$(go "$d" 1)
grep -q "^STOPPED|Run trun: STOPPED|unit 1: FAILED gate Y over its limit" "$d/sent" 2>/dev/null && grep -q "notified (command): STOPPED" "$d/out/runner.log" && [ ! -e "$d/stubs/notify" ] \
  && { echo "PASS notify command: the command gets outcome, title and detail"; pass=$((pass+1)); } || { echo "FAIL notify command: $(cat "$d/sent" 2>/dev/null)"; fail=$((fail+1)); }
d=$(fresh notifycmd2); touch "$d/stubs/unit-1"; policy_file "$d/policy.md" 'notify="command"' 'notify_cmd="exit 3"'
rc=$(go "$d" 1); check "a notify command that fails is logged, the outcome stands" 0 DONE "$rc" "$d/out" "NOTIFY FAILED (command)"

d=$(fresh suffix); touch "$d/stubs/unit-1"; policy_file "$d/policy.md" 'commit_suffix="[skip ci]"' 'unit_rules="Never write to the PRODUCTION-BUCKET."'
rc=$(go "$d" 1)
[ "$rc" = 0 ] && [ "$(git -C "$d/repo" log -1 --format=%s)" = "Run trun: unit 1 ledger [skip ci]" ] \
  && grep -q "Every commit you make carries \[skip ci\] in its subject. Never write to the PRODUCTION-BUCKET." "$d/stubs/prompt-1" \
  && { echo "PASS commit_suffix and unit_rules reach the ledger commit and the unit's prompt"; pass=$((pass+1)); } || { echo "FAIL commit_suffix / unit_rules: $(git -C "$d/repo" log -1 --format=%s)"; fail=$((fail+1)); }
d=$(fresh suffix2); touch "$d/stubs/unit-1"
rc=$(go "$d" 1)
[ "$rc" = 0 ] && [ "$(git -C "$d/repo" log -1 --format=%s)" = "Run trun: unit 1 ledger" ] && ! grep -q "Every commit you make" "$d/stubs/prompt-1" \
  && { echo "PASS without them (control) the commit and the prompt carry neither"; pass=$((pass+1)); } || { echo "FAIL suffix control: $(git -C "$d/repo" log -1 --format=%s)"; fail=$((fail+1)); }
[ "$(cat "$d/stubs/perm")" = auto ] && { echo "PASS units start in permission mode auto by default"; pass=$((pass+1)); } || { echo "FAIL default permission mode: $(cat "$d/stubs/perm" 2>/dev/null)"; fail=$((fail+1)); }
d=$(fresh perm); touch "$d/stubs/unit-1"; policy_file "$d/policy.md" 'permission_mode="acceptEdits"'
rc=$(go "$d" 1)
[ "$rc" = 0 ] && [ "$(cat "$d/stubs/perm")" = acceptEdits ] && { echo "PASS permission_mode from the policy reaches the session"; pass=$((pass+1)); } || { echo "FAIL permission_mode: $(cat "$d/stubs/perm" 2>/dev/null)"; fail=$((fail+1)); }

d=$(fresh envsetup); touch "$d/stubs/unit-1"; policy_file "$d/policy.md" 'env_setup="export WP_TEST_TOOL=1"' 'env_check="test \"$WP_TEST_TOOL\" = 1"'
rc=$(go "$d" 1); check "env_setup puts the toolchain in place for the check" 0 DONE "$rc" "$d/out"
d=$(fresh envsetup2); touch "$d/stubs/unit-1"; policy_file "$d/policy.md" 'env_check="test \"$WP_TEST_TOOL\" = 1"'
rc=$(go "$d" 1); check "without env_setup (control) the same check stops the chain" 7 ENV "$rc" "$d/out"

# tz: the daily tally is kept per day in the policy's zone. Pick the zone whose date differs from this machine's.
far="$(python3 -c 'import datetime, zoneinfo
for z in ("Pacific/Kiritimati", "Etc/GMT+12"):
    if datetime.datetime.now(zoneinfo.ZoneInfo(z)).date() != datetime.date.today(): print(z); break')"
d=$(fresh tz); touch "$d/stubs/unit-1"; policy_file "$d/policy.md" "tz=\"$far\""
rc=$(go "$d" 1)
[ "$rc" = 0 ] && [ -f "$d/daily/$(TZ="$far" date +%F).tsv" ] && [ ! -e "$d/daily/$(date +%F).tsv" ] \
  && { echo "PASS tz: the day's tally is named for the policy's zone ($far)"; pass=$((pass+1)); } || { echo "FAIL tz: $(ls "$d/daily")"; fail=$((fail+1)); }

echo "$pass passed, $fail failed"
[ $fail = 0 ]
