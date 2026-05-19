#!/usr/bin/env bash
# claim-task.sh — atomically claim 1 pending task that matches a dev's
# size bracket (DEV_SIZES from env.sh) and whose depends_on are all done.
#
# Usage:
#   .claude/bin/claim-task.sh <dev>
#
# Output:
#   On success: prints absolute path to the claimed task file (now under
#   queue/claimed/), exit 0.
#   On no-match: prints "" and exits 1 (caller should treat as "queue empty
#   for me right now").
#   On error: exits 2 with message to stderr.
#
# Concurrency: holds an exclusive flock on queue/.lock for the scan + mv.
# Safe to call from N background loops simultaneously.

set -uo pipefail

DEV="${1:-}"
if [[ -z "$DEV" ]]; then
  echo "usage: $0 <dev>" >&2
  exit 2
fi

SCRIPT_DIR="$( cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd )"
REPO="$( cd -- "$SCRIPT_DIR/../.." &>/dev/null && pwd )"
QDIR="$REPO/.claude/team/queue"
LOCK="$QDIR/.lock"

mkdir -p "$QDIR/pending" "$QDIR/claimed" "$QDIR/done" "$QDIR/failed"

# Source env.sh for DEV_SIZES.
# shellcheck disable=SC1091
source "$SCRIPT_DIR/env.sh"

if [[ -z "${DEV_SIZES[$DEV]:-}" ]]; then
  echo "error: unknown dev '$DEV' (not in DEV_SIZES — see .claude/bin/env.sh)" >&2
  exit 2
fi
ALLOWED=" ${DEV_SIZES[$DEV]} "   # e.g. " M L "

# Open the lock file (create if missing) and acquire exclusive lock.
exec 9>"$LOCK"
if ! flock -x 9; then
  echo "error: could not acquire flock on $LOCK" >&2
  exit 2
fi

# Scan pending in stable order so retries are deterministic.
shopt -s nullglob
candidates=( "$QDIR/pending"/*.task )
shopt -u nullglob

if (( ${#candidates[@]} == 0 )); then
  echo ""
  exit 1
fi

# Sort by filename (T-001 before T-002).
IFS=$'\n' candidates=( $(printf '%s\n' "${candidates[@]}" | sort) )
unset IFS

for tf in "${candidates[@]}"; do
  size=$(grep -E '^size=' "$tf" | head -1 | cut -d= -f2- | tr -d ' \r')
  if [[ -z "$size" ]]; then
    continue   # malformed, skip
  fi

  # Size bracket check.
  if [[ "$ALLOWED" != *" $size "* ]]; then
    continue
  fi

  # Dependency check: every id in depends_on must be in queue/done/.
  deps=$(grep -E '^depends_on=' "$tf" | head -1 | cut -d= -f2- | tr -d ' \r')
  ok=1
  if [[ -n "$deps" ]]; then
    IFS=',' read -r -a dep_ids <<< "$deps"
    for d in "${dep_ids[@]}"; do
      [[ -z "$d" ]] && continue
      if [[ ! -f "$QDIR/done/${d}.task" ]]; then
        ok=0
        break
      fi
    done
  fi
  (( ok == 0 )) && continue

  # Claim: append metadata, atomic mv into claimed/.
  base="$(basename "$tf")"
  dest="$QDIR/claimed/$base"
  {
    echo "claimed_by=$DEV"
    echo "claimed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date '+%Y-%m-%dT%H:%M:%SZ')"
  } >> "$tf"
  if mv "$tf" "$dest"; then
    echo "$dest"
    exit 0
  else
    echo "error: failed to mv $tf -> $dest" >&2
    exit 2
  fi
done

# Nothing matched my bracket / deps.
echo ""
exit 1
