# Memory

Cross-session continuity log. Each session writes its **own file** here — never a shared,
static file — so parallel sessions and branches don't collide in merges.

## Convention

- **One file per session**, named `YYYY-MM-DD-<slug>.md`
  (e.g. `2026-07-09-auth-redesign.md`). The date prefix keeps the folder sorted
  chronologically; the slug names the session's focus.
- Create the file on the first meaningful write of the session, then append to it.
- **Reading:** load the most recent files first — enough to grasp the current state.
  Skip this `README.md`; it is not a memory entry.

## Entry format

Within a file, each entry is a dated bullet:

```
- **YYYY-MM-DD:** What happened, what was decided, why, and the current state.
```

Write for your future self after a context compaction. Assume the reader has no prior
knowledge of this project or session. Be brief but complete. Link to documents when relevant.
Do not delete old files.
