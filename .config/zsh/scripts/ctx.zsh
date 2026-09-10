# ctx — agent context store manager
#
# Durable per-project context that lives OUTSIDE any repo, symlinked into every git worktree,
# so a fresh Claude Code chat in any worktree starts warm instead of re-deriving everything.
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

# Populates: _CTX_TOP _CTX_COMMON _CTX_REPO _CTX_STORE _CTX_BRANCH
_ctx_resolve() {
  _CTX_COMMON=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || {
    print -u2 "ctx: not inside a git repo"; return 1
  }
  _CTX_TOP=$(git rev-parse --show-toplevel)
  _CTX_BRANCH=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || print "")
  # repo identity comes from the MAIN worktree, so every linked worktree agrees
  _CTX_REPO=${$(git worktree list | head -1 | awk '{print $1}'):t}
  _CTX_STORE="$CTX_ROOT/$_CTX_REPO"
  return 0
}

# List project dirs in the current store, one per line.
_ctx_projects() {
  [[ -d $_CTX_STORE ]] || return 0
  local d
  for d in "$_CTX_STORE"/*(N/); do
    [[ ${d:t} == _* ]] && continue
    print -- "${d:t}"
  done
}

# Infer the active project. Sets _CTX_PROJECT / _CTX_PDIR.
# Order: $CTX_PROJECT env > exact branch match > longest branch prefix > cwd path > sole project.
_ctx_project() {
  local -a projects; projects=("${(@f)$(_ctx_projects)}")
  projects=(${projects:#})
  (( ${#projects} )) || { print -u2 "ctx: no projects yet in $_CTX_STORE — run: ctx new <name>"; return 1 }

  local p pick="" best=0
  # 1. explicit override
  if [[ -n $CTX_PROJECT ]] && (( ${projects[(Ie)$CTX_PROJECT]} )); then
    pick=$CTX_PROJECT
  fi
  # 2. branch == project
  if [[ -z $pick && -n $_CTX_BRANCH ]] && (( ${projects[(Ie)$_CTX_BRANCH]} )); then
    pick=$_CTX_BRANCH
  fi
  # 3. a task file already records this branch → that project owns it. This is how an arbitrary
  #    branch name gets remembered: `ctx task <project>` writes the branch into the task file, and
  #    every later invocation from any worktree on that branch resolves without being told again.
  if [[ -z $pick && -n $_CTX_BRANCH ]]; then
    local f
    for f in "$_CTX_STORE"/*/tasks/*.md(N); do
      if _ctx_task_has_ref "$f" Branch "$_CTX_BRANCH"; then pick=${${f:h:h}:t}; break; fi
    done
  fi
  # 4. longest project name that prefixes the branch  (discourse-poc-gcs-bucket -> discourse-poc)
  if [[ -z $pick && -n $_CTX_BRANCH ]]; then
    for p in $projects; do
      if [[ $_CTX_BRANCH == ${p}* ]] && (( ${#p} > best )); then pick=$p; best=${#p}; fi
    done
  fi
  # 5. cwd sits inside a dir named after a project  (kubernetes/discourse-poc/...)
  if [[ -z $pick ]]; then
    for p in $projects; do
      if [[ $PWD == *"/$p"(/*|) ]] && (( ${#p} > best )); then pick=$p; best=${#p}; fi
    done
  fi
  # 6. only one candidate
  if [[ -z $pick ]] && (( ${#projects} == 1 )); then pick=$projects[1]; fi

  [[ -n $pick ]] || {
    print -u2 "ctx: can't tell which project (branch '$_CTX_BRANCH'). Pick one:"
    printf '  CTX_PROJECT=%s ctx ...\n' $projects >&2
    return 1
  }
  _CTX_PROJECT=$pick
  _CTX_PDIR="$_CTX_STORE/$pick"
  return 0
}

# ---------------------------------------------------------------------------
# auto-heal — idempotent, silent when already correct
# ---------------------------------------------------------------------------

_ctx_repo_claude_md() {
  cat <<EOF
# $_CTX_REPO — repo context

<TODO: one paragraph on this repo's shape and conventions.>

## Project context store

\`./context/\` is a symlink to \`$_CTX_STORE/\` — outside the repo, never committed, shared
identically by every worktree.

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
contradicting one. **Never** have two chats edit the same file — the store is shared across
worktrees, so one file per subtask.
EOF
}

# Ensures store dir, store git repo, repo CLAUDE.md, both symlinks, and git exclude entries.
# Prints only what it actually changed.
_ctx_ensure_wired() {
  local -a did
  local ex pat

  [[ -d $_CTX_STORE ]] || { mkdir -p "$_CTX_STORE"; did+=("created store $_CTX_STORE"); }

  if [[ ! -d $CTX_ROOT/.git ]]; then
    git -C "$CTX_ROOT" init -q
    [[ -f $CTX_ROOT/.gitignore ]] || print '.DS_Store' > "$CTX_ROOT/.gitignore"
    did+=("git init $CTX_ROOT")
  fi

  [[ -f $_CTX_STORE/CLAUDE.md ]] || {
    _ctx_repo_claude_md > "$_CTX_STORE/CLAUDE.md"
    did+=("created $_CTX_REPO/CLAUDE.md (has TODOs — run: ctx edit claude)")
  }

  if [[ -e $_CTX_TOP/context && ! -L $_CTX_TOP/context ]]; then
    print -u2 "ctx: $_CTX_TOP/context exists and is NOT a symlink — move it aside first"
    return 1
  fi
  if [[ ${${:-$_CTX_TOP/context}:A} != ${_CTX_STORE:A} ]]; then
    ln -sfn "$_CTX_STORE" "$_CTX_TOP/context"; did+=("linked ./context -> $_CTX_STORE")
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

# Does this task file list <branch> on its **Branch:** line? Matches anywhere on the line, so a
# comma-separated list of branches all resolve (a task survives rebases/renames/new branches).
_ctx_task_has_ref() {  # $1 file  $2 label (Branch|Worktree)  $3 value
  grep -m1 "^\*\*$2:\*\*" "$1" 2>/dev/null | grep -qF "\`$3\`"
}

# Append a backtick-quoted value to a task file's **Label:** line. No-op if already listed.
_ctx_task_add_ref() {  # $1 file  $2 label  $3 value
  local file=$1 label=$2 val=$3 tmp
  [[ -f $file ]] || return 1
  _ctx_task_has_ref "$file" "$label" "$val" && return 1
  tmp=$(mktemp) || return 1
  awk -v lbl="**$label:**" -v v="$val" '
    !added && index($0, lbl) == 1 { print $0 ", `" v "`"; added=1; next }
    { print }
    END { exit(added ? 0 : 1) }
  ' "$file" > "$tmp" || { rm -f "$tmp"; return 1 }
  mv "$tmp" "$file"
}

# Insert a markdown table row under a heading, idempotently. Non-fatal: on failure, prints the row.
# $1 file  $2 exact heading line  $3 row  $4 uniqueness grep pattern
_ctx_table_add() {
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
  local tpl="$CTX_ROOT/_template/INDEX.md"
  if [[ -f $tpl ]]; then
    sed -e "s|<project>|$1|g" -e "s|<YYYY-MM-DD>|$(date +%F)|g" -e "s|<path>|$_CTX_TOP|g" "$tpl"
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

| Branch / worktree | Scope | Notes |
|---|---|---|

## Read only if relevant

- **\`DECISIONS.md\`** — dated don't-re-derive log. Read before touching <the expensive areas>.

## Deferred

- <explicitly out of scope for now>

## Where things live

- Repo: \`$_CTX_TOP\`
EOF
}

_ctx_task_md() {  # $1 slug
  cat <<EOF
# $1 — in progress

**Worktree:** \`$_CTX_TOP\`
**Branch:** \`${_CTX_BRANCH:-<detached>}\`
**Status:** not started

## Goal

<what done looks like>

## Findings (don't re-derive)

> Graduate these into \`DECISIONS.md\` once this branch lands.

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
  _ctx_resolve || return 1
  print "repo      $_CTX_REPO  ($_CTX_TOP)"
  print "branch    ${_CTX_BRANCH:-<detached>}"
  print "store     $_CTX_STORE"

  local link="missing"
  [[ -L $_CTX_TOP/context ]] && { [[ ${${:-$_CTX_TOP/context}:A} == ${_CTX_STORE:A} ]] && link="ok" || link="WRONG TARGET"; }
  local cl="missing"; [[ -L $_CTX_TOP/CLAUDE.md ]] && cl="ok"
  print "links     context=$link  CLAUDE.md=$cl"

  if [[ $link != ok || $cl != ok ]]; then
    print "          -> run: ctx link"
  fi

  local -a projects; projects=("${(@f)$(_ctx_projects)}"); projects=(${projects:#})
  print "projects  ${projects:-<none>}"

  if _ctx_project 2>/dev/null; then
    print ""
    print "active    $_CTX_PROJECT"
    print "mention   @context/$_CTX_PROJECT/INDEX.md"
    [[ -f $_CTX_PDIR/INDEX.md ]] && {
      print ""
      grep -m2 -E '^\*\*(Updated|Status):' "$_CTX_PDIR/INDEX.md" | sed 's/^/          /'
    }
    # the current task is the one recording this branch — same signal the project inference uses
    local -a tasks others; local f cur=""
    tasks=("$_CTX_PDIR"/tasks/*.md(Nom))
    for f in $tasks; do
      if [[ -z $cur && -n $_CTX_BRANCH ]] && _ctx_task_has_ref "$f" Branch "$_CTX_BRANCH"; then
        cur=$f
      else
        others+=($f)
      fi
    done

    if [[ -n $cur ]]; then
      print ""
      print "task      ${cur:t}   (this branch)"
      grep -m1 -E '^\*\*Status:' "$cur" | sed 's/^/          /'
      print "          @context/$_CTX_PROJECT/tasks/${cur:t}"
    elif (( ${#tasks} )); then
      print ""
      print "task      <none for branch '${_CTX_BRANCH:-?}'>  -> ctx task"
    fi

    (( ${#others} )) && { print ""; print "other tasks"; printf '          %s\n' ${others:t}; }
  fi

  if [[ -d $CTX_ROOT/.git ]]; then
    local dirty=$(git -C "$CTX_ROOT" status --porcelain | wc -l | tr -d ' ')
    print ""
    (( dirty )) && print "store git $dirty uncommitted change(s) -> ctx save" \
                || print "store git clean"
  fi
}

_ctx_cmd_link() { _ctx_resolve || return 1; _ctx_ensure_wired || return 1; print "ctx: wired."; }

_ctx_cmd_new() {
  _ctx_resolve || return 1
  _ctx_ensure_wired || return 1

  local name=${1:-$_CTX_BRANCH}
  [[ -n $name ]] || { print -u2 "ctx new: give a project name (can't infer from a detached HEAD)"; return 1 }
  name=${name//[^a-zA-Z0-9._-]/-}

  local pdir="$_CTX_STORE/$name"
  if [[ -d $pdir ]]; then
    print "ctx: project '$name' already exists."
  else
    mkdir -p "$pdir/tasks"
    _ctx_index_md "$name" > "$pdir/INDEX.md"
    _ctx_table_add "$_CTX_STORE/CLAUDE.md" '| Project | Context |' \
      "| $name | \`context/$name/INDEX.md\` |" "context/$name/INDEX.md"
    print "ctx: created $pdir"
    print "ctx: registered in $_CTX_REPO/CLAUDE.md"
  fi

  print ""
  print "next:  ctx edit          # fill in INDEX.md (it has placeholders)"
  print "       ctx task          # if this project has subtasks"
  print "       ctx save          # commit the store"
  print ""
  print "mention in a chat:  @context/$name/INDEX.md"
}

# ctx task                     project inferred, slug = branch
# ctx task <slug>               project inferred, explicit slug
# ctx task <project>            explicit project (arg matches an existing project dir), slug = branch
# ctx task <project> <slug>     both explicit
_ctx_cmd_task() {
  _ctx_resolve || return 1
  _ctx_ensure_wired || return 1

  local proj="" arg_slug=""
  if (( $# >= 2 )); then
    proj=$1; arg_slug=$2
  elif (( $# == 1 )); then
    # a bare arg is a project if it names one, otherwise it's the slug
    if [[ -d $_CTX_STORE/$1 ]]; then proj=$1; else arg_slug=$1; fi
  fi

  if [[ -n $proj ]]; then
    _CTX_PROJECT=$proj; _CTX_PDIR="$_CTX_STORE/$proj"
  else
    _ctx_project || {
      print -u2 "       or name it directly:  ctx task <project> [slug]"
      return 1
    }
  fi

  local slug=${arg_slug:-$_CTX_BRANCH}
  [[ -n $slug ]] || { print -u2 "ctx task: give a slug (can't infer from a detached HEAD)"; return 1 }
  slug=${slug//[^a-zA-Z0-9._-]/-}

  local f="$_CTX_PDIR/tasks/$(date +%F)-$slug.md"
  local existing=("$_CTX_PDIR"/tasks/*-${slug}.md(N))
  if (( ${#existing} )); then
    f=$existing[1]
    print "ctx: task file already exists: ${f:t}"
    # same task, new branch (rebase/rename/retry) — record it so inference finds this file again
    if [[ -n $_CTX_BRANCH ]] && _ctx_task_add_ref "$f" Branch "$_CTX_BRANCH"; then
      print "ctx: recorded branch '$_CTX_BRANCH' on it"
    fi
    if _ctx_task_add_ref "$f" Worktree "$_CTX_TOP"; then
      print "ctx: recorded worktree '$_CTX_TOP' on it"
    fi
  else
    mkdir -p "$_CTX_PDIR/tasks"
    _ctx_task_md "$slug" > "$f"
    print "ctx: created $f"
    _ctx_table_add "$_CTX_PDIR/INDEX.md" '| Branch / worktree | Scope | Notes |' \
      "| \`${_CTX_BRANCH:-?}\` @ \`$_CTX_TOP\` | <scope> | in progress → \`tasks/${f:t}\` |" \
      "tasks/${f:t}"
  fi
  print ""
  print "mention in a chat:  @context/$_CTX_PROJECT/tasks/${f:t}"
  [[ -n $EDITOR ]] && print "edit:               \$EDITOR $f"
}

_ctx_cmd_edit() {
  _ctx_resolve || return 1
  local what=${1:-index} target
  if [[ $what == claude ]]; then
    target="$_CTX_STORE/CLAUDE.md"
  else
    _ctx_project || return 1
    case $what in
      index)      target="$_CTX_PDIR/INDEX.md" ;;
      decisions)  target="$_CTX_PDIR/DECISIONS.md" ;;
      manifests)  target="$_CTX_PDIR/MANIFESTS.md" ;;
      task)       local t=("$_CTX_PDIR"/tasks/*.md(Nom[1]))
                  (( ${#t} )) || { print -u2 "ctx: no task files — run: ctx task"; return 1 }
                  target=$t[1] ;;
      *)          target="$_CTX_PDIR/$what" ;;
    esac
  fi
  [[ -f $target ]] || print -u2 "ctx: $target does not exist yet — creating"
  ${EDITOR:-vi} "$target"
}

_ctx_cmd_path() {
  _ctx_resolve || return 1
  _ctx_project || return 1
  local what=${1:-INDEX.md}
  [[ $what == index ]] && what=INDEX.md
  print -n "@context/$_CTX_PROJECT/$what"
  [[ -t 1 ]] && print ""
  return 0
}

_ctx_cmd_save() {
  _ctx_resolve 2>/dev/null
  [[ -d $CTX_ROOT/.git ]] || { print -u2 "ctx: $CTX_ROOT is not a git repo"; return 1 }
  git -C "$CTX_ROOT" status --porcelain | grep -q . || { print "ctx: nothing to save."; return 0 }

  git -C "$CTX_ROOT" --no-pager status --short
  local msg="$*"
  if [[ -z $msg ]]; then
    local -a touched
    touched=(${(f)"$(git -C "$CTX_ROOT" status --porcelain | awk '{print $NF}' \
              | cut -d/ -f1,2 | sed 's:/$::' | sort -u)"})
    msg="ctx: update ${(j:, :)touched}"
  fi
  git -C "$CTX_ROOT" add -A && git -C "$CTX_ROOT" commit -q -m "$msg" \
    && print "ctx: saved — $msg"
}

_ctx_cmd_archive() {
  _ctx_resolve || return 1
  local name=$1
  [[ -n $name ]] || { _ctx_project || return 1; name=$_CTX_PROJECT; }
  local pdir="$_CTX_STORE/$name"
  [[ -d $pdir ]] || { print -u2 "ctx: no such project: $name"; return 1 }

  print -n "ctx: archive '$_CTX_REPO/$name'? [y/N] "
  local reply; read -r reply
  [[ $reply == [yY]* ]] || { print "aborted."; return 1 }

  mkdir -p "$CTX_ROOT/_archive/$_CTX_REPO"
  mv "$pdir" "$CTX_ROOT/_archive/$_CTX_REPO/$name"
  # drop its row from the repo router
  if [[ -f $_CTX_STORE/CLAUDE.md ]]; then
    local tmp=$(mktemp)
    grep -vF "context/$name/INDEX.md" "$_CTX_STORE/CLAUDE.md" > "$tmp" && mv "$tmp" "$_CTX_STORE/CLAUDE.md"
  fi
  print "ctx: archived -> $CTX_ROOT/_archive/$_CTX_REPO/$name"
  print "ctx: run 'ctx save' to commit."
}

_ctx_cmd_ls() {
  local r p
  for r in "$CTX_ROOT"/*(N/); do
    [[ ${r:t} == _* ]] && continue
    print "${r:t}"
    for p in "$r"/*(N/); do
      [[ ${p:t} == _* ]] && continue
      local st=$(grep -m1 -E '^\*\*Status:' "$p/INDEX.md" 2>/dev/null | sed 's/^\*\*Status:\*\* *//')
      printf '  %-24s %s\n' "${p:t}" "${st:-<no INDEX.md>}"
    done
  done
}

_ctx_cmd_cd() {
  _ctx_resolve 2>/dev/null
  if [[ -n $1 ]]; then cd "$CTX_ROOT/$1"; return; fi
  if _ctx_project 2>/dev/null; then cd "$_CTX_PDIR"; else cd "$CTX_ROOT"; fi
}

_ctx_cmd_help() {
  cat <<'EOF'
ctx — agent context store manager.  Everything is inferred from cwd.

  ctx                   where am I: repo, active project, link health, store status
  ctx new [name]        create a project (auto-wires the repo first). name defaults to branch
  ctx task [proj] [slug]  new subtask file. both default to inference/branch. a single arg is
                          read as a project if it names one, otherwise as the slug
  ctx edit [what]       $EDITOR the store file. what: index|decisions|manifests|task|claude
  ctx path [file]       print the @-mention path      (ctx path | pbcopy)
  ctx save [msg]        commit the store. msg is auto-generated if omitted
  ctx ls                every repo + project + status line
  ctx cd [rel]          cd into the active project's store dir
  ctx archive [name]    move a finished project to _archive/ and deregister it
  ctx link              force re-wire this worktree (new/task do it automatically)

Project inference, in order:
  $CTX_PROJECT  >  branch == project  >  a task file recording this branch
                >  longest project name prefixing the branch
                >  cwd inside a dir named after a project  >  the only project

So an arbitrary branch name only needs naming once: `ctx task <project>` records the branch in the
task file, and every later call from any worktree on that branch resolves on its own.

`new`, `task` and `link` auto-heal: missing store dir, store git repo, repo CLAUDE.md, ./context
and ./CLAUDE.md symlinks, git exclude entries. Silent when already correct. `ctx` on its own is
read-only — it reports broken wiring and tells you to run `ctx link` rather than fixing it.
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
  case $cmd in
    status|st|'')     _ctx_cmd_status "$@" ;;
    new|n)            _ctx_cmd_new "$@" ;;
    task|t)           _ctx_cmd_task "$@" ;;
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
  local -a subs
  subs=(status new task edit path save archive ls cd link help)
  if (( CURRENT == 2 )); then
    _describe 'ctx subcommand' subs
    return
  fi
  case ${words[2]} in
    edit|e) _values 'file' index decisions manifests task claude ;;
    archive|cd|task|t)
      local -a ps
      _ctx_resolve 2>/dev/null && ps=("${(@f)$(_ctx_projects)}")
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
