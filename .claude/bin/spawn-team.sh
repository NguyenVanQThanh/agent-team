#!/usr/bin/env bash
# spawn-team.sh — spawn multiple CLI dev agents in parallel.
#
# Usage:
#   .claude/bin/spawn-team.sh <spec> [<spec> ...]
#
# Each <spec> has the form: <dev>:<cli>:<task_id>
#   dev      = dev1..dev13
#   cli      = codex | deepseek | opus | haiku | sonnet | gemini
#   task_id  = the task id from .claude/team/tasks.md (e.g. T-001)
#
# What it does, per spec:
#   1. Loads the persona prompt from .claude/team/personas/<dev>.md
#   2. Extracts the task's row from .claude/team/tasks.md
#   3. Builds the final CLI prompt = persona + task block + shared-context block
#   4. Spawns the matching .claude/bin/run_<cli>.sh in the background, tagged
#      with --dev=<dev>. Each invocation gets its own run dir under
#      .claude/team/runs/ so the TUI can show it live.
#
# Tournament mode (NEW): if ≥2 devs share the same task_id, this script
# automatically creates one git worktree per dev under
# .claude/team/worktrees/<task_id>-<dev>/ and points each CLI at its own
# isolated checkout. The leader then diffs the worktrees and picks a winner.
#
# After spawning, this script `wait`s for all of them, then prints a status
# summary read from .claude/team/status/<dev>.env (which each CLI must write
# when finished — see the persona prompt for the contract).
#
# IMPORTANT: this script enforces the team's "≥ 2 devs per run" rule.

set -uo pipefail
# Source local env (OPUS_BIN, *_FLAGS, etc.) if present.
_env_file="$( cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd )/env.sh"
[[ -f "$_env_file" ]] && source "$_env_file"

# -------- pre-flight --------

if [[ $# -lt 2 ]]; then
  cat >&2 <<USAGE
usage: $0 <dev>:<cli>:<task_id> <dev>:<cli>:<task_id> [more...]

Examples:
  $0 dev1:codex:T-001 dev3:deepseek:T-002
  $0 dev2:codex:T-005 dev5:opus:T-006 dev4:deepseek:T-007
  $0 dev5:opus:T-100 dev13:codex:T-100  # tournament on T-100

Hard rule: at least 2 specs required (>= 2 devs per run).
USAGE
  exit 2
fi

SCRIPT_DIR="$( cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd )"
REPO="$( cd -- "$SCRIPT_DIR/../.." &>/dev/null && pwd )"
PERSONA_DIR="$REPO/.claude/team/personas"
STATUS_DIR="$REPO/.claude/team/status"
TASKS_FILE="$REPO/.claude/team/tasks.md"
WORKTREES_DIR="$REPO/.claude/team/worktrees"
mkdir -p "$STATUS_DIR" "$WORKTREES_DIR"

# Validate each spec, also count distinct devs and group by task.
declare -A seen_devs
declare -A task_devs   # task_id -> space-separated dev list
for spec in "$@"; do
  IFS=':' read -r dev cli task <<< "$spec"
  if [[ -z "$dev" || -z "$cli" || -z "$task" ]]; then
    echo "error: malformed spec '$spec' (need dev:cli:task_id)" >&2; exit 2
  fi
  if [[ ! -f "$PERSONA_DIR/$dev.md" ]]; then
    echo "error: no persona for '$dev' at $PERSONA_DIR/$dev.md" >&2; exit 2
  fi
  if [[ ! -x "$SCRIPT_DIR/run_${cli}.sh" ]]; then
    echo "error: no runner for cli '$cli' at $SCRIPT_DIR/run_${cli}.sh" >&2; exit 2
  fi
  seen_devs[$dev]=1
  task_devs[$task]="${task_devs[$task]:-} $dev"
done

if (( ${#seen_devs[@]} < 2 )); then
  echo "error: >= 2 distinct devs required per run (got ${#seen_devs[@]})" >&2
  exit 2
fi

# Detect tournament tasks (>=2 devs share a task_id).
declare -A is_tournament
for task in "${!task_devs[@]}"; do
  # shellcheck disable=SC2206
  arr=( ${task_devs[$task]} )
  if (( ${#arr[@]} >= 2 )); then
    is_tournament[$task]=1
  fi
done

# -------- tournament: prepare git worktrees --------

declare -A worktree_path  # key="<dev>:<task>" -> absolute worktree path

if (( ${#is_tournament[@]} > 0 )); then
  if ! command -v git >/dev/null 2>&1; then
    echo "error: tournament mode (>=2 devs share a task) requires git on PATH" >&2
    exit 2
  fi
  if ! git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
    echo "error: $REPO is not a git repo; tournament mode needs git worktrees" >&2
    echo "       run 'git init' or assign devs to distinct task_ids" >&2
    exit 2
  fi

  echo ""
  echo "tournament mode detected on: ${!is_tournament[*]}"
  for task in "${!is_tournament[@]}"; do
    # shellcheck disable=SC2206
    devs_in_task=( ${task_devs[$task]} )
    for dev in "${devs_in_task[@]}"; do
      wt="$WORKTREES_DIR/${task}-${dev}"
      branch="tournament/${task}/${dev}"
      # Tear down any stale worktree from a previous run.
      if [[ -d "$wt" ]]; then
        git -C "$REPO" worktree remove --force "$wt" >/dev/null 2>&1 || rm -rf "$wt"
      fi
      git -C "$REPO" branch -D "$branch" >/dev/null 2>&1 || true
      if ! git -C "$REPO" worktree add -B "$branch" "$wt" HEAD >/dev/null 2>&1; then
        echo "error: failed to create worktree at $wt (branch=$branch)" >&2
        exit 2
      fi
      worktree_path["${dev}:${task}"]="$wt"
      echo "  $dev -> $wt   (branch $branch)"
    done
  done
  echo ""
fi

# -------- extract a task row's columns from tasks.md --------

extract_task() {
  # Args: <task_id>
  # Prints: a markdown blockquote of the task's row + headers, or empty string.
  local id="$1"
  awk -v id="$id" '
    /^\| *id *\|/ { hdr=$0; next }
    /^\|[^|]*\|/ && $0 ~ ("^\\| *" id " *\\|") {
      if (hdr != "") print "| header  | " hdr
      print "| row     | " $0
      found=1
    }
    END { if (!found) print "(task " id " not found in tasks.md)" }
  ' "$TASKS_FILE"
}

# -------- build the final prompt for one dev --------

build_prompt() {
  local dev="$1" task="$2" wt="${3:-}"
  local persona; persona=$(cat "$PERSONA_DIR/$dev.md")
  local task_block; task_block=$(extract_task "$task")

  local tournament_block=""
  if [[ -n "$wt" ]]; then
    tournament_block="

----

## TOURNAMENT MODE — isolated worktree

You are competing with at least one other dev on **the same task ($task)**.
Leader will diff each worktree at the end and pick a winner.

- **Your isolated git worktree this run:** $wt
- Edit files ONLY inside this worktree. Do NOT touch the main repo at $REPO.
- Commit your work in the worktree (\`git add . && git commit -m '<msg>'\`) so the leader can diff it cleanly.
- **Status file goes to the ABSOLUTE path below**, not the worktree's relative copy:
  \`$REPO/.claude/team/status/$dev.env\`
  (The leader reads only from the main repo's status dir.)
- Be opinionated. Don't try to be \"safe\" — propose your real best solution; the other dev is doing the same.
"
  fi

  cat <<PROMPT
$persona

----

## Your task this run

You are assigned task **$task** from .claude/team/tasks.md.

$task_block
$tournament_block

----

## Operating rules

- You are running as an autonomous CLI agent. Edit files directly in the working tree.
- Read \`.claude/team/tasks.md\` to see your row's full details (summary, files, acceptance, depends_on).
- Read \`.claude/memory/\` notes that look relevant (start with the per-section \`_moc.md\` files).
- When finished (or blocked / failed), overwrite the status file with the protocol fields listed in your persona (above). The leader reads it after waiting for you.
- Other devs are running in parallel right now. Do NOT touch their status files. Do NOT edit \`tasks.md\` directly — the leader aggregates.
- Honor the project rules in CLAUDE.md. Never read \`.env*\` files.

Begin.
PROMPT
}

# -------- spawn loop --------

# Clear stale status files for the devs we're about to spawn.
for spec in "$@"; do
  IFS=':' read -r dev cli task <<< "$spec"
  rm -f "$STATUS_DIR/$dev.env" 2>/dev/null || true
done

declare -a pids=() labels=()
for spec in "$@"; do
  IFS=':' read -r dev cli task <<< "$spec"
  wt_path="${worktree_path[${dev}:${task}]:-}"
  prompt="$(build_prompt "$dev" "$task" "$wt_path")"

  if [[ -n "$wt_path" ]]; then
    # Tournament: run the CLI with cwd in its isolated worktree.
    ( cd "$wt_path" && "$SCRIPT_DIR/run_${cli}.sh" --dev="$dev" "$prompt" >/dev/null 2>&1 ) &
  else
    # Normal: run the CLI with cwd at the main repo.
    ( cd "$REPO" && "$SCRIPT_DIR/run_${cli}.sh" --dev="$dev" "$prompt" >/dev/null 2>&1 ) &
  fi
  pid=$!
  pids+=("$pid")
  labels+=("$dev:$cli:$task (pid $pid)")
  if [[ -n "$wt_path" ]]; then
    echo "spawned $dev ($cli) for task $task in worktree $wt_path -> pid $pid"
  else
    echo "spawned $dev ($cli) for task $task -> pid $pid"
  fi
done

echo ""
echo "waiting for ${#pids[@]} CLI process(es) to finish..."
echo "(tail their output live with .claude/bin/team-tui.sh — view [P])"
echo ""

declare -a results=()
for i in "${!pids[@]}"; do
  if wait "${pids[$i]}"; then
    results+=("0")
  else
    results+=("$?")
  fi
done

# -------- aggregate status files --------

echo ""
echo "=================== run summary ==================="
fail_count=0
for i in "${!pids[@]}"; do
  IFS=':' read -r dev cli task <<< "${labels[$i]%% *}"
  ec="${results[$i]}"
  echo ""
  echo "--- $dev ($cli) task=$task pid-exit=$ec ---"
  status_file="$STATUS_DIR/$dev.env"
  if [[ -f "$status_file" ]]; then
    cat "$status_file"
    if grep -q '^status=failed' "$status_file" || grep -q '^status=blocked' "$status_file"; then
      fail_count=$((fail_count+1))
    fi
  else
    echo "(no $status_file written - CLI may have crashed)"
    fail_count=$((fail_count+1))
  fi
done
echo "==================================================="

# -------- tournament summary --------

if (( ${#is_tournament[@]} > 0 )); then
  echo ""
  echo "=============== tournament worktrees ==============="
  for task in "${!is_tournament[@]}"; do
    echo ""
    echo "[task=$task] candidates:"
    # shellcheck disable=SC2206
    devs_in_task=( ${task_devs[$task]} )
    for dev in "${devs_in_task[@]}"; do
      wt="${worktree_path[${dev}:${task}]}"
      diffstat=$(git -C "$wt" diff --stat HEAD 2>/dev/null | tail -1)
      [[ -z "$diffstat" ]] && diffstat="(no uncommitted diff)"
      commits=$(git -C "$wt" log --oneline HEAD ^"$(git -C "$REPO" rev-parse HEAD)" 2>/dev/null | wc -l | tr -d ' ')
      echo "  $dev"
      echo "    path:    $wt"
      echo "    branch:  tournament/$task/$dev"
      echo "    commits: $commits ahead of base"
      echo "    diff:    $diffstat"
    done
  done
  echo "===================================================="
  echo ""
  echo "Leader: inspect each worktree, pick a winner, then:"
  echo "  .claude/bin/prune-worktrees.sh <task_id> <winning-dev>"
  echo "  (merges winner into main branch and removes all worktrees for the task)"
fi

echo ""
echo "failures or blockers: $fail_count / ${#pids[@]}"
exit "$fail_count"
