---
name: new-project
description: >
  Initialize a Waypoint-tracked project by producing a CONOPS collaboratively.
  Use this skill when starting a new project from scratch, or when adopting
  Waypoint on an existing project that has no CONOPS yet.
---

# Skill: New Project

## Purpose

This skill drives the conversation that produces the project CONOPS. The CONOPS is the foundational document for the project — everything else is downstream of it. Do not write the CONOPS until the conversation has converged. Writing before convergence produces a document that reflects misunderstanding, not agreement.

---

## When to Use

- The developer is starting a new project
- The `.waypoint/` directory does not yet have a `conops.md`
- The developer has said something like "let's start a new project" or "I want to build X"

---

## Process

### Phase 1 — Understand the intent

Open with a single question: **"What are you trying to build, and what problem does it solve?"**

Listen to the answer. Do not jump to solutions. Ask follow-up questions to understand:

- Who has this problem? (users and use cases)
- Why hasn't it been solved already, or why is the existing solution insufficient?
- What does success look like?

Summarize back what you heard. Get confirmation before moving on.

### Phase 2 — Explore the design space

Once the problem is clear, explore the solution space together:

- What are the possible approaches?
- What are the risks and tradeoffs of each?
- What are the hard constraints (technical, organizational, security, time)?
- What is explicitly out of scope for the first version?

Do not advocate for a specific approach prematurely. Surface options and tradeoffs. The developer decides.

### Phase 3 — Identify open questions

Before writing anything, list the questions that are not yet answered:

- What is not yet known?
- What needs to be decided before execution can begin?
- What can be deferred to later without blocking progress?

### Phase 4 — Write the CONOPS

When the conversation has converged — the problem is understood, an approach is agreed on, constraints are known, and open questions are identified — write the CONOPS.

Use the template at `.waypoint/conops-template.md`. Fill in all eight sections. Do not skip or combine sections.

Present the draft to the developer for review. Revise until approved.

### Phase 5 — Initialize the project

After the CONOPS is approved:

1. Copy `templates/opord.md` to `.waypoint/opord.md`. Extend the code standards section with any project-specific conventions discussed during the CONOPS conversation.
2. Initialize `.waypoint/project.md` from `templates/project.md`. Set the phase to Ideation.
3. Create the first session file in `.waypoint/memory/` (named `YYYY-MM-DD-<slug>.md`) with a dated entry summarizing the project briefing. See `.waypoint/memory/README.md` for the convention.
4. Confirm with the developer that the project is ready to proceed.

---

## Notes

- The CONOPS conversation typically takes 15–45 minutes for a well-scoped project.
- If the developer cannot clearly articulate the problem, that is the most important thing to resolve before any design work begins.
- The CONOPS template structure is fixed. Do not restructure, remove, or reorder sections.
