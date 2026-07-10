# Waypoint

Waypoint is a lightweight, vendor-agnostic framework for AI-assisted software development. It gives an AI coding assistant a persistent, structured home inside a project — so that institutional knowledge survives session boundaries, contributors can orient quickly, and development follows a consistent, phase-gated process.

## What Waypoint is

Waypoint solves a knowledge and process problem: AI assistants are stateless by default. Every session starts without knowledge of the project's history, decisions, constraints, or current state. Waypoint addresses this by providing a canonical set of plain Markdown documents in a `.waypoint/` directory that the AI reads at the start of every session. These documents are version-controlled alongside the code and require no runtime or tooling to use.

The framework also defines a three-phase development workflow — Ideation, Planning, Execution — that prevents premature implementation and preserves human approval authority at each phase transition. A library of skill documents provides entry points for common activities: starting a project, adding a feature, onboarding a new contributor, resuming after a gap.

Waypoint is a knowledge management and process governance layer. It does not prescribe how tests are written, how commits are structured, how branches are managed, or how code is reviewed. Those concerns belong to the developer and to whatever tools they choose.

## How Waypoint differs from execution frameworks like Superpowers

[Superpowers](https://github.com/obra/superpowers) is a software development methodology that governs how an AI assistant develops software within a session — TDD enforcement, implementation planning, subagent orchestration, code review integration, and git workflows. Waypoint and Superpowers address different layers of the same problem and are designed to coexist.

Waypoint governs **what the AI knows** — project intent, architecture decisions, current state, accumulated memory. Superpowers governs **how the AI builds** — test cycles, task execution, branch management. A project can use both simultaneously: Waypoint provides the project knowledge and process framework; Superpowers (or any equivalent tool) handles the execution mechanics. Neither knows about the other and neither depends on the other.

## Directory structure

```
.waypoint/
  opord.md          Standing orders for the AI assistant
  conops.md         Project intent, scope, and constraints
  project.md        Current phase, shipped/deferred inventory, ground truth index
  memory/           Cross-session continuity log (one file per session)
  design/           Finalized architecture decisions
  plan/             Sequenced work plans
  features/         As-built documentation per shipped feature
  skills/           Entry point guides and domain-specific procedures
```

## Getting started

### 1. Add Waypoint to your project

The recommended approach is a git submodule, cloned into a directory named `waypoint`:

```bash
git submodule add https://github.com/<org>/waypoint waypoint
```

Alternatively, clone or copy the repo into your project root as `waypoint/`.

### 2. Install

From your project root:

```bash
make -C waypoint install
```

This auto-detects your tool (Cursor if `.cursor/` exists, otherwise Claude Code), creates the `.waypoint/` directory structure, installs templates and skills, and wires up the session-start adapter.

To target a specific tool explicitly, or install from a non-standard location:

```bash
make -C waypoint install-cursor              # Cursor
make -C waypoint install-claude              # Claude Code
make -C waypoint install-core                # Templates and skills only, no adapter
make -C path/to/waypoint install DEST=.      # If not in a subdirectory named waypoint
```

Run `make -C waypoint help` to see all available targets and options.

### 3. Produce your CONOPS

Open a session with your AI assistant and say something like:

> Let's set up this project. I want to build [brief description].

The agent, primed by the OPORD, will find and follow the `new-project` skill automatically. It will ask questions, explore the design space with you, and produce the `conops.md`. Do not write it yourself — the value is in the conversation that produces it.

### 4. Verify

Open a new session with no request — just a greeting. The AI should respond with **"Ready."** and nothing else. If instead you open with a question, it briefly notes it's coming up to speed and then answers directly. Either way, Waypoint is working.

### Keeping up to date

When the framework ships new versions:

```bash
make -C waypoint update          # Migrate layout, refresh skills + adapter, check OPORD drift
make -C waypoint update-skills   # Core skills only
make -C waypoint migrate         # Bring an older install up to the current layout only
```

`update` is safe to run repeatedly. It:

- **Migrates layout** — an old single `.waypoint/memory.md` is moved into `.waypoint/memory/` (as a dated `-legacy.md` file); the folder convention is installed. An older adapter that embedded the briefing in `CLAUDE.md` is relocated to `.claude/rules/waypoint.md`, and the stale block is reported for you to remove.
- **Refreshes core skills** — user-created skills in `.waypoint/skills/` are never touched.
- **Refreshes the adapter** — both adapters are standalone rule files (`.claude/rules/waypoint.md` and `.cursor/rules/session-briefing.mdc`), replaced wholesale.
- **Checks the OPORD** — your `.waypoint/opord.md` is yours to extend, so `update` never rewrites it. If the shipped baseline has moved, it prints a `diff` command so you can merge framework changes by hand.

Installing into a project that already has instructions is safe: each adapter is its own file under `.claude/rules/` or `.cursor/rules/`, so Waypoint never edits your `CLAUDE.md` or other rules.

## Skills reference

| Skill | Purpose |
|---|---|
| `new-project` | Initialize a Waypoint-tracked project; produce CONOPS collaboratively |
| `new-feature` | Develop a new feature through the three-phase workflow |
| `new-skill` | Identify and encode a reusable domain procedure |
| `onboarding` | Brief a new contributor on an existing project |
| `resume` | Re-brief after a session gap or context compaction |
| `debug` | Unstructured investigation; no phase gates |

## The development workflow

```
Ideation                Planning               Execution
─────────────────────── ──────────────────── ──────────────────────
Describe the intent     Break work into       Build from the plan
Explore approaches      tasks with clear      Document what shipped
Debate tradeoffs        acceptance criteria   Update memory and
Write design doc        Write plan doc        project state
  ↓ human approves        ↓ human approves      ↓ feature complete
```

## License

MIT
