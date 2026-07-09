#!/usr/bin/env bash
# Shared runner used by run_codex.sh / run_deepseek.sh / run_opus.sh.
# Records every CLI invocation as a "run" under .claude/team/runs/<run-id>/
# so the team-tui.sh dashboard can show what's executing.
#
# A wrapper may pass `--dev=devX` as its first arg to tag the run; or set
# DEV_NAME in the environment. Defaults to "unknown".

set -uo pipefail
# Unset *_FLAGS before sourcing env.sh so parent-shell exports can't override
# the project defaults (prevents BL-01-style leaks of stale flags like --yolo).
unset CODEX_FLAGS CODEX_FLAGS_DEV1 CODEX_FLAGS_DEV2 CODEX_FLAGS_DEV12 CODEX_FLAGS_DEV13 \
      DEEPSEEK_FLAGS OPUS_FLAGS OPUS_BIN \
      HAIKU_FLAGS HAIKU_BIN SONNET_FLAGS SONNET_BIN \
      GEMINI_FLAGS GEMINI_BIN 2>/dev/null || true
# Source local env (OPUS_BIN, *_FLAGS, etc.) if present.
_env_file="$( cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd )/env.sh"
[[ -f "$_env_file" ]] && source "$_env_file"
# NOTE: deliberately NOT using `set -e` here because runner_exec needs to
# capture the CLI's exit code from PIPESTATUS without aborting on failures.

# Globals so the EXIT trap (which runs after runner_exec returns) can see them.
_RUNNER_META=""
_RUNNER_TASK_FILE=""
_RUNNER_REPO=""
_RUNNER_START_EPOCH=""

# Completion validation: an `exit_code=0` from the CLI is NOT proof the task
# was actually done. If a task file declares `files=` (comma-separated paths),
# we verify at least one of those files was modified after the run started.
# Without this, sub-CLIs that silently no-op (e.g. permission-walled, or
# drifted to unrelated work) get recorded as `status=done` and poison the
# leader's status aggregation (see B-001 2026-05-20).
#
# Resulting `status=` field semantics:
#   done      — exit 0 AND (no files= declared OR all expected files modified)
#   partial   — exit 0 AND some-but-not-all expected files modified
#   degraded  — exit 0 BUT zero expected files modified (i.e. silent no-op)
#   failed    — exit non-zero
_runner_cleanup() {
  local ec=$?
  [[ -z "$_RUNNER_META" || ! -f "$_RUNNER_META" ]] && return

  # Decide the headline status first based on exit code + file validation.
  local status_word notes_runner=""
  local files_expected=0 files_touched=0
  local missing=""

  if [[ -n "$_RUNNER_TASK_FILE" && -f "$_RUNNER_TASK_FILE" ]]; then
    local files_line
    files_line=$(grep -E '^files=' "$_RUNNER_TASK_FILE" | head -1 | cut -d= -f2- | tr -d '\r')
    if [[ -n "$files_line" ]]; then
      IFS=',' read -r -a expected_files <<< "$files_line"
      for f in "${expected_files[@]}"; do
        # trim whitespace
        f="${f#"${f%%[![:space:]]*}"}"; f="${f%"${f##*[![:space:]]}"}"
        [[ -z "$f" ]] && continue
        files_expected=$((files_expected+1))
        # resolve relative to repo
        local abs="$f"
        if [[ "$f" != /* && -n "$_RUNNER_REPO" ]]; then
          abs="$_RUNNER_REPO/$f"
        fi
        local mt
        mt=$(stat -c%Y "$abs" 2>/dev/null || stat -f%m "$abs" 2>/dev/null || echo "")
        if [[ -n "$mt" && -n "$_RUNNER_START_EPOCH" && "$mt" -ge "$_RUNNER_START_EPOCH" ]]; then
          files_touched=$((files_touched+1))
        else
          missing="${missing:+$missing,}$f"
        fi
      done
    fi
  fi

  if (( ec != 0 )); then
    status_word="failed"
  elif (( files_expected == 0 )); then
    # No files= declared (research/review task) — trust exit code.
    status_word="done"
  elif (( files_touched == files_expected )); then
    status_word="done"
  elif (( files_touched == 0 )); then
    status_word="degraded"
    notes_runner="exit 0 but ZERO expected files modified — likely silent no-op (permission wall, drift, or did-nothing)"
  else
    status_word="partial"
    notes_runner="$files_touched of $files_expected expected files modified; missing: $missing"
  fi

  {
    echo "ended_at=$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')"
    echo "exit_code=$ec"
    echo "status=$status_word"
    if (( files_expected > 0 )); then
      echo "files_expected=$files_expected"
      echo "files_touched=$files_touched"
      [[ -n "$missing" ]] && echo "files_missing=$missing"
    fi
    [[ -n "$notes_runner" ]] && printf 'notes_runner=%q\n' "$notes_runner"
  } >> "$_RUNNER_META"
}

runner_resolve_repo() {
  local d
  d="$( cd -- "$(dirname -- "${BASH_SOURCE[1]:-$0}")" &>/dev/null && pwd )"
  while [[ "$d" != "/" && ! -d "$d/.claude" ]]; do d="$(dirname "$d")"; done
  echo "$d"
}

runner_exec() {
  local cli_name="$1"; shift
  local bin_spec="$1"; shift
  local flags_var="$1"; shift

  local dev="${DEV_NAME:-unknown}"
  local task_file=""
  # Accept --dev= and --task-file= in any order (both optional, both before
  # the positional prompt).
  while [[ "${1:-}" == --* ]]; do
    case "$1" in
      --dev=*)        dev="${1#--dev=}"; shift ;;
      --task-file=*)  task_file="${1#--task-file=}"; shift ;;
      *) break ;;
    esac
  done

  if [[ $# -lt 1 ]]; then
    echo "usage: run_${cli_name}.sh [--dev=devX] [--task-file=PATH] \"<prompt>\"" >&2
    return 2
  fi

  # Per-dev flags override: e.g. CODEX_FLAGS_DEV1 wins over CODEX_FLAGS.
  # Lets us run dev1 at medium reasoning and dev2 at high with the same wrapper.
  if [[ "$dev" != "unknown" ]]; then
    local dev_upper
    dev_upper="$(printf '%s' "$dev" | tr '[:lower:]' '[:upper:]')"
    local per_dev_var="${flags_var}_${dev_upper}"
    if [[ -n "${!per_dev_var:-}" ]]; then
      flags_var="$per_dev_var"
    fi
  fi

  local first_word="${bin_spec%% *}"
  if ! command -v "$first_word" >/dev/null 2>&1; then
    echo "error: '$first_word' (from bin='$bin_spec') not on PATH" >&2
    return 127
  fi

  local repo runs_dir ts run_id run_dir output
  repo="$(runner_resolve_repo)"
  runs_dir="$repo/.claude/team/runs"
  ts="$(date +%Y%m%d-%H%M%S)"
  run_id="${ts}-${cli_name}-$$"
  run_dir="$runs_dir/$run_id"
  mkdir -p "$run_dir"
  output="$run_dir/output.log"

  # Assign to GLOBAL so the EXIT trap sees it.
  _RUNNER_META="$run_dir/meta.env"

  local prompt
  prompt="$(printf '%s' "$1" | tr '\n' ' ' | cut -c1-200)"

  # If a task file was provided, prepend a Task spec block to the prompt so
  # the CLI sees the exact task it was claimed for (pool mode).
  local task_spec_block=""
  local task_id=""
  if [[ -n "$task_file" && -f "$task_file" ]]; then
    task_id=$(grep -E '^id=' "$task_file" | head -1 | cut -d= -f2- | tr -d '\r')
    task_spec_block=$(printf '\n----\n\n## Your task this run (pool mode)\n\nYou were claimed for the task spec below. The full spec lives at:\n  %s\n\n```env\n%s\n```\n\nWhen finished, you (or your runner) MUST call:\n  .claude/bin/complete-task.sh %s %s done|failed "<notes>"\n\n----\n\n' \
      "$task_file" "$(cat "$task_file")" "$dev" "$task_id")
  fi

  # Capture start epoch BEFORE invoking the CLI so completion validation
  # (in _runner_cleanup) can compare against file mtimes.
  _RUNNER_START_EPOCH="$(date +%s)"
  _RUNNER_TASK_FILE="$task_file"
  _RUNNER_REPO="$repo"

  {
    echo "run_id=$run_id"
    echo "dev=$dev"
    echo "cli=$cli_name"
    echo "pid=$$"
    echo "started_at=$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')"
    echo "started_epoch=$_RUNNER_START_EPOCH"
    echo "status=running"
    echo "flags_var=$flags_var"
    [[ -n "$task_file" ]] && echo "task_file=$task_file"
    [[ -n "$task_id" ]]   && echo "task_id=$task_id"
    printf 'prompt=%q\n' "$prompt"
  } > "$_RUNNER_META"

  trap _runner_cleanup EXIT

  echo "[runner] run_id=$run_id  dev=$dev  cli=$cli_name  flags_var=$flags_var  log=$output" >&2

  local flags="${!flags_var:-}"
  local full_prompt="${task_spec_block}${1}"
  shift   # consume the original prompt positional

  # shellcheck disable=SC2086
  $bin_spec $flags "$full_prompt" "$@" 2>&1 | tee "$output"
  local ec=${PIPESTATUS[0]}
  return "$ec"
}
