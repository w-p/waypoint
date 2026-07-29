# Changelog

Notable changes to Waypoint, newest first. Dated rather than versioned — there is no
release process yet.

Running `waypoint update` refreshes core skills and your editor's adapter. It never
rewrites `.waypoint/opord.md` or a written `.waypoint/conops.md`; where an entry below
affects those, merging is manual.

---

## 2026-07-28

- **`install` and `update` now pull the Waypoint checkout first.** Previously an
  out-of-date checkout installed out-of-date content while reporting success. A checkout
  with local edits, on a detached HEAD, without an upstream, or offline is left alone and
  reported rather than treated as an error. `WAYPOINT_NO_PULL=1` skips the pull.
- **`.waypoint/VERSION` records the source commit** a project was installed from. `update`
  uses it to list the framework changes you're crossing, and flags when the OPORD baseline
  is among them.
- Added `test.sh`, covering what `update` guarantees it will not touch — your OPORD, your
  own skills, a written CONOPS — plus the migration paths.
- The `new-project` skill no longer refers to template paths that are absent from an
  installed project. It now directs you to fill in the `opord.md` and `project.md` the
  installer already placed.
- `conops-template.md` is treated as scaffolding: refreshed on `update` while no CONOPS
  exists, and removed once `conops.md` is written. A written CONOPS is never modified.
- Reinstalling over a project that already has a CONOPS no longer tells you to go write
  one.
- README rewritten — install instructions first, corrected clone paths.
- Documentation corrections to adapter locations and project state.

## 2026-07-19

- OPORD tone guidance rewritten to cut inflated and promotional language.

## 2026-07-15

- `install` now requires an explicit editor choice. Both editors can be present on one
  machine, and guessing installed the wrong adapter.
- Makefile removed. Install and update logic moved to a single `waypoint` shell script.
- README and installation docs cleaned up.

## 2026-07-10

- **Memory is now a folder.** `.waypoint/memory.md` becomes `.waypoint/memory/`, one file
  per session named `YYYY-MM-DD-<slug>.md`, so parallel sessions and branches stop
  colliding in merges. `update` migrates an existing `memory.md` to a dated file in the
  new folder.
- **The Claude adapter is a standalone rule file** at `.claude/rules/waypoint.md`,
  mirroring the Cursor adapter. Waypoint no longer writes to your `CLAUDE.md`. An older
  install that embedded the briefing there is migrated, and the stale block is reported
  for you to remove.
- **OPORD rules of engagement revised** to defer to the host tool's permission model.
  Earlier wording imposed a second approval gate on top of the editor's own, causing
  repeated prompts for actions already permitted. *Manual merge if you extended §3c or §5.*
- Session start no longer forces a fixed `"Ready."` reply. With no request the agent
  answers `Ready.`; opening with a question gets an answer instead of a greeting.
- `update` reports OPORD drift against the shipped baseline rather than overwriting your
  copy.

## 2026-06-26

- Fixed install on Windows.

## 2026-06-09

- Initial release: `.waypoint/` structure, OPORD and CONOPS templates, the three-phase
  workflow, six core skills, and adapters for Claude Code and Cursor.
