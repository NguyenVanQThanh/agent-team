#!/usr/bin/env bash
# Wrapper for the Codex CLI. Records the invocation under
# .claude/team/runs/<run-id>/ so team-tui.sh can show it.
#
# Usage:
#   .claude/bin/run_codex.sh [--dev=dev1] "<prompt>"
#
# Optional env: CODEX_FLAGS, DEV_NAME (used if --dev= not provided).

set -euo pipefail
DIR="$( cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd )"
# shellcheck source=./_runner.sh
source "$DIR/_runner.sh"
runner_exec "codex" "codex" "CODEX_FLAGS" "$@"
