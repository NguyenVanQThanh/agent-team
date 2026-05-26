# Project rules for Claude

## Secret files — DO NOT READ

Claude must **never** read or print the contents of any real environment file.

- Forbidden: `.env`, `.env.local`, `.env.development`, `.env.production`,
  `.env.staging`, `.env.test`, and any `.env.*.local` variant — at the project
  root or anywhere under it.
- Allowed: `.env.example`, `.env.sample`, `.env.template` (these contain only
  placeholder values and are safe to read).

If a task seems to require the contents of a real `.env`, do not open it.
Instead:
1. Open `.env.example` to see which variables are expected.
2. Ask the user what the value should be, or have the user paste the specific
   line they want to discuss.
3. Never echo, `cat`, `grep`, redirect, or otherwise exfiltrate the file's
   contents through Bash or any other tool.

These rules are also enforced by `.claude/settings.json` (`permissions.deny`),
so attempts to read a forbidden file will fail at the tool layer. This file
exists so the rationale is visible to anyone — human or agent — reviewing the
project.

---

## Coding standards

All dev teammates must follow the coding rules defined in
`.claude/config/coding-rules.md`. Key points:

- **Protected files** — never edit `.env*`, secrets, or production config files.
  Only `.env.example` / `.env.sample` / `.env.template` are safe to touch.
- **File header comments** — every source file created or significantly modified
  must carry a header with `createdAt`, `createdBy`, `updatedAt`, `updatedBy`
  using the language's native comment syntax.
- **Business handler comments** — any function containing business logic must
  have a numbered process list in its docstring, with matching `// N.` markers
  inside the body so reviewers can follow the flow step by step.

See `.claude/config/coding-rules.md` for full templates per language.

---

## Agent team

This repo is configured with a 1-leader + 13-dev agent team. **The leader is a
Claude subagent; the 13 devs are external agentic CLIs** (Codex / DeepSeek /
Claude Haiku / Claude Sonnet / Claude Opus / Gemini), each spawned as a real
background process. They communicate via shared files:

- `.claude/team/tasks.md` — shared task list (per run; leader writes).
- `.claude/team/status/<dev>.status` — per-dev status protocol (each CLI writes its own).
- `.claude/team/research/<task-id>-findings.md` — dev11 research output (pre-phase).
- `.claude/memory/` — durable Obsidian-style knowledge vault.
- `.claude/memory/user-prefs/` — personal user preferences (gitignored).
- `.claude/team/runs/<run-id>/` — per-CLI invocation logs (meta.env + output.log).

Definitions:
- Leader subagent prompt: `.claude/agents/leader.md` (model: opus).
- Dev persona prompts: `.claude/team/personas/dev{1..11}.md`.

Roster:

| Dev   | CLI          | Sizes   | Phase  | Reasoning | Strengths                                          |
|-------|--------------|---------|--------|-----------|----------------------------------------------------|
| dev1  | Codex        | M, L    | main   | medium    | Coding, smoke tests, refactor (default workhorse)  |
| dev2  | Codex        | M, L    | main   | high      | Module planner, architecture notes                |
| dev3  | DeepSeek     | S, M    | main   | n/a       | Quick smoke tests, small refactors                |
| dev4  | DeepSeek     | S, M    | main   | n/a       | Coding small well-scoped changes                  |
| dev5  | Claude Opus  | XL      | main   | n/a       | Senior: hard bugs, arch rewrites (costly)         |
| dev6  | Claude Haiku | M       | main   | n/a       | Fast coder, simple tasks                          |
| dev7  | Claude Haiku | M       | main   | n/a       | Smoke tester, quick verification                  |
| dev8  | Claude Sonnet| M       | main   | n/a       | Quality implementer, focused features (down-ranked from L 2026-05-26 — Windows orphan hang on long L) |
| dev9  | Claude Sonnet| M       | main   | n/a       | Reviewer, integrator, cross-module checks (down-ranked from L 2026-05-26) |
| dev10 | DeepSeek     | M       | post   | n/a       | Memory scribe — writes bugs/fixes vault           |
| dev11 | Gemini CLI   | M       | pre    | n/a       | Researcher — external info before main batch      |
| dev12 | Codex        | S, M    | main   | low       | Smoke tester / lint / quick verify (fast, cheap)  |
| dev13 | Codex        | L, XL   | main   | xhigh     | Senior coder + tournament partner with dev5       |

### Spawning the team

The leader does NOT call `run_codex.sh` directly. It uses the orchestrator:

```
.claude/bin/spawn-team.sh dev1:codex:T-001 dev3:deepseek:T-002
```

`spawn-team.sh`:
1. Validates ≥ 2 distinct devs (the team's hard rule).
2. Builds each CLI's prompt by combining its persona + the task row + shared-context block.
3. Launches each CLI via `.claude/bin/run_<cli>.sh` in the background (parallel).
4. `wait`s for all of them.
5. Aggregates `.claude/team/status/<dev>.status` and prints a summary.

### Status file protocol

Each persona MUST write its `.claude/team/status/<dev>.status` before exiting.
Fields are flat `KEY=value` lines. Required: `task_id`, `status` (one of
`done|failed|blocked`), `notes`, `finished_at`. Optional fields per dev role
(see each persona file). The leader reads these to update `tasks.md` and the
run diary.

### CLI wrappers (`.claude/bin/`)

`run_codex.sh`, `run_deepseek.sh`, `run_opus.sh` all source `_runner.sh`, which:
- Creates `.claude/team/runs/<TS>-<cli>-<pid>/` with `meta.env` + `output.log`.
- Pipes the CLI's combined stdout+stderr to the log (still visible on the
  invoker's terminal too).
- Records `started_at`, `pid`, then `ended_at`, `exit_code`, `status` on EXIT.

Override binaries via env: `CODEX_FLAGS`, `DEEPSEEK_FLAGS`, `OPUS_BIN`,
`OPUS_FLAGS`.

### Live monitoring

`.claude/bin/team-tui.sh` opens an fzf-based dashboard with three views:
[P] Processes (live CLI runs), [M] Memory (vault notes), [L] Leader runs.

### Tournament mode (XL ensemble)

For high-stakes XL tasks the leader can spawn **dev5 + dev13 on the same
task_id**. `spawn-team.sh` detects this and creates a git worktree per dev under
`.claude/team/worktrees/<task_id>-<dev>/` (each on branch
`tournament/<task_id>/<dev>`). After the run the leader picks a winner with:

```
.claude/bin/prune-worktrees.sh <task_id> <winning-dev>    # squash-merge + cleanup
.claude/bin/prune-worktrees.sh <task_id> --abort          # drop both, no merge
```

See `.claude/agents/leader.md` for when to use tournament vs solo dev5/dev13.

### Per-dev Codex reasoning levels

The four Codex devs use different `model_reasoning_effort` levels (configured
in `.claude/bin/env.sh` as `CODEX_FLAGS_DEV{1,2,12,13}`):

- dev12 → `low`     (smoke tests, lint, quick verify)
- dev1  → `medium`  (general M/L coding — default)
- dev2  → `high`    (planning, architecture sketches)
- dev13 → `xhigh`   (XL, hard bugs, tournament partner)

`_runner.sh` picks `CODEX_FLAGS_<DEV>` over `CODEX_FLAGS` automatically when a
`--dev=` tag is passed.

## Obsidian memory vault

Long-lived knowledge — architecture decisions, feature designs, bug reports,
fix write-ups — lives in an Obsidian-style vault at `.claude/memory/`.

### Folder layout (each is its own note type)

```
.claude/memory/
  _index.md               # root Map of Content (MOC), links to everything
  _templates/             # frontmatter templates for new notes
  architecture/           # how the system is built — modules, services, ADRs
  features/               # what we're building — feature briefs and state
  fixes/                  # how we fixed something — change write-ups
  bugs/                   # what's broken — bug reports
```

### Note conventions

- Every note starts with YAML frontmatter: `type`, `id`, `created`, `updated`,
  `status`, `tags`, `related`. Use the matching template in `_templates/`.
- Cross-link with Obsidian wikilinks: `[[architecture/auth-flow]]`,
  `[[bugs/B-007]]`, `[[fixes/F-012]]`. Prefer wikilinks over relative paths so
  the graph view stays useful.
- IDs: `A-NNN` for architecture, `F-NNN` for features, `X-NNN` for fixes,
  `B-NNN` for bugs. Increment by scanning the folder for the highest existing
  ID.
- Filenames: `<id>-<slug>.md`, lowercase, kebab-case
  (e.g. `B-007-retry-loop-stalls.md`).
- Keep notes short and link-heavy. A bug note doesn't repeat the fix — it
  links to `[[fixes/X-NNN-...]]`.

### Write policy (who can edit what)

Only three agents may **write** to the vault. The other devs read it for
context but never modify it.

| Agent  | Can write to                                    |
|--------|-------------------------------------------------|
| leader | `features/`, `_index.md`, run logs              |
| dev2   | `architecture/` (module/service plans)          |
| dev5   | `architecture/`, `fixes/`, `bugs/`              |
| dev1, dev3, dev4 | **read-only** — use vault for context |

Why: dev1/3/4 are narrow-bracket implementers; centralizing writes to the
senior + planner roles keeps the knowledge base coherent. If dev1/3/4 discover
something worth recording, they leave a note in their task report and the
leader or dev5 captures it into the vault during verification.

### When to write a note

- **architecture/**: any time dev2 plans a module, or dev5 makes an
  architecture-level decision (new service, replaced library, contract change).
- **features/**: when the leader kicks off a feature run. One note per feature,
  updated as the feature evolves.
- **bugs/**: when dev5 (or the leader on dev5's behalf) confirms a bug —
  symptoms, repro, severity, suspected cause.
- **fixes/**: after dev5 lands a non-trivial fix — what was wrong, what
  changed, what tests cover it. Link back to the bug.

### Linking to task IDs

Vault notes are durable; `tasks.md` rows are ephemeral (per run). When a task
produces a vault note, the task's `note` column gets the wikilink
(e.g. `[[features/F-003-retry-policy]]`), and the vault note's `related`
frontmatter lists the task IDs it came from.
