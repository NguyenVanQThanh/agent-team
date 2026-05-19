# Task queue (pool mode)

Used by `.claude/bin/spawn-team.sh --pool`. Devs `claim-task.sh` from
`pending/`, move to `claimed/` while running, finalise into `done/` or
`failed/`. Tournament and pre/post phases still use **pinned** spawn
(`spawn-team.sh dev1:codex:T-001 ...`), not the queue.

## Lifecycle

```
pending/T-001.task          (leader writes here)
   │ claim-task.sh dev1     (flock + mv, atomic)
   ▼
claimed/T-001.task          (claimed_by=dev1, claimed_at=...)
   │ complete-task.sh dev1 T-001 done|failed
   ▼
done/T-001.task    OR   failed/T-001.task
```

## Task file format

```env
id=T-001
size=M
summary=Refactor X
files=src/a.py,src/b.py
acceptance=tests pass; lint clean
depends_on=T-000              # comma-separated, all must be in done/
created_at=2026-05-19T10:00:00Z
```

`claim-task.sh` reads `size=`, matches against `DEV_SIZES[<dev>]`
(from `.claude/bin/env.sh`), and skips any task whose deps aren't all in
`done/`.

`pending/`, `claimed/`, `done/`, `failed/` contents are gitignored —
they are per-run artifacts. Only the directory + this README are tracked.
