# Project rules for Claude

## Output style — KEEP IT SHORT

Every turn is billed the whole context, so verbose replies cost input+output tokens. Reply with only these four sections, as short as possible, and omit any that are empty:

1. **Kết quả** — 1–2 câu điều đã làm được.
2. **File thay đổi** — danh sách path (+ vài chữ mỗi file).
3. **Next** — việc cần làm tiếp (bullet ngắn).
4. **Nhận xét** — rủi ro / lưu ý, nếu có.

No preamble, no recap of steps, no restating the request, no narrating tool calls.

## Secret files — DO NOT READ

Never read or print real env files: `.env`, `.env.local`, `.env.development`, `.env.production`, `.env.staging`, `.env.test`, any `.env.*.local`. Safe: `.env.example`, `.env.sample`, `.env.template`.

If a task needs a real `.env`: read `.env.example` for the expected keys, ask the user for the value. Never echo/cat/grep/redirect the file. Enforced by `.claude/settings.json` (`permissions.deny`).

## Coding standards

Full rules in `.claude/config/coding-rules.md`. Key points:

- **Protected files** — never edit `.env*`/secrets/prod config (only `*.example|sample|template`).
- **File headers** — every created/modified source file carries `createdAt`, `createdBy`, `updatedAt`, `updatedBy` in native comment syntax.
- **Business handler comments** — functions with business logic get a numbered process list in the docstring + matching `// N.` markers in the body.

## Agent team

1 leader (Claude opus subagent, prompt `.claude/agents/leader.md`) + 16 dev CLIs spawned as background processes. They communicate via files:

- `.claude/team/tasks.md` — shared task list (leader writes).
- `.claude/team/status/<dev>.status` — per-dev status.
- `.claude/team/research/<task-id>-findings.md` — dev11 research.
- `.claude/memory/` — durable knowledge vault; `.claude/memory/user-prefs/` (gitignored).
- `.claude/team/runs/<run-id>/` — per-CLI logs.

Dev personas: `.claude/team/personas/dev{1..16}.md`.

**Codex routing:** Luna lane (`dev1/dev12/dev15`) = S/M; Terra lane (`dev2/dev13/dev16`) = M/L. Route simple local work → Luna, multi-file/architectural → Terra. Model flags in `.claude/bin/env.sh`.

Roster:

| Dev | CLI | Sizes | Phase | Reasoning | Strengths |
|-----|-----|-------|-------|-----------|-----------|
| dev1 | Codex | M,L | main | medium | Default workhorse: coding, smoke, refactor |
| dev2 | Codex | M,L | main | high | Module planner, architecture notes |
| dev3 | DeepSeek | S,M | main | — | Quick smoke, small refactors |
| dev4 | DeepSeek | S,M | main | — | Small well-scoped changes |
| dev5 | Claude Opus | XL | main | — | Senior: hard bugs, arch rewrites (costly) |
| dev6 | Claude Haiku | M | main | — | Fast coder, simple tasks |
| dev7 | Claude Haiku | M | main | — | Smoke tester, quick verify |
| dev8 | Claude Sonnet | L | main | — | Quality multi-file features |
| dev9 | Claude Sonnet | L | main | — | Reviewer, integrator |
| dev10 | DeepSeek | M | post | — | Memory scribe (bugs/fixes vault) |
| dev11 | Gemini | M | pre | — | Researcher (external info, pre-batch) |
| dev12 | Codex | S,M | main | low | Smoke/lint/quick verify (cheap) |
| dev13 | Codex | L,XL | main | xhigh | Senior coder + tournament partner |
| dev14 | Claude Opus | L,XL | main | — | Senior reviewer + security gate (review-only) |

**Spawning:** leader uses `.claude/bin/spawn-team.sh dev1:codex:T-001 dev3:deepseek:T-002`. It validates ≥2 distinct devs, builds each prompt (persona + task row + shared context), launches via `run_<cli>.sh` in parallel, waits, aggregates status files.

**Plan handoff gate:** Every plan-driven task requires explicit **plan approval**
from the user first. The leader then creates the orchestrator/task rows and asks
for **dev roster approval**. The leader must wait when the roster is missing or
declined; `spawn-team.sh` may run only after roster approval, and the leader may
not execute the plan itself.

**Status protocol:** each persona writes `.claude/team/status/<dev>.status` before exit — flat `KEY=value`; required `task_id`, `status` (done|failed|blocked), `notes`, `finished_at`.

**CLI wrappers** (`.claude/bin/run_codex|deepseek|opus.sh`) source `_runner.sh`: creates run dir with `meta.env`+`output.log`, records start/end/exit. Override via `CODEX_FLAGS`, `DEEPSEEK_FLAGS`, `OPUS_BIN`, `OPUS_FLAGS`. Per-dev Codex effort via `CODEX_FLAGS_<DEV>` (dev12 low, dev1 medium, dev2 high, dev13 xhigh) — `_runner.sh` auto-picks when `--dev=` is passed.

**Monitoring:** `.claude/bin/team-tui.sh` — fzf dashboard: [P] processes, [M] memory, [L] leader runs.

**Tournament (XL):** leader may spawn dev5 + dev13 on same task_id → git worktree per dev under `.claude/team/worktrees/<task_id>-<dev>/`. Pick winner: `prune-worktrees.sh <task_id> <dev>` (squash-merge) or `--abort`. See `.claude/agents/leader.md`.

## Memory vault (`.claude/memory/`)

Durable knowledge in Obsidian style. Layout: `_index.md` (MOC), `_templates/`, `architecture/`, `features/`, `fixes/`, `bugs/`.

- Every note starts with YAML frontmatter (`type,id,created,updated,status,tags,related`) from `_templates/`.
- Cross-link with wikilinks: `[[bugs/B-007]]`, `[[fixes/X-012]]`.
- IDs: `A-`/`F-`/`X-`/`B-NNN` (scan folder for highest). Filenames `<id>-<slug>.md`, kebab-case.
- Keep notes short + link-heavy (a bug note links to its fix, doesn't repeat it).

**Write policy:** leader → `features/`,`_index.md`,logs; dev2 → `architecture/`; dev5 → `architecture/`,`fixes/`,`bugs/`; dev14 → `bugs/` (review/security). dev1/3/4 read-only (report findings → leader/dev5 records).

**When to write:** architecture/ on module plan or arch decision; features/ per feature run; bugs/ on confirmed bug; fixes/ after non-trivial fix (link back to bug).

**Retrieval:** QMD may index the vault — `.claude/bin/memory-tools.sh bootstrap` once, `update` after a write, `search "<q>"` before scanning. Cache is local, never canonical; use `rg` fallback if QMD down. Serena is code-intelligence only (memory tools disabled) — not a memory store.

**Task IDs:** vault notes durable, `tasks.md` rows ephemeral. When a task yields a note, put the wikilink in the task's `note` column and list task IDs in the note's `related`.
