# Project state

**Phase:** Execution — the enforcement ladder (design and plan dated 2026-08-31) is built and in the working tree on branch `v2`, alongside the skill-driven update (2026-08-14) and the boot/memory optimization. All in field testing before merge to main.

**Shipped:**

- CONOPS (`.waypoint/conops.md`) — project intent, scope, and constraints
- OPORD baseline (`templates/opord.md`, dogfooded at `.waypoint/opord.md`) — standing orders, phase definitions, rules of engagement, code standards, and the project extension point
- Templates (`templates/`) — `conops.md` (the eight-section scaffold), `opord.md`, `project.md`, `memory.md` (the memory folder convention README)
- Seven core skills (`skills/`) — `new-project`, `new-feature`, `new-skill`, `onboarding`, `resume`, `debug`, `update-waypoint`
- Two vendor adapters (`adapters/`) — Claude Code (`.claude/rules/waypoint.md`) and Cursor (`.cursor/rules/session-briefing.mdc`), each a standalone rule file installed wholesale
- Installer (`waypoint`) — a single bash script providing `install-core`, `install-claude`, `install-cursor`, and `update`. Reinstalling is the refresh mechanism: framework-owned files are replaced wholesale, legacy layouts are healed, and a provably unextended OPORD is fast-forwarded to the new baseline. `update` is that reinstall with the adapter detected, and the bootstrap that gets the `update-waypoint` skill into pre-skill projects. Pulls the checkout before installing and stamps `.waypoint/VERSION` with the source commit and `origin:` repo. `update-skills` and `migrate` are stubs
- Test suite (`test.sh`) — covers `update`'s ownership guarantees, the CONOPS scaffold lifecycle, migration paths, the install guards, and the dogfooding invariant (templates ≡ dogfooded `.waypoint/`)
- Boot/memory optimization (2026-08-07 design, revised in review) — the mandatory session boot reads the binding documents (`conops.md`, `project.md`, the OPORD) plus a folder listing as index and the most-recent memory file, with design/plan and older memory pulled on demand; the filename-as-index memory convention with a safe rename/upgrade procedure and a compaction policy; a single-sourcing OPORD duty; a defined audience for `CHANGELOG.md`; and a drift test guarding the template/dogfood pairs
- Skill-driven update (2026-08-14 design) — the `update-waypoint` core skill: reads `.waypoint/VERSION` (`revision:` plus the new `origin:`), clones or reuses the source, reruns install, narrates the change log, and three-way merges an extended OPORD with the developer reviewing the diff. Install became the refresh mechanism; the standing-checkout requirement retired
- Enforcement ladder (2026-08-31 design) — every rule at the strongest layer its host can hold. A standing-rules region in the OPORD, composed into both adapter rule files by the installer with a drift test; Claude Code hooks (session-start and post-compaction injection, per-prompt reminder, phase gate on edits and shell writes, block-once memory backstop, opt-in question gate); Cursor hooks (session-start injection, shell gate, edit watcher plus stop follow-up, memory reminder); wiring created/merged/printed, never blind-edited; a §3f Voice section with the register boundary; the machine-read `**Phase:**` line; the README "What's enforced" matrix. `WAYPOINT_PHASE_GATE=off` lifts the gates for a session
- README — what Waypoint is, how to install it, what's enforced, and how to keep it current
- `CHANGELOG.md` — dated entries, backfilled to the first commit

**Approach**

- Vendor-agnostic core: all framework files are plain Markdown; no runtime, no dependencies, no external service
- Thin adapters: vendor-specific wiring ships in `adapters/` and installs into the host tool's own rules directory, never inside `.waypoint/` and never into a project's existing instruction files
- Ownership boundaries in `update`: core skills and adapters are refreshed wholesale; `.waypoint/opord.md` is project-owned and only reported on when the baseline drifts; user-authored skills are never touched
- CONOPS template is scaffolding: installed as `conops-template.md` only while there is no `conops.md`, and removed once the CONOPS is written. A written CONOPS is never migrated automatically — that requires the developer's approval
- Complementary to execution tools: Waypoint governs knowledge and process; it does not prescribe TDD, git workflows, or CI
- Dogfooding: Waypoint uses Waypoint to track its own development

**Deferred**

- Multi-repo project support (CONOPS §8.1)
- Mid-flight adoption skill — `adopt-waypoint` (CONOPS §8.2)
- CONOPS revision skill, including how a written CONOPS adopts a changed template (CONOPS §8.3)
- Framework versioning scheme (CONOPS §8.4) — partially addressed. `.waypoint/VERSION` stamps the source commit and `update` reports the changes it crosses, so a project can now see what moved. Still open: whether Waypoint needs named releases rather than commits, which would only matter if distribution stops being "clone the repo"
- Skill discoverability mechanism (CONOPS §8.5)

**Ground truth docs**

- Intent: `.waypoint/conops.md`
- Standing orders: `.waypoint/opord.md`
- Shipped skills: `skills/` (see `.waypoint/skills/README.md` — this repo is Waypoint itself, so its skills live at the source)
- Shipped templates: `templates/`
- Shipped adapters: `adapters/`, one `INSTALL.md` per vendor
- Installer behavior: `waypoint`

**Plan**

- `.waypoint/plan/2026-08-31-enforcement-ladder.md` — standing-rules extraction, adapter hooks for injection and gates on both vendors, the register boundary, the README capability contract. Executed; in the working tree on `v2`.
- `.waypoint/plan/2026-08-14-skill-driven-update.md` — update becomes a core skill, install becomes the refresh mechanism, VERSION gains `origin:`. Executed; in the working tree on `v2`.
- `.waypoint/plan/2026-08-07-cost-curve-and-document-model.md` — the boot/memory optimization, taken through the full Ideation → Planning → Execution workflow. Executed; on branch `v2`.
- The v1 framework itself was built directly from the CONOPS without a written Planning phase — a deviation recorded rather than papered over. Small fixes since have not warranted one.
