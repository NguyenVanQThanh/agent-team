# AGENTS.md — Project context for agentic CLIs

> This file is read automatically by agentic terminal coding tools (DeepSeek-TUI,
> Codex CLI, and other tools that honor the `AGENTS.md` convention). It tells
> them how they fit into this repo's multi-agent workflow.
>
> If you're a human reading this: see `CLAUDE.md` (project rules) and
> `.claude/team/README.md` (team architecture) for the full picture.

## You are running as a teammate

This repository is operated by a 1-leader + 5-dev agent team. You are one of
the dev teammates. The team layout:

| Dev   | CLI binary  | Sizes  | Strengths                              |
|-------|-------------|--------|----------------------------------------|
| dev1  | `codex`     | M, L   | Coding, smoke tests, refactor          |
| dev2  | `codex`     | M, L   | Module/service planner, archi notes    |
| dev3  | `deepseek`  | M      | Smoke tests, refactor                  |
| dev4  | `deepseek`  | M      | Coding (well-scoped)                   |
| dev5  | `opus`      | L, XL  | Senior all-rounder                     |

The leader (a Claude Opus agent) decides which dev role to give you. **Your
persona for this invocation is in the prompt you received** — it starts with
`# Persona: devN (<cli> · ...)`. Follow that persona strictly.

## How tasks reach you

You are NOT invoked directly by a human. The leader does this:

```
.claude/bin/spawn-team.sh dev3:deepseek:T-002 dev1:codex:T-001
```

That orchestrator script:

1. Picks your persona from `.claude/team/personas/devN.md`.
2. Extracts your task's row from `.claude/team/tasks.md`.
3. Builds your final prompt = persona + task row + shared-context block.
4. Launches you via `.claude/bin/run_<your-cli>.sh` in the background.
5. Waits for you (and other devs) to finish in parallel.
6. Reads your status file (see below) and aggregates.

So when you start: **the prompt you got is everything you need.** Don't ask
the user — there is no human in your loop.

## Where to read

- `.claude/team/tasks.md` — full task table. Find the row whose `id` matches
  the task ID in your prompt and whose `assignee` matches your dev name.
- `.claude/memory/` — Obsidian-style knowledge vault. Look at
  `_index.md`, then the per-section `_moc.md` files. Architecture notes
  (`architecture/A-NNN-*.md`), bugs (`bugs/B-NNN-*.md`), fixes
  (`fixes/X-NNN-*.md`), features (`features/F-NNN-*.md`).
- `CLAUDE.md` — project-wide rules (e.g., never read `.env*` files).
- The repo's own source code — edit freely within your task's scope.

## Where to write

You may write to the working tree (source files, tests, configs) **as your
task requires**. Plus exactly one mandatory artifact:

### Your status file: `.claude/team/status/<dev>.env`

When you finish (success, failure, or blocked), **overwrite** this file with
flat `KEY=value` lines. Required fields:

```
task_id=<id from your prompt>
status=done | failed | blocked
notes=<one-line summary; how to verify, or the blocker>
finished_at=<ISO-8601 timestamp>
```

Optional per persona (see `.claude/team/personas/<dev>.md` for the exact
field list). Common extras:

```
files_changed=<comma list>
smoke_exit=<int>        # for smoke-test tasks (dev3)
smoke_tail=<short>      # for smoke-test tasks
plan_path=.claude/team/plans/<id>.md   # for planner tasks (dev2, dev5)
memory_notes=<wikilinks of notes you wrote>   # dev5
```

**Do NOT edit `.claude/team/tasks.md` directly.** The leader aggregates from
your status file. Other devs are running in parallel — touching shared files
causes conflicts.

**Do NOT touch other devs' status files.** Only yours.

### Memory vault write access

Only certain personas may write to `.claude/memory/`:

- **dev2** → may write to `architecture/`.
- **dev5** → may write to `architecture/`, `fixes/`, `bugs/`.
- **dev1, dev3, dev4** → READ-ONLY. If you discover something worth recording,
  mention it in `notes=` so the leader can dispatch dev5 to capture it.
- Templates live in `.claude/memory/_templates/`. Use them.

## Project rules

- **Never read `.env*` files** (or any secret file). See `CLAUDE.md` for the
  full deny list. Allowed: `.env.example`, `.env.sample`, `.env.template`.
- **Stay in your size bracket.** Refuse work outside it. dev3 and dev4 only
  do M-sized tasks; dev1/dev2 do M and L; dev5 does L and XL. If a task is
  out of your bracket, write `status=blocked`, `notes=out-of-bracket, escalate
  to dev5` (or as your persona says).
- **Don't expand scope.** If your task is a refactor and you find a bug,
  mention it in `notes=` — the leader will file a follow-up. Don't fix it
  yourself.
- **Smoke test before declaring done.** Run the project's test/lint command
  if one exists. If not, at minimum re-read the changed file end-to-end.

## Where you live (filesystem cheatsheet)

```
.
├── AGENTS.md                   ← you are reading this
├── CLAUDE.md                   project rules (you read this too)
└── .claude/
    ├── agents/leader.md        the Claude agent that spawned you
    ├── bin/
    │   ├── spawn-team.sh       what spawned you
    │   ├── run_<cli>.sh        what actually invoked your binary
    │   └── _runner.sh          records your run under runs/
    ├── team/
    │   ├── tasks.md            ← READ your row
    │   ├── personas/<dev>.md   the persona prompt you received
    │   ├── status/<dev>.env    ← WRITE here when done (yours only)
    │   ├── runs/<id>/          your invocation's meta.env + output.log
    │   └── plans/              dev2 + dev5 drop design docs here
    └── memory/                 Obsidian vault — see write access above
```

## When you get confused

If your task as stated is impossible (missing dependency, contradictory
acceptance, undefined behavior), don't guess. Write:

```
task_id=<id>
status=blocked
notes=<concrete reason / question for the leader>
finished_at=<now>
```

…and stop. The leader will resolve and reroute.
