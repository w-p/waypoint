---
name: report
description: >
  Two checklists: how to write a status reply so the developer can act on it, and how to
  decide whether a memory entry is an observation to keep or a lesson to promote into
  sop.md. Use it whenever you report a result, answer a cost question, or write memory.
---

# Skill: Report

## Purpose

Verifying something and saying it are two halves of one duty. This skill covers the
saying half: a reply the developer can act on without re-deriving what you checked, and a
memory entry that feeds the standing rules instead of piling up behind them.

---

## When to Use

- Reporting a result, a measurement, or that something is done
- Answering a question about cost, time or risk
- Writing or appending to this session's memory file
- Ending a long autonomous run

---

## Checklist 1 — Status replies

Work through these in order; each shapes the next.

1. **Scope of what was verified.** Every result sentence says what it was checked on:
   which unit, which case, which scale. A result proven on one case is reported as one
   case, not as the whole.
2. **The view the developer judges by, first.** Before claiming a goal is met, look at
   what the developer will actually look at and describe what is still wrong there. Lead
   with that, then the rest.
3. **Action needed, then the answer.** Open with whether the developer has to do
   anything. Then the answer. Pick the right answer rather than offering a menu.
4. **Cost as necessity before size.** A cost question is answered in three parts: is the
   cost necessary at all, the cheapest path that meets the goal, then the price of the
   path asked about. Check what is already done locally and what the project's existing
   tools can deliver before quoting the price of a remote or automated path.
5. **Recorded steps are prior decisions.** If the reply relies on a plan step, say
   whether its circumstances still hold before pricing or executing it.
6. **The one assumption or question back.** End with the single assumption the developer
   should see, or the single question that would change the work, if there is one. One,
   not a list.

---

## Checklist 2 — Lessons

When writing a memory entry, decide which of two things it is.

1. **An observation.** Something that happened, dated and specific. Record it in this
   session's memory file as usual. Most entries are observations.
2. **A lesson.** An observation that generalizes beyond its incident, or one that has
   recurred. A lesson is only learned when a standing rule changes, so:
   - Write the rule into `.waypoint/sop.md` in the same turn, under the heading it
     belongs to: one or two imperative sentences, what to do and not what happened,
     ending with `(promoted YYYY-MM-DD from memory/<file>)`.
   - Add `promoted: sop.md#<section>` as the second line of the memory file, directly
     under its one-line summary.
   - Never delete or rewrite the memory file. It is the evidence behind the rule and
     stays in the index.

If you are unsure which it is, record the observation and say in the reply that it may
be a lesson. The developer can promote it, or the next recurrence will decide.

---

## Notes

- The standing rules in `sop.md` are read at every boot, so a rule's cost is paid every
  session. Promote what will save more than it costs to read; leave the rest as
  observations.
- A rule that stops being true is edited or removed from `sop.md`; the memory it came
  from keeps its `promoted:` line as history.
