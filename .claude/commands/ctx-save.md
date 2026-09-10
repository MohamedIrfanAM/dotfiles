---
description: Update the project context store before this chat ends
---

Update the current project's context store so the next chat — in any worktree — starts warm.

Run `ctx` first to see which repo and project you're in. If `ctx` reports it can't tell which
project, ask me rather than guessing.

Then:

1. **`INDEX.md`** — rewrite the `**Updated:**`, `**Status:**`, `## Current state` and
   `## Next steps` sections so they describe reality *right now*. Correct stale lines in place;
   do not append a contradicting bullet next to an outdated one. Keep it a router under ~120
   lines — it must stay cheap to read at the start of every chat.
2. **`tasks/<current-task>.md`** — append what happened to the `## Log` section with today's date.
   Update its `**Status:**` line. If this session's work has no task file and it was a distinct
   slice of work, create one with `ctx task`.
3. **`DECISIONS.md`** — promote any finding that a future chat would otherwise pay to re-derive:
   live-cluster state, a dead end and why it's dead, a non-obvious constraint, a fix whose reason
   isn't visible in the diff. Use a dated `## <topic> (YYYY-MM-DD)` heading and add a row to that
   file's index table. Create the file if it doesn't exist, and add it to `INDEX.md`'s
   "Read only if relevant" list when you do.
4. **Prune.** Delete anything now recorded in git history — a finished "done" checklist, a
   completed migration's step list. The store carries *why* and *what's left*, not *what happened*.
   Git records the rest.
5. **Fix, don't accumulate.** If you find an entry that is no longer true, correct it. A stale
   entry is worse than a missing one, because the next agent will act on it.

Do not copy code, manifests, or full file contents into the store — reference paths instead.

Finally, show me `git -C ~/Desktop/ctx diff` and stop. Ask before running `ctx save`.
