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

# Global so the EXIT trap (which runs after runner_exec returns) can see it.
_RUNNER_META=""

_runner_cleanup() {
  local ec=$?
  [[ -z "$_RUNNER_META" || ! -f "$_RUNNER_META" ]] && return
  {
    echo "ended_at=$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')"
    echo "exit_code=$ec"
    if [[ $ec -eq 0 ]]; then echo "status=done"; else echo "status=failed"; fi
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

  {
    echo "run_id=$run_id"
    echo "dev=$dev"
    echo "cli=$cli_name"
    echo "pid=$$"
    echo "started_at=$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')"
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
