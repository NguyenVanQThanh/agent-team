# DeepSeek CLI Resolution Implementation Plan

> **For agentic workers:** Hand this plan back to the agent-team **leader**, which slices it into sized rows in `.Codex/team/tasks.md` and spawns devs in parallel via `.Codex/bin/spawn-team.sh`. Do NOT self-dispatch subagents. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run DeepSeek teammates through `codewhale` when available, with `deepseek-tui` compatibility fallback.

**Architecture:** A sourceable shell helper resolves the command consistently for both `run_deepseek.sh` and `team-doctor.sh`. The wrapper passes the resolved command to the existing shared runner, so orchestration labels and existing flag handling stay stable.

**Tech Stack:** Bash, `command -v`, project shell wrappers, standalone Bash regression test.

## Global Constraints

- Preserve the `deepseek` orchestration label and `run_deepseek.sh` entry point.
- Resolution order is `DEEPSEEK_BIN` override, `codewhale`, then `deepseek-tui`.
- Absence of all supported commands must produce an actionable error and exit 127.
- Do not read or modify real `.env*` files or credentials.
- Modified shell source files retain the required file-header metadata.

---

### Task 1: Add a reusable CLI resolver with regression coverage

**Files:**
- Create: `.claude/bin/deepseek-cli.sh`
- Create: `tests/test_deepseek_cli_resolution.sh`

**Interfaces:**
- Produces: `deepseek_resolve_bin()`, which writes a command specification to stdout and returns 0; otherwise writes an actionable error to stderr and returns 127.
- Produces: `deepseek_cli_label <command-spec>`, which writes `CodeWhale`, `DeepSeek TUI`, or `DeepSeek CLI`.
- Consumes: optional `DEEPSEEK_BIN` and the executable names available on `PATH`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_deepseek_cli_resolution.sh` with test cases that source the new helper and assert:

```bash
assert_eq "codewhale" "$(PATH="$both_bin_dir:$PATH" DEEPSEEK_BIN='' deepseek_resolve_bin)"
assert_eq "deepseek-tui" "$(PATH="$legacy_bin_dir:$PATH" DEEPSEEK_BIN='' deepseek_resolve_bin)"
assert_eq "custom-cli --headless" "$(PATH="$empty_bin_dir" DEEPSEEK_BIN='custom-cli --headless' deepseek_resolve_bin)"
assert_status 127 "$(PATH="$empty_bin_dir" DEEPSEEK_BIN='' deepseek_resolve_bin 2>&1)"
```

The test creates executable stub commands in temporary directories and verifies the missing-CLI error contains both supported command names.

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/test_deepseek_cli_resolution.sh`

Expected: FAIL because `.claude/bin/deepseek-cli.sh` does not exist.

- [ ] **Step 3: Write the minimal resolver**

Create `.claude/bin/deepseek-cli.sh` with a Bash file header and these functions:

```bash
deepseek_resolve_bin() {
  if [[ -n "${DEEPSEEK_BIN:-}" ]]; then printf '%s\n' "$DEEPSEEK_BIN"; return 0; fi
  command -v codewhale >/dev/null 2>&1 && { printf '%s\n' codewhale; return 0; }
  command -v deepseek-tui >/dev/null 2>&1 && { printf '%s\n' deepseek-tui; return 0; }
  echo "error: no DeepSeek CLI found; install codewhale or deepseek-tui, or set DEEPSEEK_BIN" >&2
  return 127
}
```

Implement `deepseek_cli_label` from the first word of its argument for doctor output.

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/test_deepseek_cli_resolution.sh`

Expected: PASS with all four resolution cases reported.

- [ ] **Step 5: Commit**

```bash
git add .claude/bin/deepseek-cli.sh tests/test_deepseek_cli_resolution.sh
git commit -m "feat(team): resolve CodeWhale DeepSeek CLI"
```

### Task 2: Integrate the resolver into runner configuration and diagnostics

**Files:**
- Modify: `.claude/bin/env.sh`
- Modify: `.claude/bin/run_deepseek.sh`
- Modify: `.claude/bin/team-doctor.sh`
- Modify: `.claude/team/README.md`
- Test: `tests/test_deepseek_cli_resolution.sh`

**Interfaces:**
- Consumes: `deepseek_resolve_bin()` and `deepseek_cli_label()` from `.claude/bin/deepseek-cli.sh`.
- Produces: runner and doctor behavior that identify the same selected executable.

- [ ] **Step 1: Extend the failing test**

Add assertions that source `run_deepseek.sh` in a shell-safe test seam or inspect the wrapper invocation, confirming the resolver result is passed as the binary specification. Add a doctor quick-mode assertion with temporary stubs that confirms its output names the selected `codewhale` executable.

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/test_deepseek_cli_resolution.sh`

Expected: FAIL because the wrapper and doctor still reference a fixed `deepseek` command.

- [ ] **Step 3: Integrate the resolver**

In `env.sh`, define and export `DEEPSEEK_BIN` with an empty automatic-resolution default. In `run_deepseek.sh`, source the helper, resolve the command, and call:

```bash
deepseek_bin="$(deepseek_resolve_bin)" || exit $?
runner_exec "deepseek" "$deepseek_bin" "DEEPSEEK_FLAGS" "$@"
```

In `team-doctor.sh`, source the helper once, resolve it before the CLI presence and live-probe sections, use the selected first word for `check_cli`, invoke the resolved command in the probe, and tailor the login note to the selected binary. Update the README file map and customization instructions to document `DEEPSEEK_BIN`, `codewhale`, and fallback behavior.

- [ ] **Step 4: Run the test and shell syntax checks**

Run:

```bash
bash tests/test_deepseek_cli_resolution.sh
bash -n .claude/bin/deepseek-cli.sh .claude/bin/env.sh .claude/bin/run_deepseek.sh .claude/bin/team-doctor.sh
```

Expected: regression test PASS and syntax-check exit code 0.

- [ ] **Step 5: Commit**

```bash
git add .claude/bin/env.sh .claude/bin/run_deepseek.sh .claude/bin/team-doctor.sh .claude/team/README.md tests/test_deepseek_cli_resolution.sh
git commit -m "fix(team): prefer CodeWhale for DeepSeek devs"
```

## Plan Self-Review

- Spec coverage: Task 1 implements every resolution rule and the 127 error; Task 2 integrates the exact resolver into runtime, diagnostics, and documentation.
- Placeholder scan: no placeholders or deferred behavior remain.
- Type consistency: every consumer uses the two functions defined in Task 1 with the stated Bash return and stdout contracts.
