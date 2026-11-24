# Contract: session events

**Version:** 1. **Status:** in use since 2026-11-22 (one project, one reader); shipped with
Waypoint 2026-11-23.

A project's sessions and runs leave a small machine-readable record so that something other than
the session can watch them: a terminal status view, a web page, a script. This page defines that
record. It is the one place the format lives; writers and readers both point here.

## Roles

- **Waypoint defines this contract.** It is plain Markdown, like the rest of Waypoint's core.
- **Writers are per tool.** A run-mode runner writes a run's events; an adapter's hooks write a
  session's events. One writer per file.
- **Readers only read.** A reader never writes into a project; the one exception is a person
  creating `HOLD` (below).

Sessions are the general frame. A run is a group of sessions (its units) plus the machine jobs
between them. Session kinds: `interactive`, `unit` (spawned by a runner), `subagent` (spawned by a
session).

Writers shipped today: the Claude Code adapter's hook (`waypoint-events.sh`, `waypoint_events.py`)
and its runner (`run_chain.sh`). The Cursor adapter has no writer yet; a reader shows such a
project without events.

## Where

All under the project's `.waypoint/events/`, which git ignores (the folder carries its own ignore
file). Event data is never committed: a reader sees only the machine it runs on.

```
.waypoint/events/
  runs/<run>-<YYYYMMDD-HHMMSS>/     one folder per run, named by runbook and start time
    events.jsonl                    the runner's events
    pid                             the runner's process id while it lives
    HOLD                            created by a person: stop at the next boundary
    runner.log, unit-<N>.json ...   the runner's own files (not part of the contract)
  sessions/<tool>-<session id>.jsonl  one file per session, written by hooks
  daily/, sessions/.state/          writers' own bookkeeping (not part of the contract)
```

One writer per file, because appends from several processes are not guaranteed to stay whole on
every filesystem.

## Lines

One JSON object per line, appended, never rewritten. Every line carries:

| Field | Required | Meaning |
|---|---|---|
| `v` | yes | contract major version, `1` |
| `ts` | yes | ISO 8601 with offset, e.g. `2026-11-22T09:14:03-05:00` |
| `event` | yes | the type, below |
| `project` | yes | the project folder's name |
| `tool` | yes | `{"name": "claude-code", "version": "2.1.323"}`; names: `claude-code`, `cursor`, `codex`, ... |
| `writer` | yes | `runner` or `hook` |
| `run` | in a run | the run folder's name |
| `session` | when about a session | `{"id": ..., "kind": "interactive"/"unit"/"subagent", "parent": <session id or run> or null}` |

### Run events (writer: runner)

| Event | Fields |
|---|---|
| `run.started` | `runbook` (path in the project), `units` (ids in order), `names` ({id: name} from the runbook), `cap`, `may_push`, `wait_for` (text, optional) |
| `run.waiting` | `reason`: `wait_for`, `window` (a quiet window or a pause), `manual` or `job`; `detail` (text) |
| `run.resumed` | `reason` (the same values) |
| `unit.started` | `unit`, `session`: its id when the tool lets the runner choose it (Claude Code: `--session-id`); optional `transcript`, when the runner knows where the tool will write it |
| `unit.ended` | `unit`, `session`, `status` (`DONE`, `WAITING`, `BLOCKED`, `FAILED`, `NO_STATUS`), `reason` (one line, empty for DONE), `exit_code`, `duration_s`; optional: `model`, `turns`, `tokens`, `permission_denials`, `transcript` |
| `job.started` | `unit`, `pid`, `log` (path, optional) |
| `job.ended` | `unit`, `exit_code` (when known), `duration_s`, `frozen_s` |
| `run.finished` | `outcome`, `detail` (one line). Outcomes: `DONE`; `STOPPED` (a unit's status, a missing memory entry, uncommitted work); `HALT` (a hard-stop sign); `HELD` (the hold file); `CAP` (sessions or tokens); `TIMEOUT` (a wait ran out); `DEADLINE`; `ENV` (the environment check); `CI` (an open issue the runner did not open); `NOPOLICY`. A reader shows an outcome it does not know as text |

### Session events (writer: hook)

| Event | Fields |
|---|---|
| `session.started` | `session`; optional: `model`, `transcript`, `pid` (the tool's own process id, when the hook can find it), `source` (`startup`, `resume`, `clear`) |
| `session.waiting` | `session`, `reason`: `input` (the agent finished its turn and waits for its person) or `permission` (it waits on a permission prompt) |
| `session.active` | `session`. Written on activity (a prompt, a tool call), at most once a minute per session, and at once after a `session.waiting` |
| `session.model` | `session`, `model` (exact id). The model the session is using, written when first known and whenever it changes. For a tool whose start hook names the model, `session.started` carries it instead and this event marks only changes |
| `session.compacted` | `session` |
| `session.memory_written` | `session`, `file` (path in the project) |
| `session.condition` | `session`; the readings `fatigue` (`fresh`, `working`, `tiring`, `tired`, `exhausted`), `drift` (`current`, `aging`, `stale`), `unsaved` (`none`, `some`, `lots`); the flags `just_compacted`, `compaction_possible`; the measures `hours`, `compactions`, `work_summarized`, `context_k`, `state_check_h`, `outside_commits`, `unsaved_work` (each left out when it cannot be read). Written on every prompt and on tool calls (at most about once a minute, plus every memory write and commit). See Session condition, below |
| `session.ended` | `session`, `duration_s`; optional: `tokens` |

### Shared optional objects

- `tokens`: `{"input": n, "cache_write": n, "cache_read": n, "output": n}`, totals for the session.
- `transcript`: `{"path": "/abs/path.jsonl", "format": "claude-code-jsonl"}`. Detail the contract
  does not carry (context size per call, recent actions, subagents) is read from the transcript by a
  reader that knows that format. A reader that does not shows the session without it.

### Never in an event

Prompt text, code, file contents, command lines, secrets. Counts, times, statuses, short reasons and
paths only, so a file is harmless in a screenshot or a bug report.

## Session condition

A long session gets worse at its work and cannot feel it; in the project that piloted this, the
developer noticed first every time. The writer computes one record, so the session and its readers
see the same thing. Three readings, because each asks for a different action:

- **Fatigue: should the session hand over?** Set by compaction history. `fresh` (under 2 h, no
  compaction), `working` (no compaction), `tiring` (1-3), `tired` (4-7, or 100 work items
  summarized away), `exhausted` (8 or more).
- **Drift: is its picture of the world old?** Hours since its last state check (fetching or reading
  git history, reading CI's runs, reading `project.md`, or a command the project names as a state
  check) and commits on HEAD it did not make. `current`, `aging` (2 h, or 1 outside commit), `stale`
  (12 h, or 3).
- **Unsaved: what would a stop lose?** Work items (edits, commits, subagents, shell writes) since the
  memory file was written. `none`, `some` (1-5), `lots` (6 or more).
- **Flags.** `just_compacted`: compacted and has not re-read `project.md` since.
  `compaction_possible`: context past 200k tokens.

The thresholds are the writer's calibration, not the contract. The Claude Code writer's first
values come from one developer's sessions: a replay of 29 saved sessions against 116 labeled slips
found the slip rate doubled after the first compaction (6.8% to 13.1%) and ran about twice the
usual in the first stretch after any compaction, while context size and how full a stretch was
showed no relation. Levels above `tiring` are judgment. Recalibrate from the record whenever the
developer catches a slip the reading missed.

The session gets the record as one line of data on every prompt (`Session condition: {...}`); what
each value asks of it is the OPORD's standing rule "Condition". During a long turn, a tool call
repeats it only when the ask gets stronger. Readers get more: the record is written on tool calls
too, so a run's units show change during the unit, not only at its one prompt.

Readers show the latest `session.condition` of a session. A tool without a writer for this event
has no record; a reader may derive its own from the transcript and should say it did.

## Liveness and control

- A run is live while `pid` names a running process. A run with no `run.finished` and a dead pid
  died; readers say so.
- A job is running while the `pid` in its `job.started` names a running process. A job with no
  `job.ended` and a dead pid ended without a record; readers say so.
- An interactive session is gone when its `pid` is no longer running and no `session.ended` was
  written. Without a `pid`, a reader may only say how long the session has been silent.
- A wait ends with any later event from the same session except `session.model`, which can be
  written after the wait it belongs to. Nothing fires when a person answers a prompt; the next
  `session.active` (written at once after a wait) shows the session moved on.
- Pid reuse is the reader's to guard against: compare the process's start time with the event's
  `ts`.
- `HOLD` is the only input. The runner checks it at every boundary and finishes with `HELD`.

## Versioning

Within a major version, writers may add event types, fields and values; readers ignore what they
do not know. A breaking change raises `v`; a reader that meets a newer major version says so and
stops reading that file rather than guessing.

## Retention

Event files are not history. Writers prune their own kind older than 30 days (the run folder, the
session file) when they start. History is the reader's to keep, in its own storage. Nothing is
committed to the project.

## Open

- Whether Cursor and other tools expose the hooks an interactive-session writer needs, and what
  their headless mode reports. Checked when their writer is built; the contract does not depend
  on it.
- Subagents are not written by hooks; a reader takes them from the session's transcript folder.
