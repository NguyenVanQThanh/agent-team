#!/usr/bin/env bash
# Wrapper for Claude Haiku CLI (dev6, dev7).
# Usage: .claude/bin/run_haiku.sh [--dev=dev6] "<prompt>"
# Env: HAIKU_BIN (default: "claude --model haiku"), HAIKU_FLAGS, DEV_NAME

set -euo pipefail
DIR="$( cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd )"
source "$DIR/_runner.sh"
runner_exec "haiku" "${HAIKU_BIN:-claude --model haiku}" "HAIKU_FLAGS" "$@"
