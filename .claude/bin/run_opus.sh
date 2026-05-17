#!/usr/bin/env bash
# Wrapper for the Opus CLI. Records the invocation under
# .claude/team/runs/<run-id>/ so team-tui.sh can show it.
#
# Usage:
#   .claude/bin/run_opus.sh [--dev=dev5] "<prompt>"
#
# Optional env:
#   OPUS_BIN   - binary spec, default "opus". May contain spaces, e.g.
#                OPUS_BIN="claude --model opus"
#   OPUS_FLAGS - extra flags appended after OPUS_BIN.
#   DEV_NAME   - default dev tag if --dev= not provided.

set -euo pipefail
DIR="$( cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd )"
# shellcheck source=./_runner.sh
source "$DIR/_runner.sh"
runner_exec "opus" "${OPUS_BIN:-opus}" "OPUS_FLAGS" "$@"
