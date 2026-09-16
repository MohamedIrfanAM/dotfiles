# ctx — agent context store manager
#
# Durable per-project context that lives OUTSIDE any repo, so a fresh Claude Code chat starts warm
# instead of re-deriving everything.
#
# Projects and tasks are NOT owned by a repo, a worktree or a branch. A project lives once at the
# store root; each repo that touches it gets a symlink to it inside that repo's view directory
# (_repos/<repo>/), which is what ./context points at. So one project can span several repos, and
# the same task file is reachable as @context/<project>/tasks/<file>.md from every one of them.
#
# Store layout + conventions: $CTX_ROOT/README.md
#
# Sourced from .zshrc. Defines one function, `ctx`. Everything is inferred from cwd — there are
# almost no flags on purpose. Run `ctx help` for the surface.

# Interactive aliases (grep=rg, cat=bat, ls=eza) are expanded at function-DEFINITION time, so
# without this they get baked into every function below and corrupt generated files. Disable them
# while this file is parsed, then restore whatever the user had.
_ctx_had_aliases=$options[aliases]
setopt no_aliases

export CTX_ROOT="${CTX_ROOT:-$HOME/Desktop/ctx}"

# ---------------------------------------------------------------------------
# resolution — everything below reads these globals after _ctx_resolve
# ---------------------------------------------------------------------------

# Store-level paths. Never depend on being inside a repo.
_ctx_paths() {
  _CTX_REPOS="$CTX_ROOT/_repos"
  _CTX_STATE="$CTX_ROOT/_state"
  _CTX_PINS="$_CTX_STATE/pins"
}
_ctx_paths

# Populates: _CTX_TOP _CTX_COMMON _CTX_REPO _CTX_VIEW _CTX_BRANCH. Fails outside a git repo —
# only the wiring commands need it; project/task commands work store-wide without it.
_ctx_resolve() {
  _CTX_COMMON=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || {
    print -u2 "ctx: not inside a git repo"; return 1
  }
  _CTX_TOP=$(git rev-parse --show-toplevel)
  _CTX_BRANCH=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || print "")
  # repo identity comes from the MAIN worktree, so every linked worktree agrees
  _CTX_REPO=${$(git worktree list | head -1 | awk '{print $1}'):t}
  _CTX_VIEW="$_CTX_REPOS/$_CTX_REPO"
  return 0
}

# Every project in the store, one per line.
_ctx_projects() {
  [[ -d $CTX_ROOT ]] || return 0
  local d
  for d in "$CTX_ROOT"/*(N/); do
    [[ ${d:t} == _* ]] && continue
    print -- "${d:t}"
  done
}

# Projects linked into this repo's view.
_ctx_view_projects() {
  [[ -n $_CTX_VIEW && -d $_CTX_VIEW ]] || return 0
  local d
  for d in "$_CTX_VIEW"/*(N-/); do print -- "${d:t}"; done
}

# Repos whose view links to <project>. This is the project↔repo mapping — derived from the
# symlinks, never stored twice.
_ctx_project_repos() {  # $1 project
  [[ -d $_CTX_REPOS ]] || return 0
  local r
  for r in "$_CTX_REPOS"/*(N/); do
    [[ -e $r/$1 ]] && print -- "${r:t}"
  done
}

# ---------------------------------------------------------------------------
# pins — an explicit "this worktree is working on X", keyed by worktree path
# ---------------------------------------------------------------------------
# Inference covers the common cases; a pin covers the rest, which is what makes a task reachable
# from a repo that has nothing to do with its name or branch. Machine-local, so gitignored.

_ctx_pin_get() {  # prints "<project>\t<task-file>" for this worktree
  [[ -f $_CTX_PINS && -n $_CTX_TOP ]] || return 1
  local line
  line=$(awk -F'\t' -v w="$_CTX_TOP" '$1==w { print $2 "\t" $3; exit }' "$_CTX_PINS")
  [[ -n $line ]] || return 1
  print -r -- "$line"
}

_ctx_pin_set() {  # $1 project  $2 task file basename (optional)
  [[ -n $_CTX_TOP ]] || return 1
  mkdir -p "$_CTX_STATE"
  local tmp; tmp=$(mktemp) || return 1
  [[ -f $_CTX_PINS ]] && awk -F'\t' -v w="$_CTX_TOP" '$1!=w' "$_CTX_PINS" > "$tmp"
  printf '%s\t%s\t%s\n' "$_CTX_TOP" "$1" "${2:-}" >> "$tmp"
  mv "$tmp" "$_CTX_PINS"
}

_ctx_pin_clear() {  # drops this worktree's pin
  [[ -f $_CTX_PINS && -n $_CTX_TOP ]] || return 1
  local tmp; tmp=$(mktemp) || return 1
  awk -F'\t' -v w="$_CTX_TOP" '$1!=w' "$_CTX_PINS" > "$tmp"
  mv "$tmp" "$_CTX_PINS"
}

_ctx_pin_drop_task() {  # $1 project  $2 task file — keeps the project pin, forgets the task
  [[ -f $_CTX_PINS ]] || return 0
  local tmp; tmp=$(mktemp) || return 1
  awk -F'\t' -v OFS='\t' -v p="$1" -v t="$2" '
    $2==p && $3==t { print $1, $2, ""; next } { print }
  ' "$_CTX_PINS" > "$tmp"
  mv "$tmp" "$_CTX_PINS"
}

_ctx_pin_drop_project() {  # $1 project — used by archive
  [[ -f $_CTX_PINS ]] || return 0
  local tmp; tmp=$(mktemp) || return 1
  awk -F'\t' -v p="$1" '$2!=p' "$_CTX_PINS" > "$tmp"
  mv "$tmp" "$_CTX_PINS"
}

# ---------------------------------------------------------------------------
# task files — refs are lists, so one task spans repos/worktrees/branches
# ---------------------------------------------------------------------------

# The **Repos:** / **Worktrees:** / **Branches:** line of a task file. Singular labels from the
# pre-multi-repo layout still match.
_ctx_ref_line() {  # $1 base label (Repo|Worktree|Branch)  $2 file
  grep -m1 -E "^\*\*$1(e?s)?:\*\*" "$2" 2>/dev/null
}

# Does this task file list <value> under <label>? Matches anywhere on the line, so every repo,
# worktree and branch a task has lived on keeps resolving.
_ctx_task_has_ref() {  # $1 file  $2 base label  $3 value
  _ctx_ref_line "$2" "$1" | grep -qF -- "\`$3\`"
}

# Append a backtick-quoted value to a task file's ref line. No-op (returns 1) if already listed.
# A file that has no such line yet (hand-written, or pre-dating the multi-repo layout) gets one.
_ctx_task_add_ref() {  # $1 file  $2 base label  $3 value
  local file=$1 base=$2 val=$3 line lbl tmp plural
  [[ -f $file ]] || return 1
  [[ -n $val ]] || return 1
  _ctx_task_has_ref "$file" "$base" "$val" && return 1
  line=$(_ctx_ref_line "$base" "$file")
  if [[ -z $line ]]; then
    case $base in
      Repo) plural=Repos ;; Worktree) plural=Worktrees ;; Branch) plural=Branches ;;
      *)    plural="$base" ;;
    esac
    tmp=$(mktemp) || return 1
    # slot it in above **Status:**, which every task file has right after the ref block
    awk -v new="**$plural:** \`$val\`" '
      !added && index($0, "**Status:**") == 1 { print new; added=1 }
      { print }
      END { exit(added ? 0 : 1) }
    ' "$file" > "$tmp" || { rm -f "$tmp"; return 1 }
    mv "$tmp" "$file"
    return 0
  fi
  lbl="${line%%:*}:**"          # "**Branches:** `a`" -> "**Branches:**"
  tmp=$(mktemp) || return 1
  awk -v lbl="$lbl" -v v="$val" '
    !added && index($0, lbl) == 1 { print $0 ", `" v "`"; added=1; next }
    { print }
    END { exit(added ? 0 : 1) }
  ' "$file" > "$tmp" || { rm -f "$tmp"; return 1 }
  mv "$tmp" "$file"
}

# Record this repo/worktree/branch on a task file. Prints what it added.
_ctx_task_record_here() {  # $1 file
  local -a added
  [[ -n $_CTX_REPO ]]   && _ctx_task_add_ref "$1" Repo     "$_CTX_REPO"   && added+=("repo '$_CTX_REPO'")
  [[ -n $_CTX_TOP ]]    && _ctx_task_add_ref "$1" Worktree "$_CTX_TOP"    && added+=("worktree '$_CTX_TOP'")
  [[ -n $_CTX_BRANCH ]] && _ctx_task_add_ref "$1" Branch   "$_CTX_BRANCH" && added+=("branch '$_CTX_BRANCH'")
  (( ${#added} )) && print "ctx: recorded ${(j:, :)added} on ${1:t}"
  return 0
}

# Find a task file by slug (or exact filename) anywhere in a project.
_ctx_find_task() {  # $1 project dir  $2 slug-or-filename
  local -a hits
  hits=("$1"/tasks/*-${2}.md(N) "$1"/tasks/${2}(N) "$1"/tasks/${2}.md(N))
  (( ${#hits} )) || return 1
  print -r -- "$hits[1]"
}

# Every task file matching a slug, deduped. `smtp` matches both 2026-09-10-smtp.md and
# 2026-09-16-discourse-poc-smtp.md — a caller that deletes must see both, not the first.
_ctx_find_tasks() {  # $1 project dir  $2 slug-or-filename
  local -a hits
  hits=("$1"/tasks/*-${2}.md(N) "$1"/tasks/${2}(N) "$1"/tasks/${2}.md(N))
  (( ${#hits} )) || return 1
  print -l -- ${(u)hits}
}

# The values on a ref line, backticks and label stripped: "`a`, `b`" -> "a, b"
_ctx_ref_values() {  # $1 base label  $2 file
  _ctx_ref_line "$1" "$2" | sed -E 's/^\*\*[A-Za-z]+:\*\* *//; s/`//g'
}

# A task's **Status:** as one short line, markdown bold stripped.
_ctx_task_status() {  # $1 file  $2 max width
  local st
  st=$(grep -m1 -E '^\*\*Status:' "$1" 2>/dev/null | sed -E 's/^\*\*Status:\*\* *//')
  st=${st//\*\*/}
  (( ${#st} > $2 )) && st="${st[1,$(($2-1))]}…"
  print -r -- "$st"
}

# ---------------------------------------------------------------------------
# inference — project, then task. Both consult the WHOLE store, not one repo.
# ---------------------------------------------------------------------------

# Sets _CTX_PROJECT / _CTX_PDIR / _CTX_PSRC (how it was picked).
# Order: $CTX_PROJECT > pin > task file recording this branch > branch == project
#        > longest project name prefixing the branch > cwd > sole project.
_ctx_project() {
  local -a projects; projects=("${(@f)$(_ctx_projects)}"); projects=(${projects:#})
  (( ${#projects} )) || { print -u2 "ctx: no projects yet in $CTX_ROOT — run: ctx new <name>"; return 1 }

  local p pick="" src="" best=0 pin

  # 1. explicit override
  if [[ -n $CTX_PROJECT ]] && (( ${projects[(Ie)$CTX_PROJECT]} )); then
    pick=$CTX_PROJECT; src="CTX_PROJECT"
  fi
  # 2. this worktree is pinned — the repo-independent answer
  if [[ -z $pick ]] && pin=$(_ctx_pin_get); then
    p=${pin%%$'\t'*}
    (( ${projects[(Ie)$p]} )) && { pick=$p; src="pinned"; }
  fi
  # 3. a task file already records this branch → that project owns it, whatever repo we're in
  if [[ -z $pick && -n $_CTX_BRANCH ]]; then
    local f
    for f in "$CTX_ROOT"/*/tasks/*.md(N); do
      [[ ${${f:h:h}:t} == _* ]] && continue
      if _ctx_task_has_ref "$f" Branch "$_CTX_BRANCH"; then
        pick=${${f:h:h}:t}; src="branch on task ${f:t}"; break
      fi
    done
  fi
  # 4. branch == project
  if [[ -z $pick && -n $_CTX_BRANCH ]] && (( ${projects[(Ie)$_CTX_BRANCH]} )); then
    pick=$_CTX_BRANCH; src="branch name"
  fi
  # 5. longest project name that prefixes the branch  (discourse-poc-gcs-bucket -> discourse-poc)
  if [[ -z $pick && -n $_CTX_BRANCH ]]; then
    for p in $projects; do
      if [[ $_CTX_BRANCH == ${p}* ]] && (( ${#p} > best )); then pick=$p; best=${#p}; src="branch prefix"; fi
    done
  fi
  # 6. cwd sits inside a dir named after a project  (kubernetes/discourse-poc/...)
  if [[ -z $pick ]]; then
    for p in $projects; do
      if [[ $PWD == *"/$p"(/*|) ]] && (( ${#p} > best )); then pick=$p; best=${#p}; src="cwd"; fi
    done
  fi
  # 7. the only candidate — this repo's view first, then the store
  if [[ -z $pick ]]; then
    local -a view; view=("${(@f)$(_ctx_view_projects)}"); view=(${view:#})
    if (( ${#view} == 1 )); then pick=$view[1]; src="only project in this repo"
    elif (( ${#projects} == 1 )); then pick=$projects[1]; src="only project in the store"; fi
  fi

  [[ -n $pick ]] || {
    print -u2 "ctx: can't tell which project (branch '${_CTX_BRANCH:-?}'). Pin one:"
    printf '  ctx use %s\n' $projects >&2
    return 1
  }
  _CTX_PROJECT=$pick
  _CTX_PDIR="$CTX_ROOT/$pick"
  _CTX_PSRC=$src
  return 0
}

# Sets _CTX_TASK (path) / _CTX_TSRC. Pin first, then the branch recorded on a task file.
_ctx_task() {
  _CTX_TASK=""; _CTX_TSRC=""
  [[ -n $_CTX_PDIR ]] || return 1
  local pin t f
  if pin=$(_ctx_pin_get); then
    t=${pin##*$'\t'}
    if [[ -n $t && -f $_CTX_PDIR/tasks/$t ]]; then
      _CTX_TASK="$_CTX_PDIR/tasks/$t"; _CTX_TSRC="pinned"; return 0
    fi
  fi
  if [[ -n $_CTX_BRANCH ]]; then
    for f in "$_CTX_PDIR"/tasks/*.md(Nom); do
      if _ctx_task_has_ref "$f" Branch "$_CTX_BRANCH"; then
        _CTX_TASK=$f; _CTX_TSRC="this branch"; return 0
      fi
    done
  fi
  return 1
}

# ---------------------------------------------------------------------------
# auto-heal — idempotent, silent when already correct
# ---------------------------------------------------------------------------

_ctx_repo_claude_md() {
  cat <<EOF
# $_CTX_REPO — repo context

<TODO: one paragraph on this repo's shape and conventions.>

## Project context store

\`./context/\` is **this repo's view** of the shared store at \`$CTX_ROOT\` — outside the repo,
never committed, identical in every worktree. Each project below is a symlink to the one copy of
that project, so **a project can span several repos**: the same \`INDEX.md\` and the same task
files may be open in a chat rooted in a different repo. When a note only applies to one repo, say
which.

**Before working on a project below, read its \`INDEX.md\` first.** It is a short router: summary,
current state, next steps, and a manifest saying which sibling files matter for the task at hand.
Do not read the sibling files unless \`INDEX.md\` says they're relevant — that's the point of the split.

| Project | Context |
|---|---|

## Repo-wide standing rules

- <TODO: e.g. any new/changed GCP resource → hand over as Terraform code, never \`gcloud create\`.>

## Keeping the store current

At the end of a task that changed project state, update that project's \`INDEX.md\` and append to
\`context/<project>/tasks/<YYYY-MM-DD-slug>.md\`. Prefer correcting a stale entry over adding a
contradicting one. **Never** have two chats edit the same file — the store is shared across repos
and worktrees, so one file per subtask. A task file's \`**Repos:**\`, \`**Worktrees:**\` and
\`**Branches:**\` lines are append-only lists; a task that grows into another repo gains a value
there rather than forking into a second file.
EOF
}

# Ensures store root, store git repo, this repo's view dir + router, both symlinks, excludes.
# Prints only what it actually changed. Requires _ctx_resolve.
_ctx_ensure_wired() {
  local -a did
  local ex pat

  [[ -d $CTX_ROOT ]] || { mkdir -p "$CTX_ROOT"; did+=("created store $CTX_ROOT"); }

  if [[ ! -d $CTX_ROOT/.git ]]; then
    git -C "$CTX_ROOT" init -q
    did+=("git init $CTX_ROOT")
  fi
  # pins are machine-local paths — never part of the store's history
  if ! grep -qxF '_state/' "$CTX_ROOT/.gitignore" 2>/dev/null; then
    print '_state/' >> "$CTX_ROOT/.gitignore"
    grep -qxF '.DS_Store' "$CTX_ROOT/.gitignore" 2>/dev/null || print '.DS_Store' >> "$CTX_ROOT/.gitignore"
    did+=("gitignored _state/")
  fi

  [[ -d $_CTX_VIEW ]] || { mkdir -p "$_CTX_VIEW"; did+=("created view $_CTX_VIEW"); }

  [[ -f $_CTX_VIEW/CLAUDE.md ]] || {
    _ctx_repo_claude_md > "$_CTX_VIEW/CLAUDE.md"
    did+=("created _repos/$_CTX_REPO/CLAUDE.md (has TODOs — run: ctx edit claude)")
  }

  if [[ -e $_CTX_TOP/context && ! -L $_CTX_TOP/context ]]; then
    print -u2 "ctx: $_CTX_TOP/context exists and is NOT a symlink — move it aside first"
    return 1
  fi
  if [[ ${${:-$_CTX_TOP/context}:A} != ${_CTX_VIEW:A} ]]; then
    ln -sfn "$_CTX_VIEW" "$_CTX_TOP/context"; did+=("linked ./context -> $_CTX_VIEW")
  fi

  if [[ -e $_CTX_TOP/CLAUDE.md && ! -L $_CTX_TOP/CLAUDE.md ]]; then
    print -u2 "ctx: $_CTX_TOP/CLAUDE.md is a real file (tracked?) — leaving it alone"
  elif [[ ! -L $_CTX_TOP/CLAUDE.md ]]; then
    ln -sfn context/CLAUDE.md "$_CTX_TOP/CLAUDE.md"; did+=("linked ./CLAUDE.md")
  fi

  # info/exclude lives in the COMMON git dir → shared by every worktree, written once ever
  ex="$_CTX_COMMON/info/exclude"
  [[ -d ${ex:h} ]] || mkdir -p "${ex:h}"
  for pat in '/context' '/CLAUDE.md'; do
    grep -qxF "$pat" "$ex" 2>/dev/null || { print "$pat" >> "$ex"; did+=("excluded $pat"); }
  done

  (( ${#did} )) && printf 'ctx: %s\n' $did
  return 0
}

# Join this repo to a project: symlink it into the view and register it in the repo router.
# This is the whole of "a project spans repos" — no state to keep in sync.
_ctx_view_link() {  # $1 project
  [[ -n $_CTX_VIEW ]] || return 0
  [[ -d $CTX_ROOT/$1 ]] || return 1
  [[ -d $_CTX_VIEW ]] || mkdir -p "$_CTX_VIEW"
  if [[ ! -e $_CTX_VIEW/$1 ]]; then
    ln -sfn "../../$1" "$_CTX_VIEW/$1"
    local -a spans; spans=("${(@f)$(_ctx_project_repos $1)}"); spans=(${spans:#})
    print "ctx: linked $1 into $_CTX_REPO's context (project now spans: ${(j:, :)spans})"
  fi
  _ctx_table_add "$_CTX_VIEW/CLAUDE.md" '| Project | Context |' \
    "| $1 | \`context/$1/INDEX.md\` |" "context/$1/INDEX.md"
}

# Insert a markdown table row under a heading, idempotently. Non-fatal: on failure, prints the row.
_ctx_table_add() {  # $1 file  $2 exact heading line  $3 row  $4 uniqueness grep pattern
  local file=$1 head=$2 row=$3 key=$4 tmp
  [[ -f $file ]] || return 1
  grep -qF -- "$key" "$file" && return 0
  tmp=$(mktemp)
  awk -v head="$head" -v row="$row" '
    $0 == head { inh=1; print; next }
    inh && /^\|/ { print; seen=1; next }
    inh && seen && !/^\|/ { print row; inh=0; seen=0; print; next }
    { print }
    END { if (inh && seen) print row }
  ' "$file" > "$tmp"
  if grep -qF -- "$key" "$tmp"; then
    mv "$tmp" "$file"
  else
    rm -f "$tmp"
    print -u2 "ctx: couldn't auto-insert into '$head' of ${file:t}. Add manually:"
    print -u2 "  $row"
  fi
}

# ---------------------------------------------------------------------------
# templates
# ---------------------------------------------------------------------------

_ctx_index_md() {  # $1 project
  local tpl="$CTX_ROOT/_template/INDEX.md" bt='`' here=""
  [[ -n $_CTX_REPO ]] && here="$bt$_CTX_REPO$bt — $bt$_CTX_TOP$bt"
  if [[ -f $tpl ]]; then
    sed -e "s|<project>|$1|g" -e "s|<YYYY-MM-DD>|$(date +%F)|g" \
        -e "s|<repo>|${_CTX_REPO:-<repo>}|g" -e "s|<path>|${_CTX_TOP:-<path>}|g" "$tpl"
    return
  fi
  cat <<EOF
# $1 — context index

**Updated:** $(date +%F)
**Status:** <one line: where this actually stands>

> Start here. This file is a router — read the linked files only when the task calls for them.
> If you change project state, update this file at the end of the task.

## What this is

<2-4 sentences: goal, cluster/env, namespace, the one hard constraint.>

## Current state

- <5-8 bullets. What is true RIGHT NOW — not history.>

## Next steps

1. <concrete action>

## Active subtasks

| Task | Repos | Scope | Notes |
|---|---|---|---|

## Read only if relevant

- **\`DECISIONS.md\`** — dated don't-re-derive log. Read before touching <the expensive areas>.

## Deferred

- <explicitly out of scope for now>

## Where things live

- Repos: $here
EOF
}

_ctx_task_md() {  # $1 slug  $2 project
  # backticks are built OUTSIDE the heredoc — an unquoted heredoc would run them
  local bt='`' r="" w="" b=""
  [[ -n $_CTX_REPO ]]   && r="$bt$_CTX_REPO$bt"
  [[ -n $_CTX_TOP ]]    && w="$bt$_CTX_TOP$bt"
  [[ -n $_CTX_BRANCH ]] && b="$bt$_CTX_BRANCH$bt"
  cat <<EOF
# $1 — in progress

**Project:** \`$2\`
**Repos:** $r
**Worktrees:** $w
**Branches:** $b
**Status:** not started

> These three are append-only lists. Same task in another repo or on a new branch:
> \`ctx task $2 $1\` there — it records the new value here instead of forking a second file.

## Goal

<what done looks like>

## Findings (don't re-derive)

> Graduate these into \`DECISIONS.md\` once this work lands.

-

## Loose ends

- [ ]

## Log

- $(date +%F) — created.
EOF
}

# ---------------------------------------------------------------------------
# subcommands
# ---------------------------------------------------------------------------

_ctx_cmd_status() {
  local in_repo=0
  _ctx_resolve 2>/dev/null && in_repo=1

  if (( in_repo )); then
    print "repo      $_CTX_REPO  ($_CTX_TOP)"
    print "branch    ${_CTX_BRANCH:-<detached>}"
    print "view      $_CTX_VIEW"

    local link="missing"
    [[ -L $_CTX_TOP/context ]] && { [[ ${${:-$_CTX_TOP/context}:A} == ${_CTX_VIEW:A} ]] && link="ok" || link="WRONG TARGET"; }
    local cl="missing"; [[ -L $_CTX_TOP/CLAUDE.md ]] && cl="ok"
    print "links     context=$link  CLAUDE.md=$cl"
    [[ $link != ok || $cl != ok ]] && print "          -> run: ctx link"

    local -a here; here=("${(@f)$(_ctx_view_projects)}"); here=(${here:#})
    print "projects  ${here:-<none linked here>}"
  else
    print "repo      <not in a git repo — store-wide view>"
  fi

  local -a all; all=("${(@f)$(_ctx_projects)}"); all=(${all:#})
  print "store     $CTX_ROOT  (${#all} project(s))"

  if ! _ctx_project 2>/dev/null; then
    (( ${#all} )) && {
      print ""
      print "active    <can't tell from here>"
      print "          ctx use <project>   ->  ${(j:, :)all}"
    }
  else
    local -a repos; repos=("${(@f)$(_ctx_project_repos $_CTX_PROJECT)}"); repos=(${repos:#})
    print ""
    print "active    $_CTX_PROJECT  (${_CTX_PSRC})"
    print "repos     ${(j:, :)repos:-<none>}"
    print "mention   @context/$_CTX_PROJECT/INDEX.md"
    if (( in_repo )) && [[ ! -e $_CTX_VIEW/$_CTX_PROJECT ]]; then
      print "          ! not linked into $_CTX_REPO yet -> run: ctx use $_CTX_PROJECT"
    fi
    [[ -f $_CTX_PDIR/INDEX.md ]] && {
      print ""
      grep -m2 -E '^\*\*(Updated|Status):' "$_CTX_PDIR/INDEX.md" | sed 's/^/          /'
    }

    local -a tasks others; local f
    tasks=("$_CTX_PDIR"/tasks/*.md(Nom))
    if _ctx_task; then
      print ""
      print "task      ${_CTX_TASK:t}   (${_CTX_TSRC})"
      grep -m1 -E '^\*\*Status:' "$_CTX_TASK" | sed 's/^/          /'
      print "          @context/$_CTX_PROJECT/tasks/${_CTX_TASK:t}"
    elif (( ${#tasks} )); then
      print ""
      print "task      <none pinned here>  -> ctx use $_CTX_PROJECT/<slug>   or   ctx task"
    fi
    for f in $tasks; do [[ $f == $_CTX_TASK ]] || others+=($f); done
    (( ${#others} )) && { print ""; print "other tasks"; printf '          %s\n' ${others:t}; }
  fi

  if [[ -d $CTX_ROOT/.git ]]; then
    local dirty=$(git -C "$CTX_ROOT" status --porcelain | wc -l | tr -d ' ')
    print ""
    (( dirty )) && print "store git $dirty uncommitted change(s) -> ctx save" \
                || print "store git clean"
  fi
}

_ctx_cmd_link() {
  _ctx_resolve || return 1
  _ctx_ensure_wired || return 1
  # keep the view honest for whatever this worktree is working on
  _ctx_project 2>/dev/null && _ctx_view_link "$_CTX_PROJECT"
  print "ctx: wired."
}

_ctx_cmd_new() {
  # a project is not owned by a repo — it can be created from anywhere
  local in_repo=0
  _ctx_resolve 2>/dev/null && in_repo=1
  (( in_repo )) && { _ctx_ensure_wired || return 1 }

  local name=${1:-$_CTX_BRANCH}
  [[ -n $name ]] || { print -u2 "ctx new: give a project name (nothing to infer from here)"; return 1 }
  name=${name//[^a-zA-Z0-9._-]/-}

  local pdir="$CTX_ROOT/$name"
  if [[ -d $pdir ]]; then
    print "ctx: project '$name' already exists."
  else
    mkdir -p "$pdir/tasks"
    _ctx_index_md "$name" > "$pdir/INDEX.md"
    print "ctx: created $pdir"
  fi
  (( in_repo )) && _ctx_view_link "$name"

  print ""
  print "next:  ctx edit          # fill in INDEX.md (it has placeholders)"
  print "       ctx task          # if this project has subtasks"
  print "       ctx save          # commit the store"
  print ""
  print "mention in a chat:  @context/$name/INDEX.md"
}

# ctx task                     project inferred, slug = branch
# ctx task <slug>              project inferred, explicit slug
# ctx task <project>           explicit project, slug = branch
# ctx task <project> <slug>    both explicit — the cross-repo form: run it in the second repo and
#                              the existing task file gains this repo/worktree/branch
_ctx_cmd_task() {
  local in_repo=0
  _ctx_resolve 2>/dev/null && in_repo=1
  (( in_repo )) && { _ctx_ensure_wired || return 1 }

  local proj="" arg_slug=""
  if (( $# >= 2 )); then
    proj=$1; arg_slug=$2
  elif (( $# == 1 )); then
    # a bare arg is a project if it names one, otherwise it's the slug
    if [[ -d $CTX_ROOT/$1 ]]; then proj=$1; else arg_slug=$1; fi
  fi

  if [[ -n $proj ]]; then
    _CTX_PROJECT=$proj; _CTX_PDIR="$CTX_ROOT/$proj"
  else
    _ctx_project || {
      print -u2 "       or name it directly:  ctx task <project> [slug]"
      return 1
    }
  fi

  local slug=${arg_slug:-$_CTX_BRANCH}
  [[ -n $slug ]] || { print -u2 "ctx task: give a slug (nothing to infer from here)"; return 1 }
  slug=${slug//[^a-zA-Z0-9._-]/-}

  local f
  if f=$(_ctx_find_task "$_CTX_PDIR" "$slug"); then
    print "ctx: task file already exists: ${f:t}"
    _ctx_task_record_here "$f"
  else
    mkdir -p "$_CTX_PDIR/tasks"
    f="$_CTX_PDIR/tasks/$(date +%F)-$slug.md"
    _ctx_task_md "$slug" "$_CTX_PROJECT" > "$f"
    print "ctx: created $f"
    _ctx_table_add "$_CTX_PDIR/INDEX.md" '| Task | Repos | Scope | Notes |' \
      "| \`tasks/${f:t}\` | \`${_CTX_REPO:-?}\` | <scope> | in progress |" "tasks/${f:t}"
  fi

  (( in_repo )) && { _ctx_view_link "$_CTX_PROJECT"; _ctx_pin_set "$_CTX_PROJECT" "${f:t}" }

  print ""
  print "mention in a chat:  @context/$_CTX_PROJECT/tasks/${f:t}"
  [[ -n $EDITOR ]] && print "edit:               \$EDITOR $f"
}

# ctx use <project>[/<slug>]   pin this worktree — the repo-independent way to say what you're on
# ctx use                      show the current pin
# ctx use --clear              drop it
_ctx_cmd_use() {
  _ctx_resolve || return 1

  if (( ! $# )); then
    local pin pp pt
    if pin=$(_ctx_pin_get); then
      pp=${pin%%$'\t'*}; pt=${pin##*$'\t'}
      print "pinned    $pp${pt:+ / $pt}"
      print "          ($_CTX_TOP)"
    else
      print "ctx: no pin for $_CTX_TOP"
      print "     ctx use <project>[/<slug>]"
    fi
    return 0
  fi

  if [[ $1 == (--clear|-c|-|none) ]]; then
    _ctx_pin_clear && print "ctx: pin cleared for $_CTX_TOP" || print "ctx: no pin to clear"
    return 0
  fi

  local spec=$1 proj=${1%%/*} slug=""
  [[ $spec == */* ]] && slug=${spec#*/}
  [[ -d $CTX_ROOT/$proj ]] || {
    print -u2 "ctx: no such project: $proj"
    print -u2 "available:"; _ctx_projects | sed 's/^/  /' >&2
    return 1
  }
  _ctx_ensure_wired || return 1
  _CTX_PROJECT=$proj; _CTX_PDIR="$CTX_ROOT/$proj"

  local f="" task=""
  if [[ -n $slug ]]; then
    f=$(_ctx_find_task "$_CTX_PDIR" "$slug") || {
      local -a have; have=("$_CTX_PDIR"/tasks/*.md(N:t))
      if (( ${#have} )); then
        print -u2 "ctx: no task '$slug' in $proj. Existing:"
        printf '  %s\n' $have >&2
      else
        print -u2 "ctx: $proj has no task files yet."
      fi
      print -u2 "  (create it with: ctx task $proj $slug)"
      return 1
    }
    task=${f:t}
  fi

  _ctx_view_link "$proj"
  _ctx_pin_set "$proj" "$task"
  [[ -n $f ]] && _ctx_task_record_here "$f"

  local mention="@context/$proj/INDEX.md"
  [[ -n $task ]] && mention="@context/$proj/tasks/$task"
  print "ctx: $_CTX_TOP -> $proj${task:+ / $task}"
  print ""
  print "mention in a chat:  $mention"
}

_ctx_cmd_edit() {
  _ctx_resolve 2>/dev/null
  local what=${1:-index} target
  if [[ $what == claude ]]; then
    [[ -n $_CTX_VIEW ]] || { print -u2 "ctx: not in a repo — no repo router to edit"; return 1 }
    target="$_CTX_VIEW/CLAUDE.md"
  else
    _ctx_project || return 1
    case $what in
      index)      target="$_CTX_PDIR/INDEX.md" ;;
      decisions)  target="$_CTX_PDIR/DECISIONS.md" ;;
      manifests)  target="$_CTX_PDIR/MANIFESTS.md" ;;
      task)       _ctx_task || {
                    local t=("$_CTX_PDIR"/tasks/*.md(Nom[1]))
                    (( ${#t} )) || { print -u2 "ctx: no task files — run: ctx task"; return 1 }
                    _CTX_TASK=$t[1]
                  }
                  target=$_CTX_TASK ;;
      *)          target="$_CTX_PDIR/$what" ;;
    esac
  fi
  [[ -f $target ]] || print -u2 "ctx: $target does not exist yet — creating"
  ${EDITOR:-vi} "$target"
}

_ctx_cmd_path() {
  _ctx_resolve 2>/dev/null
  _ctx_project || return 1
  local what=${1:-INDEX.md}
  case $what in
    index) what=INDEX.md ;;
    task)  _ctx_task || { print -u2 "ctx: no current task — ctx use $_CTX_PROJECT/<slug>"; return 1 }
           what="tasks/${_CTX_TASK:t}" ;;
  esac
  print -n "@context/$_CTX_PROJECT/$what"
  [[ -t 1 ]] && print ""
  return 0
}

_ctx_cmd_save() {
  [[ -d $CTX_ROOT/.git ]] || { print -u2 "ctx: $CTX_ROOT is not a git repo"; return 1 }
  git -C "$CTX_ROOT" status --porcelain | grep -q . || { print "ctx: nothing to save."; return 0 }

  git -C "$CTX_ROOT" --no-pager status --short
  local msg="$*"
  if [[ -z $msg ]]; then
    local -a touched
    touched=(${(f)"$(git -C "$CTX_ROOT" status --porcelain | awk '{print $NF}' \
              | cut -d/ -f1 | sed 's:/$::' | sort -u)"})
    msg="ctx: update ${(j:, :)touched}"
  fi
  git -C "$CTX_ROOT" add -A && git -C "$CTX_ROOT" commit -q -m "$msg" \
    && print "ctx: saved — $msg"
}

_ctx_cmd_archive() {
  _ctx_resolve 2>/dev/null
  local name=$1
  [[ -n $name ]] || { _ctx_project || return 1; name=$_CTX_PROJECT; }
  local pdir="$CTX_ROOT/$name"
  [[ -d $pdir ]] || { print -u2 "ctx: no such project: $name"; return 1 }

  local -a repos; repos=("${(@f)$(_ctx_project_repos $name)}"); repos=(${repos:#})
  print -n "ctx: archive '$name' (linked in: ${(j:, :)repos:-none})? [y/N] "
  local reply; read -r reply
  [[ $reply == [yY]* ]] || { print "aborted."; return 1 }

  mkdir -p "$CTX_ROOT/_archive"
  mv "$pdir" "$CTX_ROOT/_archive/$name"

  # unlink from every repo view and drop its router row
  local r tmp
  for r in $repos; do
    rm -f "$_CTX_REPOS/$r/$name"
    if [[ -f $_CTX_REPOS/$r/CLAUDE.md ]]; then
      tmp=$(mktemp)
      grep -vF "context/$name/INDEX.md" "$_CTX_REPOS/$r/CLAUDE.md" > "$tmp" \
        && mv "$tmp" "$_CTX_REPOS/$r/CLAUDE.md"
    fi
  done
  _ctx_pin_drop_project "$name"

  print "ctx: archived -> $CTX_ROOT/_archive/$name  (unlinked from ${(j:, :)repos:-nothing})"
  print "ctx: run 'ctx save' to commit."
}

_ctx_cmd_ls() {
  local p st
  local -a repos n
  for p in "$CTX_ROOT"/*(N/); do
    [[ ${p:t} == _* ]] && continue
    st=$(grep -m1 -E '^\*\*Status:' "$p/INDEX.md" 2>/dev/null | sed 's/^\*\*Status:\*\* *//')
    repos=("${(@f)$(_ctx_project_repos ${p:t})}"); repos=(${repos:#})
    n=(${p}/tasks/*.md(N))
    printf '%-26s %s\n' "${p:t}" "${st:-<no INDEX.md>}"
    printf '  %-24s %s\n' "repos: ${(j:, :)repos:-<none>}" "tasks: ${#n}"
  done
}

# ctx tasks [project]   every task file in a project, current one marked
_ctx_cmd_tasks() {
  _ctx_resolve 2>/dev/null
  if [[ -n $1 && -d $CTX_ROOT/$1 ]]; then
    _CTX_PROJECT=$1; _CTX_PDIR="$CTX_ROOT/$1"
  else
    [[ -n $1 ]] && { print -u2 "ctx: no such project: $1"; return 1 }
    _ctx_project || return 1
  fi

  local -a tasks; tasks=("$_CTX_PDIR"/tasks/*.md(N))
  (( ${#tasks} )) || { print "$_CTX_PROJECT — no task files yet.  ctx task <slug>"; return 0 }

  _ctx_task 2>/dev/null   # sets _CTX_TASK if one is current here
  local cols=$COLUMNS; (( cols > 0 )) || cols=100     # unset/0 when there's no tty
  local width=$(( cols - 42 )); (( width < 30 )) && width=30
  local f mark br rp
  print "$_CTX_PROJECT — ${#tasks} task(s)${_CTX_TASK:+   (* = current here)}"
  print ""
  for f in $tasks; do
    mark=" "; [[ $f == $_CTX_TASK ]] && mark="*"
    printf '%s %-38s %s\n' "$mark" "${f:t}" "$(_ctx_task_status $f $width)"
    br=$(_ctx_ref_values Branch "$f"); rp=$(_ctx_ref_values Repo "$f")
    print "    ${br:+branches: $br}${br:+   }${rp:+repos: $rp}"
  done
  print ""
  print "  ctx use $_CTX_PROJECT/<slug>   ctx rm <slug>"
}

# ctx rm [project] <slug>   delete one task file
_ctx_cmd_rm() {
  _ctx_resolve 2>/dev/null
  local proj="" slug=""
  if (( $# >= 2 )); then
    proj=$1; slug=$2
  elif (( $# == 1 )); then
    slug=$1
  else
    print -u2 "ctx rm: which task? (ctx tasks lists them)"; return 1
  fi

  if [[ -n $proj ]]; then
    [[ -d $CTX_ROOT/$proj ]] || { print -u2 "ctx: no such project: $proj"; return 1 }
    _CTX_PROJECT=$proj; _CTX_PDIR="$CTX_ROOT/$proj"
  else
    _ctx_project || return 1
  fi

  local -a hits; hits=("${(@f)$(_ctx_find_tasks "$_CTX_PDIR" "$slug")}"); hits=(${hits:#})
  if (( ${#hits} == 0 )); then
    print -u2 "ctx: no task '$slug' in $_CTX_PROJECT. Existing:"
    printf '  %s\n' "$_CTX_PDIR"/tasks/*.md(N:t) >&2
    return 1
  fi
  if (( ${#hits} > 1 )); then
    print -u2 "ctx: '$slug' matches ${#hits} task files — name one exactly:"
    printf '  %s\n' ${hits:t} >&2
    return 1
  fi

  local f=$hits[1]
  print "ctx: $_CTX_PROJECT/${f:t}"
  print "     $(_ctx_task_status $f 200)"
  print -n "ctx: delete it? (recoverable from the store's git history) [y/N] "
  local reply; read -r reply
  [[ $reply == [yY]* ]] || { print "aborted."; return 1 }

  rm -f "$f"
  _ctx_pin_drop_task "$_CTX_PROJECT" "${f:t}"

  # drop its row from INDEX.md's subtask table
  local idx="$_CTX_PDIR/INDEX.md" tmp
  if [[ -f $idx ]]; then
    tmp=$(mktemp)
    awk -v n="${f:t}" '/^\|/ && index($0, n) { next } { print }' "$idx" > "$tmp" && mv "$tmp" "$idx"
    grep -nF -- "${f:t}" "$idx" >/dev/null 2>&1 && {
      print "ctx: INDEX.md still mentions it outside the table:"
      grep -nF -- "${f:t}" "$idx" | sed 's/^/     /'
    }
  fi

  print "ctx: deleted ${f:t}"
  print "ctx: run 'ctx save' to commit  (undo: git -C $CTX_ROOT checkout -- $_CTX_PROJECT/tasks/${f:t})"
}

_ctx_cmd_cd() {
  _ctx_resolve 2>/dev/null
  if [[ -n $1 ]]; then cd "$CTX_ROOT/$1"; return; fi
  if _ctx_project 2>/dev/null; then cd "$_CTX_PDIR"; else cd "$CTX_ROOT"; fi
}

_ctx_cmd_help() {
  cat <<'EOF'
ctx — agent context store manager.

Projects and tasks belong to the STORE, not to a repo, worktree or branch. A project lives once at
the store root; every repo that touches it gets a symlink inside _repos/<repo>/, which is what
./context points at. So one project can span repos, and @context/<project>/tasks/<file>.md is the
same file from all of them.

  ctx                   where am I: repo, active project + how it was picked, task, link health
  ctx new [name]        create a project (works outside a repo too). name defaults to branch
  ctx task [proj] [slug]  new subtask, or join the current repo/branch to an existing one.
                          a single arg is read as a project if it names one, otherwise as the slug
  ctx tasks [proj]      list a project's task files: status, branches, repos. * = current here
  ctx rm [proj] <slug>  delete one task file (asks first; recoverable from the store's git)
  ctx use <proj>[/<slug>]  pin THIS worktree to a project/task — the repo-independent answer when
                          nothing can be inferred. `ctx use` shows it, `ctx use --clear` drops it
  ctx edit [what]       $EDITOR the store file. what: index|decisions|manifests|task|claude
  ctx path [file|task]  print the @-mention path      (ctx path | pbcopy)
  ctx save [msg]        commit the store. msg is auto-generated if omitted
  ctx ls                every project, the repos it spans, task count
  ctx cd [rel]          cd into the active project's store dir
  ctx archive [name]    move a finished project to _archive/ and unlink it from every repo
  ctx link              force re-wire this worktree (new/task/use do it automatically)

Project inference, in order:
  $CTX_PROJECT  >  this worktree's pin  >  a task file recording this branch (any project)
                >  branch == project  >  longest project name prefixing the branch
                >  cwd inside a dir named after a project  >  the only project

Same task from a second repo:
  ctx task <project> <slug>     records this repo/worktree/branch on the existing file
  ctx use  <project>/<slug>     pins this worktree to it, no branch convention needed

A task file's **Repos:** / **Worktrees:** / **Branches:** lines are append-only lists — a task
that grows into another repo gains a value there instead of forking into a second file.

`new`, `task`, `use` and `link` auto-heal: store dir, store git repo, view dir, repo CLAUDE.md,
./context and ./CLAUDE.md symlinks, git exclude entries. Silent when already correct. `ctx` on its
own is read-only — it reports broken wiring and tells you to run `ctx link`.
EOF
}

# ---------------------------------------------------------------------------
# dispatch
# ---------------------------------------------------------------------------

ctx() {
  emulate -L zsh
  setopt local_options no_nomatch extended_glob
  # no_aliases matters at RUNTIME too: command substitutions `$(grep ...)` are re-parsed when
  # evaluated, so the file-level no_aliases (definition time) does not cover them.
  setopt local_options no_aliases
  local cmd=${1:-status}
  (( $# )) && shift
  _ctx_paths   # honour a CTX_ROOT changed since this file was sourced
  # each invocation starts clean — stale globals from a previous call must never leak
  local _CTX_TOP _CTX_COMMON _CTX_REPO _CTX_VIEW _CTX_BRANCH
  local _CTX_PROJECT _CTX_PDIR _CTX_PSRC _CTX_TASK _CTX_TSRC
  case $cmd in
    status|st|'')     _ctx_cmd_status "$@" ;;
    new|n)            _ctx_cmd_new "$@" ;;
    task|t)           _ctx_cmd_task "$@" ;;
    tasks|ts)         _ctx_cmd_tasks "$@" ;;
    rm|remove)        _ctx_cmd_rm "$@" ;;
    use|u)            _ctx_cmd_use "$@" ;;
    edit|e)           _ctx_cmd_edit "$@" ;;
    path|p)           _ctx_cmd_path "$@" ;;
    save|s)           _ctx_cmd_save "$@" ;;
    archive)          _ctx_cmd_archive "$@" ;;
    ls|list)          _ctx_cmd_ls "$@" ;;
    cd)               _ctx_cmd_cd "$@" ;;
    link)             _ctx_cmd_link "$@" ;;
    help|-h|--help)   _ctx_cmd_help ;;
    *) print -u2 "ctx: unknown subcommand '$cmd'"; _ctx_cmd_help; return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# completion
# ---------------------------------------------------------------------------

_ctx() {
  # contain the resolution globals — this runs in the user's live shell
  local _CTX_TOP _CTX_COMMON _CTX_REPO _CTX_VIEW _CTX_BRANCH _CTX_PROJECT _CTX_PDIR _CTX_PSRC
  local -a subs
  subs=(status new task tasks use rm edit path save archive ls cd link help)
  if (( CURRENT == 2 )); then
    _describe 'ctx subcommand' subs
    return
  fi
  case ${words[2]} in
    edit|e) _values 'file' index decisions manifests task claude ;;
    rm|remove)
      local -a ts
      _ctx_resolve 2>/dev/null
      _ctx_project 2>/dev/null && ts=("$_CTX_PDIR"/tasks/*.md(N:t))
      _describe 'task' ts ;;
    use|u|archive|cd|task|t|tasks|ts)
      local -a ps
      ps=("${(@f)$(_ctx_projects)}")
      _describe 'project' ps ;;
  esac
}
# compinit may not have run (non-interactive shell) — completion is optional
(( $+functions[compdef] )) && compdef _ctx ctx

# restore the user's alias setting (see the no_aliases note at the top)
[[ $_ctx_had_aliases == on ]] && setopt aliases
unset _ctx_had_aliases

# never let this file's exit status be non-zero: `source ... && x` must not break
true
