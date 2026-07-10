---
name: debug
description: >
  Unstructured investigation of a bug, unexpected behavior, or unknown system state.
  Lighter weight than new-feature — no phase gates, no design document required.
  Use when something is broken or not understood and the fix is exploratory.
---

# Skill: Debug

## Purpose

This skill governs unstructured investigation. It provides enough structure to avoid wasted effort and ensure findings are recorded, without imposing the full phase-gated workflow that feature development requires.

---

## When to Use

- Something is broken and the cause is unknown
- Behavior is unexpected and needs to be understood before a fix can be designed
- The developer says "something is wrong with X" or "I don't understand why Y is happening"
- Exploratory work: investigating a system, a dependency, or an unfamiliar codebase area

---

## Process

### Step 1 — Establish the observable problem

Before touching any code, get a clear statement of the problem:

- What is the observed behavior?
- What is the expected behavior?
- When did it start? What changed?
- Is it reproducible? Under what conditions?

If the developer cannot answer these clearly, the first task is to gather that information — not to start fixing.

### Step 2 — Form a hypothesis

Based on what is known, form one or more hypotheses about the root cause. State them explicitly:

- "This could be caused by X because..."
- "The most likely cause is Y because..."

Do not start investigating everything at once. Pick the most probable hypothesis first.

### Step 3 — Investigate

Test the hypothesis. Read code, check logs, reproduce the issue, inspect state. Narrow the scope with each step.

If the hypothesis is disproved, state clearly why and form the next one. Do not anchor on a failing hypothesis.

### Step 4 — Identify the root cause

Stop investigating when you have identified the root cause — not just a symptom. A fix applied to a symptom will recur.

State the root cause clearly: "The bug is X. It is caused by Y. Evidence: Z."

### Step 5 — Fix and verify

Apply the minimal fix that addresses the root cause. Verify the original behavior is resolved and no new issues are introduced.

### Step 6 — Record findings

If the investigation revealed something non-obvious about the system — a surprising behavior, an undocumented constraint, a fragile interaction — record it:

- Add a note to this session's file in `.waypoint/memory/`
- Consider whether a design document in `.waypoint/design/` is warranted
- Add a code comment at the affected location if the fix would otherwise be confusing

---

## Notes

- Debugging that reveals a missing capability (not a bug) should transition to the `new-feature` skill for that capability.
- Do not skip step 6 — the most valuable output of a debugging session is often the understanding, not the fix.
- Time-box investigation steps. If a hypothesis cannot be confirmed or denied within a reasonable effort, discard it and move on.
