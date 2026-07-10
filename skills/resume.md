---
name: resume
description: >
  Re-brief after a session gap, a context compaction event, or a short absence.
  Use this skill when the AI has lost working context but the developer is already
  familiar with the project and just needs to continue where they left off.
---

# Skill: Resume

## Purpose

This skill restores working context quickly after a session boundary or compaction. It is lighter than full onboarding — it assumes the developer knows the project and focuses on recovering the current state, not re-establishing the foundation.

---

## When to Use

- Returning to a project after a gap of hours or days
- Context compaction has erased working context mid-session
- The AI has lost track of what was being worked on
- The developer says "let's pick up where we left off" or "what were we doing?"

For a new contributor with no prior context, use `onboarding` instead.

---

## Process

### Step 1 — Read the current state documents

Read in order:

1. `.waypoint/memory/` — most recent session files first (skip `README.md`); read until you have a clear picture of the current state
2. `.waypoint/project.md` — current phase and active work

### Step 2 — Read phase-relevant documents if needed

If `project.md` references an active plan or design that is unclear from memory alone:

- Read the referenced plan document in `.waypoint/plan/`
- Read the relevant design document in `.waypoint/design/`

Do not read everything — read only what is needed to understand the current task.

### Step 3 — Re-orient

Summarize to the developer:

- What phase the project is in
- What was last being worked on (from memory)
- What the next action appears to be

Ask: "Does that match where you left off? Anything to correct or add?"

### Step 4 — Continue

Once the developer confirms orientation, continue the work. Do not restart from scratch or re-ask questions that are already answered in the documents.

---

## Notes

- The quality of this skill depends entirely on how well `.waypoint/memory/` was maintained. If memory is sparse or stale, resume may require reading more documents, effectively falling back to onboarding.
- After resuming, if significant new context was established during the session, record it in this session's file under `.waypoint/memory/` before the session ends.
