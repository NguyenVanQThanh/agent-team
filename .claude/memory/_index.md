---
type: moc
title: Memory Vault — Root Index
updated: 2026-05-18
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

- 2026-05-20 — run 20260520-033403 — shipped [[features/F-001-browser-games-dashboard]];
  spawned dev8+dev9+dev6, all 3 sub-CLIs blocked by harness write perms → leader self-handled
  all 6 files. Follow-up T-FU01 filed in [[../team/tasks#Backlog]].

- 2026-05-25 — rule audit triggered by user — fixed Rule #7 override loophole; new Hard rules #8 (Claude-variant token budget) + #9 (no size-splitting). See [[bugs/B-002-rule7-override-loophole]] / [[fixes/X-002-rule7-override-gate]] / [[user-prefs/thanh]].
