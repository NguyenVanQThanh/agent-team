# Codex Luna/Terra Team Implementation Plan

> **For agentic workers:** Hand this plan back to the agent-team leader for future routing changes.

**Goal:** Configure six medium-reasoning Codex teammates split evenly between Luna for S/M and Terra for M/L.

**Architecture:** Keep the existing Codex runner and add per-dev model flags. Existing devs are reclassified into the two routing tiers; dev15 and dev16 are added as parallel Luna/Terra implementation roles. Documentation and leader routing remain synchronized.

**Tech Stack:** Bash runner configuration, Markdown personas and team documentation.

## Tasks

- [x] Update `.claude/bin/env.sh` with Luna/Terra medium flags and six Codex assignments.
- [x] Update `.claude/bin/_runner.sh` so new per-dev flags cannot leak from the parent environment.
- [x] Update existing Codex personas and add `dev15.md`/`dev16.md`.
- [x] Synchronize `CLAUDE.md`, `AGENTS.md`, `.claude/team/README.md`, `.claude/team/tasks.md`, and `.claude/agents/leader.md`.
- [x] Run static routing/model checks; Bash-based `team-doctor.sh` execution is unavailable because this Windows environment has no `/bin/bash`.
