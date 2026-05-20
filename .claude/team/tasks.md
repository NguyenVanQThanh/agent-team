# Shared Task List

The leader writes here at the start of every run. Each row maps to one CLI
spawn. After the run, the leader aggregates each `.claude/team/status/<dev>.status`
into the row's `status` and `note` columns.

**Status legend**: `todo` → `in_progress` → `done` | `failed` | `blocked`
**Size legend**: `S` (skip team) | `M` | `L` | `XL` (dev5 only)

| Dev    | CLI      |
|--------|----------|
| dev1, dev2, dev12, dev13 | `codex`  |
| dev3, dev4, dev10        | `deepseek` |
| dev5   | `claude --model opus`  |
| dev6, dev7 | `claude --model haiku` |
| dev8, dev9 | `claude --model sonnet` |
| dev11  | `gemini` |

---

## Current run — 20260520-033403 — Browser games (Minesweeper + FruitBox + Dashboard)

Feature note: [[features/F-001-browser-games-dashboard]]

| id    | size | summary | files | acceptance | assignee | depends_on | status | note |
|-------|------|---------|-------|------------|----------|------------|--------|------|
| T-001 | L | Build Minesweeper game | d:/agent-team/games/minesweeper.html, d:/agent-team/games/js/minesweeper.js | All requirements met | dev8 → leader | — | done (leader-self-handled) | dev8 sub-CLI blocked by harness write permissions — leader took over. See [[runs/leader-20260520-033403]] |
| T-002 | L | Build FruitBox game | d:/agent-team/games/fruitbox.html, d:/agent-team/games/js/fruitbox.js | All requirements met | dev9 → leader | — | done (leader-self-handled) | dev9 sub-CLI drifted onto unrelated task — leader took over. See [[runs/leader-20260520-033403]] |
| T-003 | M | Dashboard + shared css/style.css | d:/agent-team/games/index.html, d:/agent-team/games/css/style.css | All requirements met | dev6 → leader | — | done (leader-self-handled) | dev6 sub-CLI blocked by harness write permissions — leader took over. See [[runs/leader-20260520-033403]] |

---

## Backlog (follow-ups filed by devs)

_When a dev's `status/<dev>.status` mentions a follow-up in `notes=`, the leader
adds a row here (status `todo`, assignee blank — leader routes next run)._

| id | size | summary | files | acceptance | filed_by | status |
|----|------|---------|-------|------------|----------|--------|
| T-FU01 | M | Investigate why sub-CLIs (haiku, sonnet) can't write files into the project root in this harness. Likely need to widen `.claude/settings.json` `permissions.allow` to include `Write(d:/agent-team/**)`. Propose patch. | .claude/settings.json | sub-CLIs can write to games/ and similar paths without blocking on "explicit user approval" | leader (run 20260520-033403) | todo |

---

## History

_Completed runs get moved here (most recent on top). Keep last ~5 runs;
older ones can be pruned._
