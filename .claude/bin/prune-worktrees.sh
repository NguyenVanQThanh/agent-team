#!/usr/bin/env bash
# prune-worktrees.sh — clean up tournament worktrees after the leader picks a winner.
#
# Usage:
#   .claude/bin/prune-worktrees.sh <task_id> <winning-dev>
#   .claude/bin/prune-worktrees.sh <task_id> --abort     # drop all candidates, no merge
#
# Behaviour with a winner:
#   1. Squash-merge the winner's branch (tournament/<task_id>/<dev>) into the
#      current branch in the main repo.
#   2. Remove every worktree under .claude/team/worktrees/<task_id>-*.
#   3. Delete every tournament/<task_id>/* branch.
#
# Behaviour with --abort:
#   Removes worktrees + branches without merging anything.

set -uo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <task_id> <winning-dev|--abort>" >&2
  exit 2
fi

task="$1"
winner="$2"

SCRIPT_DIR="$( cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd )"
REPO="$( cd -- "$SCRIPT_DIR/../.." &>/dev/null && pwd )"
WORKTREES_DIR="$REPO/.claude/team/worktrees"

if ! git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
  echo "error: $REPO is not a git repo" >&2; exit 2
fi

# List worktrees / branches that match this task.
mapfile -t candidate_dirs < <(find "$WORKTREES_DIR" -maxdepth 1 -type d -name "${task}-dev*" 2>/dev/null | sort)
mapfile -t candidate_branches < <(git -C "$REPO" branch --list "tournament/${task}/*" | sed 's|^[* ] *||')

if (( ${#candidate_dirs[@]} == 0 && ${#candidate_branches[@]} == 0 )); then
  echo "no worktrees or branches found for task=$task" >&2
  exit 1
fi

if [[ "$winner" != "--abort" ]]; then
  win_branch="tournament/${task}/${winner}"
  if ! git -C "$REPO" rev-parse --verify "$win_branch" >/dev/null 2>&1; then
    echo "error: no branch '$win_branch' for winner '$winner'" >&2
    echo "candidates:" >&2
    printf '  %s\n' "${candidate_branches[@]}" >&2
    exit 2
  fi

  echo "merging $win_branch into $(git -C "$REPO" rev-parse --abbrev-ref HEAD) (squash)..."
  if ! git -C "$REPO" merge --squash "$win_branch"; then
    echo "error: squash merge failed — resolve in $REPO and commit manually" >&2
    exit 1
  fi
  echo "squash merge staged. review with 'git -C $REPO diff --cached' then commit."
fi

# Cleanup: remove worktrees, delete branches.
echo ""
echo "cleaning up worktrees for task=$task:"
for d in "${candidate_dirs[@]}"; do
  echo "  rm worktree $d"
  git -C "$REPO" worktree remove --force "$d" 2>/dev/null || rm -rf "$d"
done

echo "deleting branches:"
for b in "${candidate_branches[@]}"; do
  echo "  - $b"
  git -C "$REPO" branch -D "$b" >/dev/null 2>&1 || true
done

echo ""
echo "done. tournament task=$task cleaned up."
[[ "$winner" != "--abort" ]] && echo "next: commit the staged squash merge in $REPO."
