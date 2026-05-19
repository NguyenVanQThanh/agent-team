#!/usr/bin/env bash
# complete-task.sh — finalize a claimed task into done/ or failed/.
#
# Usage:
#   .claude/bin/complete-task.sh <dev> <task_id> <done|failed> [notes...]
#
# Reads queue/claimed/<task_id>.task, appends finished_at + final_status +
# notes, and atomically moves it to queue/<done|failed>/.

set -uo pipefail

DEV="${1:-}"; ID="${2:-}"; STAT="${3:-}"; shift 3 2>/dev/null || true
NOTES="$*"

if [[ -z "$DEV" || -z "$ID" || -z "$STAT" ]]; then
  echo "usage: $0 <dev> <task_id> <done|failed> [notes...]" >&2
  exit 2
fi
case "$STAT" in
  done|failed) : ;;
  *) echo "error: status must be 'done' or 'failed' (got '$STAT')" >&2; exit 2 ;;
esac

SCRIPT_DIR="$( cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd )"
REPO="$( cd -- "$SCRIPT_DIR/../.." &>/dev/null && pwd )"
QDIR="$REPO/.claude/team/queue"
SRC="$QDIR/claimed/${ID}.task"
DEST="$QDIR/${STAT}/${ID}.task"

if [[ ! -f "$SRC" ]]; then
  echo "error: no claimed task $ID at $SRC" >&2
  exit 1
fi

# Sanity: only the dev who claimed it should complete it.
claimed_by=$(grep -E '^claimed_by=' "$SRC" | head -1 | cut -d= -f2- | tr -d ' \r')
if [[ -n "$claimed_by" && "$claimed_by" != "$DEV" ]]; then
  echo "warn: task $ID was claimed by '$claimed_by', completer is '$DEV'" >&2
fi

{
  echo "finished_by=$DEV"
  echo "finished_at=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date '+%Y-%m-%dT%H:%M:%SZ')"
  echo "final_status=$STAT"
  if [[ -n "$NOTES" ]]; then
    # Single-line escape: collapse newlines to spaces so the .task file
    # stays parseable as KEY=value.
    echo "notes=$(echo "$NOTES" | tr '\n' ' ')"
  fi
} >> "$SRC"

mv "$SRC" "$DEST"
echo "$DEST"
