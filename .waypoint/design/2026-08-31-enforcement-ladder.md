# Design: The enforcement ladder

**Status:** Executed 2026-08-31 — shipped to the working tree on branch `v2` via the
plan at `.waypoint/plan/2026-08-31-enforcement-ladder.md`; execution notes in §10.
Approved the same day by the operator after revision in review (plain language
affirmed, "card" renamed, Cursor surface verified, plugin packaging rejected) and a
plan-review rescope: register repair became a register *boundary* — the OPORD and
CONOPS keep their format terms; plain language everywhere else (§3e).
**Scope:** Where rules live and how long they survive; adapter-level enforcement; the
register of the framework's own prose. Everything ships downstream; we inherit it too.

---

## 1. Problem

Three field reports:

1. **Instruction decay.** Late in a long session the agent violates standing rules it
   followed early. Concrete case: a project whose rules forbid popping question prompts
   sees the agent start popping them again after enough turns.
2. **Jargon escalation.** On tasks the agent reads as complex, prose density climbs until
   sentences are unintelligible even to people deep in the subject matter.
3. **"Everything is advisory, nothing is enforced."** Downstream users point out that the
   host tools have hooks and Waypoint uses none of them, so the agent can skip any
   instruction it holds loosely.

These look like three problems. The first two share a root cause, and the third is the
missing fix for both.

### 1a. Where an instruction lives determines how long it lives

A session's context has layers with very different lifetimes:

- **Durable:** the system prompt and always-on rule files. Re-sent every request.
  Survive compaction.
- **Recent:** the last stretch of conversation. Fully attended, rolling window.
- **Perishable:** old tool results. Attention-diluted as the session grows, and the first
  content summarized away when the harness compacts.

Waypoint puts a pointer in the durable layer (the adapter rule file: "read the OPORD")
and all actual policy in the perishable one — the OPORD's text enters context as a Read
result on turn one. Fifty turns later the standing orders are the oldest, least-attended
content in the window. After a compaction they are gone entirely; the pointer survives,
but nothing fires it again. §3a step 5 ("re-read these instructions") runs only at boot,
the one moment the orders are already fresh. The `resume` skill covers compaction but a
human has to invoke it, and humans rarely see the compaction happen.

The OPORD already documents the symptom. The tone duty ends: "This drifts back toward
polished, promotional phrasing over long sessions; treat that as an error to correct."
An instruction to resist decay is itself subject to decay. The perishable layer cannot
fix the perishable layer.

### 1b. Jargon has the same decay plus two amplifiers of its own

- **Register priming.** The framework speaks staff-officer: "Issuing HQ," "SUSTAINMENT,"
  "COMMAND & SIGNAL," "logistics line," "rules of engagement." The dogfooded corpus —
  design docs, memory files — is dense insider prose on top of that. Models match the
  register of what they read, and they escalate register on material that reads as
  high-stakes. A complex task plus an operationally-voiced corpus is exactly the trigger
  the field report describes. A correction from review: the OPORD's format terms are
  load-bearing for the document itself — the schema is part of its value. The defect is
  the register crossing out of the document into the corpus and the conversation; §3e
  draws that line rather than stripping the format.
- **The corpus feedback loop.** Every session boots on prior sessions' outputs. Drift
  written into `memory/` or `design/` today is read back as ground truth tomorrow.
  Waypoint is a drift integrator: it amplifies whatever style the model trends toward,
  because the corpus is the prompt.

Meanwhile the tone rule — the counterweight — is one bullet, two hundred words deep in
§3d, sitting in the perishable layer. It loses to both amplifiers on schedule.

### 1c. Advisory-only is a design decision whose bill has come due

The CONOPS promises no runtime and no dependencies, so every guarantee is a bet that a
frontier model follows Markdown instructions. Field evidence: the bet holds early in a
session, degrades with context length, and re-prices at every model update. The
framework already goes mechanical where a check is cheap and decidable — installer
ownership guarantees, drift tests in `test.sh`. That principle currently stops at
install time. Both host tools offer run-time mechanics; Waypoint declines them on
principle, and the principle is costing fidelity.

---

## 2. Design principle: every rule lives at the strongest layer that can hold it

The ladder, strongest first:

1. **Deterministic gates.** Host hooks that block an action outright. Reserved for rules
   a script can check: phase gating on file edits, a forbidden tool, a missing memory
   entry.
2. **Deterministic presence.** Host mechanisms that keep instructions in the attended
   window — always-applied rule files, and hooks that inject at session start, after
   compaction, or per prompt. The rule is guaranteed to be read; the model still
   exercises the judgment.
3. **Advisory prose.** Judgment calls: tone quality, design taste, when to ask. This is
   where everything lives today; after this design it is where only judgment lives.

Corollary: **the core stays Markdown; adapters carry the enforcement.** Policy in
`.waypoint/` remains vendor-neutral prose. An adapter compiles that policy into whatever
its host offers and degrades gracefully where the host offers less. "Thin adapter" was
never about line count; it is about adapters holding no policy of their own. That stays
true.

Everything an adapter installs is repo-local: rule files, hook scripts, and hook config
live inside the project (`.claude/`, `.cursor/`) and ship with it. Packaging the Claude
adapter as a Claude Code plugin was considered and rejected (operator decision,
2026-08-31): a plugin attaches to the tool, and Waypoint's enforcement must attach to
the repository — present for whoever opens this project, absent everywhere else.

This amends the CONOPS. "No runtime, no dependencies" softens to "no runtime required;
adapters may use host-native enforcement," and §6's "anything outside `.waypoint/`" was
already bent the day adapters shipped. The amendment should go through the CONOPS
revision path (CONOPS §8.3) deliberately, not slide in.

Layers 1 and 2 behave identically under any model. That is the hedge against the third
force in the field reports — model updates repricing instruction-following — and the
limit of the design: layer 3 remains model-dependent, and tone quality inside the
attended window always will be.

---

## 3. Proposed changes

### 3a. The standing rules — the always-in-context extract

Extract the rules that must never decay into a marked region of the OPORD, delimited
with HTML comments so extraction is mechanical:

```
<!-- standing-rules:begin -->
...the rules, ≤500 tokens, plain register...
<!-- standing-rules:end -->
```

Contents: the boot pointer, the phase gate, the question-prompt policy, the tone and
register-boundary lines, the memory duty, the confirmation rules. Nothing that needs
surrounding context to apply.

On the name: an earlier draft called this "the card." That was invented terminology —
not a convention in this space — and it violated the plain-language principle this very
design argues for. The mechanism itself is ordinary and widely practiced: a small,
always-present rules digest is exactly what `CLAUDE.md` and Cursor's always-applied
rules are for. "Standing rules" says what it is.

The standing rules are single-sourced in the OPORD. Every other appearance is made
mechanically: the installer copies the region verbatim into the adapter rule file at
install time (so it lands in the durable layer on every vendor, hooks or not), and
hooks re-inject it at run time. `test.sh` gets a drift test: extracted region ≡ the copy
in each installed rule file, same treatment as templates ≡ dogfood. The region is part
of the project-owned OPORD and rides the existing fast-forward/three-way-merge story.

### 3b. Claude Code adapter: injection hooks (the decay fix)

- **SessionStart, matchers `startup|resume|clear`:** inject the standing rules, the
  current phase line from `project.md`, and the §3a boot instruction. The boot becomes a
  delivery, not a request the model might shortcut.
- **SessionStart, matcher `compact`:** inject the standing rules plus "context was
  compacted; recover per §3a — read `project.md` and the most recent memory file." This
  is the automatic `resume`. Verified: the `compact` matcher exists and stdout injection
  is the documented pattern for exactly this use.
- **UserPromptSubmit:** inject one to three lines — current phase plus the most
  decay-prone rules (tone, question-prompt policy) — via
  `hookSpecificOutput.additionalContext`. Lands at the recency end of context on every
  turn, which is where register drift happens. Cost is tens of tokens per turn, appended
  after the cached prefix, so it does not disturb caching.

### 3c. Claude Code adapter: gates (the enforcement fix)

- **Phase gate — PreToolUse on `Edit|Write|NotebookEdit`:** while `project.md` says
  Ideation or Planning, deny edits to paths outside `.waypoint/`, with a reason that
  names the phase and the two legitimate ways forward: the operator approves a phase
  change in `project.md`, or sets the documented override for a `debug`-style session.
  Writes inside `.waypoint/` are always allowed, so producing designs, plans, and memory
  is never blocked. This turns the framework's central promise — no production code
  before an approved plan — from a hope into a mechanism.
- **Question gate — PreToolUse on `AskUserQuestion`:** deny with "present options and
  questions in prose instead." Ships with the adapter but off by default; the baseline
  OPORD legitimately wants questions surfaced on consequential decisions, so a hard
  block is a per-project choice, made by the projects whose rules already forbid prompt
  pop-ups. This is the deterministic fix for field report 1's concrete case.
- **Memory backstop — Stop hook:** if the git working tree changed during the session
  and no memory file dated today was touched, block the stop once with "record this
  session's memory (§3d) first." Block-once semantics: the hook checks
  `stop_hook_active` and always allows the second attempt, so it can remind but never
  trap. Sessions that changed nothing are never nagged.
- **Mechanics:** hooks are dependency-free shell scripts in `adapters/claude/hooks/`,
  installed to `.claude/hooks/`, wired through `.claude/settings.json`. The installer
  writes that file if absent; if it exists, it merges with `jq` when available and
  otherwise prints the exact fragment for the developer to paste. It never blind-edits a
  file it does not own. Verified: the PreToolUse deny shape (`permissionDecision:
  "deny"` with a reason fed back to the model) and Stop blocking are current, documented
  behavior.

### 3d. Cursor adapter: near parity, one real gap

Verified against cursor.com/docs/hooks (2026-08-31). Cursor hooks are documented and
project-scoped: config in `.cursor/hooks.json` at the repo root, scripts under
`.cursor/hooks/`, JSON over stdio, exit code 2 blocks, an optional `failClosed` flips a
hook from fail-open to fail-closed. Repo-local, which is exactly the deployment model
this design requires.

- **Presence comes mostly free.** The existing adapter rule is `alwaysApply`, and Cursor
  re-sends such rules on every request. Putting the standing rules *into* the rule file
  (3a) therefore gives Cursor durable presence, per-prompt presence, and
  compaction survival in one Markdown-only change — no hook involved. This is why 3a
  ships first.
- **`sessionStart` hook:** injects `additional_context` into the conversation's initial
  context — carries the boot instruction and the current phase, same payload as the
  Claude SessionStart hook. Caveat: `sessionStart` is not available to Cursor cloud
  agents; those still get the always-applied rule.
- **Phase gate — partial.** `afterFileEdit` is observational and cannot block, so Cursor
  cannot deny a file edit before it lands the way Claude's PreToolUse can. Two
  compensations: `beforeShellExecution` and `beforeMCPExecution` can deny, closing the
  shell-side write path during gated phases; and detect-and-correct — `afterFileEdit`
  flags an out-of-bounds edit, and the `stop` hook auto-submits a follow-up instructing
  the agent to revert or get a phase change approved. Weaker than a pre-deny, and the
  capability matrix (3f) says so plainly. Cursor's generic `preToolUse` can block tool
  calls and modify input; whether the agent's native edit mechanism passes through it is
  not clear from the docs — test during implementation (§7.4). If it does, Cursor gets
  the full gate.
- **Memory backstop:** the `stop` hook auto-submits the "record this session's memory"
  follow-up, guarded by its `loop_limit` so it reminds once rather than trapping.
- **No post-compaction hook.** `preCompact` is observational and nothing fires after
  compaction. Mitigated structurally: the standing rules live in the always-applied
  rule, so the durable layer never lost them; what compaction still costs on Cursor is
  the working state, and the always-present boot pointer plus `project.md` and the
  latest memory file are the recovery path, as today.
- **Ownership mechanics:** same rules as Claude — the installer writes
  `.cursor/hooks.json` if absent, merges or prints the fragment if the project already
  has one, never blind-edits.

### 3e. Register boundary (the jargon fix at the root)

Direction set by the operator, 2026-08-31, and refined in plan review: the OPORD and
CONOPS keep their names *and their format*. SITUATION, MISSION, EXECUTION, SUSTAINMENT,
COMMAND & SIGNAL are not decoration — they are the schema that makes an OPORD an OPORD,
the same way the CONOPS's fixed eight-section structure is already non-negotiable
(CONOPS §7). Part of both documents' value lives in that structure. It stays.

The fix is a boundary, not a ban:

- **Inside the two documents:** format terms stay. Body prose under the headings is
  still written plainly — the schema is format, but flourishes like "logistics line"
  are voice, and voice goes plain.
- **Everywhere else** — the agent's conversation in a user's project, memory files,
  designs, plans, feature docs, README, code comments — plain, normal language. The
  format terms never cross out of the documents that own them.
- **Promote tone out of the §3d bullet pile** into a short standalone section: the
  boundary stated explicitly, the falsifiable rules (a cold reader parses every
  sentence on first read; no term of art unless this repo defines it; a memory file's
  first line is plain language), and the corpus feedback loop named as the reason —
  the corpus is the next session's prompt, so jargon written today is jargon amplified
  tomorrow. The agent follows a rule better when the mechanism is named.
- **One boundary-and-tone line rides the standing rules**, which 3b re-injects per
  prompt on Claude and the always-applied rule carries per request on Cursor. The
  counterweight finally sits in the same window as the drift.

Residual risk: the priming input remains — the OPORD is read every
session in its own format. The bet is that an always-present boundary rule beats
stripping the format, and it preserves what the format is worth. Field testing
arbitrates; if register drift persists downstream, plainer headings are the fallback,
a decision to revisit then rather than pre-take now.

### 3f. The capability contract (README)

A short section stating, per adapter, what is enforced (gates), what is guaranteed
present (injection and always-applied rules), and what is advisory (judgment) — a
capability matrix. Claude Code: all three layers, including post-compaction recovery
and the full phase gate. Cursor: durable presence and session-start injection, shell
and MCP gates, detect-and-correct on file edits, no post-compaction hook. Core-only
installs: the boot instruction and prose. This turns "everything is advisory" from a
discovered disappointment into a stated contract, and makes adapter capability a
visible axis for anyone adding a vendor.

---

## 4. What this does not fix

Tool-result volume still dominates long-session cost; Waypoint still does not control
it. On-demand pulls can still be skipped — the map stays advisory. Tone quality within
the attended window remains model-dependent; presence guarantees the rule is read, not
that it is followed perfectly. And a model update can still change behavior at layer 3;
the design shrinks the exposed surface, it does not eliminate it.

---

## 5. Risks and tradeoffs

- **Scope amendment.** The no-runtime promise narrows to the core. Real change, done
  through CONOPS revision with intent (§2).
- **The installer touches host config it may not own** — `.claude/settings.json`,
  `.cursor/hooks.json`. Mitigated identically on both: create-if-absent, merge only via
  `jq`, otherwise print-and-instruct. Uninstall documented alongside.
- **Gate misfires erode trust faster than advisory misses.** Every deny names the rule
  and the way forward. The phase gate never blocks `.waypoint/` writes. The question
  gate is opt-in. The memory backstop blocks exactly once.
- **The standing rules are a second copy of OPORD content by construction** — prime
  drift territory. Mechanical extraction plus a drift test, the same discipline that
  guards templates ≡ dogfood.
- **Per-prompt presence is a recurring token cost.** The ≤500-token budget on the
  standing rules (and the far smaller per-prompt slice) is the control. If the region
  grows, that is a review flag, not a config knob.
- **Hook scripts are code Waypoint now ships and must test.** `test.sh` grows
  behavioral cases: phase parse, gate deny/allow paths, block-once, both vendors'
  config-merge paths. The operator has opened a separate follow-on discussion on moving
  the test harness to a real language (TypeScript or Go); hook tests should land in
  whatever harness that produces. The hook scripts themselves stay dependency-free
  shell regardless — a consumer's machine should not need a toolchain to be governed.

---

## 6. Migration

- Standing-rules extraction and register repair are OPORD baseline changes:
  fast-forward for provably unextended OPORDs, three-way merge via `update-waypoint`
  for extended ones. CHANGELOG marks them manual for extended installs.
- Adapter hooks land through the existing wholesale adapter refresh; the config
  fragment prints when a merge is not safe. Nothing forces a downstream project to
  enable gates — presence is the default win, gates are the offered one.
- `project.md` needs a parseable phase line (§7.3). Existing projects already match the
  `**Phase:**` convention; the change is specifying it, not migrating it.

---

## 7. Open questions

1. **Question gate default.** Off in the baseline (leaning), on for projects whose
   OPORD extension forbids prompt pop-ups. Is a toggle read from the standing-rules
   region enough signal for the hook, or does it stay "delete the hook entry to
   disable"?
2. **Phase grammar.** Bold line in `project.md` (zero migration, grep-able, leaning) vs
   YAML frontmatter (sturdier parse, new convention). Either way it gets a spec line in
   the OPORD and a test.
3. **Memory backstop carve-outs.** Is "working tree changed" the right trigger, or does
   a docs-only session deserve the reminder too?
4. **Cursor `preToolUse` vs native edits.** Does the agent's file-edit mechanism pass
   through the generic `preToolUse` hook (blockable) or only surface at `afterFileEdit`
   (observational)? The docs don't say. One implementation-time experiment decides
   whether Cursor gets the full phase gate or the detect-and-correct fallback.

Resolved during review (2026-08-31): plugin packaging is out — enforcement attaches to
the repo, not the tool (§2). Cursor's hook surface is verified, not open (§3d, §9).

---

## 8. Sequencing (proposed plan, pending approval)

1. **Standing-rules extraction + carried into both adapter rule files** (3a) —
   Markdown-only, no new mechanics, and on Cursor it already delivers per-prompt
   presence and compaction survival. Ship first.
2. **Claude SessionStart injection, all four matchers** (3b) — the decay fix and the
   automatic post-compaction resume. The single highest-value hook.
3. **Claude UserPromptSubmit reminder** (3b) — the drift-persistence fix.
4. **Register boundary** (3e) — tone section promotion, plain body prose, the boundary
   line into the standing rules.
5. **Gates + tests** (3c) — phase gate, memory backstop, opt-in question gate. Needs
   the phase grammar (§7.2) settled first.
6. **Cursor hooks** (3d) — sessionStart injection, shell/MCP gates, stop-hook
   backstop, and the §7.4 experiment.
7. **Capability contract** (3f) — README matrix, written once the above is real.

Each step is independently shippable. 1–3 are the highest value for the least risk and
none of them can block a user's action; the gates come only after the presence layer
has proven itself in field testing.

---

## 9. Grounding

Claude Code hook mechanics verified against current documentation on 2026-08-31:
SessionStart matchers include `compact` and stdout is injected into context (the
documented post-compaction re-briefing pattern); UserPromptSubmit injects via
`hookSpecificOutput.additionalContext`; PreToolUse matches built-in tools by name and
denies with a reason the model sees; Stop hooks block with a `stop_hook_active` loop
guard and a hard cap on consecutive blocks.

Cursor hook mechanics verified against cursor.com/docs/hooks on 2026-08-31: project
config at `.cursor/hooks.json`, JSON over stdio, exit 2 blocks, `failClosed` available;
`sessionStart` injects `additional_context` (not in cloud agents); `beforeShellExecution`
and `beforeMCPExecution` deny; `preToolUse` blocks or modifies tool input;
`afterFileEdit` and `preCompact` are observational; `stop` auto-submits follow-ups under
`loop_limit`. An earlier draft of this design wrongly reported Cursor's surface as
unverifiable — that was a research miss, corrected by reading the primary source.

Still unverified: Claude Code PreCompact's exact capabilities (not load-bearing here),
and §7.4.

---

## 10. Execution notes — 2026-08-31

Built in one working session; the body above stands as the decision record. Deviations
and findings:

- **A Claude shell gate was added** (`waypoint-shell-gate.sh`, PreToolUse on Bash),
  beyond the plan's T5 list. The edit-only gate had a trivial bypass: a shell command
  can write files too. Both editors now gate write-shaped shell commands outside
  `.waypoint/` during Ideation and Planning, with the same override.
- **§7.4 stays open, with a shipped default.** The preToolUse-vs-native-edits
  experiment needs a live Cursor session, which this environment does not have. The
  detect-and-correct variant (edit watcher + stop follow-up) shipped as the Cursor
  default; if field testing shows Cursor's `preToolUse` sees the native edit tools,
  the full pre-deny gate replaces it.
- **The register test caught a real leak on its first run**: the onboarding skill said
  "rules of engagement." Now reads "working rules."
- **Untracked-directory collapse**: `git status --porcelain` collapses a fully
  untracked `.waypoint/`, hiding dated memory files from the backstop. Both stop hooks
  use `-uall`.
- The open questions resolved as planned: question gate ships present but unwired;
  the phase line stays a bold Markdown line, specified in §3d and tested; the memory
  backstop triggers only when the tree changed outside `.waypoint/`.
- Suite: 67 → 127 assertions, green. Both template↔dogfood pairs identical; the
  composed rule-file copies are drift-tested against the OPORD region.
