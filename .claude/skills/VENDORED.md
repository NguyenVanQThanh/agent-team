# Vendored skills — Superpowers (subset)

These skills are **vendored** (copied into this repo) from
[obra/superpowers](https://github.com/obra/superpowers) — MIT License,
Copyright (c) 2025 Jesse Vincent. Full license text in
[`SUPERPOWERS-LICENSE`](SUPERPOWERS-LICENSE).

**Why vendored instead of installed as a plugin:** Claude Code cannot disable
individual skills of an installed plugin (only whole plugins). The agent-team
must exclude two skills that conflict with the leader's orchestration, so we
copy only the skills we want. See `ARCHITECTURE (1).md` §4 and the
implementation-status log.

## Included (6)

| Skill | Purpose |
|-------|---------|
| `brainstorming` | Socratic design refinement before planning |
| `writing-plans` | Detailed task breakdown (patched — see below) |
| `test-driven-development` | RED-GREEN-REFACTOR cycle |
| `systematic-debugging` | Root-cause analysis |
| `requesting-code-review` | Structured review requests |
| `verification-before-completion` | Prove the change works before "done" |

## Deliberately EXCLUDED (conflict with the agent-team leader)

- `subagent-driven-development` — overlaps with leader "slice → spawn → review".
- `dispatching-parallel-agents` — the leader + `spawn-team.sh` is the single
  orchestration layer.

Any other Superpowers skills (`executing-plans`, `using-git-worktrees`,
`using-superpowers`, etc.) are simply not vendored.

## Local modifications

- `writing-plans/SKILL.md` — the plan-execution step originally pointed agents at
  `subagent-driven-development` / `executing-plans`. Repointed to hand the plan to
  the agent-team **leader** (`.claude/team/tasks.md` → `spawn-team.sh`) so nothing
  self-dispatches subagents. Worktree note repointed to the tournament flow.

## Updating

Not auto-updated. To refresh: re-pull the 6 skill dirs from obra/superpowers,
then re-apply the `writing-plans` patches above.

_Vendored 2026-07-09 from `main`._
