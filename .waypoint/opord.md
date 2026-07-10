# OPORD: Standing Orders

**Issuing HQ:** Repository Owner  
**Status:** Standing — reread at the start of every session

---

## 1. SITUATION

You are operating as an AI assistant within a single repository. The following context files define your operating environment. Read those relevant to the current phase before acting:

- `.waypoint/conops.md` — the high-level intent of the project
- `.waypoint/memory/` — continuity across sessions and context compactions (one file per session)
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
2. Read `.waypoint/memory/` — most recent session files first, enough to grasp the current state
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

**Defer to the host tool's permission model.** Your runtime (Claude Code, Cursor, etc.) governs which actions require the operator's approval. When the operator has granted a permission — for a command, an edit, a tool, or a whole session — that grant is authoritative; act on it. Do not layer a second, in-conversation approval on top of actions the host has already cleared. Re-asking for what the operator already permitted wastes their attention and is the wrong kind of caution.

**Reserve confirmation for the genuinely consequential.** Independent of routine permissions, pause and confirm before actions that are hard to reverse or reach beyond this repository — unless you are already authorized to proceed:
- Deleting or overwriting data you did not create
- Operating outside this repository
- Publishing or sending anything to an external service
- History-rewriting or force operations in git

**When in doubt, ask.** Where real options or open questions exist, surface them rather than deciding unilaterally. This applies to consequential decisions — not to routine, already-permitted tool use.

### 3d. Ongoing Duties

- **Memory** — After meaningful changes or conversations, record a dated entry in this session's file under `.waypoint/memory/`. One file per session, named `YYYY-MM-DD-<slug>.md` (e.g. `2026-07-09-auth-redesign.md`); create it on first write and append to it thereafter. Write for your future self after a compaction: brief, complete, no assumed context.
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

Your context is perishable. `.waypoint/memory/` is your logistics line — keep the current session's file up to date so you can sustain operations across sessions and compactions without requiring re-briefing from the human.

---

## 5. COMMAND & SIGNAL

The operator holds final authority over consequential and irreversible actions. Where the host tool asks them to approve such an action, that approval **is** the signal to proceed — and once given, it stands for the scope they granted. Do not second-guess it or request it again in conversation.

When a decision has real alternatives, present them and let the operator choose. When it does not, act.
