# Design: Run mode, session events and the session condition

**Status:** Decided with the developer in a downstream project between 2026-11-13 and
2026-11-23, piloted there, and brought into Waypoint on branch `v2-run-mode` as a pull
request against `v2`. The developer asked for the pull request on 2026-11-23, before the
pilot's own bar (a full batch run under the policy-reading runner) was met; section 6 says
what that leaves unproven.
**Scope:** Two core skills, one contract, an OPORD paragraph and a standing rule, and in the
Claude Code adapter a hook, a runner and a workflow file. The Cursor adapter is unchanged.

---

## 1. Problem

Waypoint assumed one interactive session at a time. A project in execution spends long
stretches on work that is already decided and largely machine time: in the pilot project,
batch jobs of about 25 machine hours each. A live session there only waits, and its context
grows while it waits. Three things followed from that:

- **Long sessions get worse and cannot feel it.** In every case the pilot recorded, the
  developer noticed the degradation before the session did: status relayed without checking,
  state lagging facts, a rule out of view.
- **Nothing outside the session could see it.** The developer ran sessions in eleven
  projects and had no view of which were working, waiting on them, or stuck.
- **Decided work was done by a session with no reason to be there.** The alternative, a
  chain of fresh sessions, needs limits written down in advance, because nobody watches each
  one.

## 2. What the pilot showed

Recorded by the pilot project in its own memory and design files; not re-measured here.

- **A cold session works from artifacts alone.** Thirteen sessions spawned by a supervising
  session (2026-11-15 and 16) each booted from the repository and the run's memory file,
  and fresh sessions caught defects the long session had missed. There was no token saving
  while a supervisor sat between units; its review and growing context ate the difference.
- **A runner removes the supervisor.** A throwaway four-unit chain (2026-11-20) stopped
  correctly on a rehearsal lost to an outside service. A real five-unit chain (2026-11-22)
  finished clean with nobody between units, 0.28 to 1.18 million tokens a unit.
- **Stops are mostly drafting defects.** Each stop in the first run traced to something made
  before the run, in interactive drafting. A stop took the supervisor 10 to 20 minutes to
  decide and the unit under 15 minutes to finish once decided. One stop took a night of
  interactive work, and the run's only job was to leave the tree resumable.
- **A recommended safeguard can be wrong.** The setup interview recommended GitHub issues
  because "the phone already gets those". The developer did not watch the repository, and an
  issue the runner opens under the developer's own login notifies nobody. Found only because
  the interview's rule is that a safeguard counts once it has been seen to fire.
- **Fatigue follows compactions, not context size.** A replay of 29 saved sessions against
  116 labeled slips: the slip rate went from 6.8% to 13.1% after the first compaction and ran
  about double in the first stretch after any compaction. Context size and how full a
  stretch was showed no relation.

## 3. Decisions

1. **Two modes.** Interactive for anything with an open decision. Run mode for planned,
   decided work, executed as a chain of fresh sessions. A run never improvises; a surprise
   ends the chain and returns the work to an interactive session.
2. **Entering a run is a conversation, not a command.** The assistant may suggest one and
   never starts one on its own; it refuses while any decision in the runbook is open; it
   restates the scope and gets a yes that covers exactly that scope. This is the one part
   that has to be in front of every interactive session, so it is an OPORD paragraph (§3c).
   The rest is the `run` skill, read when a run is being written or started.
3. **The policy is a file, written by an interview, proven by drills.**
   `.waypoint/automation.md`: Markdown for people, one fenced JSON block for the runner. The
   `run-setup` skill is not done until each safeguard has fired and its control has let a
   session through.
4. **The run's memory file is the handoff.** One status line per unit (`DONE`, `WAITING pid`,
   `BLOCKED`, `FAILED`), a note for a cold reader, and a ledger line the runner adds. No
   separate handoff format: that would duplicate memory.
5. **The core stays Markdown; the runner belongs to an adapter.** The skills, the runbook
   format and the contract are plain text and work with any host tool, with a supervising
   session spawning units where no runner exists. The script that chains `claude -p`
   sessions is Claude Code's and ships in that adapter.
6. **Waypoint owns the session-events contract.** `contracts/session-events.md`, version 1:
   one JSON object per line under `.waypoint/events/`, one writer per file, readers never
   write. It lives in the Waypoint repository and is not installed into projects, because
   its audience is the people who build writers and readers.
7. **Event files are never committed, and the installer does not edit `.gitignore`.** The
   events folder carries its own ignore file. Writers create it too, so a hand-copied hook is
   as safe as an installed one.
8. **The session condition is one record, three readings.** Fatigue (hand over?), drift (is
   the picture old?), unsaved (what would a stop lose?), with two flags. The session gets it
   as one line of data on each prompt; the standing rule **Condition** says what each value
   asks. Readers get the same record. The thresholds are the writer's calibration, not the
   contract.
9. **The events hook is on for every Claude Code install.** A status view is only useful if
   every project writes, and the condition record is only useful if the session receives it.
   The hook never fails its session and does nothing without `python3`.

## 4. What changed between the pilot and what ships

The pilot's runner named its project's own scripts. Each became a policy key, optional with
a neutral default, so the required keys are the six the pilot already had.

| In the pilot | Ships as |
|---|---|
| The project's build pauser decides the quiet window | `quiet` (weekly or daily windows) and `held_cmd` (any command) |
| Eastern time throughout | `tz`, default the machine's zone |
| A hard-coded toolchain path | `env_setup` |
| The project's job wrapper writes exit codes to a fixed folder | `job_exit_dir` |
| Always halts on a dispatched workflow | `halt_on_dispatch`, default off (needs `gh`) |
| `main` is the protected branch | `protected_branch`, default origin's default branch |
| Notifies through a GitHub workflow | `notify`: `none`, `github-issue` or `command` |
| The prompt names the project's bucket and CI skip marker | `unit_rules`, `commit_suffix` |
| Units always start in permission mode `auto` | `permission_mode`, default `auto` |
| The hook knows the project's state scripts by name | `WAYPOINT_STATE_CHECK`, a pattern in the settings file's `env` |

The weekly and daily window parser is new code the pilot never ran; it is covered by stub
checks with a fake clock, each with its control.

## 5. Rejected

- **A command phrase that enters run mode.** A phrase gets a reflexive yes. The restated
  scope is the safeguard.
- **A separate handoff folder.** It would restate the memory log.
- **One fatigue level from the worst of four measures.** Built first and replaced the same
  day: each reading asks for a different action, and one number hid which.
- **Editing the project's `.gitignore`.** The installer never blind-edits project files.
- **Widening the permission layer to fit a runbook.** An action the layer refuses goes to
  the developer.
- **A runner in the core.** It would make the core depend on one host tool.

## 6. Known limits

- **The pilot's bar is not met.** A full batch has not yet run under the runner as it reads
  the policy; the policy-reading runner has run drills and short chains. The generalized
  runner has run its stub suite and one real two-unit chain in a scratch project.
- **Linux and WSL only.** The runner uses GNU `timeout`, `date -d` and `stat -c`, and reads
  `/proc` for a job's log. The hook finds its session's process through `/proc` and leaves
  the pid out elsewhere.
- **One developer's calibration.** The condition thresholds come from 29 sessions of one
  person's work. Levels above `tiring` are judgment.
- **Claude Code only.** No Cursor writer and no Cursor runner. Whether Cursor's hooks can
  support a writer is unchecked.
- **Serial chains only.** Parallel agents on work with open decisions are a third mode with
  shared things to own. A downstream project recorded what goes wrong there; nothing in
  this design covers it.
- **Not built:** amending a runbook mid-run as a recorded step, units marked interactive
  inside a runbook, a per-unit token cap that acts during a unit, and the memory backstop
  comparing against the tree as it was at session start.
- **Waypoint's CONOPS lists orchestration and observability as out of scope.** This design
  crosses both lines in a narrow way. The pull request proposes the wording; the CONOPS is
  the developer's to approve.
