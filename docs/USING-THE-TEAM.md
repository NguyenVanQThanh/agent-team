# Using the Agent Team

How to actually run the 1-leader + 14-dev team, given the current config
(RTK adopted, Headroom removed, Superpowers skills vendored).

---

## 0. One-time setup

**Authenticate each CLI** (once):

```bash
codex auth              # or: export OPENAI_API_KEY=...
deepseek login          # or: key in .claude/bin/env.local.sh
claude                  # authenticates interactively on first use (subscription)
gemini auth             # optional — only dev11 (research)
```

- The DeepSeek key lives in `.claude/bin/env.local.sh` (gitignored). It serves
  the DeepSeek devs (dev3/dev4/dev10).

**Activate RTK hooks** — they're installed but take effect only after each CLI
restarts. Close and reopen Claude Code, Codex, and Gemini once.

**Pre-flight check:**

```bash
.claude/bin/team-doctor.sh
```

All green = good to go. RTK shows as warn-only (optional, never blocks the team).

---

## 1. The normal way — delegate to the leader

You do **not** call `spawn-team.sh` by hand. In a Claude Code chat, just describe
the work and mention the team:

> "Use the agent team to add feature X to module Y, with tests."

The **leader** subagent then automatically:

1. Reads the memory vault (`.claude/memory/`) for context.
2. Slices the work into `.claude/team/tasks.md` rows (each sized S/M/L/XL).
3. Spawns devs in parallel via `spawn-team.sh` (≥ 2 devs per call), preferring
   the cheaper non-Claude CLIs first.
4. Waits, aggregates each `.claude/team/status/<dev>.status`, updates tasks.md
   and the run diary.
5. Post-phase: dev10 writes memory notes; dev9/dev14 review when warranted.

Trigger words that route to the leader: **"team", "agent team", "leader",
"use the team"**, or any non-trivial multi-file request.

---

## 2. Three phases the leader runs

```
Pre   (when research is needed)  → dev11 (Gemini) gathers external info first
Main  (implementation)           → several devs code in parallel
Post  (memory + review)          → dev10 writes vault; dev9/dev14 review
```

## 3. Methodology skills (vendored, auto-activating)

Six Superpowers skills in `.claude/skills/` surface automatically by context for
the leader and Claude/Codex devs:

- `brainstorming` — before design work
- `writing-plans` — multi-step tasks (patched: hands execution to the leader)
- `test-driven-development`
- `systematic-debugging`
- `requesting-code-review`
- `verification-before-completion`

`subagent-driven-development` and `dispatching-parallel-agents` are deliberately
absent — the leader is the only orchestration layer. See
`.claude/skills/VENDORED.md`.

---

## 4. Monitoring a run

```bash
.claude/bin/team-tui.sh          # live dashboard: [P]rocesses / [M]emory / [L]eader runs
cat .claude/team/tasks.md        # task states
ls .claude/team/status/          # per-dev done | failed | blocked
ls .claude/team/runs/            # per-invocation logs (output.log + meta.env)
```

---

## 5. Tournament mode (hard XL work)

Tell the leader it's an XL task with no obviously-correct approach. It spawns
**dev5 (Opus) + dev13 (Codex)** on the same task ID, each in its own git
worktree, then you pick the winner:

```bash
.claude/bin/prune-worktrees.sh T-100 dev5      # squash-merge the winner
.claude/bin/prune-worktrees.sh T-100 --abort   # drop both, no merge
```

Use it for: hard bug with uncertain root cause, cross-module refactor with
multiple valid designs, or high-stakes changes (auth, data migration).
Not for mechanically-clear work or anything below L.

---

## 6. Examples

| You say | Leader does |
|---------|-------------|
| "Use the team to fix the login timeout bug" | optional pre-research → 2-3 devs fix + smoke test → review |
| "Team: refactor the payment module, XL, tricky" | tournament dev5 + dev13 → pick winner |
| "Fix this one-line typo" | leader **self-handles** (no spawn — below the ≥2-dev threshold) |

---

## 7. Token compression (RTK)

RTK compresses shell-command output at the source (~32% on sampled commands,
Bash channel only). It's transparent once hooks are active — nothing to invoke.
Check savings anytime:

```bash
rtk gain
```

---

## Notes & gotchas

- RTK hooks need a CLI **restart** to activate.
- Vendored skills do **not** auto-update; refresh per `.claude/skills/VENDORED.md`.
- Never edit `.env*` or `env.local.sh` — protected/secret (see `CLAUDE.md`).
- Every `spawn-team.sh` call uses **≥ 2 distinct devs** (hard rule).
