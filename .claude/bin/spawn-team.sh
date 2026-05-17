#!/usr/bin/env bash
# spawn-team.sh — spawn multiple CLI dev agents in parallel.
#
# Usage:
#   .claude/bin/spawn-team.sh <spec> [<spec> ...]
#
# Each <spec> has the form: <dev>:<cli>:<task_id>
#   dev      = dev1 | dev2 | dev3 | dev4 | dev5
#   cli      = codex | deepseek | opus
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

Hard rule: at least 2 specs required (>= 2 devs per run).
USAGE
  exit 2
fi

SCRIPT_DIR="$( cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd )"
REPO="$( cd -- "$SCRIPT_DIR/../.." &>/dev/null && pwd )"
PERSONA_DIR="$REPO/.claude/team/personas"
STATUS_DIR="$REPO/.claude/team/status"
TASKS_FILE="$REPO/.claude/team/tasks.md"
mkdir -p "$STATUS_DIR"

# Validate each spec, also count distinct devs.
declare -A seen_devs
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
done

if (( ${#seen_devs[@]} < 2 )); then
  echo "error: ≥ 2 distinct devs required per run (got ${#seen_devs[@]})" >&2
  exit 2
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
  local dev="$1" task="$2"
  local persona; persona=$(cat "$PERSONA_DIR/$dev.md")
  local task_block; task_block=$(extract_task "$task")

  cat <<PROMPT
$persona

----

## Your task this run

You are assigned task **$task** from .claude/team/tasks.md.

$task_block

----

## Operating rules

- You are running as an autonomous CLI agent. Edit files directly in the repo at $REPO.
- Read \`.claude/team/tasks.md\` to see your row's full details (summary, files, acceptance, depends_on).
- Read \`.claude/memory/\` notes that look relevant (start with the per-section \`_moc.md\` files).
- When finished (or blocked / failed), overwrite \`.claude/team/status/$dev.env\` with the protocol fields listed in your persona (above). The leader reads it after waiting for you.
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
  prompt="$(build_prompt "$dev" "$task")"

  # Spawn the runner in the background. We discard its stdout (it's already
  # tee'd to the run's output.log by _runner.sh).
  "$SCRIPT_DIR/run_${cli}.sh" --dev="$dev" "$prompt" >/dev/null 2>&1 &
  pid=$!
  pids+=("$pid")
  labels+=("$dev:$cli:$task (pid $pid)")
  echo "spawned $dev ($cli) for task $task -> pid $pid"
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
    echo "(no $status_file written — CLI may have crashed)"
    fail_count=$((fail_count+1))
  fi
done
echo "==================================================="
echo ""
echo "failures or blockers: $fail_count / ${#pids[@]}"
exit "$fail_count"
