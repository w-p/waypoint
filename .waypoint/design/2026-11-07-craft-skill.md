# Design: The craft skill, teaching code placement and reuse

**Status:** Proposed 2026-11-07 from a downstream project's finding, built on branch
`v2-craft` for review as a pull request against `v2`.
**Scope:** One new core skill, two rows and a pointer in OPORD §3e, pointers from the
`new-feature` and `debug` skills.

---

## 1. Problem

A downstream project, after about three weeks of assistant-written code, inventoried its
timing constants and found roughly eighty of them declared across some twenty-five files,
each beside its first use. A wider survey found the same pattern in other forms: file names
and device identifiers typed as literals where a named constant already existed in a lower
layer; a small node-building helper copied into seven modules; the same palette declared
in four; layout numbers inline throughout the system screens. No single addition was wrong.
The OPORD's code standards said "readability above all" and "no invented conventions", and
every addition met them. What was missing was the step before writing: look for what exists,
and ask who owns the fact.

The developer's framing: the principle (clean, organized, obvious, reusable) seemed too
obvious to state, and it had to be stated anyway. They asked for teaching rather than
rules, because the decisions involved are judgment calls, and a this-goes-there map is
specific to one project.

## 2. Decisions

1. **A skill, not OPORD prose.** Teaching text is longer than the OPORD can carry at every
   boot (the cost-curve design, 2026-08-07). A skill is read on demand, when code is being
   written, which is the moment the questions apply. The OPORD gains only two table rows
   (Reuse, Placement) and one sentence pointing at the skill.
2. **Questions with their reasoning, not placement rules.** The skill walks seven
   questions: does this exist, who owns this fact, is this number a requirement, where
   would someone look, share at the second use, respect the direction of dependency,
   prefer a check to a sentence. Each gives the reason, so the assistant can apply it to a
   case the text did not foresee. Project-specific placement belongs in that project's
   `design/` and OPORD extension point; the skill says to read and extend those.
3. **File size is guidance.** The developer's call: sometimes a large file is right. The
   skill names size as a signal that the next duplicate is coming and says to split on a
   concept boundary, never on a line count.
4. **A closing pass.** Five questions to run before the memory entry, ending with recording
   the shared things added, so the next session searches for them.
5. **Pointers from where code is written.** `new-feature` step 1 and `debug` step 5 name
   the skill, the same way they name `report` for verification.

## 3. Rejected

- **A standing rule in `sop.md`.** The SOP holds one- or two-sentence imperatives. The
  developer asked for teaching, and a rule without its reasoning is what produced the
  problem in the first place: the standards were followed and the codebase still scattered.
  A project that wants a hard rule can promote one from its own memory.
- **A placement map in the framework.** Where things go differs by project and language.
  The skill tells the assistant to look for the project's map and to write one when it
  places something non-obvious.
- **A mechanical check shipped by Waypoint.** Waypoint does not touch execution mechanics
  (README, "What Waypoint doesn't do"). The skill teaches when a project should write its
  own check and what a good one looks like.
