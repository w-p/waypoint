Added `sop.md`, a project-owned standing-rules document read every boot, with a promotion path from memory into it, a `report` skill, and two OPORD blocks on conversational posture and decision points; built from a brief the developer brought from a downstream project.

- **2026-10-12:** The developer brought a written brief: three incidents in a downstream
  project (scope overclaimed, a cost priced without asking whether it was necessary, a plan
  step treated as a constraint) had each been recorded as feedback memories that nothing
  reads back into behaviour. The fix is a layer between the OPORD and the skills. Recorded
  the brief as the design (`.waypoint/design/2026-10-12-standing-rules-and-lessons-pipeline.md`)
  and plan, with the brief itself taken as the developer's approval of both, then built it:
  - `templates/sop.md` and its dogfooded copy, six headings, seed rules from the brief,
    citing `(baseline 2026-10-12)` because the source memories live in the downstream
    project. At the developer's request the rules and the design's incident list were
    generalized so nothing names that project's tools, data, or pipeline. The Verification heading ships empty, as the brief gave it; a rule I
    had added there was dropped at the developer's request.
  - OPORD: `sop.md` in §1, step 5 of §3a, **Conversational posture** in §3c, **CCIR and
    decision points** in §5. Nothing else.
  - `skills/report.md`, added to the installer's core list, README, CONOPS §5c, skills README.
    The brief's `verify.md` does not exist here; the pointer line went into `new-feature`
    step 2 and `debug` step 5.
  - Memory convention: optional `promoted: sop.md#<section>` second line, not frontmatter.
  - Installer: `install_opord` became `install_owned <name>`, called for both files.
    `update-waypoint` step 5 now covers the SOP. Help text and README ownership notes updated.
  - Tests: SOP and report installed, extended SOP survives reinstall, SOP drift pair.
  The developer confirmed the name `sop.md` over `doctrine.md`. Nothing open.
