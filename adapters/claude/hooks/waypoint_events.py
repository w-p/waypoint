#!/usr/bin/env python3
"""
Session events writer (contract version 1: contracts/session-events.md in the Waypoint repository).

Two callers:
    waypoint_events.py hook <kind>              Claude Code hooks; the hook's JSON on stdin.
        kind: start | stop | permission | prompt | active | post | end
        prompt (UserPromptSubmit) and post (PostToolUse) may print the hook's JSON reply: the
        session's condition record, given to the session itself.
    waypoint_events.py runner <file> <event> [key=value | key:=json ...]
        .claude/runner/run_chain.sh; common fields from WAYPOINT_PROJECT, WAYPOINT_RUN,
        WAYPOINT_TOOL_VERSION.

A hook must never fail or slow its session: every error is swallowed, nothing is printed, and
the exit code is always 0. Nothing from a prompt, a file or a command line goes into an event.
The only output is the session's condition record (prompt, and post when the ask gets stronger).
"""
import datetime
import glob
import json
import os
import re
import subprocess
import sys
import time

V = 1
THROTTLE_S = 60          # session.active at most once a minute per session
PRUNE_DAYS = 30
MAX_SUM_BYTES = 400e6    # a transcript bigger than this is not summed at session end

# Session condition (the contract's "Session condition"). The thresholds are this writer's
# calibration, not the contract. They come from a replay, in the project that piloted this, of 29
# saved sessions against 116 labeled slips (2026-11-23): the slip rate doubled after the first
# compaction (6.8% -> 13.1%) and was about twice the usual in the first stretch after any
# compaction; context size and how full a stretch was showed no relation. Levels above "tiring"
# are judgment. One developer's sessions: expect to recalibrate.
FATIGUE = (                        # first match wins, top down
    ("exhausted", {"compactions": 8}),
    ("tired", {"compactions": 4}),
    ("tired", {"work_summarized": 100}),
    ("tiring", {"compactions": 1}),
    ("working", {"hours": 2}),
)
FATIGUE_LEVELS = ("fresh", "working", "tiring", "tired", "exhausted")
DRIFT = (                          # hours since the last state check, commits made by others since
    ("stale", {"state_check_h": 12}),
    ("stale", {"outside_commits": 3}),
    ("aging", {"state_check_h": 2}),
    ("aging", {"outside_commits": 1}),
)
DRIFT_LEVELS = ("current", "aging", "stale")
UNSAVED = (("lots", {"unsaved_work": 6}), ("some", {"unsaved_work": 1}))
UNSAVED_LEVELS = ("none", "some", "lots")
COMPACTION_POSSIBLE_K = 200        # every compaction seen fired past 200k tokens of context
FIRST_SCAN_MAX = 40_000_000        # a session's first scan reads at most this much of its transcript

def now_iso():
    return datetime.datetime.now().astimezone().isoformat(timespec="seconds")


def ignore_events(root):
    """Keep event files out of git whatever the project's own .gitignore says: an ignore file
    inside .waypoint/events/ that covers everything there, itself included."""
    p = os.path.join(root, ".waypoint", "events", ".gitignore")
    if not os.path.exists(p):
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "w") as f:
            f.write("*\n")


def append(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    line = json.dumps(obj, separators=(",", ":")) + "\n"
    with open(path, "a") as f:     # one writer per file: this session's hook, or this run's runner
        f.write(line)


def claude_process():
    """(pid, version) of the nearest `claude` ancestor, or (None, None)."""
    pid = os.getppid()
    for _ in range(8):
        if pid <= 1:
            break
        try:
            comm = open(f"/proc/{pid}/comm").read().strip()
            exe = os.readlink(f"/proc/{pid}/exe")
            argv = open(f"/proc/{pid}/cmdline").read().split("\0")
        except OSError:
            break
        if comm == "claude" or (comm == "node" and any("claude" in a for a in argv[1:2])):
            m = re.search(r"(\d+\.\d+\.\d+)", exe + " " + " ".join(argv[:2]))
            return pid, (m.group(1) if m else None)
        try:
            stat = open(f"/proc/{pid}/stat").read()
            pid = int(stat.rsplit(")", 1)[1].split()[1])
        except (OSError, ValueError, IndexError):
            break
    return None, None


# ---- hooks ------------------------------------------------------------------------------------

def project_dir(h):
    return os.environ.get("CLAUDE_PROJECT_DIR") or h.get("cwd") or os.getcwd()


def session_obj(sid):
    run = os.environ.get("WAYPOINT_RUN")
    if run:
        return {"id": sid, "kind": "unit", "parent": run}
    return {"id": sid, "kind": "interactive", "parent": None}


def state_path(sessions, sid):
    return os.path.join(sessions, ".state", sid)


def write_state(sessions, sid, event, model):
    """The hook's own note: last state-setting event, when, and the model last reported. The shell
    gate in waypoint-events.sh reads the first two fields."""
    p = state_path(sessions, sid)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w") as f:
        f.write(f"{event} {int(time.time())} {model or '-'}\n")


def read_state(sessions, sid):
    try:
        parts = open(state_path(sessions, sid)).read().split()
        return parts[0], int(parts[1]), (parts[2] if len(parts) > 2 and parts[2] != "-" else None)
    except (OSError, ValueError, IndexError):
        return None, 0, None

TAIL_BYTES = 512 * 1024


def last_reply(path):
    """The message of the transcript's latest real reply (a dict), or None. Reads only the file's
    tail: the latest reply is near the end."""
    try:
        with open(path, "rb") as f:
            f.seek(0, os.SEEK_END)
            size = f.tell()
            f.seek(max(0, size - TAIL_BYTES))
            lines = f.read().decode("utf-8", "replace").splitlines()
    except (OSError, TypeError):
        return None
    for line in reversed(lines):
        if '"model"' not in line or '"assistant"' not in line:
            continue
        try:
            e = json.loads(line)
        except ValueError:
            continue
        msg = e.get("message")
        if e.get("type") == "assistant" and isinstance(msg, dict):
            m = msg.get("model")
            if m and not m.startswith("<"):     # "<synthetic>" marks a reply the tool made up
                return msg
    return None


def transcript_model(path):
    """The model of the transcript's latest reply (exact id, e.g. claude-opus-5-5), or None."""
    msg = last_reply(path)
    return msg.get("model") if msg else None


def context_tokens(path):
    """Tokens sent with the latest model call (input plus cache read and write), or None."""
    msg = last_reply(path)
    if not msg:
        return None
    u = msg.get("usage") or {}
    keys = ("input_tokens", "cache_read_input_tokens", "cache_creation_input_tokens")
    return sum(u.get(k, 0) or 0 for k in keys)


def prune(sessions):
    cutoff = time.time() - PRUNE_DAYS * 86400
    for p in glob.glob(os.path.join(sessions, "*.jsonl")) + glob.glob(os.path.join(sessions, ".state", "*")):
        try:
            if os.path.getmtime(p) < cutoff:
                os.remove(p)
        except OSError:
            pass


def transcript_tokens(path):
    """Totals over the transcript's replies, each reply counted once (its usage repeats per line)."""
    if not path or not os.path.isfile(path) or os.path.getsize(path) > MAX_SUM_BYTES:
        return None
    seen, tot = set(), {"input": 0, "cache_write": 0, "cache_read": 0, "output": 0}
    with open(path, errors="replace") as f:
        for line in f:
            if '"usage"' not in line:
                continue
            try:
                e = json.loads(line)
            except ValueError:
                continue
            msg = e.get("message")
            if e.get("type") != "assistant" or not isinstance(msg, dict):
                continue
            mid = msg.get("id")
            if not mid or mid in seen:
                continue
            seen.add(mid)
            u = msg.get("usage") or {}
            tot["input"] += u.get("input_tokens", 0) or 0
            tot["cache_write"] += u.get("cache_creation_input_tokens", 0) or 0
            tot["cache_read"] += u.get("cache_read_input_tokens", 0) or 0
            tot["output"] += u.get("output_tokens", 0) or 0
    return tot


def first_ts(path):
    try:
        with open(path) as f:
            for line in f:
                e = json.loads(line)
                if e.get("event") == "session.started":
                    return datetime.datetime.fromisoformat(e["ts"])
    except (OSError, ValueError, KeyError):
        pass
    return None


def session_start(path):
    """Time of the session's latest session.started: a resume restarts the clock."""
    start = None
    try:
        with open(path) as f:
            for line in f:
                if '"session.started"' in line:
                    start = datetime.datetime.fromisoformat(json.loads(line)["ts"])
    except (OSError, ValueError, KeyError):
        pass
    return start


# ---- session condition --------------------------------------------------------------------------
# The hook keeps running tallies in .state/<session>.json and reads only the transcript's new bytes
# on each run, so a long session costs no more per prompt than a short one.

WORK_TOOLS = {"Edit", "Write", "MultiEdit", "NotebookEdit"}
AGENT_TOOLS = {"Agent", "Task"}
# A state check is the session looking at the world instead of at what it remembers: fetching or
# reading history, reading CI's runs, reading project.md. A project names its own state commands
# (a state script, a CI summary) in WAYPOINT_STATE_CHECK, a regular expression matched against
# shell commands; set it in the `env` block of .claude/settings.json.
STATE_CHECK_BASE = r"gh run (?:list|view)|git (?:-C \S+ )?(?:fetch|pull|log)\b"


def state_check_pattern():
    extra = os.environ.get("WAYPOINT_STATE_CHECK", "").strip()
    if extra:
        try:
            return re.compile(f"{STATE_CHECK_BASE}|(?:{extra})")
        except re.error:
            pass                    # a pattern that does not compile is ignored, never fatal
    return re.compile(STATE_CHECK_BASE)


STATE_CHECK = state_check_pattern()
PROJECT_MD = re.compile(r"\.waypoint/project\.md")
COMMIT = re.compile(r"\bgit (?:-C \S+ )?commit\b")
COMMIT_HASH = re.compile(r"\[[\w./-]+ ([0-9a-f]{7,40})\] ")
LINE_TS = re.compile(r'"timestamp":\s*"([^"]+)"')   # some assistant lines carry none (seen 2026-11-23)
# A shell command that writes files: in-place edits, redirects to a file (not 2>, &> or /dev/null),
# tee, or a heredoc fed to an interpreter. An approximation: it counts the call, not the files.
SHELL_WRITE = re.compile(r"\bsed -i|\bperl -pi|(?<![0-9&>])>>?\s*(?!/dev/null)[\w\"'$./~-]|\btee\b"
                         r"|\b(?:python3?|node|ruby|perl)\b[^|;&]*<<")


def tally_path(sessions, sid):
    return os.path.join(sessions, ".state", f"{sid}.json")


def load_tally(sessions, sid):
    try:
        return json.load(open(tally_path(sessions, sid)))
    except (OSError, ValueError):
        return {}


def save_tally(sessions, sid, t):
    p = tally_path(sessions, sid)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    tmp = p + ".tmp"
    with open(tmp, "w") as f:
        json.dump(t, f)
    os.replace(tmp, p)


def note_tool(t, block, at):
    """Count one tool call from the transcript into the tallies."""
    name = block.get("name")
    inp = block.get("input") or {}
    if name in WORK_TOOLS:
        target = inp.get("file_path") or inp.get("notebook_path") or ""
        if MEMORY.search(target):
            t["unsaved_work"] = 0
            return
        t["unsaved_work"] += 1
        t["work_since_compact"] += 1
    elif name in AGENT_TOOLS:
        t["unsaved_work"] += 1
        t["work_since_compact"] += 1
    elif name == "Read":
        if PROJECT_MD.search(inp.get("file_path") or ""):
            t["reread"] = True
            t["state_check"] = at
    elif name == "Bash":
        cmd = inp.get("command") or ""
        writes_memory = memory_in_command(cmd) is not None
        if writes_memory:
            t["unsaved_work"] = 0
        elif COMMIT.search(cmd) or SHELL_WRITE.search(cmd):
            t["unsaved_work"] += 1
            t["work_since_compact"] += 1
        if STATE_CHECK.search(cmd):
            t["state_check"] = at
        if PROJECT_MD.search(cmd) and not writes_memory:
            t["reread"] = True
            t["state_check"] = at


def is_compaction(line):
    try:
        e = json.loads(line)
    except ValueError:
        return False
    return e.get("type") == "system" and e.get("subtype") == "compact_boundary"


def scan(t, transcript):
    """Fold the transcript's new complete lines into the tallies."""
    defaults = {"offset": 0, "compactions": 0, "work_since_compact": 0, "work_summarized": 0,
                "unsaved_work": 0, "state_check": None, "reread": True, "own_commits": []}
    for k, v in defaults.items():
        t.setdefault(k, v)
    try:
        size = os.path.getsize(transcript)
    except (OSError, TypeError):
        return
    if t["offset"] > size:              # a different or rewritten file: start over
        t.clear()
        t.update(defaults)
    start = t["offset"]
    if start == 0 and size > FIRST_SCAN_MAX:
        start = size - FIRST_SCAN_MAX
    with open(transcript, "rb") as f:
        f.seek(start)
        data = f.read()
    end = data.rfind(b"\n")
    if end < 0:
        return
    lines = data[:end].decode("utf-8", "replace").split("\n")
    if start != t["offset"]:
        lines = lines[1:]               # began mid-line
    t["offset"] = start + end + 1
    seen = None     # the latest timestamp on any line so far, for lines that carry none
    for line in lines:
        m = LINE_TS.search(line)
        if m:
            seen = m.group(1)
        # Only the line's own type counts: newer versions also write api-request-blob lines that
        # repeat earlier tool calls (seen 2026-11-23, which doubled the work counts).
        if '"compact_boundary"' in line and is_compaction(line):
            t["compactions"] += 1
            t["work_summarized"] += t["work_since_compact"]
            t["work_since_compact"] = 0
            t["reread"] = False
        elif '"tool_use"' in line and '"assistant"' in line:
            try:
                e = json.loads(line)
            except ValueError:
                continue
            if e.get("type") != "assistant":
                continue
            for b in (e.get("message") or {}).get("content") or []:
                if isinstance(b, dict) and b.get("type") == "tool_use":
                    note_tool(t, b, e.get("timestamp") or seen)
        elif '"tool_result"' in line:
            for m in COMMIT_HASH.finditer(line):
                t["own_commits"] = (t["own_commits"] + [m.group(1)[:7]])[-100:]


def head_commit(root):
    """HEAD's short hash, or None."""
    try:
        out = subprocess.run(["git", "-C", root, "rev-parse", "--short=7", "HEAD"],
                             capture_output=True, text=True, timeout=2).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return None
    return out or None


def outside_commits(root, since, own):
    """Commits on HEAD after `since` (a datetime) that this session did not make. Strictly after:
    a runner commits a unit's ledger line and starts the next unit within the same second, and
    that commit is not news to the session that boots from it."""
    try:
        out = subprocess.run(["git", "-C", root, "log", f"--since=@{int(since.timestamp()) + 1}",
                              "--format=%h", "-n", "100", "HEAD"],
                             capture_output=True, text=True, timeout=2).stdout.split()
    except (OSError, subprocess.SubprocessError):
        return 0
    mine = set(own)
    return sum(1 for c in out if c[:7] not in mine)


def grade(rules, levels, m):
    """The first level whose thresholds the measures meet, else the lowest."""
    for level, need in rules:
        if all(m.get(k) is not None and m[k] >= v for k, v in need.items()):
            return level
    return levels[0]


def condition(path, transcript, root, t):
    """The session's condition record: the three readings, the two flags, and every measure."""
    scan(t, transcript)
    now = datetime.datetime.now().astimezone()
    start = session_start(path)
    m = {"compactions": t["compactions"], "work_summarized": t["work_summarized"],
         "unsaved_work": t["unsaved_work"]}
    if start:
        m["hours"] = round((now - start).total_seconds() / 3600, 1)
    ctx = context_tokens(transcript)
    if ctx is not None:
        m["context_k"] = round(ctx / 1000)
    checked = None
    if t["state_check"]:
        checked = datetime.datetime.fromisoformat(t["state_check"].replace("Z", "+00:00"))
    since = checked or start
    if since:
        m["state_check_h"] = round((now - since).total_seconds() / 3600, 1)
        m["outside_commits"] = outside_commits(root, since, t["own_commits"])
    return {"fatigue": grade(FATIGUE, FATIGUE_LEVELS, m),
            "just_compacted": t["compactions"] > 0 and not t["reread"],
            "drift": grade(DRIFT, DRIFT_LEVELS, m),
            "unsaved": grade(UNSAVED, UNSAVED_LEVELS, m),
            "compaction_possible": m.get("context_k", 0) >= COMPACTION_POSSIBLE_K,
            **m}


def urgency(c):
    """What the session is asked to act on, as numbers that only rise when the ask gets stronger."""
    return [FATIGUE_LEVELS.index(c["fatigue"]), int(c["just_compacted"]), DRIFT_LEVELS.index(c["drift"]),
            int(c["unsaved"] != "none" and c["compaction_possible"])]


def reply(hook_event, text):
    """The hook's JSON reply, giving the session extra context."""
    out = {"hookSpecificOutput": {"hookEventName": hook_event, "additionalContext": text}}
    print(json.dumps(out))


MEMORY = re.compile(r"(?:^|/)\.waypoint/memory/[^/\s'\"]+\.md")


def memory_in_command(cmd):
    """The memory file a shell command writes by redirect or tee, as written in the command, or None."""
    m = re.search(r"(?:>>?|\btee\s+(?:-a\s+)?)\s*['\"]?([^\s'\";|&]*\.waypoint/memory/[^\s'\";|&]+\.md)", cmd)
    if m:
        return m.group(1)
    # f=.waypoint/memory/x.md ... > "$f"  (seen in units, 2026-11-22 and 11-23)
    for a in re.finditer(r"\b(\w+)=['\"]?([^\s'\";|&]*\.waypoint/memory/[^\s'\";|&]+\.md)", cmd):
        var = re.escape(a.group(1))
        if re.search(rf"(?:>>?|\btee\s+(?:-a\s+)?)\s*['\"]?\$\{{?{var}\}}?\b", cmd):
            return a.group(2)
    return None


def memory_file(h, root):
    """The memory file an Edit, Write or shell redirect wrote, as a path in the project, or None."""
    tool = h.get("tool_name")
    ti = h.get("tool_input") or {}
    path = None
    if tool in ("Edit", "Write", "MultiEdit", "NotebookEdit"):
        path = ti.get("file_path") or ti.get("notebook_path")
        if not (path and MEMORY.search(path)):
            return None
    elif tool == "Bash":
        path = memory_in_command(ti.get("command") or "")
        if not path:
            return None
    else:
        return None
    if os.path.isabs(path):
        try:
            rel = os.path.relpath(os.path.realpath(path), os.path.realpath(root))
            if not rel.startswith(".."):
                return rel
        except ValueError:
            pass
        m = MEMORY.search(path)
        return m.group(0).lstrip("/") if m else None
    return path


def hook(kind):
    h = json.load(sys.stdin)
    sid = h.get("session_id")
    if not sid:
        return
    root = project_dir(h)
    sessions = os.path.join(root, ".waypoint", "events", "sessions")
    path = os.path.join(sessions, f"claude-code-{sid}.jsonl")
    pid, version = claude_process()
    base = {"v": V, "ts": now_iso(), "event": None, "project": os.path.basename(os.path.normpath(root)),
            "tool": {"name": "claude-code", "version": version or os.environ.get("WAYPOINT_TOOL_VERSION", "")},
            "writer": "hook"}
    if os.environ.get("WAYPOINT_RUN"):
        base["run"] = os.environ["WAYPOINT_RUN"]
    base["session"] = session_obj(sid)

    last, at, known_model = read_state(sessions, sid)
    events = []
    told = None     # (hook event, text) to give the session

    def model_change():
        # Claude Code's start hook carries no model, and a session can switch (/model): report the
        # latest reply's model when first known or changed. Checked at turn end, and again at the
        # next activity and at session end, because the turn-end hook can run before the reply's
        # line reaches the transcript (seen 2026-11-22: Stop fired in the same second).
        nonlocal known_model
        model = transcript_model(h.get("transcript_path"))
        if model and model != known_model:
            known_model = model
            return [{"event": "session.model", "model": model}]
        return []
    if kind == "start":
        source = h.get("source") or "startup"
        if source == "compact":
            events.append({"event": "session.compacted"})
        else:
            ignore_events(root)
            prune(sessions)
            e = {"event": "session.started", "source": source}
            if pid:
                e["pid"] = pid
            model = h.get("model")
            if isinstance(model, dict):
                model = model.get("id") or model.get("display_name")
            if model:
                e["model"] = model
                known_model = model
            if h.get("transcript_path"):
                e["transcript"] = {"path": os.path.abspath(os.path.expanduser(h["transcript_path"])),
                                   "format": "claude-code-jsonl"}
            events.append(e)
    elif kind == "stop":
        events += model_change()
        events.append({"event": "session.waiting", "reason": "input"})
    elif kind == "permission":
        events.append({"event": "session.waiting", "reason": "permission"})
    elif kind in ("prompt", "active", "post"):
        if kind == "post":
            mf = memory_file(h, root)
            if mf:
                events.append({"event": "session.memory_written", "file": mf})
        if last != "session.active" or time.time() - at >= THROTTLE_S:
            events.insert(0, {"event": "session.active"})
            events += model_change()
        if kind in ("prompt", "post"):
            # Every prompt and every tool call that gets past the shell gate (at most once a minute,
            # plus memory writes and commits) records the condition for readers. The session is told
            # on every prompt, and on a tool call only when the ask gets stronger.
            t = load_tally(sessions, sid)
            cmd = (h.get("tool_input") or {}).get("command") or "" if kind == "post" else ""
            if COMMIT.search(cmd):
                # `git commit -q` prints no hash, so ask git which commit this session just made.
                c = head_commit(root)
                if c:
                    t["own_commits"] = (t.get("own_commits", []) + [c])[-100:]
            c = condition(path, h.get("transcript_path"), root, t)
            now_u = urgency(c)
            rose = any(a > b for a, b in zip(now_u, t.get("told") or [0, 0, 0, 0]))
            events.append({"event": "session.condition", **c})
            if kind == "prompt" or rose:
                name = "UserPromptSubmit" if kind == "prompt" else "PostToolUse"
                told = (name, "Session condition: " + json.dumps(c, separators=(", ", ": ")))
            t["told"] = now_u
            save_tally(sessions, sid, t)
    elif kind == "end":
        events += model_change()
        e = {"event": "session.ended"}
        t0 = first_ts(path)
        e["duration_s"] = round((datetime.datetime.now().astimezone() - t0).total_seconds()) if t0 else 0
        tok = transcript_tokens(h.get("transcript_path"))
        if tok:
            e["tokens"] = tok
        events.append(e)

    for e in events:
        append(path, {**base, **e})
    if events:
        quiet = ("session.memory_written", "session.model", "session.condition")
        ev = [e["event"] for e in events if e["event"] not in quiet]
        write_state(sessions, sid, ev[-1] if ev else (last or "session.active"), known_model)
    if told:
        reply(*told)


# ---- runner -----------------------------------------------------------------------------------

def runner(path, event, pairs):
    e = {"v": V, "ts": now_iso(), "event": event,
         "project": os.environ.get("WAYPOINT_PROJECT", ""),
         "tool": {"name": "claude-code", "version": os.environ.get("WAYPOINT_TOOL_VERSION", "")},
         "writer": "runner", "run": os.environ.get("WAYPOINT_RUN", "")}
    for p in pairs:
        if ":=" in p and ("=" not in p or p.index(":=") < p.index("=")):
            k, v = p.split(":=", 1)
            e[k] = json.loads(v)
        else:
            k, v = p.split("=", 1)
            e[k] = v
    append(path, e)


def main():
    if len(sys.argv) >= 3 and sys.argv[1] == "hook":
        try:
            hook(sys.argv[2])
        except Exception:
            pass
        return 0
    if len(sys.argv) >= 4 and sys.argv[1] == "runner":
        runner(sys.argv[2], sys.argv[3], sys.argv[4:])
        return 0
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
