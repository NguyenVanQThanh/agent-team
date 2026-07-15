#!/usr/bin/env bash
# File:        deepseek-cli.sh
# Description: Resolves the installed CLI for DeepSeek teammates.
# Created at:  2026-07-15   Created by: Codex
# Updated at:  2026-07-15   Updated by: Codex

deepseek_resolve_bin() {
  if [[ -n "${DEEPSEEK_BIN:-}" ]]; then
    printf '%s\n' "$DEEPSEEK_BIN"
    return 0
  fi

  if command -v codewhale >/dev/null 2>&1; then
    printf '%s\n' "codewhale"
    return 0
  fi

  if command -v deepseek-tui >/dev/null 2>&1; then
    printf '%s\n' "deepseek-tui"
    return 0
  fi

  echo "error: no DeepSeek CLI found; install codewhale or deepseek-tui, or set DEEPSEEK_BIN" >&2
  return 127
}

deepseek_cli_label() {
  case "${1%% *}" in
    codewhale) printf '%s\n' "CodeWhale" ;;
    deepseek-tui) printf '%s\n' "DeepSeek TUI" ;;
    *) printf '%s\n' "DeepSeek CLI" ;;
  esac
}
