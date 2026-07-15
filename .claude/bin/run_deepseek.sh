#!/usr/bin/env bash
# Wrapper for CodeWhale or DeepSeek TUI. Records the invocation under
# .claude/team/runs/<run-id>/ so team-tui.sh can show it.
#
# Usage:
#   .claude/bin/run_deepseek.sh [--dev=dev3] "<prompt>"
#
# Optional env: DEEPSEEK_BIN, DEEPSEEK_FLAGS, DEV_NAME.

set -euo pipefail
DIR="$( cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd )"
# shellcheck source=./_runner.sh
source "$DIR/_runner.sh"
# shellcheck source=./deepseek-cli.sh
source "$DIR/deepseek-cli.sh"

deepseek_bin="$(deepseek_resolve_bin)" || exit $?
runner_exec "deepseek" "$deepseek_bin" "DEEPSEEK_FLAGS" "$@"
