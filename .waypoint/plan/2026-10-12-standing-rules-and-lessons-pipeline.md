# Plan: Standing rules and the lessons pipeline

**Design:** `.waypoint/design/2026-10-12-standing-rules-and-lessons-pipeline.md`
(approved 2026-10-12)
**Status:** Executed 2026-10-12 on branch `v2`; deviations in design §6.

Two tasks touch the OPORD baseline (T2) and the memory convention (T4), so extended
downstream copies take them through the `update-waypoint` merge. Everything else lands by
reinstall.

## T1 — `sop.md`

Write `templates/sop.md` with the six headings, the seed rules, and the promotion
convention; copy it to `.waypoint/sop.md` (dogfood pair, drift-tested).

## T2 — OPORD edits

In `templates/opord.md` and its dogfooded copy: §1 lists `sop.md`; §3a reads it after
the memory step; §3c gains **Conversational posture**; §5 gains **CCIR and decision points**.
Nothing else.

## T3 — `report` skill

Write `skills/report.md` with the status-reply and lessons checklists. Add it to the
installer's core skill list, the README skills table, the CONOPS entry-point table, and
the skills README. Point the verification steps of `new-feature` and `debug` at it.

## T4 — Memory convention

Document the optional `promoted:` second line in `templates/memory.md` and its dogfooded
copy.

## T5 — Installer and update skill

Generalize the OPORD ownership function to any project-owned baseline file and call it
for `sop.md`. Extend the `update-waypoint` merge step to cover `sop.md`. Update the
installer's help text.

## T6 — Tests, docs, closeout

`test.sh`: `sop.md` installed, extended copy survives reinstall, `report` installed, drift
pair. README (`.waypoint/` listing, ownership, skills table, staying current), CONOPS §4
and §5c, `CHANGELOG.md`, `project.md`, this session's memory file.
