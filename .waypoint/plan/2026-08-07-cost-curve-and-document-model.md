# Plan: Bending Waypoint's cost curve

**Design:** `.waypoint/design/2026-08-07-cost-curve-and-document-model.md` (approved)
**Status:** Executed 2026-08-14. Post-execution operator review revised the boot composition —
see the design's §9 revision note.

Turns the design's §8 sequence into discrete tasks. One refinement over §8: **all OPORD
baseline edits are consolidated into a single pass (T2)** rather than split across two items,
because OPORD is project-owned and every consumer manual-merges baseline changes — one clean
bump is far kinder than two. And the **drift test goes first (T1)**, so it guards the OPORD
and memory-README edits that follow instead of being added after them.

The dogfooding invariant governs everything: `templates/opord.md` ≡ `.waypoint/opord.md` and
`templates/memory.md` ≡ `.waypoint/memory/README.md`. Every edit to one of a pair edits both,
identically. T1 makes a slip fail loudly.

---

## T1 — Drift test (guard first)

**Goal:** Turn "edited one copy of a paired file" into a loud test failure before we start
editing those pairs.

**Changes:** `test.sh` — add assertions that `templates/opord.md` is byte-identical to
`.waypoint/opord.md`, and `templates/memory.md` to `.waypoint/memory/README.md`.

**Acceptance:**
- `./test.sh` runs the two new assertions and passes against the current tree (the pairs are
  already identical today).
- Deliberately diverging one pair makes `./test.sh` fail with a clear message naming the pair.
- Assertion count in the suite reflects the additions.

**Dependencies:** none. First.

---

## T2 — OPORD baseline revision (one pass, both copies)

**Goal:** Replace the additive-read boot model with the graduated map-based read, and add the
duties the rest of the plan points at — in a single baseline change.

**Changes:** `templates/opord.md` and `.waypoint/opord.md` (identical edits):
- **§1 SITUATION** — reframe the context-file list from "read those relevant to the phase"
  to "these exist; the boot reads the state and a map of the rest, then pulls on demand."
- **§3a Pre-Action Checklist** — rewrite to the graduated read: mandatory = `project.md` +
  `ls` of `memory/`/`design/`/`plan/` + the single most-recent `memory/` file; on demand =
  `head -1` an ambiguous memory file, open the specific design/plan/older-memory the task
  needs, read `conops.md` when intent/scope is in question. Phrase the mandatory reads as one
  batch. Keep the "re-read these instructions" step.
- **§3d Ongoing Duties** — (a) elevate keeping `project.md` current to a load-bearing duty,
  since the boot now leans on it; (b) add the memory-naming duty (name files for their
  subject; offer to upgrade weak names — detail in the memory README); (c) add the
  single-sourcing duty (define each fact where it is owned; reference, don't restate).

**Acceptance:**
- §3a describes the graduated read; mandatory floor is exactly project.md + map + latest
  memory; everything else is on-demand; mandatory reads are phrased as a batch.
- §3d contains the three duties above, each short and pointing at detail where detail lives.
- `templates/opord.md` and `.waypoint/opord.md` are byte-identical → T1 passes.
- Adapters are unchanged and still valid — both `adapters/claude/rules/waypoint.md` and
  `adapters/cursor/rules/session-briefing.mdc` say "read `opord.md`, follow §3a," so the new
  §3a propagates with no adapter edit. Confirm by reading them, no change expected.
- `bash -n waypoint` and `./test.sh` still clean.

**Dependencies:** T1 (so the pair-identity is guarded during this edit).

---

## T3 — Memory README revision (both copies)

**Goal:** Give the map good names to read, a safe way to upgrade weak ones, and a cap on
growth — all in the doc `update` refreshes wholesale, so consumers get it without an OPORD
merge.

**Changes:** `templates/memory.md` and `.waypoint/memory/README.md` (identical edits):
- **Naming guidance** — name for the subject not the activity; 3–6 words / ~50–60 chars
  (an order of magnitude under any filesystem limit, so informative and safe never conflict);
  lead each file with a standalone one-line summary (the second index tier).
- **The two-tier index** — explain that `ls` is the map and `head -1` is the next tier, so a
  terse filename is backed by a strong first line.
- **Upgrade procedure** — strengthen the first-line summary as the safe default; rename only
  for *misleading* names, as a confirmed `git mv` mini-refactor: propose → grep for the old
  basename → `git mv` → fix every reference → verify; slug only, never the date prefix.
- **Compaction policy** — replace "do not delete old files" with a rolling policy: recent
  sessions verbatim, older ones folded into `memory/archive.md` (lossy is fine — git keeps
  originals); the most-recent file always verbatim; the `ls` map still lists everything.

**Acceptance:**
- README covers naming, the two-tier index, the upgrade procedure, and compaction.
- "Do not delete old files" is gone, replaced by the rolling policy.
- `templates/memory.md` ≡ `.waypoint/memory/README.md` → T1 passes.
- Still plain, readable Markdown; no tooling implied to consume it.

**Dependencies:** T2 (so the OPORD duties that point here have a resolved target).

---

## T4 — Single-source our own CONOPS

**Goal:** Make our dogfooded docs model the single-sourcing duty we just added, and remove a
live drift surface.

**Changes:** `.waypoint/conops.md` (project-owned; no template pair):
- **§5b** (phase definitions) → point at OPORD §3b instead of restating the three phases.
- **§5d** (ongoing duties) → point at OPORD §3d instead of restating (it already admits it is
  "repeated here for visibility").
- **§4** (directory structure) → keep the one authoritative statement; if it duplicates the
  README's layout block, point rather than restate.

**Acceptance:**
- §5b/§5d/§4 reference their owning document; no information is lost (every pointer resolves
  to the same or fuller content).
- CONOPS still reads coherently top to bottom.

**Dependencies:** T2 (the OPORD sections being pointed at are in their final form).

---

## T5 — Consumer usage guidance (README)

**Goal:** Turn the usage hygiene that isn't expressible in `.waypoint/` into shipped guidance.

**Changes:** `README.md` — a short "Using Waypoint well" section: start a fresh chat per task;
keep `project.md` current; disable MCP servers you are not using; the boot is cheap by design,
keep it that way.

**Acceptance:** the section exists, is brief, and does not restate content owned elsewhere
(links to it instead).

**Dependencies:** none (independent; sequenced last as the lightest).

---

## Closeout (after T1–T5)

Not code, but part of the definition of done:
- **Verify:** `./test.sh` green (incl. the new drift assertions); `bash -n waypoint` clean; a
  manual boot-sanity read-through of the new §3a to confirm it is followable and unambiguous.
- **`CHANGELOG.md`:** dated entry; mark the OPORD §3a/§3d change as **manual-merge** for
  existing consumers (consistent with prior entries).
- **`project.md`:** move these items to Shipped; set phase back to Execution (v1 maintenance)
  or as appropriate; update the ground-truth index.
- **Memory:** dated entry in this session's `memory/` file summarizing what shipped and the
  key design decisions (the corrected cost model, map-not-taxonomy, the naming/upgrade
  convention), for a future reader who has lost this context.
- **Design doc:** flip its status to executed, linking the feature/record.

---

## Sequence

T1 → T2 → T3 → T4 → T5 → Closeout. T4 depends on T2; T3 depends on T2; T5 is independent.
T1 and T2 are the highest-value, lowest-risk pair (the curve-bender plus its guard) and could
ship and be measured before T3–T5 if we want a checkpoint.

Each shipped artifact change is shown as a diff before it lands. No implementation begins
until this plan is approved.
