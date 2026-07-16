#!/usr/bin/env bash
# File:        test_serena_hybrid_config.sh
# Description: Verifies the repository-scoped Serena hybrid memory contract.
# Created at:  2026-07-16   Created by: Codex
# Updated at:  2026-07-16   Updated by: Codex

set -euo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_FILE="$REPO/.serena/project.yml"
MEMORY_DIR="$REPO/.serena/memories"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

grep -Fq 'no-memories' "$PROJECT_FILE" && fail "Serena memories must be enabled"
grep -Fq 'languages:' "$PROJECT_FILE" || fail "Serena project must declare languages"

for memory in \
  "$MEMORY_DIR/memory_maintenance.md" \
  "$MEMORY_DIR/core/project_overview.md" \
  "$MEMORY_DIR/core/agent_workflow.md" \
  "$MEMORY_DIR/core/code_navigation.md" \
  "$MEMORY_DIR/core/build_and_test.md"; do
  [[ -f "$memory" ]] || fail "missing Serena memory: $memory"
done

grep -Fq '`.claude/memory/`' "$MEMORY_DIR/core/agent_workflow.md" \
  || fail "agent workflow memory must identify the canonical vault"
grep -Fq 'mem:core/agent_workflow' "$MEMORY_DIR/core/project_overview.md" \
  || fail "Serena core memory references are missing"
grep -Fq 'no-memories' "$REPO/README.md" \
  && fail "README must not describe Serena memories as disabled"

echo "PASS: Serena hybrid memory configuration"
