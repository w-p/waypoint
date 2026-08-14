# Memory

Cross-session continuity log. Each session writes its **own file** here — never a shared,
static file — so parallel sessions and branches don't collide in merges.

The filenames are also the index. The boot (OPORD §3a) lists this folder to see what exists
and opens only what the task needs, so a file's name and its first line carry real weight —
they are what a future session reads before deciding whether to open the file at all.

## Naming

- **One file per session**, named `YYYY-MM-DD-<slug>.md`
  (e.g. `2026-07-09-auth-redesign.md`). The date prefix sorts the folder chronologically.
- **Name the slug for the subject, not the activity.** `installer-permission-fix`, not
  `fixes`; `oauth-token-refresh`, not `changes`. Prefer the noun — the thing worked on — over
  a vague verb. A name that could describe any session is a blind spot in the index.
- **Keep it to roughly 3–6 words / 50–60 characters.** That is well under every filesystem's
  limit (255 bytes per name; Windows' old 260-character full-path cap only bites in deep
  trees, which this folder is not), so being informative never risks being too long.
- Create the file on the first meaningful write of the session, then append to it.

## The two-tier index

A reader finds what matters cheaply, descending only as far as needed:

1. `ls` the folder — the filenames alone are the map.
2. `head -1` a file — its standalone one-line summary, when the name is ambiguous.
3. Open the file — only when it is relevant to the task at hand.

So **lead every file with a one-line summary that stands on its own**, and give the file a
name that tells the truth about its contents.

## Entry format

Within a file, each entry is a dated bullet, most recent last:

```
- **YYYY-MM-DD:** What happened, what was decided, why, and the current state.
```

Write for your future self after a context compaction. Assume the reader has no prior
knowledge of this project or session. Be brief but complete. Link to documents when relevant.

## Upgrading a weak name

When you notice an existing file whose name or first line undersells its contents, improve the
index — safely. Memory files are the assistant's own artifacts, but a rename ripples through
every reference to the old name, so propose it and get the developer's go-ahead like any other
refactor:

- **Prefer strengthening the first line.** Rewriting the file's opening summary breaks no
  references and is usually enough to make the file findable.
- **Rename only for genuinely misleading names**, as a small refactor:
  1. Propose the new name and get approval.
  2. `grep` the repo for the old filename.
  3. `git mv` the file (preserves history).
  4. Update every reference you found (`project.md`, other memory files, design docs,
     `CHANGELOG.md`).
  5. Verify nothing dangles.

  Change the slug only — **never the `YYYY-MM-DD` prefix**, which is the stable sort key and
  the part most often referenced.

## Keeping the folder small

Memory is read at boot, so it should not grow without bound:

- The most-recent file is always kept verbatim — it is the gap- and compaction-recovery read.
- Keep recent sessions verbatim. When the folder grows large, fold older sessions into a
  single `archive.md` digest — a lossy summary is fine here, because git history keeps the
  originals. The `ls` map still lists whatever remains.

Skip this `README.md` when reading memory; it is the convention, not an entry.
