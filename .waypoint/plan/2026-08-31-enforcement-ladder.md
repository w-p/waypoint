# Plan: The enforcement ladder

**Design:** `.waypoint/design/2026-08-31-enforcement-ladder.md` (approved 2026-08-31)
**Status:** Executed 2026-08-31, all seven tasks plus closeout, in the working tree on
branch `v2`. Deviations from the written tasks are recorded in design §10: a Claude
shell gate was added (the edit-only gate had a trivial shell bypass), and T6's
preToolUse-vs-native-edits experiment needs a live Cursor session, so the
detect-and-correct variant shipped as the default and the experiment moved to field
testing.

Two properties up front. First, three tasks change the OPORD baseline (T1, T4, T5's spec
line), so extended downstream OPORDs take them through the `update-waypoint` three-way
merge; everything else lands mechanically via reinstall. Second, the design's three open
leanings are adopted here as decisions: the question gate ships disabled, the phase line
stays a bold Markdown line (no frontmatter), and the memory backstop triggers only when
the working tree changed. Each is called out in its task.

---

## T1 — Standing rules: extract, carry, guard

**Goal:** The rules that must never decay exist once in the OPORD and land in the durable
layer of every adapter mechanically.

**Changes:**

- `templates/opord.md` + `.waypoint/opord.md`: add the `<!-- standing-rules:begin/end -->`
  region — boot pointer, phase gate, question-prompt policy, two tone lines, memory duty,
  confirmation rules. ≤500 tokens, plain register. Condensed from the full sections, which
  stay authoritative for detail.
- `adapters/claude/rules/waypoint.md` + `adapters/cursor/rules/session-briefing.mdc`: gain
  an insertion marker. At install, the installer composes the rule file from the adapter
  template plus the region extracted verbatim from the project's `opord.md` (awk between
  markers). Reinstall recomposes, so an OPORD merge that changes the region propagates on
  the next update.
- `waypoint`: the extraction/composition step in `install_claude`/`install_cursor`.
- `test.sh`: drift test — in a sandbox install, the region in the installed rule file is
  byte-identical to the region in the project's `opord.md`; recomposition after an OPORD
  edit propagates.

**Acceptance:** fresh installs of both adapters carry the region; edited-region reinstall
propagates; extraction is pure POSIX (awk/grep, no jq); suite green; template↔dogfood
pairs still identical.

**Dependencies:** none. First — it alone gives Cursor per-prompt presence and compaction
survival.

---

## T2 — Claude adapter: session-start injection

**Goal:** The boot becomes a delivery. Compaction recovery becomes automatic.

**Changes:**

- `adapters/claude/hooks/session-start.sh`: reads the standing-rules region from
  `.waypoint/opord.md` and the phase line from `project.md`, emits them plus the §3a boot
  instruction on stdout. On the `compact` matcher, emits the region plus the recovery
  instruction ("context was compacted; read `project.md` and the most recent memory
  file") instead of the full boot. Dependency-free shell.
- `waypoint`: installs hook scripts to `.claude/hooks/`, wires `.claude/settings.json` —
  SessionStart entries for `startup|resume|clear` and `compact`. Settings handling:
  create if absent; merge via `jq` when available; otherwise print the exact fragment and
  instructions. Never blind-edit.
- `test.sh`: hook emits region + phase on a sandbox project; compact variant emits the
  recovery line; settings created when absent; existing settings without `jq` produce the
  printed fragment and an unmodified file.

**Acceptance:** fresh `install-claude` yields working hooks with zero manual steps on a
project with no prior `.claude/settings.json`; a project with one gets a correct merge or
a correct printout; `bash -n` clean on all scripts; suite green.

**Dependencies:** T1 (injects the region).

---

## T3 — Claude adapter: per-prompt reminder

**Goal:** The decay-prone rules sit at the recency end of every turn.

**Changes:**

- `adapters/claude/hooks/user-prompt.sh`: emits `hookSpecificOutput.additionalContext`
  JSON with one to three lines — current phase plus the tone and question-prompt rules
  (read from the region, not hardcoded, so project extensions ride along).
- `waypoint` + `test.sh`: wiring as in T2; test asserts valid JSON shape and content.

**Acceptance:** hook output is well-formed on a sandbox project; payload stays under a
tested line-count cap; suite green.

**Dependencies:** T2 (shares the settings wiring).

---

## T4 — Register boundary

**Goal:** The OPORD and CONOPS keep their format — the five-paragraph terms and the
eight-section structure are the documents' value, not decoration. What changes is that
the format never crosses into a user's sessions: everything the agent writes is plain,
normal language.

**Changes:**

- `templates/opord.md` + `.waypoint/opord.md`: the section structure and format terms
  (SITUATION, MISSION, EXECUTION, SUSTAINMENT, COMMAND & SIGNAL, Issuing HQ) stay. A
  body-prose pass under the headings makes the sentences plain; voice-only flourishes
  ("logistics line") go. Promote tone from the §3d bullet to its own short section: the
  register boundary stated explicitly (format terms belong to the OPORD and CONOPS and
  never appear in the agent's own prose — conversation, memory, designs, plans, feature
  docs, README, comments), the falsifiable rules (cold reader parses every sentence
  first read; no term of art the repo doesn't define; memory first lines in plain
  language), and the corpus feedback loop named as the reason.
- Standing-rules region (T1): carries the one-line boundary-and-tone rule so it is
  re-delivered per prompt on Claude and per request on Cursor.
- `test.sh`: register test, rescoped — the format terms appear in no shipped surface
  *other than* the OPORD and CONOPS: the extracted standing-rules region, both adapter
  rule templates, all skills, the memory README, and the remaining templates. The
  always-injected text is the register the model sees most often, so it especially must
  be plain. (Session prose itself isn't testable here; that's what the per-prompt
  reminder is for.)
- `CHANGELOG.md` note (in T7) flags the manual merge for extended OPORDs.

**Acceptance:** register test green; OPORD section structure unchanged; tone section
reads as specified; template↔dogfood identical.

**Dependencies:** T1 (edits the same file and the region; sequence avoids merge noise).
Independent of T2/T3.

---

## T5 — Phase grammar and Claude gates

**Goal:** The framework's central promise — no production code before an approved plan —
becomes a mechanism. The memory duty gets a backstop.

**Decisions adopted:** phase is the first body line of `project.md`, matching
`**Phase:** <Ideation|Planning|Execution>` with optional prose after; the question gate
ships present but unwired; the memory backstop triggers only when the tree changed
outside `.waypoint/`.

**Changes:**

- `templates/project.md` + OPORD project-state duty: one spec line each for the phase
  grammar.
- `adapters/claude/hooks/phase-gate.sh` (PreToolUse on `Edit|Write|NotebookEdit`): parse
  phase; during Ideation/Planning deny writes outside `.waypoint/` with a reason naming
  the phase, the approval path, and the documented override (`WAYPOINT_PHASE_GATE=off`).
  Unparseable phase fails open with a one-line warning — a broken `project.md` must not
  brick editing.
- `adapters/claude/hooks/memory-backstop.sh` (Stop): tree changed outside `.waypoint/`
  and no memory file dated today created or modified → block once with the §3d reminder;
  honor `stop_hook_active` so the second attempt always passes.
- `adapters/claude/hooks/question-gate.sh` (PreToolUse on `AskUserQuestion`): deny with
  "present options and questions in prose instead." Installed to `.claude/hooks/` but not
  wired into the settings fragment; enabling is adding the documented entry.
- `test.sh`: phase parse (all three phases + garbage); gate denies a source write in
  Ideation, allows `.waypoint/` writes always, allows everything in Execution; override
  respected; backstop blocks once and only when the tree changed; question gate denies
  with the right reason when wired.

**Acceptance:** all gate paths tested green; the dogfooded `project.md` parses; no gate
can block `.waypoint/` writes in any phase.

**Dependencies:** T2 (settings wiring). The phase-grammar spec line is an OPORD baseline
change; batch its CHANGELOG caveat with T4's.

---

## T6 — Cursor adapter: hooks

**Goal:** Cursor gets everything its surface supports, and the §7.4 question gets
answered by experiment, not assumption.

**Changes:**

- **First, the experiment (design §7.4):** in a scratch Cursor project, determine whether
  the agent's native file edits pass through the generic `preToolUse` hook (blockable) or
  surface only at `afterFileEdit` (observational). The result picks the phase-gate
  variant below and is recorded in the design as a revision note.
- `adapters/cursor/hooks/`: `session-start` (emit `additional_context`: region + phase +
  boot instruction), phase gate (full pre-deny via `preToolUse` if the experiment says
  yes; otherwise `beforeShellExecution`/`beforeMCPExecution` deny plus
  `afterFileEdit`-flag-and-`stop`-follow-up detect-and-correct), memory backstop (`stop`
  auto-submit under `loop_limit`).
- `waypoint`: install scripts to `.cursor/hooks/`, write or merge `.cursor/hooks.json`
  with the same create/merge/print ownership rules as T2.
- `test.sh`: script I/O tested directly (feed the documented stdin JSON, assert stdout/
  exit codes); config creation and merge paths covered.

**Acceptance:** fresh `install-cursor` yields working hooks with zero manual steps on a
clean project; experiment outcome recorded; suite green.

**Dependencies:** T1, T5 (ports the gate logic; keep the phase-parse snippet in one
shared sourced file under each adapter's hooks dir to avoid drift between copies).

---

## T7 — Shipped docs

**Goal:** The contract is stated, not discovered.

**Changes:**

- `README.md`: the capability contract — per adapter, what is enforced, what is guaranteed
  present, what is advisory; the capability matrix (Claude full; Cursor per T6 outcome;
  core-only prose); a short note on enabling the question gate and the phase-gate
  override.
- `CHANGELOG.md`: dated human-facing entry; explicitly lists the manual OPORD merge for
  extended installs (T1 region, T4 voice, T5 spec line) and that everything else is
  mechanical.
- CONOPS amendment (operator-reviewed, per design §2): "no runtime required; adapters
  may use host-native enforcement," and the §6 scope line adjusted. Presented as its own
  small diff for sign-off, not slipped in.

**Acceptance:** docs agree with behavior and restate nothing owned elsewhere; CONOPS diff
approved explicitly.

**Dependencies:** T1–T6.

---

## Closeout (after T1–T7)

- **Verify:** `./test.sh` green; `bash -n` on installer and every hook script; a
  read-through of installed output on fresh sandbox installs of both adapters.
- **`project.md`:** phase and shipped list updated; ground-truth index checked.
- **Memory:** dated entry — what shipped, decisions, deviations.
- **Design doc:** status flipped to Executed; §7.4 outcome recorded.
- **This plan:** status flipped to Executed.

---

## Sequence

T1 → T2 → T3 → T4 → T5 → T6 → T7 → Closeout. T1–T3 cannot block a user action and land
the decay fix; the gates (T5, T6) come only after the presence layer exists, matching the
design's field-testing posture. T4 sits between them so the OPORD baseline changes (T1,
T4, T5) arrive as one coherent merge for extended consumers rather than three.
