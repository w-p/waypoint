---
name: run
description: >
  Run planned, decided work as a chain of fresh sessions with nobody watching each one
  (run mode). Covers when a run is the right tool, how to write the runbook, what the
  developer must approve before it starts, how to launch and watch it, and how to review
  it. Use when a stretch of work is fully decided and mechanical, or when a unit of a
  run asks what is expected of it.
---

# Skill: Run

## Purpose

A long session waiting on machine work only accumulates context, and its judgment gets
worse as it does. Work that is already decided does not need one: it can be cut into
units, each done by a fresh session that boots from the repository, does one thing,
records it and exits. That is run mode. Interactive work stays the place for anything with
an open decision.

A run never improvises. Anything unexpected ends the chain and hands the work back to an
interactive session.

---

## When to Use

- The work in front of you is planned, decided and repeated or mechanical: a batch job
  with gates, landing a reviewed branch, drafting from a settled template.
- A stretch of it is machine time (a build, a test suite, a CI run) that no session should
  sit through.

Not for research, design, debugging, or anything where a unit would have to choose between
approaches. Expect the first runs to stop: a stop is usually a defect made before the run,
in the drafting, and a fresh session finding it is the run working.

---

## Before a run exists

1. **The policy.** `.waypoint/automation.md` must exist. If it does not, the project has
   not been set up for run mode: follow `run-setup.md` first.
2. **Every decision made.** A run is legal only when each decision its units depend on is
   already made and recorded. Refuse to start one with an open decision; settle it in
   conversation first.

---

## The runbook

One file per run, `.waypoint/plan/runs/<name>.md`, drawn from the plan.

**The header** records who approved the run and when, how it is launched, what stops the
whole run, and what is expected: sessions, machine time, tokens.

**The units** are one table. The runner reads the first two columns (id and name); the
rest is for the session doing the unit.

```
| # | Unit | Entry | Do | Exit check | On fail |
|---|---|---|---|---|---|
| 1 | Merge the branch | unit 0 DONE; tree clean; branch at <commit> | `git merge --no-ff <branch>`; the one expected conflict is decided: ... | merge commit on local main, not pushed; `make check` exits 0 | stop: BLOCKED naming the file that conflicts |
```

- **Entry:** what must already be true, checked against artifacts, not against what an
  earlier unit said.
- **Do:** the procedure, or the skill to follow. Decisions are stated here as decided.
- **Exit check:** the command whose result proves the unit finished.
- **On fail:** stop, with what to report.

**Where to cut units.** A boundary is a point where a fresh session can recover the full
state from the repository and its artifacts alone: commits, gate results, logs, the run's
memory file. If a session would need something that exists only in conversation, that point
is not a boundary. In practice:

- A unit ends when it starts long machine work. It launches the job, records it and exits;
  the job's exit starts the next unit. No session stays open waiting on a build.
- Every gate verdict is a boundary. A pass moves on; a failure stops the chain.
- A release, a deploy or anything else the policy names as a hard stop is never inside a
  run. The run ends before it and the developer takes it from there.

**Deadlines.** A line `**Deadline:** unit <id> starts by YYYY-MM-DD HH:MM` makes the runner
stop rather than start that unit late.

**Write tooling text from the tool.** Anything the runbook says about how a script behaves
(what it prints, whether it returns at once, which process id to report) comes from running
it, not from memory of it. Units check instead of trusting, but a wrong brief costs a stop.

---

## Entering run mode

There is no command phrase; the developer gets there in conversation.

- You may suggest a run. You never start one on your own.
- Before starting, restate the run and ask for a yes: the units, the stops, what ends it,
  the expected machine time, sessions and tokens, and when the developer will hear back. A
  bare "are you sure?" is not enough, because it gets a reflexive yes.
- The yes covers exactly the restated scope. Sessions in the run do not ask again, and
  nothing is added partway through. A change to the runbook mid-run is a new approval,
  recorded in the runbook's header.
- Getting out is conversational too: "hold on" or "pause after this" stops at the next
  boundary.

---

## Launching and watching

With the Claude Code adapter, the runner is `.claude/runner/run_chain.sh` (its header has
the options). Start it detached, so it outlives the session that launched it:

```
setsid nohup .claude/runner/run_chain.sh .waypoint/plan/runs/<name>.md 1 2 3 --may-push 3 \
  > /dev/null 2>&1 &
```

It spawns each unit as a fresh scripted session, waits on jobs and quiet windows without
spending tokens, and stops on anything but `DONE` or `WAITING`. Its folder is
`.waypoint/events/runs/<name>-<start time>/`: `runner.log`, each session's result,
`events.jsonl`, and at the end a file `done` holding the outcome.

- **To hold:** create a file named `HOLD` in that folder. The chain stops at the next
  boundary.
- **To see where it is:** read `runner.log`, or use a reader of the session-events record
  (the contract is in the Waypoint repository, `contracts/session-events.md`).
- **While it runs, nobody else edits this checkout.** The runner stops on any modified
  tracked file after a unit. A supervising session works in a separate worktree, and wakes
  when `done` appears, not on a timer of relayed status.
- **A unit changes none of the files that govern the run:** the policy, the runbook, and
  `.claude`'s settings, hooks, rules and runner. The runner compares them before and after
  each unit, tracked or not, and halts on any difference. You may change them between
  units, while the chain waits on a job or a quiet window; a change while a unit is running
  halts the chain, because the runner cannot tell whose it was. Work on those files
  themselves (reinstalling Waypoint, editing a hook) is not work for a run.
- **Watch what the project runs on a schedule as well.** A scheduled job failing during a
  run is the run's business; the policy's CI stop exists for it.

On a host tool with no shipped runner, the same runbook works with a supervising session
spawning each unit and reading its status line. That costs the supervisor's context, so
keep it to reading status and stopping.

---

## What a unit does

A unit's session is told its unit id and the runbook. It:

1. Boots as every session does (the OPORD's checklist), and reads this run's memory file.
2. Confirms its Entry against artifacts.
3. Does its Do column and runs its Exit check. Nothing outside the unit.
4. Stops without improvising if anything is unexpected, a check fails, or a decision is
   needed that the runbook and its sources do not settle.
5. Appends to the run's memory file, `.waypoint/memory/YYYY-MM-DD-<run>.md` (first line a
   standalone summary of the run): a heading `## <local time> -- unit <id>: <name>`, then
   one line holding exactly one status, then a short note a cold reader can act on.
6. Commits that entry with its other changes, leaving no tracked file modified, and ends
   its reply with the same status line, alone on the last line.

| Status | Meaning | What the runner does |
|---|---|---|
| `DONE` | The exit check passed | Starts the next unit |
| `WAITING pid <N> <job>` | The unit launched a job and exited | Waits for that process, then starts the next unit |
| `BLOCKED <reason>` | The unit could not proceed (an entry not met, an action refused) | Ends the chain |
| `FAILED <reason>` | A check or gate failed | Ends the chain |

A reason is one plain line a person can act on. The runner reads only the reply's last
line. `DONE` stands by itself there: a `DONE` that goes on to say more, or a status word
anywhere above the last line, ends the chain as no status at all. The memory entry must be
new as well; when a chain is run again after a stop, the earlier attempt's entry for the
same unit does not count. The runner adds a ledger line under the
entry (session, times, turns, tokens), which turns the run's estimates into measurements.

---

## When it ends

Every end notifies the developer the way the policy says. Then, in an interactive session:

- Read the run's memory file and the runner's log before reporting anything.
- A stop goes back to interactive work. Diagnose it there; a stop can take a day, and the
  run's only job at that point was to leave the tree resumable.
- Compare the ledger with what the runbook expected and correct the next runbook's
  estimates.
- Have the result judged by a session other than the one that built it, on the thing the
  developer judges by. A unit's own exit check passing is not that.
- Record what the run taught: in the runbook template the project uses, or as a rule in
  `sop.md` (`report.md`, checklist 2).

---

## Notes

- The run's memory file is the handoff. There is no separate handoff document.
- Run mode covers serial chains. Parallel agents on work with open decisions are a
  different thing, with shared resources to own (one machine, one main copy, one log); this
  skill does not cover it.
