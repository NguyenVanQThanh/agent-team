# Agent Team

A 1-leader + 13-dev autonomous coding team built on top of Claude Code.

The leader is a **Claude Opus subagent** that plans work, slices it into tasks, and spawns external CLI processes in parallel. The 13 "devs" are real background processes — each a different AI CLI (Codex, DeepSeek, Claude Haiku/Sonnet/Opus, Gemini) given a persona and a task.

---

## Architecture

```
  user (chat)
      │
      ▼
  [leader]  (Claude Opus subagent — .claude/agents/leader.md)
      │
      │  writes .claude/team/tasks.md
      │  spawns via .claude/bin/spawn-team.sh
      │
      ▼
┌──────────┬──────────┬──────────┬──────────┬──────────┐
│  codex   │ deepseek │  haiku   │  sonnet  │  gemini  │
│ dev1/2   │ dev3/4   │ dev6/7   │ dev8/9   │  dev11   │
│ dev12/13 │ dev10    │          │          │          │
└──────────┴──────────┴──────────┴──────────┴──────────┘
      │ each writes .claude/team/status/<dev>.status on finish
      │ each writes .claude/team/runs/<run-id>/{output.log,meta.env}
      ▼
  .claude/memory/   (durable Obsidian-style vault)
```

---

## Dev Roster

| Dev    | CLI      | Task sizes | Phase | Role                                               |
|--------|----------|------------|-------|----------------------------------------------------|
| dev1   | codex    | M, L       | main  | Default workhorse — coding, refactor, smoke tests  |
| dev2   | codex    | M, L       | main  | Module/service planner, architecture notes         |
| dev3   | deepseek | S, M       | main  | Quick fixes, smoke tests, simple refactors         |
| dev4   | deepseek | S, M       | main  | Coding well-scoped changes                         |
| dev5   | opus     | XL         | main  | Senior all-rounder — complex bugs, arch rewrites   |
| dev6   | haiku    | M          | main  | Fast coder, simple well-scoped tasks               |
| dev7   | haiku    | M          | main  | Smoke tester, quick verification                   |
| dev8   | sonnet   | L          | main  | Quality implementer, multi-file features           |
| dev9   | sonnet   | L          | main  | Reviewer, integrator, cross-module checks          |
| dev10  | deepseek | M          | post  | Memory scribe — synthesises bugs/fixes into vault  |
| dev11  | gemini   | M          | pre   | Researcher — external research before main batch   |
| dev12  | codex    | S, M       | main  | Smoke tester / lint fixer / quick verify (cheap)   |
| dev13  | codex    | L, XL      | main  | Senior coder, tournament partner with dev5         |

**Routing quick-reference:**
```
Size S  → dev3, dev4, dev12
Size M  → dev1, dev3, dev4, dev6, dev7, dev12
Size L  → dev1, dev2, dev8, dev9, dev13
Size XL → dev5 or dev13 (or both in tournament mode)
Pre-phase research  → dev11 (gemini)
Post-phase memory   → dev10 (deepseek, always paired with ≥1 other dev)
```

---

## Codex Reasoning Levels

Codex (gpt-5.5) supports per-dev reasoning effort. The mapping lives in [`.claude/bin/env.sh`](.claude/bin/env.sh):

| Dev    | Reasoning effort | Typical use                              |
|--------|-----------------|------------------------------------------|
| dev12  | `low`           | Lint, smoke checks, trivial verify       |
| dev1   | `medium`        | General coding, refactor (default)       |
| dev2   | `high`          | Module planning, architecture scribe     |
| dev13  | `xhigh`         | Hardest tasks, tournament partner        |

Overrides are loaded automatically by `_runner.sh` via the `CODEX_FLAGS_DEV<N>` env vars.

---

## 3-Phase Spawn Model

Every significant run follows three phases. `spawn-team.sh` enforces the **≥ 2 devs per call** rule across all phases.

### Phase 0 — Pre (research, when needed)
Used when a task requires external knowledge before implementation begins.

```bash
.claude/bin/spawn-team.sh dev11:gemini:T-R01 dev3:deepseek:T-S01
```

dev11 writes findings to `.claude/team/research/<task-id>-findings.md`. Main-phase devs read it.

### Phase 1 — Main (implementation, ≥ 3 devs for complex work)
The core implementation batch. Devs run in parallel.

```bash
.claude/bin/spawn-team.sh dev1:codex:T-001 dev4:deepseek:T-002 dev8:sonnet:T-003
```

### Phase 2 — Post (memory, always run after a significant batch)
dev10 reads all status files and writes structured notes to the vault.

```bash
.claude/bin/spawn-team.sh dev10:deepseek:T-POST dev7:haiku:T-SMOKE
```

---

## Tournament Mode

For XL tasks with no obviously correct approach, spawn **dev5 and dev13 on the same task ID**. Each gets an isolated git worktree; both produce a real implementation; the leader diffs and picks a winner.

```bash
# spawn tournament on T-100 (dev5 + dev13 compete), dev7 handles unrelated work
.claude/bin/spawn-team.sh dev5:opus:T-100 dev13:codex:T-100 dev7:haiku:T-101
```

After the run, `spawn-team.sh` prints each candidate's diff stat and commit count. The leader inspects both, then:

```bash
# squash-merge the winner into the main branch, clean up all worktrees
.claude/bin/prune-worktrees.sh T-100 dev5

# or abort without merging
.claude/bin/prune-worktrees.sh T-100 --abort
```

**When to use tournament:**
- Hard bug with uncertain root cause
- Cross-module refactor with multiple valid designs
- High-stakes change (auth, data migration)

**When not to:**
- Mechanically clear XL work (mass rename, port library) — use one dev
- Anything below L size — cost not justified

---

## Memory Vault

Long-lived knowledge lives at `.claude/memory/` in Obsidian wikilink format.

```
.claude/memory/
  _index.md           # root Map of Content, links to everything
  _templates/         # frontmatter templates for each note type
  architecture/       # ADRs, module plans, service contracts (A-NNN)
  features/           # feature briefs and status (F-NNN)
  fixes/              # fix write-ups linked to bug notes (X-NNN)
  bugs/               # bug reports — symptoms, repro, severity (B-NNN)
  user-prefs/         # personal leader notes on user preferences (gitignored)
```

Note IDs: `A-NNN` / `F-NNN` / `X-NNN` / `B-NNN`. Filenames: `<id>-<slug>.md`.

**Write access:**

| Who    | Can write to                              |
|--------|-------------------------------------------|
| leader | `features/`, `_index.md`, `user-prefs/`   |
| dev2   | `architecture/`                           |
| dev5   | `architecture/`, `fixes/`, `bugs/`        |
| dev10  | `bugs/`, `fixes/`, `features/`            |
| others | read-only                                 |

---

## Key Scripts

| Script                           | Purpose                                                       |
|----------------------------------|---------------------------------------------------------------|
| `.claude/bin/spawn-team.sh`      | Parallel launcher — validates ≥2 devs, builds prompts, waits |
| `.claude/bin/env.sh`             | Central config for all CLI binaries and flags                 |
| `.claude/bin/_runner.sh`         | Shared runner sourced by all wrappers — logs every invocation |
| `.claude/bin/run_codex.sh`       | Codex CLI wrapper (dev1/2/12/13)                              |
| `.claude/bin/run_deepseek.sh`    | DeepSeek CLI wrapper (dev3/4/10)                              |
| `.claude/bin/run_opus.sh`        | Claude Opus wrapper (dev5)                                    |
| `.claude/bin/run_haiku.sh`       | Claude Haiku wrapper (dev6/7)                                 |
| `.claude/bin/run_sonnet.sh`      | Claude Sonnet wrapper (dev8/9)                                |
| `.claude/bin/run_gemini.sh`      | Gemini CLI wrapper (dev11)                                    |
| `.claude/bin/prune-worktrees.sh` | Tournament cleanup — squash-merge winner, remove worktrees    |
| `.claude/bin/team-doctor.sh`     | Pre-flight checker — verifies all CLIs, auth, and scaffolding |
| `.claude/bin/team-tui.sh`        | Live fzf dashboard: [P]rocesses, [M]emory, [L]eader runs      |

---

## Setup

**1. Verify everything is in place:**
```bash
.claude/bin/team-doctor.sh
```

All checks should pass (green). Warnings won't block the team but fix them if a dev keeps failing.

**2. Configure CLI auth:**

| CLI      | Auth method                                    |
|----------|------------------------------------------------|
| Codex    | `codex auth` or `export OPENAI_API_KEY=...`    |
| DeepSeek | `deepseek login` or `export DEEPSEEK_API_KEY=` |
| Claude   | `claude` handles auth interactively on first use |
| Gemini   | `gemini auth` (optional — only dev11)          |

**3. Run the team:**

Delegate work to the leader agent from a Claude Code chat session. Mention "team", "agent team", or "use the team" to trigger the leader subagent. The leader will plan tasks, write `.claude/team/tasks.md`, and spawn devs.

---

## Shared File Protocol

Every dev must write `.claude/team/status/<dev>.status` before exiting. Required fields:

```bash
task_id=T-001
status=done          # done | failed | blocked
notes=one-line summary of what was done
finished_at=2026-05-17T14:32:00
```

Additional optional fields per dev role (e.g., `smoke_exit`, `files_changed`, `vault_note`) are documented in each persona file under `.claude/team/personas/`.

The leader reads all status files after `spawn-team.sh` returns, aggregates them into `tasks.md`, and updates the run diary at `.claude/team/runs/leader-<TS>.md`.

---

## Project Rules

See [CLAUDE.md](CLAUDE.md) for full project rules. Key constraints:

- Never read `.env*` files (forbidden at the tool layer via `settings.json`).
- The leader never edits source code directly — devs implement, leader orchestrates.
- Always ≥ 2 devs per `spawn-team.sh` call. Default to ≥ 3 devs for tasks spanning ≥ 2 files.
- Dev10 (post-phase memory scribe) must run after every significant main batch.
