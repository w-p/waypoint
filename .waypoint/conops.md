# CONOPS: Waypoint

---

## 1. Background and Problem Statement

AI coding assistants are stateless by default. Every new session starts without knowledge of the project — its history, its architecture decisions, what was tried and discarded, what is currently in progress, and why things are the way they are. This knowledge must be re-established from scratch each time, either by the developer re-explaining context or by the agent making uninformed decisions.

The problem compounds across three dimensions:

**Session boundaries.** A developer working on a project over days or weeks re-briefs their AI assistant at the start of each session. Context compaction events — where the model discards early conversation history to make room for new tokens — can silently erase established context mid-session, causing the agent to contradict decisions it had already agreed to.

**Contributor transitions.** A new team member (human or AI) joining an existing project has no authoritative source of truth for what the project is, what constraints it operates under, or what decisions have already been made. This information lives in human memory or must be reconstructed from commit history and code.

**Process inconsistency.** Without a defined workflow, AI-assisted development tends toward premature implementation — the agent begins writing code before requirements are clear, before design has been reviewed, and before the developer has approved an approach. This produces rework and erodes trust in the assistant.

There is no established, tool-agnostic framework that addresses these problems together.

---

## 2. Vision

Waypoint is a lightweight, vendor-agnostic framework that gives an AI coding assistant a persistent, structured home inside a software project.

The framework provides three things:

1. **A canonical document set** that collectively describes what a project is, where it is going, and what state it is in today. These documents are plain Markdown, version-controlled alongside the code, and readable by any capable AI assistant without tooling installation.

2. **A phase-gated development workflow** that governs how new work is initiated, designed, planned, and executed. The workflow prevents premature implementation and preserves human approval authority at each transition.

3. **Reusable skill documents** that encode both domain-specific procedures and general-purpose entry points for common development activities — starting a project, adding a feature, onboarding a contributor, resuming after a gap.

Waypoint is a knowledge management and process governance layer. It is not an execution methodology. It does not prescribe how tests are written, how commits are structured, how branches are managed, or how code is reviewed. Those concerns belong to the developer and to whatever execution tools they choose.

---

## 3. Users and Use Cases

The primary user is a **solo developer** working with an AI assistant on a project they own or maintain. Even on a team, this person works largely alone — pairing with the AI rather than with colleagues in real time.

**Representative questions:**

*Starting work:*
- "I'm starting a new project. How do I structure my thinking before writing any code?"
- "I need to add a significant feature. What's the right process so I don't end up with something I have to throw away?"

*Returning to work:*
- "I haven't touched this project in two weeks. What was I working on and what decisions did I make?"
- "My session context was lost. What do I need to know to continue?"

*Building shared knowledge:*
- "I keep explaining the same domain concept to the AI every session. How do I encode that so I never have to again?"
- "I want to make sure any AI assistant I use on this project follows the same rules."

The secondary user is a **new contributor** — human or AI — onboarding to an existing Waypoint-tracked project.

**Representative questions:**
- "What is this project and what problem does it solve?"
- "What are the constraints and boundaries I should not cross?"
- "What's the current state of work? What has shipped and what is deferred?"
- "What conventions govern how I should work here?"

---

## 4. System Overview

Waypoint lives in a `.waypoint/` directory at the root of the project repository. All framework files are plain Markdown. No runtime, no tooling installation, and no external service is required.

**Directory structure:**

```
.waypoint/
  opord.md          Standing orders for the AI assistant
  conops.md         Project intent, scope, and constraints
  project.md        Current phase, shipped/deferred inventory, ground truth index
  memory/           Cross-session continuity log (one file per session)
  design/           Finalized architecture decisions
  plan/             Sequenced work plans
  features/         As-built documentation per shipped feature
  skills/           Entry point guides and reusable domain procedures
```

**Vendor adapters** are thin integration files that wire the framework's session-start briefing into a specific tool's native mechanism — Cursor rules, Claude Code rules, an `AGENTS.md`, and so on. They ship in the Waypoint repository under `adapters/` and install into the host tool's own rules location: `.claude/rules/waypoint.md` for Claude Code, `.cursor/rules/session-briefing.mdc` for Cursor. Nothing vendor-specific is written inside `.waypoint/` — everything there is identical regardless of which tool is in use, and the adapter never edits a project's existing instruction files.

**The framework ships** a set of templates and core skill documents that a developer copies into their project's `.waypoint/` when adopting Waypoint. Projects then customise the OPORD and CONOPS for their context; the templates themselves are not modified.

---

## 5. Concept of Operations

### 5a. Project initialization

A new project begins with the `new-project` skill. The skill drives a structured conversation between the developer and the AI assistant to produce the project CONOPS — the foundational document that defines what the project is, who uses it, what it must and must not do, and what the key risks and open questions are.

The CONOPS is written only after that conversation has converged. Writing before convergence produces a document that reflects misunderstanding rather than agreement.

After the CONOPS is written, the developer and agent together:
- Initialize the OPORD, extending the Waypoint baseline with any project-specific rules
- Initialize `project.md` to the Ideation phase
- Create the first session file in `memory/` with a dated entry summarizing the project briefing

The project is now ready for structured development.

### 5b. Phase-gated workflow

Work proceeds through three sequential phases — Ideation, Planning, Execution — defined in OPORD §3b (what each phase is fed by and what it outputs). The current phase is recorded in `project.md` and is the primary signal for what kind of work is appropriate right now.

What this section adds is the governance around those phases:

- **No production code is written in Ideation or Planning.** Those phases produce a design (`design/`) and a plan (`plan/`) respectively.
- **The developer approves each transition explicitly** — a design before Planning begins, a plan before Execution begins.
- **Execution surfaces blockers** rather than resolving them unilaterally. On completion, the feature is documented in `features/`, `project.md` is updated, and the session's `memory/` file records what was built and why.
- **Phases are sequential.** A project in Execution that discovers a significant design gap returns to Ideation for that scope — it does not extend the plan unilaterally.

### 5c. Entry points

Each of the following activities is covered by a skill document in `.waypoint/skills/`. A developer begins any of these activities by directing the AI to read and follow the appropriate skill.

| Skill | When to use |
|---|---|
| `new-project` | Starting a Waypoint-tracked project from scratch |
| `new-feature` | Adding a significant new capability through the three-phase workflow |
| `new-skill` | Identifying and encoding a reusable domain procedure |
| `onboarding` | Briefing a new contributor — human or AI — on the project |
| `resume` | Re-briefing after a session gap, a context compaction, or a long absence |
| `debug` | Unstructured investigation; lighter weight, no phase gates |

### 5d. Ongoing duties

The AI assistant has standing duties that apply continuously across all phases — maintaining memory, keeping `project.md` current, documenting shipped features, and recording design decisions during Ideation. These are defined in OPORD §3d, which owns them; they are not restated here.

### 5e. Session start

On every new session start, the AI reads `opord.md` first. Its Pre-Action Checklist (§3a) governs the rest of the boot: the binding documents and a map of the narrative folders are read every session, and everything else is pulled on demand. This is enforced through the vendor adapter for the tool in use. The adapter's sole job is to ensure this happens automatically.

---

## 6. Scope and Boundaries

**In scope:**

- The `.waypoint/` directory structure and document conventions
- Templates for the CONOPS, OPORD, `project.md`, and the `memory/` convention
- Core entry point skill documents
- The baseline OPORD content and its extension mechanism
- Thin vendor adapters for common AI development tools

**Out of scope:**

- Execution mechanics: TDD, test runners, code review workflows, subagent orchestration, git branching strategies, commit conventions
- Language, framework, or toolchain opinions
- CI/CD pipeline configuration
- Runtime monitoring, alerting, or observability
- Multi-tenancy, team-level access control, or hosted deployment of any kind
- Anything that lives outside the `.waypoint/` directory
- Compatibility with weaker or non-capable AI models (behavior on sub-frontier models is undefined and untested)

---

## 7. Assumptions and Constraints

- **Capable model required.** Waypoint assumes the AI assistant is capable of following natural language instructions in Markdown and exercising judgment about when to ask versus when to proceed. Behavior on weaker models is undefined. Developers are responsible for evaluating fitness of their chosen model.

- **Developer reads and approves the CONOPS.** A CONOPS that was produced but never reviewed by the developer does not represent genuine agreement. The phase-gate workflow depends on the developer having read and understood what the documents say.

- **Documents are treated as authoritative.** The OPORD and CONOPS are ground truth. If a developer overrides them verbally in a session, the AI should note the conflict and ask whether the document should be updated. Verbal overrides that are not reflected in the documents will be lost at the next session boundary.

- **CONOPS template structure is fixed.** The eight-section structure is non-negotiable. Projects fill in the sections; they do not restructure, remove, or reorder them.

- **OPORD baseline is opinionated.** The baseline expresses real opinions about safe, readable, maintainable AI-assisted development. Projects may extend the OPORD with project-specific rules. Removing baseline rules is permitted only with conscious intent and understanding of what is being relaxed.

- **Waypoint does not prescribe execution tools.** Developers choose how to write tests, manage branches, and review code. Waypoint governs the knowledge and process layer, not the execution layer.

- **One `.waypoint/` per repository.** Multi-repository projects are out of scope for this version. Each repository that uses Waypoint maintains its own independent `.waypoint/` directory.

---

## 8. Open Questions

| # | Question | Owner | Needed By |
|---|----------|-------|-----------|
| 1 | **Multi-repo projects.** When a project spans more than one repository, does each repo get its own `.waypoint/`, or is one repo designated canonical? How do cross-repo decisions get documented? | Framework authors | Future |
| 2 | **Mid-flight adoption.** What is the recommended process for a team adopting Waypoint on an existing project — not a greenfield? The CONOPS would need to be produced retrospectively. Does the `new-project` skill accommodate this, or is a separate `adopt-waypoint` skill warranted? | Framework authors | Before v1.0 |
| 3 | **CONOPS revision.** When a project's direction changes significantly, how is the CONOPS updated? Re-running the `new-project` skill is one option. A dedicated `revise-conops` skill is another. The revision process should be as deliberate as the original production process. | Framework authors | Before v1.0 |
| 4 | **Framework versioning.** Should `.waypoint/` files carry a Waypoint version marker? If the framework evolves in a breaking way, projects need a way to know which version of the conventions they are following. | Framework authors | Before v1.0 |
| 5 | **Skill discoverability.** How does the AI know which skills are available without reading every file in `.waypoint/skills/`? An index file, a convention in the OPORD, or something else? | Framework authors | Before v1.0 |
