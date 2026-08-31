Field reports of instruction decay, jargon escalation, and "everything is advisory" were analyzed to one root cause and drafted into the enforcement-ladder design, pending operator review.

- **2026-08-31 (Ideation):** The operator brought three field reports from testing and
  downstream users: (1) long sessions decay — rules followed early get violated late,
  e.g. question prompts popping up again after being forbidden; (2) prose density
  escalates with perceived task complexity until even experts can't parse it; (3)
  "everything is advisory, nothing is enforced" — the host tools have hooks and Waypoint
  uses none.

  **Diagnosis.** One root cause for the first two: Waypoint keeps a pointer in the
  durable context layer (the adapter rule file) but all actual policy in the perishable
  one — the OPORD arrives as a turn-one Read result, which is the oldest, least-attended
  content by mid-session and the first thing compaction erases. Nothing re-triggers a
  read; §3a's "re-read these instructions" fires only at boot, and `resume` needs a
  human to notice the compaction. Jargon adds two amplifiers: the framework's own
  staff-officer register primes the model, and the corpus feedback loop (each session
  boots on prior sessions' prose) integrates any drift. The tone rule fighting this is
  one buried §3d bullet living in the same perishable layer. The OPORD's own "this
  drifts back over long sessions" line is the proof: the perishable layer can't fix the
  perishable layer.

  **Decision drafted, not approved:** `.waypoint/design/2026-08-31-enforcement-ladder.md`.
  Principle: every rule lives at the strongest layer that can hold it — deterministic
  gates (hooks that block), deterministic presence (hooks that inject at session start,
  post-compaction, per prompt), advisory prose (judgment only). Core stays Markdown;
  adapters carry the enforcement. Key pieces: a ≤500-token "card" of standing rules
  single-sourced in a marked OPORD region and mechanically copied everywhere else;
  Claude adapter hooks (SessionStart incl. the `compact` matcher as an automatic
  `resume`, UserPromptSubmit reminder line, an opt-in AskUserQuestion deny, a phase gate
  on edits outside `.waypoint/` during Ideation/Planning, a block-once Stop memory
  backstop); register repair of the OPORD body (keep the names, drop the military
  voice); a README matrix stating what's enforced vs guaranteed-present vs advisory.
  Amends the CONOPS "no runtime" promise for adapters — flagged to go through the
  CONOPS revision path deliberately.

  **Verified against current Claude Code docs** (via the docs agent, 2026-08-31):
  SessionStart `compact` matcher + stdout injection, UserPromptSubmit
  `additionalContext`, PreToolUse deny-with-reason on built-in tools by name, Stop
  blocking with `stop_hook_active`. Unverified and flagged in the design: plugin
  auto-enable per repo, PreCompact capabilities, Cursor's hook surface.

  **Not done:** no OPORD, CONOPS, adapter, or installer changes; no plan document.
  Sequencing lives in design §8 as a proposal. Next action: operator reviews the design.

- **2026-08-31 (operator review, design revised in place):**
  - **Plain language affirmed.** OPORD and CONOPS survive as names; any military idiom
    past the names goes. Register repair is now a decided direction, not a proposal.
  - **"Card" renamed to "standing rules."** The operator asked whether "card" was
    standard notation. It isn't — it was invented terminology, which violated the
    plain-language principle the design itself argues. The mechanism (a small
    always-present rules digest) is ordinary practice; only the name was novel.
  - **Cursor's hook surface verified from the primary source** after the operator
    caught that the first pass wrongly reported it unverifiable (the docs agent came up
    empty and that answer was relayed without a direct check — a research miss worth
    remembering: verify primary sources before writing "unverifiable" into a design).
    cursor.com/docs/hooks: project-scoped `.cursor/hooks.json`, `sessionStart` injects
    `additional_context` (not in cloud agents), `beforeShellExecution`/
    `beforeMCPExecution`/generic `preToolUse` can block, `afterFileEdit` and
    `preCompact` observational, `stop` auto-submits follow-ups. Cursor is near parity;
    the real gap is no pre-deny on file edits (unless `preToolUse` intercepts native
    edits — implementation-time experiment, design §7.4) and no post-compaction hook
    (mitigated because the always-applied rule carries the standing rules every
    request). Cursor moved from "investigation-first" to a concrete adapter section.
  - **Plugin packaging rejected.** Enforcement attaches to the repo, not the tool;
    everything installs repo-local (`.claude/`, `.cursor/`). Open question closed.
  - **Test harness follow-on opened.** The operator is open to moving `test.sh` to
    TypeScript or Go; separate discussion. Hook scripts stay dependency-free shell
    either way.
  - Design doc revised in place (still Draft — Ideation). Next action unchanged:
    operator approval before Planning.

- **2026-08-31 (design approved, Planning):** Operator approved the revised design
  ("I'm good with this for now. Let's proceed."). Plan drafted:
  `.waypoint/plan/2026-08-31-enforcement-ladder.md` — seven tasks in the design's §8
  order (T1 standing-rules extraction and composition into both adapter rule files with
  a drift test; T2 Claude SessionStart injection incl. the compact matcher; T3 Claude
  per-prompt reminder; T4 register repair with a banned-terms test; T5 phase grammar
  plus the Claude gates; T6 Cursor hooks, opening with the preToolUse-vs-native-edits
  experiment; T7 README capability contract, CHANGELOG, and a separately-reviewed CONOPS
  amendment) plus closeout. The design's three leanings were adopted as plan decisions:
  question gate ships unwired, phase stays a bold first line in `project.md`, memory
  backstop triggers only on a changed tree. OPORD-baseline changes are batched (T1, T4,
  T5) so extended consumers get one coherent merge. Design status flipped to Approved;
  `project.md` phase moved to Planning. Next action: operator approves the plan, then
  Execution.

- **2026-08-31 (plan review: T4 rescoped to a register boundary):** The operator
  corrected T4's framing — the OPORD's five-paragraph terms (SITUATION, MISSION,
  EXECUTION, SUSTAINMENT, COMMAND & SIGNAL) and the CONOPS structure carry real meaning;
  stripping them would cost the documents their value. The rule is a boundary, not a
  ban: format terms stay inside the two documents that own them (body prose under the
  headings still goes plain), and everything the agent writes in a user's project —
  conversation, memory, designs, plans, feature docs — is plain, normal language. The
  register test rescopes accordingly: format terms banned from every shipped surface
  *except* the OPORD and CONOPS (standing-rules region, adapter rule templates, skills,
  memory README, other templates). Residual risk recorded in design §3e: the priming
  input remains since the OPORD is read every session; the always-present boundary line
  in the standing rules is the mitigation, plainer headings the fallback if field
  testing shows drift persisting. Design §1b/§3e/§8 and plan T4 updated. Plan still
  pending operator approval.

- **2026-08-31 (tone duty amended: no narrated candor):** The operator flagged
  "honestly rather than papering over" as unnatural, Claude-like language and asked
  whether it was already banned. Checked: the §3d tone duty bans inflated language,
  rhetorical framing, and manufactured contrast, but did not name self-narrated candor.
  Same shape as the em-dash rule from the 2026-08-14 review: recalled as existing,
  never written down. Amendment added to both OPORD copies: do not narrate your own
  candor ("honestly," "to be transparent," "stated plainly," "rather than papering
  over"); candor is the baseline, not a feature to announce. Cleaned the pattern out of
  this session's drafts, including renaming the design's "honesty contract" to
  "capability contract" (design §3f/§8, plan T7, project.md). Suite 67/67; both
  template↔dogfood pairs still identical. Extended downstream OPORDs take this line
  through the usual merge; batch its changelog caveat with T4's. Plan still pending
  operator approval.

- **2026-08-31 (new duty: no personal names):** Operator-directed §3d addition: the
  repository is shared and shipped, so people are referred to by role (the developer,
  the operator, a contributor), never by name. Audited the repo first: no personal name
  appears in any file's prose; LICENSE already says "Waypoint Contributors." Two
  residuals reported, untouched: the GitHub handle inside the functional clone URL
  (changing it means renaming the repo, not editing files) and git commit author
  metadata (history, not files; changing it means rewriting history). Duty added to
  both OPORD copies, placed beside "No paths outside this repo," which shares its
  rationale. Suite 67/67; template↔dogfood pairs identical. Another baseline line for
  the batched OPORD-merge caveat in T7's changelog entry. Plan still pending operator
  approval.

- **2026-08-31 (plan approved, Execution — the enforcement ladder shipped):** All
  seven tasks plus closeout, in the working tree on `v2`. What landed:
  - **OPORD (both copies):** standing-rules region between
    `<!-- standing-rules:begin/end -->` markers at the end; §3f Voice (checkable rules,
    the register boundary, the corpus feedback loop named); §3c retitled "Approval and
    Confirmation"; the tone bullet reduced to a pointer at §3f; §4's body prose
    plainified; the `**Phase:**` machine-read spec added to the project-state duty.
  - **Installer:** `compose_rule_files` splices the region into both adapter rule
    files on every install (placeholder or marked-block replacement, idempotent; a
    region-less OPORD gets a pointer at the update skill plus a warning);
    `install_claude_hooks`/`install_cursor_hooks` copy `waypoint-*.sh` wholesale,
    chmod, and wire `.claude/settings.json`/`.cursor/hooks.json` — created when
    absent, merged via jq with waypoint-entry dedupe when present, printed when it
    can't merge. Hook scripts are framework-owned by the `waypoint-` prefix.
  - **Claude hooks (6):** session-start (rules + phase + boot; `compact` argument
    variant delivers the recovery instruction), user-prompt (`additionalContext` with
    phase + Questions + Voice lines read from the region), phase-gate (deny
    Edit/Write/NotebookEdit outside `.waypoint/` in Ideation/Planning; fail-open on
    unreadable phase; `WAYPOINT_PHASE_GATE=off` override), shell-gate (same for
    write-shaped Bash commands — added beyond the plan because the edit-only gate had
    a trivial shell bypass), memory-backstop (Stop; block-once via
    `stop_hook_active`; `-uall` needed because porcelain collapses untracked dirs),
    question-gate (present, unwired; README shows the entry).
  - **Cursor hooks (4):** session-start (`additional_context`), shell-gate
    (deny write-shaped commands), edit-watch (records out-of-phase edits to
    `.cursor/waypoint-out-of-phase-edits`), stop (follow-up on flagged edits, then the
    memory reminder; `loop_count` guard, `loop_limit: 2`). The §7.4 experiment
    (does Cursor's preToolUse see native edit tools?) needs a live Cursor session —
    detect-and-correct shipped as the default; swap to pre-deny if field testing says
    it can.
  - **Docs:** README "What's enforced" matrix + question-gate/override instructions;
    CHANGELOG 2026-08-31 entry with the manual-merge callout; CONOPS amended for
    adapter hooks (§4, §5e, §6) — presented to the operator as its own diff.
  - **Verification:** suite 67 → 127, green; `bash -n` clean on installer, test.sh,
    and all ten hook scripts; dogfood pairs identical; the register test caught a real
    leak on its first run (onboarding skill said "rules of engagement", now "working
    rules").
  - **Field-test items:** the §7.4 Cursor experiment; whether the per-prompt reminder
    is the right size; whether the shell-gate heuristics false-positive in practice.
