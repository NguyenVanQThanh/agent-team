#!/usr/bin/env bash
# Wrapper for the DeepSeek lane. Runs `claude` (Claude Code CLI) pointed at
# 9router with the DeepSeek model prefix (ds/*) via a rendered --settings
# file — NOT a standalone codewhale/deepseek-tui binary. Records the
# invocation under .claude/team/runs/<run-id>/ so team-tui.sh can show it.
#
# Usage:
#   .claude/bin/run_deepseek.sh [--dev=dev3] "<prompt>"
#
# Optional env: DEEPSEEK_FLAGS, NINEROUTER_KEY, DEV_NAME.

set -euo pipefail
DIR="$( cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd )"
# shellcheck source=./_runner.sh
source "$DIR/_runner.sh"

rendered="$(runner_render_settings "$DIR/settings/settings-deepseek.json")"
export DEEPSEEK_FLAGS="--settings $rendered --dangerously-skip-permissions -p"

runner_exec "deepseek" "claude" "DEEPSEEK_FLAGS" "$@"
