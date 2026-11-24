Brought run mode (planned work as a chain of fresh sessions), the session-events contract and the session condition record into Waypoint from the downstream project that piloted them, on branch `v2-run-mode` for a pull request against `v2`.

- **2026-11-23, 09:21 PM EST:** The developer asked for the pilot's capability as a pull request against
  `v2` unless there were major issues. None were found. Design
  `.waypoint/design/2026-11-23-run-mode-and-session-events.md`, plan of the same name. Built:
  - `contracts/session-events.md`: event format version 1, kept in this repository and not
    installed into projects.
  - `skills/run-setup.md` and `skills/run.md`; both in the installer's core list.
  - OPORD (template and dogfooded copy): a line in §1 for `automation.md`, a **Run mode**
    paragraph in §3c, the **Condition** standing rule. Nothing else.
  - Claude Code adapter: `hooks/waypoint-events.sh` and `waypoint_events.py`, wired at seven
    points in `hooks-settings.json`; `runner/run_chain.sh` and `run-notify.yml`;
    `tests/test_run_chain.sh` and `tests/test_condition.py`.
  - Installer: copies the Python writer with the hook scripts, installs the runner, creates
    `.waypoint/events/.gitignore`, and says so when `python3` is missing.
  - What the pilot's runner hard-coded became optional policy keys (design §4). The weekly and
    daily quiet-window parser is new code.
- **Checked:** the runner's stub suite, 71 checks, every stop with its control, 20 of them new
  for the policy keys. The condition suite, 55 checks. One real chain in a scratch project
  installed from the branch: two units as real scripted sessions, both DONE in about a minute,
  the notify command fired, a state-check pattern set in the settings file's `env` reached
  the hook, and git saw no event files.
- **Found in that chain and fixed:** the second unit's first condition record read drift
  `aging` with one outside commit. The runner had committed the first unit's ledger line in
  the same second the second unit started, and the count included commits made at the start
  second. It now counts strictly after; a check pins it, and fails on the old rule.
- **Not done here:** no run of a full batch under this runner (the pilot project does that
  next, on its own copy, and moves to this one afterward); nothing on macOS; no Cursor writer.
- **For the developer:** the CONOPS edits in this branch (§4, §5c, §6) are proposed wording.
  Run mode and the events record cross two of §6's out-of-scope lines, narrowly; the wording
  says how narrowly.
