# Design: Bending Waypoint's cost curve

**Status:** Executed 2026-08-14 — shipped to the working tree via the plan at
`.waypoint/plan/2026-08-07-cost-curve-and-document-model.md`, then revised the same day
after operator review (§9). Session record:
`.waypoint/memory/2026-08-14-boot-cost-and-memory-optimization.md`.
**Scope:** The framework's session-boot convention, the memory read/naming convention,
document single-sourcing, and the guardrails around them. Everything here ships to
downstream consumers; we inherit it too, because we dogfood.

---

## 1. Problem

A downstream project using Waypoint reported a ~26k-token boot floor that grows with the
project, the same command surface written out four times, and a memory file already the
largest thing in the boot after one session. Our own repo is the young version of the same
thing (~9.7k boot, empty `design/`/`plan/`). Those numbers are our trajectory, not a
different project's problem — Waypoint produces them.

Two properties compound:

- **Additive documents.** The phase gate produces a new document at every transition
  (CONOPS → design → plan → features). Nothing supersedes or consolidates, and each
  re-describes the same system at a different altitude, so a fact legitimately appears in
  several places. That is the duplication.
- **Additive reads.** OPORD §3a says read everything relevant to the phase, every session.
  Boot cost = the running sum of everything ever produced. Monotonic in project age.

### The cost model, corrected

The "26k floor" implies boot tokens are paid every turn. With prompt caching they mostly
are not: cached prefix tokens read at ~0.1x, and the boot docs sit at the front of context,
read first and never edited — the warmest part of the cache. After turn 1, a big boot is
cheap *per turn*. The one-time cost is the cache write.

So the boot's real harm is not dollars-per-turn. It is:

1. **Context budget.** A big front-load is that much less working room before the window
   fills and the harness compacts — and **compaction is where fidelity dies** (early
   context, including decisions, gets summarized away). A smaller boot delays compaction.
2. **Fresh-session re-pay.** Each new chat is a cache-cold write of the whole boot. True
   cost ≈ boot size × session count, so boot size bites hardest on the "start a fresh chat
   per task" pattern that is otherwise good hygiene.

This is the key reframe: **shrinking the boot and preserving fidelity are the same goal, not
a tradeoff.** Smaller boot → more working room → later/rarer compaction → less fidelity loss.

Honest ceiling: the dominant token cost in an execution-heavy session is the accumulating
tool-result volume (file reads, command output, diffs), which Waypoint does not control. We
optimize the boot because it is the part Waypoint owns and because it is coupled to fidelity
— not because it is the whole bill.

### Duplication drives PR churn

Our git history is mostly doc-sync and tone churn. One recent session fixed six drift bugs,
five of them "document X disagrees with document Y." Every duplicated surface is a scheduled
future drift-fix PR. Duplication and churn are the same problem.

---

## 2. Design principle

Everything Waypoint stores is one of two kinds:

- **Binding state** — decisions, constraints, current phase, next action, scope. Few,
  slow-changing, small. Contradicting these is the fidelity failure.
- **Narrative** — what happened, session by session. Most of the token volume, rarely
  needed to *act* correctly; needed for audit, history, and human onboarding.

The token problem in one line: **the mandatory boot reads narrative-sized files to recover
decision-sized information.**

The fix is not a smarter classification of narrative. It is a **cheap, complete, mechanical
map** over which the agent decides what to actually open. Waypoint already has the map: the
`YYYY-MM-DD-<slug>.md` filename convention means `ls memory/` is a complete, dated,
human-labeled index of the entire history for almost no tokens. The only bug is that OPORD
§3a says *read the files* instead of *read the list, then open what the task needs.*

Principle: **route, don't hold.** The mandatory boot carries the binding state plus a
mechanical map. Everything narrative sits behind the map, pulled on demand. The map is
complete (nothing is invisible → discoverability fidelity preserved) and cheap (the token
win). No taxonomy, no per-file metadata, no curated "current focus" field — nothing for a
consumer to learn beyond a naming convention that already exists.

---

## 3. Proposed changes

### 3a. Rework the boot sequence (OPORD §3a template) — the load-bearing change

The graduated, cheapest-first read:

**Mandatory, every session (one batch):**
- `project.md` — current phase, active work, next action, ground-truth index (the binding
  state).
- `ls` of `memory/`, `design/`, `plan/` — the mechanical map. Filenames are the index.
- The single most-recent `memory/` file — "where did I leave off." One small file; this is
  the compaction-recovery read, and on a fresh start it is exactly the right one (chrono-
  latest *is* "most recent work" by definition).

**On demand, guided by the map:**
- `head -1` an ambiguous memory file to read its one-line summary before deciding to open it.
- Open the specific `design/`, `plan/`, or older `memory/` files the task or the map points
  at — not the whole folders.
- `conops.md` — when you need intent, scope, or a boundary decision (onboarding, scoping a
  feature). Not a per-session read.

Effect: mandatory floor ~9.7k → ~2–3k (project.md + map + one memory file), and it stops
climbing with project age because the rest is behind the map. Adapters need no change — they
already say "read `opord.md`, follow §3a."

**Fidelity guards:** the most-recent memory file stays mandatory (compaction recovery);
`project.md`'s ground-truth index becomes load-bearing, so its currency is a duty, not a
nicety; `onboarding`/`resume` still do fuller reads for their purposes.

### 3b. Make the filename a good index (OPORD duty + memory README)

The map is only as good as the names, so:

- **Name for the subject, not the activity.** `installer-permission-fix`, not `fixes`;
  `removed-makefile`, not `cleanup`. Prefer the noun (the thing worked on) over a vague verb.
- **3–6 words, ~50–60 chars.** That is an order of magnitude under every filesystem limit
  (255 bytes/component; Windows' 260-char full-path only bites in deep trees, which
  `.waypoint/memory/` is not), so "informative" and "safe" never conflict.
- **Lead the file with a standalone one-line summary** — the second index tier that `head -1`
  reads. A strong first line makes a terse filename cheap to recover from.

### 3c. Upgrade weak names in place — safely (memory README procedure)

When boot surfaces an uninformative name, the agent may offer to improve the index. Two
levers, safe one first:

1. **Strengthen the first-line summary** — breaks no references, costs nothing. The default.
2. **Rename** — the escalation, only for *misleading* names, and only as a confirmed
   mini-refactor:
   - It touches a file the agent did not create → OPORD §3c already requires confirming
     first. Never silent, never a boot side-effect.
   - Procedure: propose → `grep` the repo for the old basename → `git mv` (preserve history)
     → fix every reference (`project.md`, other memory, design docs, `CHANGELOG.md`) → verify.
   - **Slug only; never change the `YYYY-MM-DD` prefix** — it is the stable sort key and the
     thing most often referenced.

### 3d. Cap memory growth (memory README convention)

The current "do not delete old files" rule is the downstream memory bloat. Replace with a
rolling policy: recent sessions verbatim; older ones fold into a `memory/archive.md` digest
(lossy is fine — git holds the originals). The map (`ls`) still lists everything; the archive
just moves narrative out of the default on-demand surface. The most-recent file is always
verbatim.

### 3e. Teach single-sourcing (OPORD baseline) + fix our own docs

Add to the OPORD's Documents duty: *define each fact in the document that owns it and
reference it elsewhere; do not restate. When you catch yourself copying a block between
documents, replace the copy with a pointer.* Then make our dogfooded docs obey it — CONOPS
§5b/§5d/§4 point at OPORD and the README instead of restating phases, duties, and the
directory structure. Consumers copy what we model.

### 3f. Ship a drift test (test.sh)

Turn "someone edited one copy" into a loud CI failure:
- `diff templates/opord.md .waypoint/opord.md` — the dogfooding invariant.
- `diff templates/memory.md .waypoint/memory/README.md`.

This is what makes "change the template, feel it via dogfooding, then ship" honest.

### 3g. Document consumer usage hygiene (README)

A short "Using Waypoint well" note: start a fresh chat per task; keep `project.md` current;
disable MCP servers you are not using (per-request tool-definition overhead); the boot is
cheap by design — keep it that way. Outside `.waypoint/`, but squarely how consumers get
value.

---

## 4. On batching (raised in review)

Parallel reads reduce round-trips and latency; they do **not** reduce token usage — the same
content lands in context either way. Worth doing for the mandatory boot (the file set is
known up front), zero fidelity cost, but it is a latency win, not the cost-floor lever. §3a
phrases the mandatory reads as one batch; we do not file batching under "token savings."

---

## 5. Risks and tradeoffs

- **On-demand pulls can be skipped.** The agent might not open something it should. Mitigation:
  the map is complete and visible (the choice is auditable), the most-recent memory stays
  mandatory, and onboarding/resume cover the fuller-read cases.
- **`project.md` becomes a single point of failure.** A stale index blinds the boot. No
  automated check for semantic staleness — only the elevated duty and review.
- **Renames break references** if done carelessly — mitigated by the §3c procedure, and
  preferred-avoided in favor of strengthening the first line.
- **OPORD §3a is a baseline change, and OPORD is project-owned** — existing consumers must
  manual-merge it. `update` already reports OPORD drift; call this out in CHANGELOG as manual.

---

## 6. Migration for existing consumers

- OPORD §3a and the single-sourcing duty: manual-merge (project-owned). CHANGELOG marked so.
- Memory README (naming guidance, upgrade procedure, compaction policy): refreshed wholesale
  by `update` — lands automatically, no merge.
- Archiving old memory: lightweight guidance for existing projects; no forced migration.

---

## 7. Open questions

1. Memory compaction trigger — session count, byte budget, or "when the agent notices the
   folder is large"? Simpler is better here.
2. Does any naming/compaction guidance also belong in the auto-refreshed README so consumers
   get it without the OPORD merge? (Leaning yes — see 3b–3d, which already target the README.)
3. Is `project.md`-as-load-bearing acceptable with no staleness check, or do we want a cheap
   "project.md older than the newest memory file" nudge at boot?

---

## 8. Sequencing (proposed plan, pending approval)

1. **OPORD §3a rewrite + batching phrasing** (3a, §4) — the curve-bender. Ship first, measure.
2. **Drift test** (3f) — cheap; locks the dogfooding invariant before more edits land.
3. **Filename guidance + upgrade procedure + compaction** (3b–3d) — all in the memory README,
   auto-refreshed, no OPORD merge.
4. **Single-sourcing duty + fix our dogfooded CONOPS** (3e).
5. **Consumer usage guidance** (3g).

Each is independently shippable. 1 and 2 are highest value for least risk. A dedicated
`curate-memory` skill is deferred unless the upgrade procedure proves it needs to be invokable.

---

## 9. Revision — 2026-08-14 operator review

Review of the shipped change set corrected three positions. The OPORD, CONOPS, changelog,
and project state in the working tree reflect them; the body above stands as the record of
the original decision.

- **The CONOPS returns to the mandatory boot.** §3a above filed it under on-demand; that was
  wrong. Intent, scope, and boundaries are binding state — a session can cross a boundary on
  a task that never looks like a scoping question, so it must hold them before acting. The
  mandatory boot is `conops.md` + `project.md` + the OPORD + the folder map + the most-recent
  (and any salient) memory. Design, plan, and older memory stay behind the map.
- **No "stops climbing" claim.** The binding documents can, will, and sometimes must grow with
  the project. The defensible claim is narrower: growth in `memory/`, `design/`, and `plan/`
  no longer lands in the mandatory boot. Where this document says the floor "stops climbing,"
  read it with that correction.
- **The changelog's audience is defined.** `CHANGELOG.md` is the human-facing record, kept by
  tradition and written in release-notes style for a person scanning what changed between
  updates. The framework's own record is `project.md` and `memory/`. OPORD §3d owns the duty.
