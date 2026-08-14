# Waypoint

A `.waypoint/` directory of plain Markdown that gives your AI coding assistant persistent
project knowledge and a phase-gated workflow. No runtime, no dependencies, no service.
The assistant reads it at the start of every session, so you stop re-explaining your
project.

## Install

Clone Waypoint and run it against your project. The clone doesn't need to be permanent:
`.waypoint/VERSION` records where it came from, and updates can fetch the source
themselves (see [Staying current](#staying-current)).

```bash
git clone https://github.com/w-p/waypoint ~/src/waypoint

cd your-project
~/src/waypoint/waypoint install-claude    # Claude Code
~/src/waypoint/waypoint install-cursor    # Cursor
~/src/waypoint/waypoint install-core      # Templates and skills only, no adapter
```

Installs into the current directory unless you pass a path: `waypoint install-claude
/path/to/project`. There is no bare `install` — the script can't tell which editor you
use and won't guess.

You get `.waypoint/` plus one rule file for your editor (`.claude/rules/waypoint.md` or
`.cursor/rules/session-briefing.mdc`). Nothing else is touched — your existing
`CLAUDE.md` and rules are left alone. Commit all of it.

## Then write your CONOPS

```
Read .waypoint/skills/new-project.md and follow it.
```

The assistant interviews you about what you're building and writes `.waypoint/conops.md`
from that conversation. Don't write it yourself — the value is in the questions it asks.
Expect 15–45 minutes.

To check the wiring took: open a fresh session and say nothing but hello. You should get
`Ready.` and nothing else. Open with a real question instead and it briefly notes it's
coming up to speed, then answers.

## What's in `.waypoint/`

```
opord.md      Standing orders — what the assistant reads, how it behaves, code standards
conops.md     What the project is, who uses it, what's in and out of scope
project.md    Current phase, what shipped, what's deferred, where the docs are
memory/       One file per session; how context survives compaction and gaps
design/       Architecture decisions, written before anything is built
plan/         Sequenced work, written before anything is built
features/     As-built docs, written after something ships
skills/       Procedures the assistant follows for recurring activities
```

`opord.md` is yours once installed — extend it at the marked extension point in §3e with
your language conventions, test expectations, linting rules. `update` never overwrites it.

## Workflow

```
Ideation              →   Planning              →   Execution
Explore approaches        Break into tasks          Build from the plan
Debate tradeoffs          Set acceptance criteria   Document what shipped
Write design/*            Write plan/*              Update project.md + memory/
  ↓ you approve             ↓ you approve             ↓ feature complete
```

The point is that no code gets written before you've approved a design and a plan. The
current phase lives in `project.md`.

## Skills

| Skill | Use it when |
|---|---|
| `new-project` | Starting a Waypoint project; produces the CONOPS |
| `new-feature` | Adding a real capability, through all three phases |
| `new-skill` | You've explained the same procedure twice |
| `onboarding` | Briefing a contributor with no context |
| `resume` | Picking up after a gap or a compaction |
| `debug` | Something's broken; no phase gates |
| `update-waypoint` | Updating the installed framework from its source repo |

Point the assistant at one by name: `Read .waypoint/skills/debug.md and follow it.`

## Staying current

Updating is a skill, not a command. Tell your assistant:

```
Read .waypoint/skills/update-waypoint.md and follow it.
```

It finds your Waypoint source (`.waypoint/VERSION` records the repo and commit you
installed from), reinstalls the framework files, summarizes the changes you're crossing,
and merges OPORD baseline changes into your extended copy with you reviewing the diff.
That last part is the reason it's a skill: merging prose takes judgment a script doesn't
have.

The mechanical half is plain reinstalling, safe to run directly any time:

- **The checkout is pulled first**, so you get what's actually current rather than
  whatever you last happened to fetch. If it has local edits, is on a detached HEAD, has
  no upstream, or you're offline, it says so and carries on with the files on disk.
  `WAYPOINT_NO_PULL=1` skips the pull.
- **Framework-owned files are replaced wholesale**: core skills, your editor's adapter,
  the memory README. Skills you wrote yourself are never touched.
- **Project-owned files are never rewritten**: `project.md`, a written `conops.md`, and
  an OPORD you've extended. An OPORD you *haven't* extended is fast-forwarded to the new
  baseline automatically; the installer can prove nothing was lost.
- **Old layouts are healed.** A legacy single `memory.md` becomes a dated file inside
  `memory/`. A briefing that an old version embedded in your `CLAUDE.md` moves to
  `.claude/rules/waypoint.md`, and the stale block is reported for you to delete.
- **`conops-template.md`** is scaffolding. It's kept current while you have no CONOPS and
  removed once `conops.md` exists.

What changed between updates is in [CHANGELOG.md](CHANGELOG.md).

Changing the installer? `./test.sh` covers what reinstalling promises not to touch.

## Using Waypoint well

Keeping `project.md` current and memory well-named is the assistant's job, not yours — that's
the point. Your part is small:

- **Start a fresh chat for a new task.** A long-running chat carries its whole history forward
  and re-pays for it every turn. Waypoint exists so a fresh session comes up to speed in
  seconds — use it instead of nursing one endless thread.
- **Turn off tools you aren't using.** Idle integrations (MCP servers and the like) spend
  tokens describing themselves on every request whether or not you use them.

## What Waypoint doesn't do

It doesn't touch execution mechanics — no TDD enforcement, no git or branching strategy,
no commit conventions, no CI, no subagent orchestration. It governs what the assistant
*knows*; tools like [Superpowers](https://github.com/obra/superpowers) govern how it
*builds*. Run both if you want. Neither knows the other exists.

It also assumes a frontier model. Behavior on weaker models is untested.

## License

MIT
