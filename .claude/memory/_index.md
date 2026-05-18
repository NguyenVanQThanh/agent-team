---
type: moc
title: Memory Vault — Root Index
updated: 2026-05-15
tags: [moc, index]
---

# Memory Vault

This is the team's long-lived knowledge base. The shared task list
(`.claude/team/tasks.md`) is for *this run*; notes here are for *forever*.

## Sections

- [[architecture/_moc|Architecture]] — how the system is built.
- [[features/_moc|Features]] — what we're building / shipped.
- [[fixes/_moc|Fixes]] — change write-ups for non-trivial fixes.
- [[bugs/_moc|Bugs]] — open and resolved defects.

## ID space

| Prefix | Type         | Example                            |
|--------|--------------|------------------------------------|
| `A-`   | architecture | `architecture/A-001-event-bus.md`  |
| `F-`   | feature      | `features/F-001-auth-mfa.md`       |
| `X-`   | fix          | `fixes/X-001-retry-stall.md`       |
| `B-`   | bug          | `bugs/B-001-stale-cache.md`        |

## Recent runs

_Leader appends a one-line summary per run._

- 2026-05-18 (run 20260518-081736): shipped standalone HTML ports of both mini-games + a new [[features/F-003-game-dashboard]]. Three CLIs (codex/deepseek/opus) ran in parallel, 0 failures, no re-routing. **Validates BL-02 fix**: dev4 (deepseek `exec --auto`) wrote a non-trivial HTML file unsupervised for the first time.
- 2026-05-17 (run 20260517-231455): shipped [[features/F-001-tic-tac-toe]] + [[features/F-002-rock-paper-scissors]]; introduced [[architecture/A-001-rock-paper-scissors-component]]. dev3/dev4 (deepseek) found unusable for FS tasks in this env — see backlog BL-01/BL-02.

