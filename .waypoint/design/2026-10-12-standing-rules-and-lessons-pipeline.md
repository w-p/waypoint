# Design: Standing rules and the lessons pipeline

**Status:** Approved 2026-10-12 by the developer, who brought the design as a written
brief from a downstream project; executed the same day on branch `v2` via
`.waypoint/plan/2026-10-12-standing-rules-and-lessons-pipeline.md`. Execution notes in §6.
**Scope:** A new document layer between the OPORD and the skills, a promotion path from
memory into it, and decision points in the OPORD itself.

---

## 1. Problem

In a downstream project, three things went wrong in the same way:

1. A result proven on one input at one scale was reported as if it held for the whole.
2. Asked what a rebuild would cost on the remote pipeline, the assistant priced that path
   and stopped, when the work was already done locally and an existing tool made the
   remote cost avoidable.
3. A plan step on file, written when it was the only option, was treated as a constraint
   rather than a prior decision to revisit.

Each was recorded as a feedback memory. Memory is an inbox with no outbox: thirty-odd
dated incident files whose one-line index hooks fade. The OPORD is strong on evidence
(phase gates, confirmation, memory) and silent on conversational posture: nothing asks the
assistant to question whether a cost is necessary, to re-check recorded decisions, or to
end an answer with the assumption the developer should see. Long autonomous runs reinforce
a report-after posture.

## 2. The layer that is missing

Waypoint's documents map onto a known structure, and the mapping shows the gap:

| Waypoint | Counterpart |
|---|---|
| `conops.md` | Concept of operations, the intent |
| `opord.md` | The operations order; §3c is already rules of engagement |
| `skills/*.md` | Drills and procedures |
| `memory/*.md` | After-action observations: dated, incident-specific, kept |
| missing | Standing operating procedures: rules distilled from observations |

Two further ideas from the same tradition, used by name:

- **The lessons-learned pipeline:** observation, insight, lesson, lesson learned. A lesson
  is "learned" only when a standing procedure or doctrine changes. The memory file is the
  observation record and stays behind. Memories are never deleted; they are marked
  promoted.
- **Decision points:** the information the developer must hear because a decision hangs
  on it, and the decision points named in advance. Home: OPORD §5, Command & Signal.

## 3. Decisions

1. **A new document, `sop.md`,** holds the standing rules. Six topic headings: Reporting;
   Costs and alternatives; Verification; Documents versus artifacts; Cadence on long
   runs; Promotion convention. Each rule is one or two imperative sentences followed by
   its provenance. It says what to do, not what happened. The name is "SOP"; "doctrine"
   was the alternative, and the developer settled on SOP the same day.
2. **The OPORD reads it every session** (§3a, after the memory step) and lists it among
   the ground-truth documents (§1).
3. **Two new blocks in the OPORD.** §3c gains **Conversational posture**: cost answered
   as necessity before size; a recorded plan step is a prior decision, re-checked when
   circumstances change; a substantive answer ends with the one assumption or question the
   developer should see. §5 gains **CCIR and decision points**: before any step over about thirty
   minutes or a few dollars, one line stating what, why and the alternative rejected; a
   "proceed" on a task does not pre-approve the alternatives not named. The OPORD grows
   by exactly these edits; everything else goes in `sop.md`.
4. **A `report` skill** carries two checklists: how to write a status reply, and how to
   decide whether a memory entry is an observation or a lesson. A lesson that generalizes
   or has recurred is written into `sop.md` in the same turn, and the memory file is
   marked `promoted: sop.md#<section>`.
5. **The memory convention** gains that optional `promoted:` line, directly under the
   one-line summary. Promoted memories stay in the index.
6. **Ownership.** `sop.md` is project-owned exactly as the OPORD is: installed when
   absent, fast-forwarded when provably unextended, otherwise left alone and merged by
   the `update-waypoint` skill.

## 4. Seed rules

The baseline ships with the rules distilled from the three incidents in §1, generalized
so that no rule names the downstream project's tools or data. They cite the baseline rather
than a memory file: the observations behind them live in a downstream project's memory,
which a fresh install does not have.

## 5. Rejected

- **Growing the OPORD with the rules themselves.** The OPORD is the durable layer and
  every line in it is paid for on every boot. Rules that accrete belong in a document
  built to accrete.
- **Putting incident narrative in `sop.md`.** The memory holds the story; the SOP holds
  the rule. A rule with its story attached stops being scannable.
- **Deleting or rewriting promoted memories.** The observation record is evidence; the
  index must keep showing it.

## 6. Execution notes

- The brief asked for one line at the end of a `verify` skill. Waypoint ships no such
  skill; the line went where verification is actually prescribed, the execution step of
  `new-feature` and the fix step of `debug`.
- The brief described the `promoted:` marker as frontmatter. Waypoint memory files carry
  no frontmatter; the marker is a plain second line, which keeps `head -1` as the summary.
- The installer's OPORD ownership function was generalized to take the file name, so
  `sop.md` gets the same install, fast-forward and left-alone behaviour with no second
  copy of the logic.
