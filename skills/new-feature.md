---
name: new-feature
description: >
  Develop a new feature through the three-phase Waypoint workflow: Ideation,
  Planning, and Execution. Use this skill whenever a developer wants to add
  a significant new capability to an existing project.
---

# Skill: New Feature

## Purpose

This skill governs how new features are developed. It enforces the three-phase workflow — design before planning, planning before building — so that work is never started without an approved design and a clear plan.

---

## When to Use

- The developer wants to add a meaningful new capability
- The work is substantial enough to warrant design review before implementation
- The developer says something like "I want to add X" or "we need to build Y"

For trivial changes (typos, minor config updates, small bug fixes), this skill is unnecessary.

---

## Process

### Phase 1 — Ideation and Refinement

**Goal:** Produce an approved design document.

Open with: **"Tell me about the feature. What should it do and why does it need to exist?"**

Work through:

1. **Intent** — What capability does this add? What user need does it address?
2. **Approach options** — What are the viable ways to implement this? What are the tradeoffs?
3. **Integration** — How does this fit with what already exists? What does it touch?
4. **Risks and challenges** — What could go wrong? What is the hard part?
5. **Scope** — What is in scope for this feature? What is explicitly deferred?

When the design is settled, write a design document in `.waypoint/design/`. The document should cover: intent, chosen approach and rationale, alternatives considered, integration points, and risks.

**Do not write any implementation code until the design is approved.**

Present the design to the developer. Revise until approved. Then ask: "Ready to move to Planning?"

### Phase 2 — Planning

**Goal:** Produce an approved implementation plan.

Break the approved design into discrete tasks. For each task:

- What specifically needs to be done?
- What files or components are affected?
- What is the acceptance criterion?
- Are there dependencies on other tasks in this plan?

Write the plan to `.waypoint/plan/`. Sequence tasks so earlier ones do not depend on later ones where possible.

**Do not write any implementation code until the plan is approved.**

Present the plan to the developer. Revise until approved. Then ask: "Ready to proceed with Execution?"

### Phase 3 — Execution

**Goal:** Implement, test, and document the feature according to the approved plan.

Work through the plan task by task. For each task:

1. Implement the change
2. Verify it works as specified
3. Note any discovered complexity or necessary deviations from the plan

If a deviation is significant, stop and surface it to the developer before continuing. Do not silently extend the scope.

When all tasks are complete:

1. Write an as-built feature document in `.waypoint/features/`. This document records what was built, key implementation decisions, and anything future contributors need to know.
2. Update `.waypoint/project.md`: add the feature to the Shipped list, update phase if appropriate.
3. Record a dated entry in this session's file under `.waypoint/memory/` summarizing what was built.
4. Update `CHANGELOG.md` and `README.md` if the change is user-visible.

---

## Notes

- If a new discovery during Execution changes the design significantly, return to Ideation for that scope rather than extending the plan.
- The design document is the contract. The plan is the schedule. The feature doc is the record.
- Features that span multiple sessions resume from `.waypoint/plan/` — pick up the next incomplete task.
