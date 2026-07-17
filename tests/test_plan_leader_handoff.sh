#!/usr/bin/env bash
# File:        test_plan_leader_handoff.sh
# Description: Verifies the plan-to-leader approval-gated workflow contract.
# Created at:  2026-07-17   Created by: Codex
# Updated at:  2026-07-17   Updated by: Codex

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
required_files=(
  "$ROOT/AGENTS.md"
  "$ROOT/CLAUDE.md"
  "$ROOT/.claude/agents/leader.md"
  "$ROOT/.claude/skills/writing-plans/SKILL.md"
  "$ROOT/docs/USING-THE-TEAM.md"
  "$ROOT/README.md"
  "$ROOT/.claude/team/README.md"
)

for file in "${required_files[@]}"; do
  grep -Fq "plan approval" "$file"
  grep -Fq "dev roster approval" "$file"
done

leader="$ROOT/.claude/agents/leader.md"
plan_line=$(grep -nF "plan approval" "$leader" | head -n1 | cut -d: -f1)
roster_line=$(grep -nF "dev roster approval" "$leader" | head -n1 | cut -d: -f1)
spawn_line=$(grep -nF "spawn-team.sh" "$leader" | awk -F: -v r="$roster_line" '$1 > r { print $1; exit }')

test -n "$plan_line"
test -n "$roster_line"
test -n "$spawn_line"
test "$plan_line" -lt "$roster_line"
test "$roster_line" -lt "$spawn_line"

printf '%s\n' "plan-leader-handoff contract: PASS"
