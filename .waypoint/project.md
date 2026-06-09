# Project state

**Phase:** Ideation — CONOPS written; OPORD, templates, skills, and adapters in progress.

**Shipped:**
- CONOPS (`.waypoint/conops.md`)
- OPORD baseline (`.waypoint/opord.md`)

**Approach**

- Vendor-agnostic core: all framework files are plain Markdown; no runtime or tooling required
- Thin adapters: vendor-specific wiring lives in `.waypoint/adapters/` and is the only non-portable artifact
- Complementary to execution tools: Waypoint governs knowledge and process; it does not prescribe TDD, git workflows, or CI
- Dogfooding: Waypoint uses Waypoint to track its own development

**Deferred**

- Multi-repo project support (open question §8.1)
- Mid-flight adoption skill (`adopt-waypoint`) (open question §8.2)
- CONOPS revision skill (open question §8.3)
- Framework versioning scheme (open question §8.4)
- Skill discoverability mechanism (open question §8.5)

**Ground truth docs**

- Intent: `.waypoint/conops.md`
- Standing orders: `.waypoint/opord.md`

**Plan**

- No plan document yet — project is in Ideation phase.
