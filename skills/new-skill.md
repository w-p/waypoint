---
name: new-skill
description: >
  Identify and encode a reusable domain procedure as a Waypoint skill document.
  Use this skill when a procedure is being explained to the AI for the second time,
  or when a recurring workflow would benefit from a canonical written form.
---

# Skill: New Skill

## Purpose

Skills are reusable procedure documents. They encode domain-specific knowledge or recurring workflows so they do not need to be re-explained each session. A well-written skill makes a procedure repeatable, transferable, and improvable over time.

---

## When to Use

- A developer is explaining a procedure they have explained before
- A recurring workflow has emerged that would benefit from being written down
- A domain concept requires specific steps that differ from general best practices
- The developer says "every time we do X, we need to remember to..."

---

## Process

### Step 1 — Identify the procedure

Clarify what the skill covers:

- What activity or workflow does this skill govern?
- When should someone use this skill vs. handle the situation without it?
- What does the skill produce or accomplish?

### Step 2 — Gather the steps

Work through the procedure with the developer:

- What is the starting state?
- What are the steps in order?
- What decisions need to be made, and what drives those decisions?
- What are the common failure modes or edge cases?
- What does the ending state look like?

### Step 3 — Write the skill document

Use the following format. Save to `.waypoint/skills/<name>.md`.

```markdown
---
name: <skill-name>
description: >
  One to three sentences. What this skill does and when to use it.
---

# Skill: [Skill Name]

## Purpose

One paragraph. Why this skill exists.

## When to Use

Bullet list of conditions that indicate this skill should be invoked.

## Process

Numbered steps or phases. For each step: what to do, what to decide, what to produce.

## Notes

Optional. Edge cases, caveats, or links to related skills or documents.
```

### Step 4 — Review and save

Present the draft to the developer. Revise until it accurately reflects the intended procedure. Save the file.

Add a note to this session's file in `.waypoint/memory/` that the skill was created.

---

## Notes

- Skills should be written for the AI, not for humans — use imperative language and be precise about what to do.
- A skill that is too long is likely covering more than one procedure. Split it.
- Skills can call other skills by name — "follow the `new-feature` skill for implementation."
