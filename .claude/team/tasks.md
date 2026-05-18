# Shared Task List

The leader writes here at the start of every run. Each row maps to one CLI
spawn. After the run, the leader aggregates each `.claude/team/status/<dev>.env`
into the row's `status` and `note` columns.

**Status legend**: `todo` → `in_progress` → `done` | `failed` | `blocked`
**Size legend**: `S` (skip team) | `M` | `L` | `XL` (dev5 only)
**Assignee**: one of `dev1` `dev2` `dev3` `dev4` `dev5`. Each maps to a CLI:

| Assignee | CLI binary |
|----------|------------|
| dev1, dev2 | `codex`  |
| dev3, dev4 | `deepseek` |
| dev5     | `opus` (or `claude --model opus`) |

---

## Current run

_Leader: replace this section each time you plan a new run._

| id    | size | summary                                | files                    | acceptance                                 | assignee | depends_on | status | note |
|-------|------|----------------------------------------|--------------------------|--------------------------------------------|----------|------------|--------|------|
| (idle) |     |                                        |                          |                                            |          |            |        |      |

---

## Backlog (follow-ups filed by devs)

_When a dev's `status/<dev>.env` mentions a follow-up in `notes=`, the leader
adds a row here (status `todo`, assignee blank — leader routes next run)._

| id    | size | summary | files | acceptance | filed_by | status |
|-------|------|---------|-------|------------|----------|--------|
| BL-01 | S    | Fix `DEEPSEEK_FLAGS` env-leak: parent shell exports `--yolo`, overriding env.sh's defensive `-p`. Either unset in `_runner.sh` before sourcing env.sh, or change env.sh to force-override (`DEEPSEEK_FLAGS=-p` instead of `:=`). | `.claude/bin/env.sh` or `.claude/bin/_runner.sh` | Re-running `spawn-team.sh dev4:deepseek:...` in a fresh shell does NOT pass `--yolo` to the binary. | leader (run 20260517-231455) | **fixed** — `_runner.sh` now unsets all `*_FLAGS` before sourcing `env.sh` |
| BL-02 | M    | Investigate whether the deepseek CLI in this env has any working file-write/tool mode. `deepseek -p` and `deepseek exec` both produced text-only output (pseudo `<read_file>` / fenced bash) with no FS effect. Until resolved, dev3/dev4 are unusable for any task that requires touching files (incl. writing their own `status/<dev>.env`). | docs only | Document findings; either configure deepseek's MCP/tool integration or mark dev3/dev4 as text-only personas. | leader (run 20260517-231455) | **fixed** — `exec --auto` enables `write_file` + `exec_shell` tools; `DEEPSEEK_FLAGS` updated in `env.sh` |

---

## History

_Completed runs get moved here (most recent on top). Keep last ~5 runs;
older ones can be pruned._

### Run 20260518-081736 — Standalone HTML ports + Game Dashboard

Outcome: **all three artifacts shipped on first try, zero failures**. First successful end-to-end run using three distinct CLIs in parallel (codex, deepseek, opus) — validates the BL-02 fix (deepseek `exec --auto` writes files).

Files shipped:
- `src/games/TicTacToe.html` (T-001, dev1/codex)
- `src/games/RockPaperScissors.html` (T-002, dev4/deepseek)
- `src/games/dashboard.html` (T-003, dev5/opus)

Memory artifacts updated:
- [[features/F-001-tic-tac-toe]] — appended HTML port to changelog
- [[features/F-002-rock-paper-scissors]] — appended HTML port to changelog
- [[features/F-003-game-dashboard]] — **new** (status=shipped)

Full task ledger for this run:

| id    | size | summary                                                     | assignee        | status | note |
|-------|------|-------------------------------------------------------------|-----------------|--------|------|
| T-001 | M    | Convert TicTacToe.jsx -> standalone TicTacToe.html          | dev1 (codex)    | done   | React 18 + Babel standalone via unpkg; createRoot; clean polished `<style>`. All logic preserved. |
| T-002 | M    | Convert RockPaperScissors.jsx -> standalone HTML            | dev4 (deepseek) | done   | First successful deepseek FS task post-BL-02. All logic byte-for-byte faithful to JSX. |
| T-003 | L    | dashboard.html with two cards switching between the games   | dev5 (opus)     | done   | Pure HTML/CSS/JS; iframe embedding; Back button + Esc; sibling-relative `data-src` so file:// works. |

Lessons:
- BL-02 fix validated end-to-end: dev4 (deepseek `exec --auto`) successfully created a non-trivial HTML file unsupervised.
- Three CLIs in parallel (codex/deepseek/opus) completed in under a couple of minutes with zero re-routing needed.
- Pinning sibling filenames in the task spec made T-003's `depends_on` effectively trivial — dev5 didn't have to wait for T-001/T-002 to finish.

### Run 20260517-231455 — Two React mini-games (Tic Tac Toe + Rock Paper Scissors)

Outcome: **both games shipped**. dev1 (codex) implemented both `.jsx` files; dev2 (codex) produced the architecture contract `A-001` and verified compliance; dev3/dev4 (deepseek) were attempted but proved unusable in this env (see Backlog BL-01/BL-02).

Files shipped:
- `src/games/TicTacToe.jsx`
- `src/games/RockPaperScissors.jsx`

Memory artifacts created:
- [[features/F-001-tic-tac-toe]] (status=shipped)
- [[features/F-002-rock-paper-scissors]] (status=shipped)
- [[architecture/A-001-rock-paper-scissors-component]] (status=active, authored by dev2)
- `.claude/team/plans/T-003.md`, `.claude/team/plans/T-006.md`

Full task ledger for this run:

| id    | size | summary                                                     | assignee     | status   | note |
|-------|------|-------------------------------------------------------------|--------------|----------|------|
| T-001 | M    | Build Tic Tac Toe React component (two-player)              | dev1 (codex) | done     | clean impl; smoke via re-read. |
| T-002 | M    | Build RockPaperScissors (first attempt)                     | dev4 (deepseek) | failed | `deepseek -p` text-only; also blocked by `--yolo` env-leak. |
| T-003 | M    | Re-route 1: RockPaperScissors                               | dev2 (codex) | blocked  | dev2 is planner; refused prod edits but produced plan + A-001. |
| T-004 | M    | Smoke-test both games                                       | dev1 (codex) | blocked  | TicTacToe verified clean; RPS file missing. |
| T-005 | M    | Re-route 2: RockPaperScissors per A-001                     | dev1 (codex) | done     | clean impl; smoke via re-read. |
| T-006 | M    | Cross-component review                                      | dev2 (codex) | done     | both games meet F-NNN; RPS matches A-001. |

Lessons:
- `deepseek -p` (and `exec`) in this env are text-only — no FS tools. Don't route file-writing tasks to dev3/dev4 until BL-02 is resolved.
- dev2's persona correctly refuses production source edits. Route implementation to dev1 (codex coder), not dev2 (codex planner).
