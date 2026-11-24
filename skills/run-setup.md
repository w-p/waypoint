---
name: run-setup
description: >
  Set up run mode for a project: a guided interview that writes the policy file
  (.waypoint/automation.md) a runner reads before it starts each fresh session in a
  chain, then proves every safeguard in it by making it fire. Use once per project,
  before the first chained run, or when the developer wants to change what an
  unattended session may do.
---

# Skill: Run Setup

## Purpose

Run mode executes planned, decided work as a chain of fresh sessions (`run.md`). Nobody is
watching each session, so the limits on what it may do have to be written down beforehand
and proven to hold. This interview produces those limits. It is not finished when the file
is written; it is finished when every safeguard in the file has been seen to stop something.

---

## When to Use

- The project has no `.waypoint/automation.md` and the developer wants chained runs.
- The developer wants to change a trigger, a quiet window, a hard stop or the unattended
  permission set. Rerun only the affected part and its drill.

Do not use it to start a run. Starting a run is a separate conversation (`run.md`).

---

## Process

Ask one topic at a time, in prose. Propose a default from what the project already records
(CI schedules, build windows, release procedure, settings files) and ask the developer to
confirm or change it. Read those records before asking; do not ask for what they already
say. Check every claim you make in a recommendation before making it: a default the
developer accepts on your word becomes policy.

1. **What may start a session.** With the shipped runner, only the previous unit: its status
   line, or the exit of a job it launched. If the project wants more (a schedule, a commit),
   say how the runner would learn of it and how that was tested to fire.
2. **Quiet windows.** Days, times and time zone, or none. If the project already has a
   schedule for machine work (a build pauser, a CI freeze), reuse it so sessions and builds
   honor one rule.
3. **Hard stops.** Actions that end the chain and wait for the developer, whatever the
   runbook says: releases to users or testers, publishing, spending money, deleting data the
   run did not create, rewriting history, anything outside the repository. Name the commands
   and paths, not categories. For each, say which layer stops it: the runner (a push to the
   protected branch, a dispatched workflow, a change to the files that govern the run),
   the host tool's permission layer, or only the unit's own instruction. The runner's halts
   come after the fact: they end the chain, they do not undo the action.
4. **The unattended permission set.** What a scripted session may run without a person. Find
   out where the host tool actually reads these rules (measure it; some settings are read
   only from the user's account-wide file) and say so before writing anything there. Prefer
   rules that live in the project. An action the permission layer refuses goes to the
   developer; do not widen the layer to fit a runbook.
5. **Session environment.** A scripted session gets a non-interactive shell: toolchains set
   up by the interactive profile may be missing or a different version. Record what a
   session needs (matching CI where CI pins it), the line that puts it in place, and the
   check the runner makes before each start.
6. **Notifications.** Where the developer hears about stops and the end of a run, and what
   each message contains. Prove delivery, not just sending: a message sent under the
   developer's own login (an issue, a comment) notifies nobody, because services do not
   notify a person of their own actions, and a channel that relies on watching a repository
   needs the watch to exist. Cover the jobs the project runs on a schedule too: a scheduled
   job that fails during a chain should stop it, or the developer hears about it last.
7. **Caps.** Sessions per day, tokens per unit and per day, and a time limit on one unit.
   Base the figures on a measured run when there is one.
8. **Between runs.** Whether finishing a run ends with a notification or the next run starts
   on its own.
9. **Deadlines.** Whether runbooks carry "starts by" lines the runner enforces.

---

## The policy file

Write `.waypoint/automation.md`: a short Markdown page for people (each answer with its
reason and date), a Drills section, then one fenced block the runner parses. The block is a
JSON object:

````
```automation
{
  "sessions_per_day": 12,
  "tokens_per_unit": 3000000,
  "tokens_per_day": 15000000,
  "unit_timeout_s": 7200,
  "stop_on_ci_issue": false,
  "env_check": "node --version | grep -q '^v24\\.' && git --version >/dev/null",
  "quiet": ["Fri 17:00-Sat 03:00"],
  "tz": "America/New_York",
  "notify": "github-issue"
}
```
````

The values above are an example, not defaults.

| Key | Required | Meaning |
|---|---|---|
| `sessions_per_day` | yes | Most sessions the runner starts in a day, across all runs |
| `tokens_per_unit` | yes | A chain stops after a unit that used more (all token kinds summed) |
| `tokens_per_day` | yes | No unit starts once the day has used this many |
| `unit_timeout_s` | yes | A unit's session is ended after this long |
| `stop_on_ci_issue` | yes | `true`: any open issue not labelled `run-mode` stops the chain (needs `gh`) |
| `env_check` | yes | A shell command that must exit 0 before each unit starts |
| `env_setup` | no | Shell run once by the runner to put the toolchain in place (a `PATH` line) |
| `quiet` | no | Windows when no session starts: weekly (`"Fri 17:00-Sat 03:00"`) or daily (`"22:00-06:00"`) |
| `held_cmd` | no | A command that exits 0 while no session may start (the project's own pause) |
| `tz` | no | The time zone for windows, deadlines, the daily tally and logs; default the machine's. A name the machine does not know (`"America/New York"`) stops the runner before any session, as does a `quiet` entry it cannot read |
| `protected_branch` | no | A unit not allowed to push that moves this branch on origin halts the chain; default origin's default branch |
| `halt_on_dispatch` | no | `true`: a manually dispatched workflow run created during the chain halts it (needs `gh`) |
| `notify` | no | `none` (default), `github-issue`, or `command` |
| `notify_cmd` | with `command` | A shell command; it gets `WAYPOINT_NOTIFY_OUTCOME`, `_TITLE`, `_DETAIL`, `_BODY`, `_RUN` |
| `permission_mode` | no | The permission mode units start in; default `auto` |
| `commit_suffix` | no | Text every commit of a run carries in its subject (for example a CI skip marker) |
| `unit_rules` | no | Sentences added to every unit's instructions (the project's hard stops, by name) |
| `job_exit_dir` | no | A folder where the project's job wrapper writes `<pid>` files holding exit codes |

`github-issue` needs the workflow at `.claude/runner/run-notify.yml` copied to
`.github/workflows/` on the default branch: the runner asks it to open the issue as the
Actions bot, with a mention of the repository owner, because an issue the runner opened
under the developer's own login would notify nobody.

A project on a host tool with no shipped runner still writes the page and the block; they
are the brief for whoever spawns the units.

---

## Drills: setup is not complete until each safeguard has fired

Run each drill against the real runner and the real policy, record the command and what
happened in the policy page, and fix anything that did not stop. For each, say which layer
the drill exercised.

- **Quiet window:** a fake clock inside the window (`RUNNER_NOW='YYYY-MM-DD HH:MM'`); the
  runner starts no session.
- **Gate failure:** a unit whose exit check is made to fail; the chain stops and notifies.
- **Hard stop:** one hard-stop action attempted during a unit; the action is refused or the
  runner halts, and the developer is notified. A unit told to attempt it may decline on its
  own instruction, which drills only that layer; to drill the runner's halt, perform the
  action yourself while a unit runs.
- **Governing files:** this policy file edited while a unit runs; the runner halts and names
  it. The control is the same edit made while the chain waits, which halts nothing.
- **Environment:** the runner started with the toolchain missing; it starts no session.
- **Caps:** the day's tally set at the cap; the next start is refused.
- **Deadline**, if used: a runbook line already past; that unit does not start.
- **Notification:** a message at a stop, and the developer confirms it arrived where they
  will see it.

A drill that passes on the first try still counts only if its control fails: show the same
check letting a session through when the condition is absent.

Say plainly what was not drilled live (a cap no real unit can reach cheaply, a refusal by
the permission layer nobody triggered) and how it was checked instead.

---

## Done when

- `.waypoint/automation.md` exists, the developer has read it, and each answer has a reason.
- Every drill above has a recorded result and a recorded control.
- The developer has confirmed a notification reached them.
- The memory file records the interview and the drills.
