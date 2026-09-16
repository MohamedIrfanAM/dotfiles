---
description: Update the project context store before this chat ends
---

Update the current project's context store so the next chat — in any worktree — starts warm.

Run `ctx` first. It prints the active project, the current task, **and which rule picked them** —
if that isn't the work this chat actually did, or `ctx` reports it can't tell, ask me rather than
guessing. A project can span several repos, so the repo you're rooted in does not identify the
work on its own.

Then:

1. **`INDEX.md`** — rewrite the `**Updated:**`, `**Status:**`, `## Current state` and
   `## Next steps` sections so they describe reality *right now*. Correct stale lines in place;
   do not append a contradicting bullet next to an outdated one. Keep it a router under ~120
   lines — it must stay cheap to read at the start of every chat.
2. **`tasks/<current-task>.md`** — append what happened to the `## Log` section with today's date.
   Update its `**Status:**` line. If this session's work has no task file and it was a distinct
   slice of work, create one with `ctx task`. If it *continued* a task that started in another repo,
   append to that existing file — `ctx task <project> <slug>` here records this repo, worktree and
   branch on it. Never fork a second file for the same task.
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

6. **Name the repo when it matters.** The next chat may be rooted in a different repo of the same
   project, so "the values file" is ambiguous — write which repo a path or rule belongs to.

Do not copy code, manifests, or full file contents into the store — reference paths instead.

Finally, show me `git -C ~/Desktop/ctx diff` and stop. Ask before running `ctx save`.
