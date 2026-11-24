#!/usr/bin/env python3
"""
Stub checks for the session condition record in the events hook (contracts/session-events.md,
"Session condition"). Each case drives the real shell entry point, waypoint-events.sh, with a hook's
JSON on stdin against a scratch project (a git repository) and a synthetic transcript, then checks
what the session was told and what was written. Every level of every reading is seen to fire, with
the value just below its threshold as the control.

    python3 adapters/claude/tests/test_condition.py

Lives in the Waypoint repository and is run by ./test.sh; it is not installed into projects.
"""
import datetime
import json
import os
import subprocess
import sys
import tempfile
import time

HOOKS = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "hooks")
SH = os.path.join(HOOKS, "waypoint-events.sh")
sys.dont_write_bytecode = True     # no __pycache__ beside the shipped hook
sys.path.insert(0, HOOKS)
import waypoint_events as we  # noqa: E402  (thresholds under test)

failures = 0
checks = 0


def check(name, ok, detail=""):
    global failures, checks
    checks += 1
    if not ok:
        failures += 1
    print(f"  {'ok  ' if ok else 'FAIL'} {name}" + (f"  ({detail})" if detail and not ok else ""))


def iso(hours_ago=0.0):
    t = datetime.datetime.now().astimezone() - datetime.timedelta(hours=hours_ago)
    return t.isoformat(timespec="seconds")


def git(d, *args, env=None):
    subprocess.run(["git", "-C", d, *args], check=True, capture_output=True, env=env)


class Session:
    """A scratch git project with one session's events file and transcript."""

    def __init__(self, started_h=1.0, env=None):
        self.env = env or {}
        self.dir = tempfile.mkdtemp(prefix="condition-")
        git(self.dir, "init", "-q")
        git(self.dir, "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "--allow-empty", "-m", "base",
            env={**os.environ, "GIT_COMMITTER_DATE": iso(48), "GIT_AUTHOR_DATE": iso(48)})
        self.sid = "s1"
        self.events = os.path.join(self.dir, ".waypoint", "events", "sessions", f"claude-code-{self.sid}.jsonl")
        self.state = os.path.join(self.dir, ".waypoint", "events", "sessions", ".state", self.sid)
        self.transcript = os.path.join(self.dir, "transcript.jsonl")
        open(self.transcript, "w").close()
        os.makedirs(os.path.dirname(self.events), exist_ok=True)
        self.started = iso(started_h)
        with open(self.events, "a") as f:
            f.write(json.dumps({"v": 1, "ts": self.started, "event": "session.started", "writer": "hook"}) + "\n")

    def event(self, name, hours_ago=0.0):
        with open(self.events, "a") as f:
            f.write(json.dumps({"v": 1, "ts": iso(hours_ago), "event": name, "writer": "hook"}) + "\n")

    def line(self, obj):
        with open(self.transcript, "a") as f:
            f.write(json.dumps(obj) + "\n")

    def reply(self, tokens):
        self.line({"type": "assistant", "timestamp": iso(), "message": {
            "id": f"m{time.time_ns()}", "model": "claude-opus-5-5", "content": [{"type": "text", "text": "x"}],
            "usage": {"input_tokens": 2, "cache_read_input_tokens": tokens - 1002,
                      "cache_creation_input_tokens": 1000, "output_tokens": 50}}})

    def tool(self, name, hours_ago=0.0, **inp):
        self.line({"type": "assistant", "timestamp": iso(hours_ago),
                   "message": {"content": [{"type": "tool_use", "name": name, "input": inp}]}})

    def edits(self, n):
        for i in range(n):
            self.tool("Edit", file_path=f"{self.dir}/src/f{i}.py")

    def blob(self, n):
        """An api-request-blob line repeating n earlier tool calls and a compaction marker."""
        self.line({"type": "api-request-blob", "timestamp": iso(), "subtype": "compact_boundary"})
        self.line({"type": "api-request-blob", "timestamp": iso(), "message": {"role": "assistant", "content":
                   [{"type": "tool_use", "name": "Edit", "input": {"file_path": f"{self.dir}/src/b{i}.py"}}
                    for i in range(n)]}})

    def compact(self):
        self.line({"type": "system", "subtype": "compact_boundary", "timestamp": iso(),
                   "compactMetadata": {"preTokens": 240000}})

    def commit(self, own, at=None):
        at = at or iso()
        env = {**os.environ, "GIT_COMMITTER_DATE": at, "GIT_AUTHOR_DATE": at}
        git(self.dir, "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "--allow-empty", "-m", "c", env=env)
        h = subprocess.run(["git", "-C", self.dir, "rev-parse", "--short=7", "HEAD"],
                           capture_output=True, text=True).stdout.strip()
        if own:
            self.tool("Bash", command="git commit -m c")
            self.line({"type": "user", "message": {"content": [
                {"type": "tool_result", "content": f"[main {h}] c\n 1 file changed"}]}})

    def run(self, kind, extra=None):
        h = {"session_id": self.sid, "transcript_path": self.transcript, "cwd": self.dir,
             "prompt": "PROMPT-TEXT-MUST-NOT-LEAK"}
        h.update(extra or {})
        env = {**os.environ, "CLAUDE_PROJECT_DIR": self.dir}
        env.pop("WAYPOINT_RUN", None)
        env.pop("WAYPOINT_STATE_CHECK", None)
        env.update(self.env)
        p = subprocess.run(["bash", SH, kind], input=json.dumps(h), capture_output=True, text=True, env=env)
        return p.returncode, p.stdout

    def prompt(self):
        """The record the session was told on a prompt, or None."""
        rc, out = self.run("prompt")
        t = told(out)
        if rc != 0 or not t or t[0] != "UserPromptSubmit":
            return None
        return json.loads(t[1].split("Session condition: ", 1)[1])

    def unthrottle(self):
        parts = open(self.state).read().split()
        parts[1] = str(int(parts[1]) - 120)
        with open(self.state, "w") as f:
            f.write(" ".join(parts) + "\n")

    def records(self):
        return [json.loads(l) for l in open(self.events) if '"session.condition"' in l]


def told(out):
    if not out.strip():
        return None
    o = json.loads(out)["hookSpecificOutput"]
    return o["hookEventName"], o["additionalContext"]


def expect(label, setup, field, want, started_h=1.0, env=None):
    s = Session(started_h, env)
    setup(s)
    c = s.prompt()
    got = c.get(field) if c else None
    recorded = s.records()[-1].get(field) if c and s.records() else None
    check(f"{label}: {field} {want}", got == want and recorded == want, f"told {got}, recorded {recorded}, {c}")
    return s


def main():
    print("fatigue: compaction history, each level with the value below as control")
    expect("1.0 h, no compaction", lambda s: None, "fatigue", "fresh", started_h=1.0)
    expect("2.1 h, no compaction", lambda s: None, "fatigue", "working", started_h=2.1)

    def compactions(n):
        return lambda s: [s.compact() for _ in range(n)]
    expect("1 compaction", compactions(1), "fatigue", "tiring")
    expect("3 compactions", compactions(3), "fatigue", "tiring")
    expect("4 compactions", compactions(4), "fatigue", "tired")
    expect("7 compactions", compactions(7), "fatigue", "tired")
    expect("8 compactions", compactions(8), "fatigue", "exhausted")

    def summarized(n):
        def f(s):
            s.edits(n)
            s.compact()
        return f
    expect("1 compaction over 99 edits", summarized(99), "fatigue", "tiring")
    expect("1 compaction over 100 edits", summarized(100), "fatigue", "tired")

    print("just compacted: set by a compaction, cleared by re-reading project.md")
    expect("no compaction", lambda s: None, "just_compacted", False)
    expect("after a compaction", compactions(1), "just_compacted", True)
    expect("compaction then Read project.md",
           lambda s: (s.compact(), s.tool("Read", file_path=f"{s.dir}/.waypoint/project.md")), "just_compacted", False)
    expect("compaction then cat project.md in the shell",
           lambda s: (s.compact(), s.tool("Bash", command="head -40 .waypoint/project.md")), "just_compacted", False)
    expect("re-read, then a second compaction",
           lambda s: (s.compact(), s.tool("Read", file_path=f"{s.dir}/.waypoint/project.md"), s.compact()),
           "just_compacted", True)

    print("drift: hours since the last state check, commits made by others")
    expect("started 1.9 h ago, never checked", lambda s: None, "drift", "current", started_h=1.9)
    expect("started 2.1 h ago, never checked", lambda s: None, "drift", "aging", started_h=2.1)
    expect("checked 11.9 h ago", lambda s: s.tool("Bash", hours_ago=11.9, command="git log --oneline -5"),
           "drift", "aging", started_h=20)
    own = lambda s: s.tool("Bash", command="scripts/project_state.sh --all")
    expect("the project's own state command, named in WAYPOINT_STATE_CHECK", own, "drift", "current",
           started_h=20, env={"WAYPOINT_STATE_CHECK": "project_state|ci_summary"})
    expect("the same command with nothing named (control)", own, "drift", "stale", started_h=20)
    expect("a pattern that does not compile is ignored; the built-in checks still count",
           lambda s: s.tool("Bash", command="git fetch origin"), "drift", "current",
           started_h=20, env={"WAYPOINT_STATE_CHECK": "("})
    expect("checked 12.1 h ago", lambda s: s.tool("Bash", hours_ago=12.1, command="gh run list --limit 5"),
           "drift", "stale", started_h=20)
    expect("checked just now", lambda s: s.tool("Bash", command="git fetch origin"), "drift", "current", started_h=20)
    expect("own commit only", lambda s: s.commit(own=True), "drift", "current")
    expect("one commit by another session", lambda s: s.commit(own=False), "drift", "aging")
    expect("two by others", lambda s: [s.commit(own=False) for _ in range(2)], "drift", "aging")
    expect("three by others", lambda s: [s.commit(own=False) for _ in range(3)], "drift", "stale")
    expect("a commit made in the second the session started (a runner's ledger line) is not news",
           lambda s: s.commit(own=False, at=s.started), "drift", "current")
    later = lambda s: s.commit(own=False, at=(datetime.datetime.fromisoformat(s.started)
                                              + datetime.timedelta(seconds=1)).isoformat())
    expect("the same commit one second later (control) is", later, "drift", "aging")
    s = expect("own commit, then three by others, all counted right",
               lambda s: (s.commit(own=True), [s.commit(own=False) for _ in range(3)]), "drift", "stale")
    check("  outside_commits is 3, not 4", s.records()[-1]["outside_commits"] == 3, str(s.records()[-1]))

    def untimed_check(s):
        s.tool("Bash", hours_ago=0.1, command="ls")
        s.line({"type": "assistant", "message": {"content": [
            {"type": "tool_use", "name": "Bash", "input": {"command": "git log -3"}}]}})
    s = expect("a state check on a line with no timestamp takes the previous line's time", untimed_check,
               "drift", "current", started_h=20)
    check("  state_check_h is about 0.1", s.records()[-1]["state_check_h"] <= 0.2, str(s.records()[-1]))

    s = Session()
    s.prompt()
    s.commit(own=False)          # made by this session, but quietly: no hash in the transcript
    rc, out = s.run("post", {"tool_name": "Bash", "tool_input": {"command": "git commit -q -m c"}})
    rec = s.prompt()
    check("a quiet commit, reported within the minute, is this session's own (gate lets it through)",
          rec["outside_commits"] == 0 and rec["drift"] == "current", str(rec))

    print("unsaved: work since the memory file was written")
    expect("nothing done", lambda s: None, "unsaved", "none")
    expect("one edit", lambda s: s.edits(1), "unsaved", "some")
    expect("five edits", lambda s: s.edits(5), "unsaved", "some")
    expect("six edits", lambda s: s.edits(6), "unsaved", "lots")
    expect("a subagent and a shell write", lambda s: (s.tool("Agent", prompt="x"), s.tool("Bash", command="sed -i s/a/b/ f")),
           "unsaved", "some")
    expect("a read-only shell command", lambda s: s.tool("Bash", command="grep -n x f 2>/dev/null"), "unsaved", "none")
    expect("six edits then a memory Write",
           lambda s: (s.edits(6), s.tool("Write", file_path=f"{s.dir}/.waypoint/memory/2026-11-23-x.md")),
           "unsaved", "none")
    expect("six edits then a shell append to memory",
           lambda s: (s.edits(6), s.tool("Bash", command="cat >> .waypoint/memory/2026-11-23-x.md <<EOF")),
           "unsaved", "none")

    print("only the transcript's own lines count, not request blobs that repeat them")
    s = Session()
    s.edits(2)
    s.blob(5)
    a = s.prompt()
    check("2 edits and a blob repeating 5: unsaved_work 2, compactions 0",
          a and a["unsaved_work"] == 2 and a["compactions"] == 0, str(a))
    s = Session()
    s.edits(6)
    s.tool("Bash", command='f=.waypoint/memory/2026-11-23-x.md && t=$(date) && cat > $f <<EOF')
    check("six edits then a memory write through a variable: unsaved none", s.prompt()["unsaved"] == "none")

    print("compaction possible: context past 200k")
    expect("199k", lambda s: s.reply(199_400), "compaction_possible", False)
    expect("200k", lambda s: s.reply(200_000), "compaction_possible", True)

    print("the transcript is read once: a second prompt does not count the same lines again")
    s = Session()
    s.edits(3)
    a = s.prompt()
    b = s.prompt()
    s.edits(1)
    c = s.prompt()
    check("3, 3, then 4 edits", (a["unsaved_work"], b["unsaved_work"], c["unsaved_work"]) == (3, 3, 4), f"{a} {b} {c}")

    print("during a long turn: a tool call records for readers, speaks only when the ask gets stronger")
    s = Session()
    s.reply(150_000)
    s.prompt()
    n0 = len(s.records())
    s.edits(2)
    s.reply(210_000)
    rc, out = s.run("post", {"tool_name": "Read", "tool_input": {"file_path": "/x"}})
    check("within the minute: gated in shell, nothing said or written", out == "" and len(s.records()) == n0, out)
    s.unthrottle()
    rc, out = s.run("post", {"tool_name": "Read", "tool_input": {"file_path": "/x"}})
    t = told(out)
    check("unsaved work while a compaction is possible: told as PostToolUse and recorded",
          t is not None and t[0] == "PostToolUse" and len(s.records()) == n0 + 1, str(t))
    s.unthrottle()
    rc, out = s.run("post", {"tool_name": "Read", "tool_input": {"file_path": "/x"}})
    check("same ask again: nothing said, recorded for readers", out == "" and len(s.records()) == n0 + 2, out)
    mem = s.dir + "/.waypoint/memory/2026-11-23-x.md"
    s.tool("Write", file_path=mem)
    rc, out = s.run("post", {"tool_name": "Write", "tool_input": {"file_path": mem}})
    r = s.records()[-1]
    check("a memory write inside the minute: past the gate, recorded as unsaved none, nothing said",
          out == "" and len(s.records()) == n0 + 3 and r["unsaved"] == "none", f"{out} {r}")
    s.compact()
    s.unthrottle()
    rc, out = s.run("post", {"tool_name": "Read", "tool_input": {"file_path": "/x"}})
    t = told(out)
    check("a compaction mid-turn: told", t is not None and '"just_compacted": true' in t[1], str(t))

    print("never fails, never leaks")
    s = Session()
    env = {**os.environ, "CLAUDE_PROJECT_DIR": s.dir}
    p = subprocess.run(["bash", SH, "prompt"], input="{not json", capture_output=True, text=True, env=env)
    check("malformed input: exit 0, no output", p.returncode == 0 and p.stdout == "", p.stdout)
    s = Session()
    rc, out = s.run("prompt")
    check("reply is one JSON object", rc == 0 and isinstance(json.loads(out), dict), out)
    leaked = any("PROMPT-TEXT-MUST-NOT-LEAK" in open(os.path.join(dp, f)).read()
                 for dp, _, fs in os.walk(os.path.join(s.dir, ".waypoint")) for f in fs)
    check("prompt text is in no event or state file", not leaked)

    print("event files stay out of git")
    s = Session()
    s.run("start", {"source": "startup"})
    s.prompt()
    ig = os.path.join(s.dir, ".waypoint", "events", ".gitignore")
    st = subprocess.run(["git", "-C", s.dir, "status", "--porcelain", "--untracked-files=all"],
                        capture_output=True, text=True).stdout
    check("session start writes .waypoint/events/.gitignore and git sees nothing under events/",
          os.path.exists(ig) and ".waypoint/events" not in st and "transcript.jsonl" in st, st)

    print(f"{checks - failures}/{checks} checks passed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
