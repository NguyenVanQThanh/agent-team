# Shared Task List

The leader writes here at the start of every run. Each row maps to one CLI
spawn. After the run, the leader aggregates each `.claude/team/status/<dev>.env`
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

## Current run

_Leader: replace this section each time you plan a new run._

| id    | size | summary | files | acceptance | assignee | depends_on | status | note |
|-------|------|---------|-------|------------|----------|------------|--------|------|
| (idle) |     |         |       |            |          |            |        |      |

---

## Backlog (follow-ups filed by devs)

_When a dev's `status/<dev>.env` mentions a follow-up in `notes=`, the leader
adds a row here (status `todo`, assignee blank — leader routes next run)._

| id | size | summary | files | acceptance | filed_by | status |
|----|------|---------|-------|------------|----------|--------|

---

## History

_Completed runs get moved here (most recent on top). Keep last ~5 runs;
older ones can be pruned._
