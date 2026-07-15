#!/usr/bin/env bash
# File:        test_deepseek_cli_resolution.sh
# Description: Regression tests for CodeWhale and DeepSeek TUI resolution.
# Created at:  2026-07-15   Created by: Codex
# Updated at:  2026-07-15   Updated by: Codex

set -euo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$REPO/.claude/bin/deepseek-cli.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_eq() {
  local expected="$1" actual="$2" label="$3"
  [[ "$actual" == "$expected" ]] || fail "$label: expected '$expected', got '$actual'"
}

make_stub() {
  local directory="$1" name="$2"
  mkdir -p "$directory"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$directory/$name"
  chmod +x "$directory/$name"
}

source "$HELPER"

both_bin_dir="$TMP_DIR/both"
legacy_bin_dir="$TMP_DIR/legacy"
empty_bin_dir="$TMP_DIR/empty"
make_stub "$both_bin_dir" codewhale
make_stub "$both_bin_dir" deepseek-tui
make_stub "$legacy_bin_dir" deepseek-tui
mkdir -p "$empty_bin_dir"

assert_eq "codewhale" "$(PATH="$both_bin_dir" DEEPSEEK_BIN='' deepseek_resolve_bin)" "prefers codewhale"
assert_eq "deepseek-tui" "$(PATH="$legacy_bin_dir" DEEPSEEK_BIN='' deepseek_resolve_bin)" "falls back to deepseek-tui"
assert_eq "custom-cli --headless" "$(PATH="$empty_bin_dir" DEEPSEEK_BIN='custom-cli --headless' deepseek_resolve_bin)" "honours DEEPSEEK_BIN"

set +e
missing_output="$(PATH="$empty_bin_dir" DEEPSEEK_BIN='' deepseek_resolve_bin 2>&1)"
missing_status=$?
set -e
assert_eq "127" "$missing_status" "fails without a supported CLI"
[[ "$missing_output" == *codewhale* && "$missing_output" == *deepseek-tui* ]] || fail "missing CLI error must name both supported commands"

doctor_output="$(PATH="$both_bin_dir:$PATH" DEEPSEEK_BIN='' bash "$REPO/.claude/bin/team-doctor.sh" --quick 2>&1 || true)"
[[ "$doctor_output" == *"CodeWhale (dev3/dev4/dev10)"* ]] || fail "team doctor must report the selected CodeWhale CLI"

echo "PASS: codewhale preference, legacy fallback, override, missing-CLI error, and doctor reporting"
