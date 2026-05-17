# Shared Task List

The leader writes here at the start of every run. Each row maps to one CLI
spawn. After the run, the leader aggregates each `.claude/team/status/<dev>.env`
into the row's `status` and `note` columns.

**Status legend**: `todo` → `in_progress` → `done` | `failed` | `blocked`
**Size legend**: `S` (skip team) | `M` | `L` | `XL` (dev5 only)
**Assignee**: one of `dev1` `dev2` `dev3` `dev4` `dev5`. Each maps to a CLI:

| Assignee | CLI binary |
|----------|------------|
| dev1, dev2 | `codex`  |
| dev3, dev4 | `deepseek` |
| dev5     | `opus` (or `claude --model opus`) |

---

## Current run

_Leader: replace this section each time you plan a new run._

| id    | size | summary                                | files                    | acceptance                                 | assignee | depends_on | status | note |
|-------|------|----------------------------------------|--------------------------|--------------------------------------------|----------|------------|--------|------|
| T-001 | L    | _(example)_ Add retry logic to client  | `src/client.ts`          | retries 3x on 5xx; unit test passes        | dev1     | —          | todo   |      |
| T-002 | M    | _(example)_ Smoke-test the retry change| —                        | runs `npm test`; reports pass/fail         | dev3     | T-001      | todo   |      |

Spawn command for the current run:

```
.claude/bin/spawn-team.sh dev1:codex:T-001 dev3:deepseek:T-002
```

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
