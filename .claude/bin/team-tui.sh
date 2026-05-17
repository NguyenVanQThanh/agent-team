#!/usr/bin/env bash
# team-tui.sh — small fzf-based TUI to inspect what the agent team is doing.
#
# Three views:
#   [P] Processes    — recent and running CLI invocations (codex/deepseek/opus)
#   [M] Memory vault — recent notes under .claude/memory/
#   [L] Leader runs  — per-run summaries written by the leader agent
#
# Requirements: bash 4+, fzf. (Falls back to a numbered menu if fzf is missing.)
# Keybindings inside the Processes view:
#   enter   = open output log in `less +F` (follow mode)
#   ctrl-k  = SIGTERM the wrapper PID (best-effort; child CLI may orphan)
#   ctrl-d  = delete this run's folder
#   esc     = back to main menu
#
# Usage:
#   .claude/bin/team-tui.sh

set -euo pipefail

SCRIPT_DIR="$( cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd )"
REPO="$( cd -- "$SCRIPT_DIR/../.." &>/dev/null && pwd )"
RUNS_DIR="$REPO/.claude/team/runs"
MEM_DIR="$REPO/.claude/memory"

HAS_FZF=0
if command -v fzf >/dev/null 2>&1; then HAS_FZF=1; fi

# ---------- helpers ----------

color() {
  # color "<color>" "<text>"
  local c="$1"; shift
  case "$c" in
    red)    printf '\033[31m%s\033[0m' "$*";;
    green)  printf '\033[32m%s\033[0m' "$*";;
    yellow) printf '\033[33m%s\033[0m' "$*";;
    blue)   printf '\033[34m%s\033[0m' "$*";;
    cyan)   printf '\033[36m%s\033[0m' "$*";;
    bold)   printf '\033[1m%s\033[0m' "$*";;
    *)      printf '%s' "$*";;
  esac
}

# Read a KEY from a meta.env file (very simple parser; values may be %q-escaped).
meta_get() {
  local file="$1" key="$2"
  awk -F= -v k="$key" '$1==k {sub(/^[^=]*=/,""); v=$0} END {print v}' "$file"
}

# Is a wrapper PID still alive?
pid_alive() {
  local pid="$1"
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

# Effective status — re-checks if the meta says "running" but PID is dead.
effective_status() {
  local meta="$1"
  local status pid
  status=$(meta_get "$meta" status)
  pid=$(meta_get "$meta" pid)
  if [[ "$status" == "running" ]] && ! pid_alive "$pid"; then
    echo "stale"
  else
    echo "$status"
  fi
}

status_badge() {
  case "$1" in
    running) color green   "● RUNNING";;
    done)    color blue    "✓ done   ";;
    failed)  color red     "✗ FAILED ";;
    stale)   color yellow  "? stale  ";;
    *)       printf '%-9s' "$1";;
  esac
}

# Print a one-line summary for a run dir (used as the fzf line).
run_line() {
  local rd="$1"
  local meta="$rd/meta.env"
  [[ -f "$meta" ]] || return 0
  local run_id status dev cli started prompt
  run_id=$(meta_get "$meta" run_id)
  status=$(effective_status "$meta")
  dev=$(meta_get "$meta" dev)
  cli=$(meta_get "$meta" cli)
  started=$(meta_get "$meta" started_at)
  prompt=$(meta_get "$meta" prompt)
  # strip surrounding $'' from %q-escaped prompt if present
  prompt=${prompt#\$\'}
  prompt=${prompt%\'}
  printf '%s\t%s  %-6s  %-9s  %-19s  %s\n' \
    "$run_id" \
    "$(status_badge "$status")" \
    "$dev" \
    "$cli" \
    "${started:0:19}" \
    "${prompt:0:80}"
}

# ---------- Processes view ----------

view_processes() {
  if [[ ! -d "$RUNS_DIR" ]] || [[ -z "$(ls -A "$RUNS_DIR" 2>/dev/null | grep -v '^\.' | head -1)" ]]; then
    echo "$(color yellow "no runs yet.") spawn one with .claude/bin/run_codex.sh \"hello\""
    read -rp "press enter..." _
    return
  fi

  # Build list of run dirs sorted newest first.
  local lines=()
  while IFS= read -r -d '' rd; do
    [[ -f "$rd/meta.env" ]] || continue
    lines+=("$(run_line "$rd")")
  done < <(find "$RUNS_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | sort -rz)

  if (( ${#lines[@]} == 0 )); then
    echo "$(color yellow "no runs found (no meta.env in subfolders).")"
    read -rp "press enter..." _
    return
  fi

  local preview_cmd="$SCRIPT_DIR/team-tui.sh --preview-run $RUNS_DIR/{1}"
  local pick
  if (( HAS_FZF )); then
    pick=$(printf '%s\n' "${lines[@]}" | \
      fzf --ansi --delimiter='\t' --with-nth=2 \
          --header='[enter] tail · [ctrl-k] kill · [ctrl-d] delete · [esc] back' \
          --preview "$preview_cmd" --preview-window=right:60%:wrap \
          --expect=ctrl-k,ctrl-d,esc) || return 0
  else
    # Fallback: numbered menu without preview
    printf '%s\n' "${lines[@]}" | awk -F'\t' '{printf "%3d) %s\n", NR, $2}'
    read -rp "pick #: " n
    [[ -z "$n" ]] && return 0
    pick=$(printf '%s\n' "${lines[@]}" | sed -n "${n}p")
  fi

  # Parse fzf output: first line = pressed key (or empty), next line = the row.
  local key="" row="$pick"
  if (( HAS_FZF )); then
    key=$(printf '%s\n' "$pick" | sed -n 1p)
    row=$(printf '%s\n' "$pick" | sed -n 2p)
  fi
  [[ -z "$row" ]] && return 0

  local run_id="${row%%$'\t'*}"
  local rd="$RUNS_DIR/$run_id"
  case "$key" in
    ctrl-k)
      local pid
      pid=$(meta_get "$rd/meta.env" pid)
      if pid_alive "$pid"; then
        kill "$pid" 2>/dev/null && echo "$(color yellow "sent SIGTERM to $pid")"
      else
        echo "$(color yellow "pid $pid not alive")"
      fi
      read -rp "press enter..." _
      ;;
    ctrl-d)
      read -rp "delete $run_id? [y/N] " yn
      if [[ "$yn" == "y" || "$yn" == "Y" ]]; then
        rm -rf "$rd" && echo "$(color red "deleted") $run_id"
      fi
      read -rp "press enter..." _
      ;;
    *)
      # default = open log
      if [[ -f "$rd/output.log" ]]; then
        less +F "$rd/output.log"
      else
        echo "no output.log in $rd"; read -rp "press enter..." _
      fi
      ;;
  esac
}

# Internal: preview a single run dir (called by fzf).
preview_run() {
  local rd="$1"
  if [[ ! -d "$rd" ]]; then echo "(missing)"; return; fi
  echo "$(color bold "── meta ──")"
  if [[ -f "$rd/meta.env" ]]; then cat "$rd/meta.env"; else echo "(no meta.env)"; fi
  echo ""
  echo "$(color bold "── output (tail) ──")"
  if [[ -f "$rd/output.log" ]]; then tail -n 40 "$rd/output.log"; else echo "(no output.log)"; fi
}

# ---------- Memory view ----------

view_memory() {
  if [[ ! -d "$MEM_DIR" ]]; then
    echo "memory dir missing: $MEM_DIR"; read -rp "press enter..." _; return
  fi

  # Find notes, exclude _moc/_index/_templates/README and .gitkeep
  mapfile -t notes < <(
    find "$MEM_DIR" -type f -name '*.md' \
      ! -path '*/_templates/*' \
      ! -name '_index.md' \
      ! -name '_moc.md' \
      ! -name 'README.md' \
      -printf '%T@\t%p\n' \
      | sort -rn | cut -f2-
  )

  if (( ${#notes[@]} == 0 )); then
    echo "$(color yellow "no notes yet.") templates live in $MEM_DIR/_templates/"
    read -rp "press enter..." _
    return
  fi

  # Show relative paths for readability
  local rels=()
  for p in "${notes[@]}"; do rels+=("${p#$MEM_DIR/}"); done

  local pick
  if (( HAS_FZF )); then
    pick=$(printf '%s\n' "${rels[@]}" | \
      fzf --header='memory vault — [enter] open · [esc] back' \
          --preview "head -n 80 $MEM_DIR/{}" --preview-window=right:65%:wrap) || return 0
  else
    printf '%s\n' "${rels[@]}" | nl
    read -rp "pick #: " n
    [[ -z "$n" ]] && return 0
    pick=$(printf '%s\n' "${rels[@]}" | sed -n "${n}p")
  fi
  [[ -z "$pick" ]] && return 0
  ${PAGER:-less} "$MEM_DIR/$pick"
}

# ---------- Leader runs view ----------

view_leader_runs() {
  mapfile -t logs < <(
    find "$RUNS_DIR" -maxdepth 1 -type f -name 'leader-*.md' \
      -printf '%T@\t%p\n' 2>/dev/null | sort -rn | cut -f2-
  )

  if (( ${#logs[@]} == 0 )); then
    echo "$(color yellow "no leader run summaries yet.")"
    echo "the leader writes these to $RUNS_DIR/leader-<TS>.md per run."
    read -rp "press enter..." _
    return
  fi

  local rels=()
  for p in "${logs[@]}"; do rels+=("${p##*/}"); done

  local pick
  if (( HAS_FZF )); then
    pick=$(printf '%s\n' "${rels[@]}" | \
      fzf --header='leader runs — [enter] open · [esc] back' \
          --preview "head -n 80 $RUNS_DIR/{}" --preview-window=right:65%:wrap) || return 0
  else
    printf '%s\n' "${rels[@]}" | nl
    read -rp "pick #: " n
    [[ -z "$n" ]] && return 0
    pick=$(printf '%s\n' "${rels[@]}" | sed -n "${n}p")
  fi
  [[ -z "$pick" ]] && return 0
  ${PAGER:-less} "$RUNS_DIR/$pick"
}

# ---------- main menu ----------

main_menu() {
  while true; do
    clear
    echo "$(color bold "Agent Team — TUI")"
    echo "repo: $REPO"
    if (( HAS_FZF )); then
      echo "fzf: $(color green available)"
    else
      echo "fzf: $(color yellow "not found — fallback menus only. install with apt/brew install fzf")"
    fi
    echo ""
    echo "  [P] Processes  — CLI invocations (codex/deepseek/opus)"
    echo "  [M] Memory     — Obsidian vault notes"
    echo "  [L] Leader runs— per-run summaries by the leader agent"
    echo "  [Q] Quit"
    echo ""
    read -rp "> " choice
    case "${choice,,}" in
      p) view_processes ;;
      m) view_memory ;;
      l) view_leader_runs ;;
      q|"") clear; return 0 ;;
      *) ;;
    esac
  done
}

# ---------- entry point ----------

case "${1:-}" in
  --preview-run)
    preview_run "$2"
    ;;
  -h|--help)
    sed -n '2,/^set -e/p' "$0" | sed 's/^# \{0,1\}//' | sed '/^set -e/d'
    ;;
  *)
    main_menu
    ;;
esac
