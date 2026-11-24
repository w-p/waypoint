# Plan: Run mode, session events and the session condition

**Design:** `.waypoint/design/2026-11-23-run-mode-and-session-events.md`
**Status:** Executed 2026-11-23 on branch `v2-run-mode`, for a pull request against `v2`.

T2 touches the OPORD baseline, so extended downstream copies take it through the
`update-waypoint` merge. Everything else lands by reinstall.

## T1 — Contract

`contracts/session-events.md`: the pilot's event format, version 1, with its project-specific
sections removed and the runner's full list of outcomes written in.

## T2 — OPORD

In `templates/opord.md` and its dogfooded copy: §1 lists `automation.md`; §3c gains **Run
mode**; the standing rules gain **Condition**. Nothing else.

## T3 — Skills

`skills/run-setup.md` (the interview, the policy block's keys, the drills) and `skills/run.md`
(when to run, the runbook, entering, launching, the unit's duties, review). Both in the
installer's core list.

## T4 — Claude Code adapter

- `hooks/waypoint-events.sh` and `waypoint_events.py`, wired at session start, prompt, tool
  call, stop, permission request and session end.
- `runner/run_chain.sh`, generalized through policy keys (design §4), and `run-notify.yml`.
- `tests/test_run_chain.sh` and `tests/test_condition.py`, ported and extended; run by
  `test.sh`, not installed.

## T5 — Installer

Copy the Python writer with the hook scripts; install the runner; create
`.waypoint/events/.gitignore`; say so when `python3` is missing.

## T6 — Tests, docs, closeout

`test.sh`: skills installed, hook and runner installed and wired, idempotent wiring, events
ignored by git, the runner refusing without a policy, the installed hook recording a session,
both stub suites, the Condition rule naming every value the hook can ask about. Then a real
chain in a scratch project installed from the branch. README, CONOPS (proposed wording),
`CHANGELOG.md`, `project.md`, the skills README, the adapter's INSTALL page, this session's
memory file.
