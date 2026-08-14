# Plan: Skill-driven update

**Design:** `.waypoint/design/2026-08-14-skill-driven-update.md` (approved)
**Status:** Executed 2026-08-14. All five tasks plus closeout shipped to the working tree
on branch `v2`.

A property worth noting up front: nothing here touches the OPORD baseline or the memory
README, so consumers receive the entire feature mechanically (installer plus refreshed core
skills). No manual merge anywhere. The dogfooding invariant is untouched but stays guarded
by the drift test.

---

## T1 — `origin:` in VERSION

**Goal:** Record where a project's Waypoint came from.

**Changes:** `waypoint` — `write_revision` adds `origin: <url>` when the checkout has an
origin remote (`git remote get-url origin`); the line is omitted otherwise.

**Acceptance:**
- Fresh install writes VERSION with `revision:`, `origin:`, and `updated:`.
- test.sh asserts the origin line matches the checkout's actual remote.
- `bash -n waypoint` clean; suite green.

**Dependencies:** none. First.

---

## T2 — Install is the refresh mechanism

**Goal:** Re-running install brings framework-owned files current, so an update reduces to
"reinstall, plus judgment."

**Changes:** `waypoint`
- Core skills copy wholesale on install (drop skip-if-exists for `CORE_SKILLS`).
  User-authored skills are outside the list and untouched.
- Fold `migrate` into `install_core`: the legacy `memory.md` move and the legacy CLAUDE.md
  block relocation run on every install (both idempotent; the conops-template lifecycle and
  memory README refresh already do).
- Pristine OPORD fast-forward: when VERSION names a revision present in the checkout and the
  project's `opord.md` is byte-identical to `git show <rev>:templates/opord.md`, replace it
  with the new baseline and say so. Otherwise leave it and print one line pointing at the
  `update-waypoint` skill for the merge.

**Acceptance:**
- Reinstall refreshes an edited core skill; preserves a user skill, an extended OPORD,
  `project.md`, and a written CONOPS.
- A pristine OPORD is fast-forwarded when the stamped baseline differs from the current one
  (test uses a real older commit of `templates/opord.md` from this repo's history); an
  extended OPORD is left alone with the pointer printed.
- A legacy `memory.md` is migrated by plain install.
- A stamped revision that is absent from the checkout skips the fast-forward without error.

**Dependencies:** T1 (the fast-forward reads VERSION).

---

## T3 — Stubs and dead code

**Goal:** Retire `update`, `update-skills`, and `migrate` as behavior; keep the names as
signposts.

**Changes:**
- `waypoint`: the three commands print what replaced them (the skill; for `migrate`,
  install itself) and exit non-zero. Remove `update()`, `report_changes`, `opord_notice`,
  and the standalone-pull wiring. `pull_source` stays (install pulls), including the
  once-per-run guard. Usage text updated.
- `test.sh`: rework update-based cases onto reinstall; add stub cases (non-zero exit,
  guidance names the replacement).
- `README.md`: "Staying current" rewritten around the skill.

**Acceptance:** stubs exit non-zero and name their replacement; no dead functions remain;
suite green with the reshaped cases.

**Dependencies:** T2.

---

## T4 — The `update-waypoint` skill

**Goal:** The update procedure itself, shipped as a core skill so it refreshes itself.

**Changes:**
- New `skills/update-waypoint.md`, added to `CORE_SKILLS`, following the standard skill
  format. Procedure per design §2b: read VERSION first and hold `revision:` (merge base) and
  `origin:`; locate or full-clone the source; detect the adapter from the installed rule
  file; run the matching install command; summarize
  `git log <old>..<new> -- skills templates adapters` for the developer, calling out
  anything needing action; if `templates/opord.md` changed and install left the project's
  OPORD alone, perform the three-way merge and present it as a single reviewed edit, never
  auto-applied; confirm the re-stamp. Covers the no-VERSION fallback (ask for the source;
  the reinstall stamps origin going forward) and the carve-out (never target the Waypoint
  checkout itself).
- `test.sh`: the skill installs fresh and refreshes on reinstall.

**Acceptance:** skill present in a fresh install, refreshed like other core skills, listed
in the README's skills table.

**Dependencies:** T1. Sequenced after T3 so the skill describes the final CLI truthfully.

---

## T5 — Shipped docs

**Goal:** README and CHANGELOG match the new reality.

**Changes:**
- `README.md`: install section no longer requires a permanent checkout (updates can clone
  origin on demand); staying-current section final wording; skills table gains
  `update-waypoint`.
- `CHANGELOG.md`: dated entry in the human-facing style; notes that the update commands are
  now stubs and that no manual merge is required for this change.

**Acceptance:** docs agree with behavior and restate nothing owned elsewhere.

**Dependencies:** T1–T4.

---

## Closeout (after T1–T5)

- **Verify:** `./test.sh` green; `bash -n waypoint` clean; a read-through of the skill for
  followability.
- **`project.md`:** phase and shipped list updated; ground-truth index checked.
- **Memory:** dated entry summarizing what shipped and the decisions.
- **Design doc:** status flipped to Executed, deviations noted.
- **This plan:** status flipped to Executed.

---

## Sequence

T1 → T2 → T3 → T4 → T5 → Closeout. Each task is independently verifiable; T1+T2 are the
riskiest pair (install semantics) and land first, guarded by the existing suite.
