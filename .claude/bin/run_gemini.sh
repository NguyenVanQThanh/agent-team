#!/usr/bin/env bash
# Wrapper for Google Gemini CLI (dev11 — research pre-phase).
# Usage: .claude/bin/run_gemini.sh [--dev=dev11] "<prompt>"
# Env: GEMINI_BIN (default: "gemini"), GEMINI_FLAGS, DEV_NAME

set -euo pipefail
DIR="$( cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd )"
source "$DIR/_runner.sh"
runner_exec "gemini" "${GEMINI_BIN:-gemini}" "GEMINI_FLAGS" "$@"
