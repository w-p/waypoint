# Changelog

Notable changes to Waypoint, newest first. Dated rather than versioned — there is no
release process yet.

Running `waypoint update` refreshes core skills and your editor's adapter. It never
rewrites `.waypoint/opord.md` or a written `.waypoint/conops.md`; where an entry below
affects those, merging is manual.

---

## 2026-08-14

- **Leaner session boot.** The OPORD's start-of-session read (§3a) no longer loads every
  document each session. It reads the binding documents — `conops.md`, `project.md`, and the
  most-recent `memory/` file — plus a cheap listing of `memory/`, `design/`, and `plan/` as an
  index, and pulls design docs, plans, and older memory on demand. Growth in those folders no
  longer lands in the mandatory boot. *Manual merge — §3a/§3d live in your OPORD.*
- **Filenames are the memory index.** The memory convention now asks you to name each session
  file for its subject and lead it with a one-line summary, so `ls` and `head -1` act as a
  two-tier index. Adds a safe procedure for upgrading a weak name and a policy for archiving old
  sessions instead of keeping everything verbatim forever.
- **Single-sourcing.** New OPORD duty: define a fact once and reference it elsewhere. The CONOPS
  now points at the OPORD for phase definitions and ongoing duties instead of restating them.
  *Manual merge if you extended OPORD §3d.*
- **The changelog has a defined audience.** New OPORD duty wording: `CHANGELOG.md` is the
  human-facing record, written in plain release-notes style for a person scanning what changed
  between updates; the framework's own record is `project.md` and `memory/`. *Manual merge —
  §3d.*
- **Feature docs are as-built records.** The §3d duty now says a feature doc describes the
  capability as it exists today and stays current; the design that produced it stays frozen as
  the decision record. Also new in the tone duty: use em dashes sparingly. *Manual merge — §3d.*
- **Updating is now a skill.** `waypoint update` and `update-skills` are stubs pointing at
  the new `update-waypoint` core skill, and `migrate` is folded into install. The skill
  finds your Waypoint source (`.waypoint/VERSION` now records the `origin:` repo alongside
  the commit), reinstalls the framework files, summarizes what changed, and merges OPORD
  baseline changes with you reviewing the diff. Reinstalling refreshes core skills
  wholesale and heals legacy layouts directly, and an OPORD you never extended is
  fast-forwarded to the new baseline automatically, so the manual merges flagged above
  apply only if you extended yours.
- Added a test asserting the dogfooded `.waypoint/` stays byte-identical to the shipped
  templates, so editing one copy can't silently drift from the other.

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
