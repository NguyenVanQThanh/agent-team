#!/usr/bin/env bash
# File:        test_memory_tools.sh
# Description: Regression tests for QMD and Serena memory tooling.
# Created at:  2026-07-15   Created by: Codex
# Updated at:  2026-07-15   Updated by: Codex

set -euo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TOOL="$REPO/.claude/bin/memory-tools.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local actual="$1" expected="$2" label="$3"
  [[ "$actual" == *"$expected"* ]] || fail "$label: expected '$expected' in '$actual'"
}

make_stub() {
  local path="$1" log="$2"
  cat > "$path" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$STUB_LOG"
STUB
  chmod +x "$path"
  : > "$log"
}

make_failing_stub() {
  local path="$1"
  cat > "$path" <<'STUB'
#!/usr/bin/env bash
exit 1
STUB
  chmod +x "$path"
}

stub_qmd="$TMP_DIR/qmd"
stub_serena="$TMP_DIR/serena"
failing_qmd="$TMP_DIR/failing-qmd"
qmd_log="$TMP_DIR/qmd.log"
serena_log="$TMP_DIR/serena.log"
make_stub "$stub_qmd" "$qmd_log"
make_stub "$stub_serena" "$serena_log"
make_failing_stub "$failing_qmd"

bootstrap_output="$(STUB_LOG="$qmd_log" QMD_BIN="$stub_qmd" "$TOOL" bootstrap)"
assert_contains "$bootstrap_output" "QMD collection ready: agent-team-memory" "bootstrap summary"
assert_contains "$(<"$qmd_log")" "collection add $REPO/.claude/memory --name agent-team-memory --mask **/*.md" "bootstrap collection"
assert_contains "$(<"$qmd_log")" "update" "bootstrap index update"
assert_contains "$(<"$qmd_log")" "embed -c agent-team-memory" "bootstrap embeddings"

search_output="$(STUB_LOG="$qmd_log" QMD_BIN="$stub_qmd" "$TOOL" search "retry policy")"
assert_contains "$search_output" "retry policy" "search output"
assert_contains "$(<"$qmd_log")" "query retry policy -c agent-team-memory --no-rerank" "scoped query"

fallback_output="$(QMD_BIN="$TMP_DIR/missing-qmd" "$TOOL" search "retry policy" 2>&1 || true)"
assert_contains "$fallback_output" "fallback: rg -n --glob '*.md' -- retry policy .claude/memory" "missing QMD fallback"

failed_qmd_output="$(QMD_BIN="$failing_qmd" "$TOOL" search "retry policy" 2>&1 || true)"
assert_contains "$failed_qmd_output" "fallback: rg -n --glob '*.md' -- retry policy .claude/memory" "failed QMD fallback"

grep -Fqx 'added_modes:' "$REPO/.serena/project.yml" || fail "Serena profile must declare added_modes"
grep -Fqx '  - no-memories' "$REPO/.serena/project.yml" || fail "Serena profile must disable memories"

serena_output="$(STUB_LOG="$serena_log" SERENA_BIN="$stub_serena" "$TOOL" serena-check)"
assert_contains "$serena_output" "serena start-mcp-server --project $REPO --context=codex" "Serena launch command"

grep -Fq '.claude/bin/memory-tools.sh search "<question>"' "$REPO/AGENTS.md" || fail "AGENTS must document QMD search"
grep -Fq 'Serena is not a durable memory store' "$REPO/CLAUDE.md" || fail "CLAUDE must document Serena boundary"
grep -Fq 'Headroom remains excluded' "$REPO/README.md" || fail "README must document Headroom exclusion"

doctor_output="$("$BASH" "$REPO/.claude/bin/team-doctor.sh" --quick 2>&1 || true)"
[[ "$doctor_output" == *"QMD        (semantic vault retrieval)  qmd found"* || "$doctor_output" == *"QMD (semantic vault retrieval) NOT on PATH (optional)"* ]] || fail "doctor must report QMD as installed or optional"
[[ "$doctor_output" == *"Serena     (symbol-level code intelligence)  serena found"* || "$doctor_output" == *"Serena (symbol-level code intelligence) NOT on PATH (optional)"* ]] || fail "doctor must report Serena as installed or optional"

echo "PASS: QMD isolation, fallback, Serena memory boundary, documentation, and optional doctor checks"
