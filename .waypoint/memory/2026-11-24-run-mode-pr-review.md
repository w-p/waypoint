Reviewed pull request 4 (`v2-run-mode`: run mode, session events, session condition) for gaps; the suite passes, and eight faults in the runner were confirmed with stub sessions, none fixed yet.

- **2026-11-24:** Read the whole diff and ran `./test.sh` on a copy of the branch: 173 passed,
  0 failed. Then ran the branch's `run_chain.sh` against stub sessions in a throwaway
  repository. Confirmed, each with a control where one applies:
  - A reply with a line starting `DONE` above a last line that is not a status is read as
    DONE. The parser walks up from the bottom instead of judging the last line only.
  - A unit can edit and commit `.waypoint/automation.md`; the runner reads the policy fresh
    before each unit and does not notice. A unit raised `sessions_per_day` from 1 to 99 and
    the chain went on. The same holds for the runbook and `.claude/`.
  - A `tz` value that does not name a zone turns the quiet window off: the window script's
    crash exits 1, which the runner reads as "outside the window".
  - No check that the tree is clean before the first unit; a file the developer left
    modified is blamed on unit 1 after a session is spent.
  - Untracked files a unit leaves behind pass the "no tracked file modified" check.
  - A second chain on the same day passes the memory-entry check on the first chain's entry.
  - A job whose recorded exit code is non-zero still starts the next unit.
  - A unit id that is not in the runbook starts a session.
  - Not a fault: a policy block that stops parsing mid-run stops the chain at the next cap
    check (an empty cap reads as 0), though the message is confusing.
- Read from the code, not reproduced: the default run folder name is computed twice (before
  and after the runner re-executes its copy), so a launch across a second boundary leaves a
  stray folder; no signal trap, so a killed runner leaves no `done` file and sends no
  notification; reinstall without `jq` reports the hooks as wired and does not add the
  events hook; the events hook has no off switch and the merge re-adds its entries; the
  condition thresholds live in a framework-owned file that reinstall overwrites; the
  Condition rule does not say what a unit does when told to hand over; `stop_on_ci_issue`
  treats every open issue as a CI failure; the contract forbids command lines in events but
  `wait_for` and the environment-check detail carry them, and the GitHub notification posts
  the log tail to an issue.
- Reported to the developer in conversation. Nothing was posted to the pull request.
- **2026-11-24, later:** The developer agreed a unit has no reason to change the policy or
  the runbook, so the first fault is fixed on `v2-run-mode`, uncommitted. `run_chain.sh`
  gained `governing` and `governing_changes`: it hashes the policy, the runbook,
  `.claude/settings.json`, `.claude/settings.local.json` and everything under
  `.claude/hooks`, `.claude/rules` and `.claude/runner` before each unit, and finishes with
  HALT naming the files if any differ afterwards. By content, not by git, because the local
  settings file is usually ignored. The developer can still change them while the chain
  waits. The rest of `.claude/` is not watched (the host tool may write there; not
  measured), nor are the account-wide settings outside the repository.
  - Eight new stub checks, 79 in all: four halts, two "unit 2 never started", and two
    controls (a unit changing only its own work; a policy edit during a job wait taking
    effect). The six non-control checks fail against the runner as it was. The stub
    `claude` gained an `sh <command>` line. `./test.sh`: 173 passed, 0 failed.
  - Documented in the `run` skill (launching and watching), the `run-setup` skill (hard
    stops, a new drill), the changelog entry of 2026-11-23 and the design as decision 10.
- **2026-11-24, later still:** Three more of the confirmed faults fixed in `run_chain.sh`,
  at the developer's direction, and pushed with the first as one commit.
  - Status: only the reply's last line is read, and `DONE` must stand alone on it (bold and
    a full stop are allowed). Anything else is `NO_STATUS` and stops the chain. The unit's
    prompt now says so. This is stricter than the pilot's runner: a unit that ends on
    "DONE, all checks pass" stops the chain.
  - Quiet windows: `in_quiet_window` prints a reason and exits 2 for anything it cannot
    read (an unknown `tz`, a `quiet` entry that does not parse or has an hour past 23, an
    unreadable block, any crash), and the new `quiet` wrapper ends the chain with NOPOLICY.
    Checked at start and at every later use, so a policy made unreadable during a wait
    stops the chain too. `tz` is checked even when no window is set.
  - Memory entry: the new `entries` helper counts a unit's headings across the run's memory
    files before and after the unit; the count must rise.
  - The stub suite is 92 checks; the 16 that cover the four fixes fail against the runner
    as first committed (one of them only because its message changed). `./test.sh`: 173
    passed, 0 failed. The stub `claude` gained an `after <line>` line.
  - Recorded in the design as decision 11, the `run` and `run-setup` skills and the
    changelog.
  - Still open from the review: no clean-tree check before the first unit; untracked files
    pass; a job's non-zero exit is ignored; unit ids are not checked against the runbook;
    and everything in the "read from the code" list above.
