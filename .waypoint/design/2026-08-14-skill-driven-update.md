# Design: Skill-driven update

**Status:** Executed 2026-08-14 — shipped via the plan at
`.waypoint/plan/2026-08-14-skill-driven-update.md`, then revised the same day after a
field report (§6): `update` returned as a real command. One deviation: `pull_source`'s
once-per-run guard was removed rather than kept, since install is now its only caller.
Session record: `.waypoint/memory/2026-08-14-boot-cost-and-memory-optimization.md`.
**Scope:** The update path (CLI and skill), VERSION provenance, and the standing-checkout
requirement.

---

## 1. Problem

Two findings from testing the v2 boot changes on real projects:

- **`update` leaves the OPORD stale by design.** The ownership rule is right (never rewrite
  a file the developer may have extended) but the outcome is wrong: the OPORD is where
  behavior lives, so the one file updates exist to improve is the one file updates never
  improve. Manual merge was the documented answer, and in practice it did not happen. A
  before/after test ran old boot against old boot without the operator noticing.
- **Nothing records where a project's Waypoint came from.** VERSION stamps `revision:` but
  not the repo, so a future session or another machine cannot find the source to update from.

A shell script cannot fix the first problem, because merging prose takes judgment. The
assistant can, and the assistant is always present, because Waypoint requires one.

---

## 2. Design

**The script installs. The skill updates.**

- The `waypoint` script keeps only what must be deterministic and must work before any skill
  exists: laying files down. Re-running install brings framework-owned files current and
  never touches project-owned ones.
- Updating becomes a core skill (`update-waypoint`), because an update is a procedure with
  judgment in the middle: find the source, run the installer, explain what changed, merge
  the OPORD with the developer reviewing diffs.

**VERSION gains `origin:`**, the checkout's remote URL, recorded at install time.
`revision:` plus `origin:` are the whole story: the hash says what you have, origin says
where newer content lives. No `source:` path (machine-specific, churns in a committed file)
and no `previous:` (the skill captures `revision:` before reinstalling).

### 2a. Script changes

- `install-core` / `install-claude` / `install-cursor` remain, with one semantic change:
  core skills are refreshed wholesale on reinstall, where today install skips ones that
  exist. They are framework-owned, same as the adapter and the memory README, and reinstall
  is now the update mechanism. Ownership is otherwise unchanged: `opord.md`, `project.md`,
  a written `conops.md`, and user-authored skills are never touched.
- `migrate` folds into install; it is idempotent and cheap.
- `update` and `update-skills` are removed as behavior. The command names remain as stubs
  that point at the skill, since the README has been telling people to run them.
- `write_revision` records `origin:` when the checkout has one; a checkout with no remote
  simply omits the line.

### 2b. The skill

Shipped as a core skill, so every update refreshes the update procedure itself. Procedure:

1. Read `.waypoint/VERSION`; hold `revision:` (the merge base) and `origin:`.
2. Locate a checkout: one the developer points at, or clone `origin:` to a temporary
   location. Full clone, not shallow; the merge base and the change report need history.
3. Detect the adapter from the installed rule file and run the matching install command
   against the project. This is the whole mechanical update.
4. Report what changed: `git log <old>..<new> -- skills templates adapters`, summarized for
   the developer, calling out anything that needs action.
5. If `templates/opord.md` changed in that range: three-way merge. Old baseline via
   `git show <old>:templates/opord.md`, new baseline from the checkout, project OPORD as
   the working copy. Preserve the project's extensions, present the result as a normal file
   edit, and let the developer review the diff. Never auto-applied, regardless of session
   permissions: the assistant is editing its own standing orders.
6. Confirm VERSION was re-stamped with the new revision and origin.

### 2c. Consequences

- **The standing checkout becomes optional.** With origin recorded, the skill can clone on
  demand and discard. The README's "clone somewhere permanent" requirement retires.
- The mechanical bulk of an update stays deterministic (one installer run); the assistant
  adds discovery, narration, and the merge. Token cost per update is bounded, and updates
  are infrequent.
- Waypoint's own repo remains the carve-out: templates here are maintained by hand, and the
  installer refuses to target its own checkout.

---

## 3. Risks

- Skill-driven update varies with the model. Mitigated by the procedure's core being one
  deterministic installer run.
- Reinstall-refreshes-skills is a behavior change to install. Someone who hand-edited a
  core skill loses the edit on reinstall. This is already true of `update` today; the rule
  moves, it does not grow.
- An interrupted merge could leave a half-edited OPORD. The skill writes the merge as a
  single approved edit, not incremental ones.

---

## 4. Migration for existing consumers

- Existing installs lack `origin:`. The first skill-driven update asks where the source is,
  and the reinstall stamps origin going forward. One update heals it.
- Old checkouts still expose `update`; the stub says what replaced it.

---

## 5. Open questions — resolved 2026-08-14

1. Stubs exit non-zero, with guidance naming the replacement.
2. Yes: install fast-forwards a provably pristine OPORD (byte-identical to the baseline
   `revision:` points at). The skill covers assisted flows; this covers script-only runs.
3. `update-waypoint`, verb-first like the other core skills.

---

## 6. Revision — 2026-08-14 field report

Stubbing `update` had a bootstrap hole that §4 papered over: a project installed before
this change has no `update-waypoint` skill, and the stub pointed at exactly that missing
file. `update` is therefore back as a real command — the adapter-detected reinstall, the
mechanical half of the skill's procedure — ending with a pointer at the skill, which by
then exists because the reinstall just installed it. It also keeps every old README's
instructions working. `update-skills` and `migrate` remain stubs; `update-skills` points
at `update`.

---

## 7. Sequencing (proposed, pending approval)

1. `origin:` in VERSION. Tiny and independent.
2. Install semantics: refresh core skills, fold in migrate, add stubs, retire dead code
   (`report_changes`, `opord_notice` move conceptually into the skill).
3. The `update-waypoint` skill.
4. README, CHANGELOG, and test.sh reshaped to match (ownership tests now run against
   reinstall).
