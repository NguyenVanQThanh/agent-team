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

SCRIPT_DIR="$( cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd )"
REPO="$( cd -- "$SCRIPT_DIR/../.." &>/dev/null && pwd )"
PERSONA_DIR="$REPO/.claude/team/personas"
STATUS_DIR="$REPO/.claude/team/status"
TASKS_FILE="$REPO/.claude/team/tasks.md"
WORKTREES_DIR="$REPO/.claude/team/worktrees"
QUEUE_DIR="$REPO/.claude/team/queue"
PLANS_DIR="$REPO/.claude/team/plans"
mkdir -p "$STATUS_DIR" "$WORKTREES_DIR" "$QUEUE_DIR/pending" "$QUEUE_DIR/claimed" "$QUEUE_DIR/done" "$QUEUE_DIR/failed"

# -------- new-flag parsing (pool mode + plan ingestion) --------
# Both flags can appear before positional specs. They short-circuit into
# alternative flows; legacy pinned mode is untouched if neither is used.

POOL_MODE=0
FROM_PLAN=""
declare -a POOL_DEVS=()       # specs like "devN:cli" (no task_id in pool mode)
declare -a PINNED_SPECS=()    # passthrough to legacy logic below

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pool)
      POOL_MODE=1; shift ;;
    --from-plan)
      FROM_PLAN="${2:-}"; shift 2 ;;
    --from-plan=*)
      FROM_PLAN="${1#--from-plan=}"; shift ;;
    -h|--help)
      cat >&2 <<USAGE
usage:
  # pinned mode (legacy, leader pre-assigns task_id):
  $0 <dev>:<cli>:<task_id> <dev>:<cli>:<task_id> [more...]

  # pool mode (devs pull from .claude/team/queue/pending/):
  $0 --pool <dev>:<cli> <dev>:<cli> [more...]

  # plan-document mode (leader gives a plan.md, spawn parses tasks into queue):
  $0 --from-plan .claude/team/plans/<id>.md --pool <dev>:<cli> [more...]
  $0 --from-plan .claude/team/plans/<id>.md <dev>:<cli>:<task_id> [more...]

Hard rule (all modes): >= 2 distinct devs per run.
USAGE
      exit 0 ;;
    *)
      # Distinguish pool spec (dev:cli) vs pinned spec (dev:cli:task_id) by
      # the number of colons.
      if [[ "$1" == *:*:* ]]; then
        PINNED_SPECS+=("$1")
      elif [[ "$1" == *:* ]]; then
        POOL_DEVS+=("$1")
      else
        echo "error: unrecognised arg '$1'" >&2; exit 2
      fi
      shift ;;
  esac
done

# If --from-plan given: parse plan and write task files into queue/pending/.
plan_parse() {
  # Args: <plan-file>
  # Looks for a markdown table whose header row contains "id" and "size".
  # Each subsequent row becomes one queue/pending/T-XXX.task file.
  # Columns recognised (case-insensitive): id, size, summary, files,
  # acceptance, depends_on. Unknown columns are ignored.
  local plan="$1"
  [[ -f "$plan" ]] || { echo "error: plan file not found: $plan" >&2; return 2; }
  python3 - "$plan" "$QUEUE_DIR/pending" <<'PY'
import re, sys, os, datetime
plan_path = sys.argv[1]
pending = sys.argv[2]
text = open(plan_path, encoding='utf-8').read()
# find first table that has an "id" header column
tables = re.findall(r'(\|[^\n]*\|\n\|[ \-:|]+\|\n(?:\|[^\n]*\|\n?)+)', text)
hdr_idx = None
for tbl in tables:
    first_line = tbl.splitlines()[0]
    cols = [c.strip().lower() for c in first_line.strip().strip('|').split('|')]
    if 'id' in cols and 'size' in cols:
        hdr = cols
        rows = []
        for line in tbl.splitlines()[2:]:
            if not line.strip(): continue
            cells = [c.strip() for c in line.strip().strip('|').split('|')]
            if len(cells) != len(hdr): continue
            rows.append(dict(zip(hdr, cells)))
        ts = datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
        n = 0
        for r in rows:
            tid = r.get('id','').strip()
            if not tid: continue
            outp = os.path.join(pending, f'{tid}.task')
            with open(outp, 'w', encoding='utf-8') as f:
                f.write(f'id={tid}\n')
                f.write(f'size={r.get("size","M")}\n')
                f.write(f'summary={r.get("summary","")}\n')
                f.write(f'files={r.get("files","")}\n')
                f.write(f'acceptance={r.get("acceptance","")}\n')
                f.write(f'depends_on={r.get("depends_on","")}\n')
                f.write(f'created_at={ts}\n')
                f.write(f'source_plan={os.path.relpath(plan_path)}\n')
            n += 1
        print(f'wrote {n} task files into {pending} from {plan_path}', file=sys.stderr)
        sys.exit(0)
print('error: no table with id+size columns in plan', file=sys.stderr)
sys.exit(2)
PY
}

if [[ -n "$FROM_PLAN" ]]; then
  plan_parse "$FROM_PLAN" || exit $?
fi

# -------- pool mode dispatch --------
if (( POOL_MODE == 1 )); then
  # Validate >= 2 distinct devs
  declare -A pool_seen=()
  for spec in "${POOL_DEVS[@]:-}"; do
    [[ -z "$spec" ]] && continue
    IFS=':' read -r dev cli <<< "$spec"
    if [[ -z "$dev" || -z "$cli" ]]; then
      echo "error: malformed pool spec '$spec' (need dev:cli)" >&2; exit 2
    fi
    if [[ ! -f "$PERSONA_DIR/$dev.md" ]]; then
      echo "error: no persona for '$dev'" >&2; exit 2
    fi
    if [[ ! -x "$SCRIPT_DIR/run_${cli}.sh" ]]; then
      echo "error: no runner for cli '$cli'" >&2; exit 2
    fi
    pool_seen[$dev]=1
  done
  if (( ${#pool_seen[@]} < 2 )); then
    echo "error: --pool needs >= 2 distinct devs (got ${#pool_seen[@]})" >&2
    exit 2
  fi

  # Verify queue has work.
  shopt -s nullglob
  q=( "$QUEUE_DIR/pending"/*.task )
  shopt -u nullglob
  if (( ${#q[@]} == 0 )); then
    echo "error: queue/pending/ is empty — nothing for pool to claim" >&2
    exit 2
  fi

  echo "pool mode: ${#pool_seen[@]} devs, ${#q[@]} pending tasks"
  declare -a pool_pids=() pool_labels=()
  for spec in "${POOL_DEVS[@]}"; do
    IFS=':' read -r dev cli <<< "$spec"
    rm -f "$STATUS_DIR/$dev.env" 2>/dev/null || true
    (
      while true; do
        tf=$("$SCRIPT_DIR/claim-task.sh" "$dev" 2>/dev/null) || break
        [[ -z "$tf" ]] && break
        tid=$(grep -E "^id=" "$tf" | head -1 | cut -d= -f2- | tr -d "\r")
        persona=$(cat "$PERSONA_DIR/$dev.md")
        prompt=$(cat <<PROMPT
$persona

----

## Pool mode

You are running in **pool mode**. The runner has already claimed task **$tid**
for you. The full spec is appended below by the runner.

When finished, the runner trailer will call complete-task.sh for you with
the exit code. If your CLI exits 0 the task is recorded as done; otherwise
failed. If you need to mark it specifically, run:
  .claude/bin/complete-task.sh $dev $tid done|failed "<notes>"
before exiting.

DO NOT edit .claude/team/tasks.md (the leader aggregates).
Read shared context: CLAUDE.md, .claude/config/coding-rules.md, .claude/memory/.

Begin.
PROMPT
)
        if ( cd "$REPO" && "$SCRIPT_DIR/run_${cli}.sh" --dev="$dev" --task-file="$tf" "$prompt" >/dev/null 2>&1 ); then
          # If the dev did not write the final state itself, do it now.
          [[ -f "$QUEUE_DIR/claimed/${tid}.task" ]] && \
            "$SCRIPT_DIR/complete-task.sh" "$dev" "$tid" done "auto-finalised by spawn-team" >/dev/null
        else
          [[ -f "$QUEUE_DIR/claimed/${tid}.task" ]] && \
            "$SCRIPT_DIR/complete-task.sh" "$dev" "$tid" failed "runner exit non-zero" >/dev/null
        fi
      done
    ) &
    pid=$!
    pool_pids+=("$pid"); pool_labels+=("$dev:$cli (pid $pid)")
    echo "pool worker $dev ($cli) started, pid $pid"
  done

  echo ""
  echo "waiting for ${#pool_pids[@]} pool worker(s) to drain the queue..."
  for i in "${!pool_pids[@]}"; do
    wait "${pool_pids[$i]}" || true
  done

  echo ""
  echo "============= pool run summary ============="
  for st in done failed; do
    shopt -s nullglob
    files=( "$QUEUE_DIR/$st"/*.task )
    shopt -u nullglob
    echo "$st: ${#files[@]} task(s)"
    for f in "${files[@]}"; do
      tid=$(grep -E "^id=" "$f" | head -1 | cut -d= -f2-)
      by=$(grep -E "^claimed_by=" "$f" | head -1 | cut -d= -f2-)
      echo "  - $tid (claimed_by=$by)"
    done
  done
  echo "============================================"
  exit 0
fi

# -------- legacy pinned mode --------
# Replace positional args with the collected pinned specs so the rest of
# the original script works unchanged.
set -- "${PINNED_SPECS[@]:-}"

# -------- pre-flight (pinned mode) --------

if [[ $# -lt 2 || -z "${1:-}" ]]; then
  cat >&2 <<USAGE
usage: $0 <dev>:<cli>:<task_id> <dev>:<cli>:<task_id> [more...]
       $0 --pool <dev>:<cli> <dev>:<cli> [more...]
       $0 --from-plan PATH ...

Examples:
  $0 dev1:codex:T-001 dev3:deepseek:T-002
  $0 dev2:codex:T-005 dev5:opus:T-006 dev4:deepseek:T-007
  $0 dev5:opus:T-100 dev13:codex:T-100  # tournament on T-100
  $0 --pool dev1:codex dev4:deepseek dev8:sonnet

Hard rule: at least 2 specs required (>= 2 devs per run).
USAGE
  exit 2
fi

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
