---
name: onboarding
description: >
  Brief a new contributor — human or AI — on an existing Waypoint-tracked project.
  Use this skill when someone new needs to understand the project before contributing.
---

# Skill: Onboarding

## Purpose

This skill orients a new contributor to a Waypoint-tracked project quickly and completely. It ensures they understand what the project is, what constraints it operates under, and what the current state of work is — before they make any changes.

---

## When to Use

- A new developer is joining the project
- An AI assistant is being used on a project for the first time (and no session briefing automation is in place)
- A contributor returns after a long absence and needs a full re-orientation

For a shorter re-orientation after a normal session gap, use the `resume` skill instead.

---

## Process

### Step 1 — Read the foundational documents

Read the following in order:

1. `.waypoint/opord.md` — standing orders and rules of engagement
2. `.waypoint/conops.md` — what the project is, who uses it, what it must and must not do
3. `.waypoint/project.md` — current phase, what has shipped, what is deferred

### Step 2 — Read phase-relevant documents

Depending on the current phase recorded in `project.md`:

- **Ideation:** Read `.waypoint/design/*` if any design documents exist.
- **Planning:** Read `.waypoint/design/*` and `.waypoint/plan/*`.
- **Execution:** Read `.waypoint/design/*` and `.waypoint/plan/*`. Skim `.waypoint/features/*` for context on what has already been built.

### Step 3 — Read recent memory

Read the session files in `.waypoint/memory/` (skip `README.md`), most recent first. These capture decisions and context that may not be reflected in the structured documents yet.

### Step 4 — Confirm understanding

Summarize the following to the developer for confirmation:

- What the project does and why it exists
- The current phase and what work is active or next
- Any open questions or known constraints that would affect upcoming work
- Anything in the memory log that seems particularly relevant to current work

Ask: "Is there anything I've missed or misunderstood?"

### Step 5 — Proceed

Once orientation is confirmed, proceed with the task the contributor needs to perform. If the task is a new feature, follow the `new-feature` skill. If the task is a new skill, follow the `new-skill` skill.

---

## Notes

- Onboarding is not a one-time activity — it is the correct starting point for any contributor who does not already have live context.
- If the project has no `.waypoint/conops.md`, the project has not been initialized. Use the `new-project` skill before proceeding.
