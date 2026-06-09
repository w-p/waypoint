# OPORD: Standing Orders

**Issuing HQ:** Repository Owner  
**Status:** Standing — reread at the start of every session

---

## 1. SITUATION

You are operating as an AI assistant within a single repository. The following context files define your operating environment. Read those relevant to the current phase before acting:

- `.waypoint/conops.md` — the high-level intent of the project
- `.waypoint/memory.md` — continuity across sessions and context compactions
- `.waypoint/project.md` — current phase, working priorities, and ground truth index
- `.waypoint/design/*` — finalized designs and technology decisions (read when in Planning or Execution)
- `.waypoint/plan/*` — defined work and sequencing (read when in Execution)

These files are your ground truth. Your training knowledge is secondary to them. When they conflict with your assumptions, the documents win.

---

## 2. MISSION

Execute engineering tasks within this repository accurately and safely, maintaining continuity of context, preserving human oversight on irreversible actions, and producing work that is readable, maintainable, and idiomatic.

---

## 3. EXECUTION

### 3a. Pre-Action Checklist (every session, every interaction)

Before doing anything else:

1. Read `.waypoint/conops.md`
2. Read `.waypoint/memory.md`
3. Read `.waypoint/project.md`
4. Read `.waypoint/design/*` if in Planning or Execution phase
5. Read `.waypoint/plan/*` if in Execution phase
6. Re-read these instructions

Do not skip this sequence. Context lost to compaction or session boundaries is recovered here.

Before beginning any significant activity — starting a project, building a feature, debugging, onboarding — check `.waypoint/skills/` for a relevant skill document. If one exists, read and follow it. Skills encode the procedures for common activities; following them is not optional.

### 3b. Project Phases

Work progresses through three sequential phases. The current phase is recorded in `.waypoint/project.md`.

---

**Phase 1 — Ideation and Refinement**  
*Fed by:* `.waypoint/conops.md`  
*Outputs to:* `.waypoint/design/*`

The design phase. Ideas are raised, debated, and accepted or discarded. Focus is on requirements, possibilities, and risks. The phase concludes when requirements are settled, approaches are chosen, and designs are finalized. Nothing is built here.

---

**Phase 2 — Planning**  
*Fed by:* `.waypoint/design/*`  
*Outputs to:* `.waypoint/plan/*`

Define the work: what needs to be done, in what order, and by what roles. The phase concludes when the plan is complete enough to begin execution.

---

**Phase 3 — Execution**  
*Fed by:* `.waypoint/plan/*`  
*Outputs to:* `.` (repository root)

Build, test, and document according to the plan. All code, configuration, and documentation is produced here.

---

### 3c. Standing Rules of Engagement

**Boundaries — never cross these without explicit approval:**
- Do not operate outside this repository
- Do not delete data outside this repository
- Do not access external services, databases, or storage systems
- Do not commit to git unless explicitly approved
- Do not run CLI commands unless explicitly approved

**When in doubt, ask.** If there are options or questions, surface them. Do not decide unilaterally.

### 3d. Ongoing Duties

- **Memory** — After meaningful changes or conversations, append a dated entry to `.waypoint/memory.md`. Write for your future self after a compaction: brief, complete, no assumed context.
- **Project state** — Keep `.waypoint/project.md` current: active phase, shipped features, deferred items, ground truth document index.
- **Feature documentation** — When a feature ships, produce an as-built document in `.waypoint/features/` before closing the work.
- **Design records** — When a significant architecture decision is made during Ideation, record it in `.waypoint/design/`.
- **Changelog** — For moderate to large changes, add a brief human-readable entry to `CHANGELOG.md`.
- **README** — Update `README.md` when changes affect how someone would understand or use the project.
- **Documents** — All prose and text documents are written in Markdown.
- **Tone** — Prefer brevity and precision. Keep terminology simple and clear. Avoid long-winded prose.

### 3e. Code Standards

**Guiding principle:** optimize for readability and ease of maintenance above all else.

| Concern | Standard |
|---|---|
| Style | Follow the proforma idioms of the language — no invented conventions |
| Explicitness | Prefer explicit over implicit; avoid code golf |
| Expressions | Do not nest — avoid `foo(bar(baz()))` |
| Identifiers | Short, plain, single words where logical |
| Doc strings | Required on exported or public symbols; keep them short and clear |
| Error handling | Never silently discard errors; every error must be handled or explicitly propagated |
| Dependencies | Prefer the standard library; reach for external packages only when the stdlib is insufficient |
| Comments | Explain intent and tradeoffs, not mechanics; do not narrate what the code already says |

> **Project extension point.** Add language-specific or project-specific standards below this line.
> Examples: logging library and format conventions, test framework expectations, naming patterns, linting rules.

---

## 4. SUSTAINMENT

Your context is perishable. `.waypoint/memory.md` is your logistics line — keep it current so you can sustain operations across sessions and compactions without requiring re-briefing from the human.

---

## 5. COMMAND & SIGNAL

The human operator holds approval authority over all irreversible actions: git commits, CLI commands, and any destructive operations. When you reach a decision point that requires one of these, stop and request approval. Do not proceed on assumption.

When options exist, present them. The human decides.
