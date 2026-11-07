Added the `craft` core skill, which teaches how to decide what already exists, who owns a value, when to share and when to split while writing code, from a downstream project's finding that assistant-written constants and helpers had scattered across its tree; built on branch `v2-craft` for a pull request against `v2`.

- **2026-11-07:** A downstream project inventoried its timing constants after a session had
  to sweep about twenty-five files to list them, then surveyed wider and found the same
  pattern as copied helpers, literals typed where a constant already existed in a lower
  layer, and inline layout numbers. The developer asked for guidance that teaches the
  practices rather than a project-specific map, delivered to Waypoint as a pull request
  against `v2`. Recorded as `.waypoint/design/2026-11-07-craft-skill.md` and built:
  - `skills/craft.md`: seven questions with their reasoning (exists already, owner,
    requirement or not, where someone would look, share at the second use, direction of
    dependency, check over sentence), a five-step closing pass, and notes that keep the
    project's own map in its `design/` and OPORD extension point. File size is guidance,
    at the developer's direction.
  - OPORD §3e (template and dogfooded copy): rows Reuse and Placement, one pointer
    sentence. Nothing else in the OPORD.
  - Pointers in `new-feature` step 1 and `debug` step 5; the skill in the installer's core
    list, `test.sh`, the README table, CONOPS §5c, the skills README and `project.md`.
  - Changelog entry for 2026-11-07 with the by-hand merge note for extended OPORDs.
