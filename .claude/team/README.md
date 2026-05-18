# Agent team — usage guide

A 1-leader + 13-dev agent team running on this repo. **Only the leader is a
Claude subagent.** The 13 devs are external agentic CLIs (Codex / DeepSeek /
Claude Haiku / Claude Sonnet / Claude Opus / Gemini) launched as real background
processes and communicating via shared files.

## Roster

| Dev    | CLI            | Sizes   | Phase | Role                                               |
|--------|----------------|---------|-------|----------------------------------------------------|
| leader | Claude Opus    | —       | —     | Plan, slice, spawn, verify, curate memory          |
| dev1   | Codex          | M, L    | main  | Default workhorse — coding, refactor, smoke tests  |
| dev2   | Codex          | M, L    | main  | Module/service planner, architecture notes         |
| dev3   | DeepSeek       | S, M    | main  | Quick fixes, smoke tests, small refactors          |
| dev4   | DeepSeek       | S, M    | main  | Coding well-scoped changes                         |
| dev5   | Claude Opus    | XL      | main  | Senior all-rounder — complex bugs, arch rewrites   |
| dev6   | Claude Haiku   | M       | main  | Fast coder, simple well-scoped tasks               |
| dev7   | Claude Haiku   | M       | main  | Smoke tester, quick verification                   |
| dev8   | Claude Sonnet  | L       | main  | Quality implementer, multi-file features           |
| dev9   | Claude Sonnet  | L       | main  | Reviewer, integrator, cross-module checks          |
| dev10  | DeepSeek       | M       | post  | Memory scribe — writes bugs/fixes/features vault   |
| dev11  | Gemini         | M       | pre   | Researcher — external research before main batch   |
| dev12  | Codex          | S, M    | main  | Smoke tester / lint fixer / quick verify (cheap)   |
| dev13  | Codex          | L, XL   | main  | Senior coder, tournament partner with dev5         |

**Routing quick-reference:**
```
Size S  → dev3, dev4, dev12
Size M  → dev1, dev3, dev4, dev6, dev7, dev12
Size L  → dev1, dev2, dev8, dev9, dev13
Size XL → dev5 or dev13 (or both — tournament mode)
Pre-phase research → dev11 (gemini)
Post-phase memory  → dev10 (deepseek, always paired with ≥1 other dev)
```

## How a run flows (3 phases)

```
user > use the leader agent to <X>
   │
   ▼
leader (Claude Opus subagent)
   ├─ consults .claude/memory/ vault
   ├─ writes .claude/team/tasks.md  (Current run section)
   ├─ writes .claude/team/runs/leader-<TS>.md  (run diary)
   │
   ├─ [Phase 0 — pre, if external research needed]
   │     .claude/bin/spawn-team.sh dev11:gemini:T-R01 dev3:deepseek:T-S01
   │        └─ dev11 writes .claude/team/research/<task-id>-findings.md
   │
   ├─ [Phase 1 — main, ≥ 3 devs for complex work]
   │     .claude/bin/spawn-team.sh dev1:codex:T-001 dev4:deepseek:T-002 dev8:sonnet:T-003
   │        ├─ builds each CLI's prompt = persona + task row + shared context
   │        ├─ launches each via .claude/bin/run_<cli>.sh in parallel (&)
   │        ├─ waits for all
   │        └─ each CLI writes .claude/team/status/<dev>.env when finished
   │
   ├─ [Phase 2 — post, always run after a significant batch]
   │     .claude/bin/spawn-team.sh dev10:deepseek:T-POST dev7:haiku:T-SMOKE
   │        └─ dev10 synthesises all status files into vault notes
   │
   └─ leader reads status/<dev>.env, aggregates tasks.md, summarises to user
```

## How to invoke

In Claude Code (CLI or extension), from this repo:

```
> use the leader agent: <your request>
```

The leader will plan and spawn. To watch CLIs live in a second terminal:

```bash
.claude/bin/team-tui.sh
```

## File map

```
.claude/
  agents/
    leader.md                   # the only Claude subagent
  bin/
    spawn-team.sh               # orchestrator: ≥2 devs, parallel, wait, aggregate
    _runner.sh                  # shared helper sourced by all run_*.sh wrappers
    env.sh                      # central config for all CLI binaries + flags
    run_codex.sh                # → invokes the real `codex` CLI
    run_deepseek.sh             # → invokes the real `deepseek` CLI
    run_opus.sh                 # → invokes `claude --model opus`
    run_haiku.sh                # → invokes `claude --model haiku`
    run_sonnet.sh               # → invokes `claude --model sonnet`
    run_gemini.sh               # → invokes the real `gemini` CLI
    prune-worktrees.sh          # tournament cleanup: squash-merge winner + rm worktrees
    team-doctor.sh              # pre-flight checker: verifies all CLIs and auth
    team-tui.sh                 # fzf dashboard: [P]rocesses [M]emory [L]eader runs
  team/
    tasks.md                    # shared task list (per run, leader writes)
    personas/
      dev1.md ... dev13.md      # prompt fragments injected into each CLI
    status/
      dev1.env ... dev13.env    # status protocol; each CLI writes its own  [gitignored]
    runs/
      leader-<TS>.md            # per-run diary the leader keeps             [gitignored]
      <TS>-<cli>-<pid>/         # per-CLI invocation: meta.env + output.log  [gitignored]
    research/
      <task-id>-findings.md     # dev11 output (pre-phase)                   [gitignored]
    plans/
      <task-id>.md              # planning docs (dev2)                        [gitignored]
    worktrees/
      <task_id>-<dev>/          # isolated git worktrees for tournament mode  [gitignored]
  memory/
    _index.md, _templates/
    architecture/, features/, fixes/, bugs/
    user-prefs/                 # personal leader notes on user overrides     [gitignored]
  settings.json                 # permission rules (e.g. deny reads of .env*)
```

## Status file protocol

Each persona writes `.claude/team/status/<dev>.env` exactly once per run.
Required fields: `task_id`, `status` (= `done|failed|blocked`), `notes`,
`finished_at`. Optional fields depend on the persona (see each persona file).
Leader reads them after `spawn-team.sh` returns.

## "≥ 2 devs per run" rule

Enforced by `spawn-team.sh`: exits with code 2 if fewer than 2 distinct devs
are passed. The leader's persona reinforces this. Default to ≥ 3 devs for
tasks spanning ≥ 2 files or modules.

## Codex reasoning levels

All four Codex devs use gpt-5.5 with different `model_reasoning_effort` levels,
configured in `.claude/bin/env.sh` as `CODEX_FLAGS_DEV<N>`:

| Dev   | Level  | Use case                              |
|-------|--------|---------------------------------------|
| dev12 | low    | Lint, smoke checks, trivial verify    |
| dev1  | medium | General coding, refactor (default)    |
| dev2  | high   | Module planning, architecture sketches|
| dev13 | xhigh  | Hardest tasks, tournament partner     |

`_runner.sh` picks the right var automatically when `--dev=` is passed.

## Tournament mode

For hard XL tasks, spawn **dev5 and dev13 on the same task ID**. Each gets an
isolated git worktree; both produce a real implementation; leader diffs + picks:

```bash
.claude/bin/spawn-team.sh dev5:opus:T-100 dev13:codex:T-100 dev7:haiku:T-101
# after run:
.claude/bin/prune-worktrees.sh T-100 dev5      # squash-merge winner
.claude/bin/prune-worktrees.sh T-100 --abort   # drop both
```

Use tournament when: root cause is unclear, multiple valid designs exist,
or the change is high-stakes (auth, data migrations). Skip for mechanical XL work.

## TUI — `.claude/bin/team-tui.sh`

Requires `bash` and (for best UX) `fzf`; falls back to numbered menus.

- **[P] Processes** — every `run_*.sh` invocation, newest first. Keys: `enter`
  tails in `less +F`, `ctrl-k` SIGTERM, `ctrl-d` deletes run dir.
- **[M] Memory** — recent notes in `.claude/memory/`.
- **[L] Leader runs** — `.claude/team/runs/leader-<TS>.md` diaries.

## Customising

- CLI binaries / flags: edit `.claude/bin/env.sh` (`CODEX_FLAGS`, `DEEPSEEK_FLAGS`,
  `OPUS_BIN`, `HAIKU_BIN`, `SONNET_BIN`, `GEMINI_BIN`, and the per-dev overrides).
- Size routing: edit `.claude/agents/leader.md` routing table and the matching
  size bracket in each persona file.
- Add a dev: add `devN.md` in `personas/`, add a `run_<cli>.sh` wrapper if the
  CLI is new, update the leader's roster.
