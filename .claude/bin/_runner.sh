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
unset CODEX_FLAGS DEEPSEEK_FLAGS OPUS_FLAGS OPUS_BIN 2>/dev/null || true
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
  if [[ "${1:-}" == --dev=* ]]; then
    dev="${1#--dev=}"; shift
  fi

  if [[ $# -lt 1 ]]; then
    echo "usage: run_${cli_name}.sh [--dev=devX] \"<prompt>\"" >&2
    return 2
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

  {
    echo "run_id=$run_id"
    echo "dev=$dev"
    echo "cli=$cli_name"
    echo "pid=$$"
    echo "started_at=$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')"
    echo "status=running"
    printf 'prompt=%q\n' "$prompt"
  } > "$_RUNNER_META"

  trap _runner_cleanup EXIT

  echo "[runner] run_id=$run_id  dev=$dev  cli=$cli_name  log=$output" >&2

  local flags="${!flags_var:-}"

  # shellcheck disable=SC2086
  $bin_spec $flags "$@" 2>&1 | tee "$output"
  local ec=${PIPESTATUS[0]}
  return "$ec"
}
