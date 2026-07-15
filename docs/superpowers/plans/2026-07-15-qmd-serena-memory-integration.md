# QMD and Serena Memory Integration Implementation Plan

> **For agentic workers:** Hand this plan back to the agent-team **leader**, which slices it into sized rows in `.Codex/team/tasks.md` and spawns devs in parallel via `.Codex/bin/spawn-team.sh`. Do NOT self-dispatch subagents. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add local semantic retrieval over `.claude/memory/` and optional Serena code intelligence without adding a second durable memory store or reintroducing Headroom.

**Architecture:** A project-owned Bash command wraps QMD with a repository-local, ignored XDG runtime and only indexes `.claude/memory/`. A tracked Serena profile disables Serena memories; client setup remains opt-in and is validated by the wrapper. Documentation teaches agents to retrieve narrowly, then read canonical Markdown, with `rg` as a no-blocking fallback.

**Tech Stack:** Bash, QMD (`@tobilu/qmd`), Serena (`serena-agent`), MCP, `rg`, RTK.

## Global Constraints

- `.claude/memory/` is the only durable memory source of truth.
- QMD indexes only Markdown under `.claude/memory/`; its config/cache/index are ignored under `.claude/runtime/qmd/`.
- Serena uses `--context=codex` and `no-memories`; do not use its write/read memory tools.
- RTK remains the only token optimisation mechanism; do not add Headroom or API proxy configuration.
- QMD and Serena absence must produce a clear fallback, never block team execution.

---

### Task 1: Add a testable QMD lifecycle wrapper

**Files:**
- Create: `.claude/bin/memory-tools.sh`
- Create: `tests/test_memory_tools.sh`
- Modify: `.gitignore`

**Interfaces:**
- Produces: `.claude/bin/memory-tools.sh {status|bootstrap|update|search|mcp|serena-check}`.
- Consumes: `qmd`, `serena`, and `rg` discovered on `PATH`; test doubles use `QMD_BIN` and `SERENA_BIN`.

- [ ] **Step 1: Write the failing Bash tests**

```bash
assert_contains "$(QMD_BIN="$stub_qmd" "$TOOL" bootstrap)" "collection add $REPO/.claude/memory --name agent-team-memory --mask **/*.md"
assert_contains "$(QMD_BIN="$stub_qmd" "$TOOL" search "retry policy")" "query retry policy -c agent-team-memory --no-rerank"
assert_contains "$(PATH="$empty_path" "$TOOL" search "retry policy")" "fallback: rg -n --glob '*.md' -- retry policy .claude/memory"
```

- [ ] **Step 2: Run the test to verify RED**

Run: `bash tests/test_memory_tools.sh`

Expected: FAIL because `.claude/bin/memory-tools.sh` does not exist.

- [ ] **Step 3: Implement the minimal wrapper**

```bash
case "${1:-status}" in
  bootstrap) "$QMD_BIN" collection add "$MEMORY_DIR" --name "$COLLECTION" --mask "**/*.md"; "$QMD_BIN" update; "$QMD_BIN" embed -c "$COLLECTION" ;;
  search) shift; "$QMD_BIN" query "$*" -c "$COLLECTION" --no-rerank ;;
  *) usage ;;
esac
```

The implementation must export `XDG_CONFIG_HOME` and `XDG_CACHE_HOME` below `.claude/runtime/qmd`, detect missing executables, and print an exact `rg` fallback without invoking it automatically.

- [ ] **Step 4: Run the test to verify GREEN**

Run: `bash tests/test_memory_tools.sh`

Expected: PASS with bootstrap, search, runtime-isolation, and missing-QMD fallback assertions.

- [ ] **Step 5: Ignore runtime artefacts**

Add `.claude/runtime/` to `.gitignore`; retain no runtime content in Git.

- [ ] **Step 6: Commit**

```bash
git add .claude/bin/memory-tools.sh tests/test_memory_tools.sh .gitignore
git commit -m "feat: add local QMD memory tooling"
```

### Task 2: Add a Serena profile with no competing memory

**Files:**
- Create: `.serena/project.yml`
- Modify: `.claude/bin/memory-tools.sh`
- Modify: `tests/test_memory_tools.sh`

**Interfaces:**
- Produces: project configuration that selects `no-memories` and a `serena-check` command.
- Consumes: `serena start-mcp-server --project-from-cwd --context=codex`.

- [ ] **Step 1: Write the failing profile assertions**

```bash
grep -Fqx 'added_modes:' .serena/project.yml
grep -Fqx '  - no-memories' .serena/project.yml
assert_contains "$(SERENA_BIN="$stub_serena" "$TOOL" serena-check)" "start-mcp-server --project-from-cwd --context=codex"
```

- [ ] **Step 2: Run the test to verify RED**

Run: `bash tests/test_memory_tools.sh`

Expected: FAIL because the Serena profile and command do not exist.

- [ ] **Step 3: Implement the profile and validation command**

```yaml
added_modes:
  - no-memories
```

`serena-check` must verify the binary exists and print the exact MCP launch command; it must not start a persistent process.

- [ ] **Step 4: Run the test to verify GREEN**

Run: `bash tests/test_memory_tools.sh`

Expected: PASS, including `no-memories` and command assertions.

- [ ] **Step 5: Commit**

```bash
git add .serena/project.yml .claude/bin/memory-tools.sh tests/test_memory_tools.sh
git commit -m "feat: configure Serena without persistent memory"
```

### Task 3: Document retrieval, MCP setup, and rollback

**Files:**
- Modify: `AGENTS.md`
- Modify: `CLAUDE.md`
- Modify: `.claude/memory/README.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: `memory-tools.sh` commands and QMD/Serena MCP configurations.
- Produces: one consistent operational contract for all agents and maintainers.

- [ ] **Step 1: Write failing documentation assertions**

```bash
grep -Fq '.claude/bin/memory-tools.sh search "<question>"' AGENTS.md
grep -Fq 'Serena is not a durable memory store' CLAUDE.md
grep -Fq 'Headroom remains excluded' README.md
```

- [ ] **Step 2: Run the test to verify RED**

Run: `bash tests/test_memory_tools.sh`

Expected: FAIL because the operational contract is absent.

- [ ] **Step 3: Add concise operational guidance**

Specify bootstrap/update/search/status commands, the Codex MCP configuration (`serena start-mcp-server --project-from-cwd --context=codex` and `qmd mcp`), the `rg` fallback, update ownership after dev10 writes, and rollback (`remove MCP entries`, remove `.claude/runtime/`). State that neither tool modifies canonical vault notes.

- [ ] **Step 4: Run documentation tests to verify GREEN**

Run: `bash tests/test_memory_tools.sh`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add AGENTS.md CLAUDE.md .claude/memory/README.md README.md tests/test_memory_tools.sh
git commit -m "docs: define QMD and Serena memory workflow"
```

### Task 4: Verify the installation path and safe degradation

**Files:**
- Modify: `.claude/bin/team-doctor.sh`
- Modify: `tests/test_memory_tools.sh`

**Interfaces:**
- Produces: optional QMD/Serena health checks that warn but do not fail the existing team preflight.

- [ ] **Step 1: Write a failing optional-tool assertion**

```bash
doctor_output="$(PATH="$empty_path" bash .claude/bin/team-doctor.sh --quick || true)"
assert_contains "$doctor_output" "QMD (semantic vault retrieval) NOT on PATH (optional)"
assert_contains "$doctor_output" "Serena (symbol-level code intelligence) NOT on PATH (optional)"
```

- [ ] **Step 2: Run the test to verify RED**

Run: `bash tests/test_memory_tools.sh`

Expected: FAIL because team doctor has no memory-tool checks.

- [ ] **Step 3: Implement optional doctor checks**

Add a `Memory retrieval and code intelligence (optional)` section. `qmd --version`, `qmd status`, and `serena --version` are checked only when their binary is present; missing tools emit `warn`, never `bad`.

- [ ] **Step 4: Run full verification**

Run: `bash tests/test_memory_tools.sh && bash tests/test_deepseek_cli_resolution.sh && bash .claude/bin/team-doctor.sh --quick`

Expected: both tests pass; doctor exits `0` or reports only pre-existing optional-tool warnings.

- [ ] **Step 5: Commit**

```bash
git add .claude/bin/team-doctor.sh tests/test_memory_tools.sh
git commit -m "feat: verify optional memory tooling"
```

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-15-qmd-serena-memory-integration.md`. The leader can slice it into `.Codex/team/tasks.md` rows and spawn devs in parallel via `.Codex/bin/spawn-team.sh` (≥ 2 devs per call).
