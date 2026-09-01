# 2026-08-31 — Hook corrections from a field review

Fixed two enforcement-ladder hooks in both adapters — the memory backstop missed committed entries, and the shell gate's `.waypoint/` bypass waved through compound commands — with regression tests that fail against the old scripts.

## What happened

A review of the v2 branch from a downstream project (deciding whether to adopt it)
surfaced two defects in the hooks shipped by the enforcement ladder:

1. **Memory backstop** (`waypoint-memory-backstop.sh`, cursor `waypoint-stop.sh`):
   "was memory recorded today" was answered by grepping `git status --porcelain` for a
   dated path. Status only shows uncommitted files, so a session that committed its
   memory entry mid-session and kept working was blocked at stop anyway. Replaced with
   a file-existence check on `.waypoint/memory/<today>-*.md`, which is also the
   question the hook was actually asking.
2. **Shell gate** (`waypoint-shell-gate.sh`, both adapters): any command whose text
   mentioned `.waypoint/` anywhere passed wholesale, so
   `rm -rf src && echo done >> .waypoint/notes.md` cleared an Ideation gate. The gate
   now splits the command on `;`, `|`, `&` and denies if any write-shaped segment
   lacks `.waypoint/`. The header comments now state the design intent explicitly:
   a deterrent for a cooperating agent, not a security boundary.

## Verification

Four new test.sh assertions cover the compound-command bypass and the
committed-entry case for both adapters. Negative control run: with the hook fixes
stashed, exactly those four assertions fail (128 passed, 4 failed); with the fixes,
132 passed, 0 failed.

## Open

- The segment split is deliberately coarse: `2>&1` still reads as a write (as it did
  before the change), and a single segment can still mix a `.waypoint/` path with an
  outside write. Accepted under the deterrent-not-boundary intent.
