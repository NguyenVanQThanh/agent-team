#!/usr/bin/env bash
# File:        memory-tools.sh
# Description: Manages local QMD retrieval and validates Serena integration.
# Created at:  2026-07-15   Created by: Codex
# Updated at:  2026-07-15   Updated by: Codex

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
MEMORY_DIR="$REPO/.claude/memory"
RUNTIME_DIR="$REPO/.claude/runtime/qmd"
COLLECTION="agent-team-memory"
QMD_BIN="${QMD_BIN:-}"
QMD_PREFIX=()
SERENA_BIN="${SERENA_BIN:-serena}"

export XDG_CONFIG_HOME="$RUNTIME_DIR/config"
export XDG_CACHE_HOME="$RUNTIME_DIR/cache"

usage() {
  cat <<'USAGE'
usage: .claude/bin/memory-tools.sh <command> [query]

commands:
  status             Show QMD collection/index status.
  bootstrap          Register, index, and embed the team memory vault.
  update             Refresh and embed the team memory vault.
  search <query>     Search the team memory vault without reranking.
  mcp                Start the QMD stdio MCP server.
  serena-check       Print the project-scoped Serena MCP launch command.
USAGE
}

qmd_available() {
  if [[ -n "$QMD_BIN" ]]; then
    command -v "$QMD_BIN" >/dev/null 2>&1
  elif command -v qmd >/dev/null 2>&1; then
    QMD_BIN="qmd"
  elif command -v npx >/dev/null 2>&1 && npx --no-install @tobilu/qmd --version >/dev/null 2>&1; then
    QMD_BIN="npx"
    QMD_PREFIX=(--no-install @tobilu/qmd)
  else
    return 1
  fi
}

run_qmd() {
  "$QMD_BIN" "${QMD_PREFIX[@]}" "$@"
}

qmd_fallback() {
  local query="${1:-<question>}"
  printf "QMD is unavailable; fallback: rg -n --glob '*.md' -- %s .claude/memory\n" "$query"
}

require_qmd() {
  if ! qmd_available; then
    qmd_fallback "${1:-<question>}"
    return 1
  fi
  mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
}

bootstrap_qmd() {
  # 1. Register the canonical vault; an existing collection is harmless.
  run_qmd collection add "$MEMORY_DIR" --name "$COLLECTION" --mask "**/*.md" || true
  # 2. Build the lexical index before vector embeddings.
  run_qmd update || return 1
  # 3. Generate embeddings for semantic retrieval.
  run_qmd embed -c "$COLLECTION" || return 1
  printf 'QMD collection ready: %s\n' "$COLLECTION"
}

update_qmd() {
  # 1. Refresh the canonical files and remove stale index entries.
  run_qmd update || return 1
  # 2. Refresh vectors only after the lexical update succeeds.
  run_qmd embed -c "$COLLECTION" || return 1
  printf 'QMD collection updated: %s\n' "$COLLECTION"
}

search_qmd() {
  local query="$1"
  # 1. Keep retrieval scoped to the durable team-memory collection.
  run_qmd query "$query" -c "$COLLECTION" --no-rerank || return 1
  # 2. Tell callers which query was executed without changing canonical notes.
  printf 'QMD search completed: %s\n' "$query"
}

case "${1:-}" in
  status)
    require_qmd || exit 0
    run_qmd status || qmd_fallback
    ;;
  bootstrap)
    require_qmd || exit 0
    bootstrap_qmd || qmd_fallback
    ;;
  update)
    require_qmd || exit 0
    update_qmd || qmd_fallback
    ;;
  search)
    shift
    [[ $# -gt 0 ]] || { usage >&2; exit 2; }
    require_qmd "$*" || exit 0
    search_qmd "$*" || qmd_fallback "$*"
    ;;
  mcp)
    require_qmd || exit 0
    exec "$QMD_BIN" "${QMD_PREFIX[@]}" mcp || qmd_fallback
    ;;
  serena-check)
    if ! command -v "$SERENA_BIN" >/dev/null 2>&1; then
      printf 'Serena is unavailable; fallback: rg and built-in file tools remain active.\n'
      exit 0
    fi
    printf 'serena start-mcp-server --project %s --context=codex\n' "$REPO"
    ;;
  -h|--help|"")
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
