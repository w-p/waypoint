# Project state

**Phase:** Execution — the v1 framework is built and in use. Current work is dogfooding fixes: correcting drift between the documents and what actually ships.

**Shipped:**

- CONOPS (`.waypoint/conops.md`) — project intent, scope, and constraints
- OPORD baseline (`templates/opord.md`, dogfooded at `.waypoint/opord.md`) — standing orders, phase definitions, rules of engagement, code standards, and the project extension point
- Templates (`templates/`) — `conops.md` (the eight-section scaffold), `opord.md`, `project.md`, `memory.md` (the memory folder convention README)
- Six core skills (`skills/`) — `new-project`, `new-feature`, `new-skill`, `onboarding`, `resume`, `debug`
- Two vendor adapters (`adapters/`) — Claude Code (`.claude/rules/waypoint.md`) and Cursor (`.cursor/rules/session-briefing.mdc`), each a standalone rule file installed wholesale
- Installer (`waypoint`) — a single bash script providing `install-core`, `install-claude`, `install-cursor`, `update`, `update-skills`, and `migrate`. Pulls the checkout before installing, stamps `.waypoint/VERSION` with the source commit, and reports the framework changes an update crosses
- Test suite (`test.sh`) — 52 assertions covering `update`'s ownership guarantees, the CONOPS scaffold lifecycle, migration paths, and the install guards
- README — what Waypoint is, how to install it, and how to keep it current
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

- No plan document. The v1 framework was built directly from the CONOPS without passing through a written Planning phase — a deviation from the workflow Waypoint prescribes, recorded here rather than papered over. Work since v1 has been small, well-understood fixes that do not warrant one.
