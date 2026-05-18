#!/usr/bin/env bash
# Wrapper for Claude Sonnet CLI (dev8, dev9).
# Usage: .claude/bin/run_sonnet.sh [--dev=dev8] "<prompt>"
# Env: SONNET_BIN (default: "claude --model sonnet"), SONNET_FLAGS, DEV_NAME

set -euo pipefail
DIR="$( cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd )"
source "$DIR/_runner.sh"
runner_exec "sonnet" "${SONNET_BIN:-claude --model sonnet}" "SONNET_FLAGS" "$@"
