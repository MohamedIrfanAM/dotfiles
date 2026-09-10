---
description: Scaffold a project's context store from a plan-mode plan
argument-hint: [project-name] [path-to-plan]
---

Turn a plan into a project context store, so every future chat about this work starts warm.

Arguments (both optional): `$ARGUMENTS` — first is the project name, second is a path to the plan.

## 1. Find the plan

In order of preference:
- A plan path given in `$ARGUMENTS`.
- The plan produced in *this* session, if we just came out of plan mode.
- Otherwise list `~/.claude/plans/` by modification time (`ls -lat ~/.claude/plans/`) and **ask me
  which one** — do not assume the newest is the right one.

Read the whole plan before writing anything.

## 2. Create the project

Work out the project name from `$ARGUMENTS`, else the plan's subject, else the current branch.
Use the repo's existing naming convention (check `ctx ls` and the directory names in the repo).

```sh
ctx new <name>
```

That scaffolds `INDEX.md`, creates `tasks/`, registers the project in the repo's auto-loaded
`CLAUDE.md`, and wires this worktree if it isn't already. If `ctx new` reports the project already
exists, stop and ask me whether to overwrite `INDEX.md` or merge into it.

## 3. Write INDEX.md

Replace the placeholders. **This is a router, not a copy of the plan** — cap it at ~120 lines.
Every chat pays to read it, so density matters more than completeness.

- `**Status:**` — one line on where this actually stands. At init that's usually "planned, nothing
  built yet".
- `## What this is` — 2–4 sentences: goal, target env/cluster/namespace, and the one hard
  constraint. Include concrete identifiers (project, cluster, namespace, hostname) since those are
  what future chats look up.
- `## Current state` — 5–8 bullets of what is true *now*. At init, mostly "not started".
- `## Next steps` — the plan's first concrete actions, numbered, in order. If the plan has phases,
  this is phase 1 only — not all of them.
- `## Deferred` — everything the plan explicitly scopes out or leaves for later.
- `## Where things live` — repo path, the directories this work touches, and a link to the plan
  file itself.

**Link to the plan, don't inline it.** Add it under "Read only if relevant" with a one-line note on
what it's still the source of truth for. If the plan is long, say which sections matter.

## 4. Seed DECISIONS.md — only if the plan has real decisions

Many plans have a "decisions already confirmed / not re-litigated" section, or reject alternatives
with reasons. Those are exactly the don't-re-derive facts worth keeping. If the plan has them,
create `DECISIONS.md` with a dated `## <topic> (YYYY-MM-DD)` entry each, plus the index table at
the top, and add the file to `INDEX.md`'s "Read only if relevant" list.

If the plan has no such content, **do not create the file.** An empty `DECISIONS.md` that an agent
reads is pure waste.

## 5. Optional: seed task files

If the plan splits into phases you'll work on separately — likely in different worktrees — create a
task file per phase with `ctx task <project> <phase-slug>` and put that phase's goal and steps in
it. Don't do this for a plan you'll execute in one sitting.

## 6. Finish

Run `ctx` to confirm the wiring, show me `git -C ~/Desktop/ctx diff`, and stop. Ask before running
`ctx save`.

Do not copy code or manifests into the store — reference paths.
