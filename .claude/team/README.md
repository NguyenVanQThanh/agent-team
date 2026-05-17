# Agent team — usage guide

A 1-leader + 5-dev agent team running on this repo. **Only the leader is a
Claude subagent.** The 5 devs are external agentic CLIs (Codex / DeepSeek /
Opus) launched as real background processes.

## Roster

| Agent  | What it is              | Sizes  | Strengths                              |
|--------|-------------------------|--------|----------------------------------------|
| leader | Claude Opus subagent    | —      | Plan, slice, spawn, verify, curate     |
| dev1   | Codex CLI process       | M, L   | Coding, smoke tests, refactor          |
| dev2   | Codex CLI process       | M, L   | Plan a module / service breakdown      |
| dev3   | DeepSeek CLI process    | M      | Smoke tests, refactor                  |
| dev4   | DeepSeek CLI process    | M      | Coding                                 |
| dev5   | Opus CLI process        | L, XL  | All-rounder for hard / large work      |

## How a run flows

```
user > use the leader agent to <X>
   │
   ▼
leader (Claude Opus)
   ├─ consults .claude/memory/
   ├─ writes .claude/team/tasks.md (Current run section)
   ├─ writes .claude/team/runs/leader-<TS>.md (run diary)
   └─ runs ONE bash call:
         .claude/bin/spawn-team.sh dev1:codex:T-001 dev3:deepseek:T-002
            │
            ├─ builds each CLI's prompt = persona + task row + shared context
            ├─ launches each via .claude/bin/run_<cli>.sh in parallel (&)
            ├─ waits for all
            └─ each CLI writes .claude/team/status/<dev>.env when finished
   │
   ▼
leader
   ├─ reads each status/<dev>.env
   ├─ aggregates into tasks.md
   ├─ updates memory (feature note, MOC entries)
   └─ summarizes to user
```

## How to invoke

In Claude Code (CLI or extension), from this repo:

```
> use the leader agent: <your request>
```

The leader will plan and spawn. If you want to watch what the CLIs are doing
live, open a second terminal:

```
.claude/bin/team-tui.sh
```

## File map

```
.claude/
  agents/
    leader.md                # the only Claude subagent
  bin/
    spawn-team.sh            # ← orchestrator: ≥2 devs, parallel, wait, aggregate
    _runner.sh               # shared helper used by run_*.sh
    run_codex.sh             # → invokes the real `codex` CLI
    run_deepseek.sh          # → invokes the real `deepseek` CLI
    run_opus.sh              # → invokes the real `opus` (or `claude --model opus`)
    team-tui.sh              # fzf TUI to inspect processes, memory, leader runs
  team/
    tasks.md                 # shared task list (per run, leader writes)
    personas/
      dev1.md ... dev5.md    # prompt fragments injected into each CLI
    status/
      dev1.env ... dev5.env  # status protocol; each CLI writes its own
    runs/
      leader-<TS>.md         # per-run diary the leader keeps
      <TS>-<cli>-<pid>/      # per-CLI invocation: meta.env + output.log
    plans/
      <task-id>.md           # planning docs (dev2 + dev5)
  memory/
    _index.md, _templates/
    architecture/, features/, fixes/, bugs/
  settings.json              # permission rules (e.g. deny reads of .env*)
```

## Status file protocol

Each persona writes `.claude/team/status/<dev>.env` exactly once per run.
Required fields: `task_id`, `status` (= `done|failed|blocked`), `notes`,
`finished_at`. Optional fields depend on the persona (see each persona file).
Leader reads them after `spawn-team.sh` returns.

## "≥ 2 devs per run" rule

Enforced by `spawn-team.sh`: it exits with code 2 if fewer than 2 distinct
devs are passed. The leader's persona reinforces this.

## TUI — `.claude/bin/team-tui.sh`

A small dashboard. Requires `bash` and (for best UX) `fzf`. Falls back to
numbered menus if fzf isn't installed. Three views:

- **[P] Processes** — every `run_*.sh` invocation, newest first, with status
  (running / done / failed / stale), dev, cli, prompt excerpt. Keys: `enter`
  tail in `less +F`, `ctrl-k` SIGTERM, `ctrl-d` delete run.
- **[M] Memory** — recent notes in `.claude/memory/`.
- **[L] Leader runs** — `.claude/team/runs/leader-<TS>.md` diaries.

## Customizing

- Different CLI binaries: edit the wrappers, or set
  `CODEX_FLAGS` / `DEEPSEEK_FLAGS` / `OPUS_FLAGS` / `OPUS_BIN` in your env.
- Different size rules: edit `.claude/agents/leader.md` routing table and the
  matching bracket in each persona file.
- More / fewer devs: add `dev6.md` to `personas/`, add a `run_<newcli>.sh`
  wrapper if needed, update the leader's roster.
