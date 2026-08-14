---
name: update-waypoint
description: >
  Update a project's installed Waypoint framework from its source repository.
  Use when the developer asks to update Waypoint or when framework files are
  known to be stale. Pulls current source, reinstalls the framework-owned
  files, reports what changed, and merges OPORD baseline changes with the
  developer reviewing the diff.
---

# Skill: Update Waypoint

## Purpose

An update is a procedure with judgment in the middle. The installer does everything
deterministic (refreshing framework-owned files, healing old layouts, stamping the
version); this skill supplies the rest: finding the source, explaining what changed, and
merging OPORD baseline changes into a copy the developer has extended, which no script
can do safely.

## When to Use

- The developer asks to update Waypoint
- `waypoint update` was run and pointed here (it is a stub)
- A framework file is known to be stale relative to the source

Never run this against the Waypoint repository itself. That repo maintains its templates
by hand, and the installer refuses to target its own checkout.

## Process

### Step 1 — Read the stamp before anything else

Read `.waypoint/VERSION` and hold two values:

- `revision:` — the baseline this project was installed from. This is the merge base for
  Step 5. The reinstall in Step 3 overwrites the stamp, so capture it now.
- `origin:` — the repository the framework came from.

If VERSION or `origin:` is missing (an older install), ask the developer where their
Waypoint checkout or repository is. The reinstall stamps both going forward, so this
happens once.

### Step 2 — Get a current source

Use the developer's existing checkout if they have one; otherwise clone `origin:` to a
temporary location. Clone with full history, not shallow — Steps 4 and 5 need it. Do not
pull an existing checkout yourself; the installer does that.

### Step 3 — Reinstall

Detect the adapter from the installed rule file and run the matching command against the
project root:

- `.claude/rules/waypoint.md` exists → `<source>/waypoint install-claude <project>`
- `.cursor/rules/session-briefing.mdc` exists → `<source>/waypoint install-cursor <project>`
- neither → `<source>/waypoint install-core <project>`

This is the whole mechanical update: framework-owned files refresh, legacy layouts heal,
an unextended OPORD fast-forwards, and VERSION re-stamps. Project-owned files are never
touched. Do not hand-copy framework files.

### Step 4 — Report what changed

```
git -C <source> log <old-revision>..HEAD --oneline -- skills templates adapters
```

Summarize the range for the developer in plain language: what moved and whether anything
needs action from them. If the range is empty, say the project was already current and
stop after confirming the stamp.

### Step 5 — Merge the OPORD if the baseline moved

If `templates/opord.md` changed in that range and the installer reported the project's
OPORD was left alone (meaning it is extended), perform a three-way merge:

- **Base:** `git -C <source> show <old-revision>:templates/opord.md`
- **Theirs:** `<source>/templates/opord.md` (the new baseline)
- **Yours:** `.waypoint/opord.md` (the project's copy, with its extensions)

Apply the baseline's changes while preserving every project extension, and present the
result as a single file edit so the developer reviews it as a diff. **Never apply it
without their review, regardless of session permissions — you are editing your own
standing orders.** Where a baseline change conflicts with a project extension, show the
conflict and let the developer decide.

### Step 6 — Confirm and record

Verify `.waypoint/VERSION` stamps the new revision and `origin:`. Remove a temporary
clone if you made one. Record the update in this session's file under
`.waypoint/memory/`: the revision range crossed and whether an OPORD merge happened.

## Notes

- A written `conops.md` is never migrated by this skill. If the CONOPS template changed
  in a way the developer should consider, say so and let them decide separately.
- If the project has no `.waypoint/` at all, this is an install, not an update — use the
  installer directly per the README.
- This skill is itself a core skill: every update refreshes the update procedure.
