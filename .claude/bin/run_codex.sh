#!/usr/bin/env bash
# Wrapper for the Codex lane. Runs `claude` (Claude Code CLI) pointed at
# 9router with the Codex model prefix (cx/*) via a rendered --settings file —
# NOT the standalone `codex` binary. Records the invocation under
# .claude/team/runs/<run-id>/ so team-tui.sh can show it.
#
# Usage:
#   .claude/bin/run_codex.sh [--dev=dev1] "<prompt>"
#
# Optional env: CODEX_FLAGS, CODEX_FLAGS_DEV<N>, NINEROUTER_KEY, DEV_NAME
# (used if --dev= not provided).

set -euo pipefail
DIR="$( cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd )"
# shellcheck source=./_runner.sh
source "$DIR/_runner.sh"

dev="${DEV_NAME:-unknown}"
for arg in "$@"; do
  case "$arg" in
    --dev=*) dev="${arg#--dev=}" ;;
  esac
done

case "$dev" in
  dev1|dev12|dev15) template="$DIR/settings/settings-codex-luna.json" ;;
  dev2|dev13|dev16) template="$DIR/settings/settings-codex-terra.json" ;;
  *) template="$DIR/settings/settings-codex-luna.json" ;;
esac

rendered="$(runner_render_settings "$template")"
export CODEX_FLAGS="--settings $rendered --dangerously-skip-permissions -p"

runner_exec "codex" "claude" "CODEX_FLAGS" "$@"
