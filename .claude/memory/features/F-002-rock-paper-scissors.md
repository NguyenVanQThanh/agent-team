---
type: feature
id: F-002
title: Rock Paper Scissors mini-game
created: 2026-05-17
updated: 2026-05-18
status: shipped
tags: [feature, react, game, mini-game, html-port]
related: [T-002, T-003, T-005, T-006, A-001, T-002-r2, F-003]
owner: dev4
authored_by: leader
---

# F-002 — Rock Paper Scissors mini-game

## Goal
Ship a self-contained Rock-Paper-Scissors React component (`src/games/RockPaperScissors.jsx`) where the user plays against a random computer opponent, with a persistent score tracker.

## Acceptance
- [x] Default-exported `RockPaperScissors` component, pure React + hooks (no extra deps).
- [x] Three buttons: Rock, Paper, Scissors.
- [x] Computer picks randomly each round.
- [x] Round result computed: win / lose / draw.
- [x] Persistent score tracker: player wins, computer wins, draws — accumulates until restart.
- [x] Shows last round's picks + outcome.
- [x] Restart button resets scores and current round display.
- [x] File is valid JSX and renders without runtime errors.

## Plan / Tasks
- Run 20260517-231455:
  - T-002 (dev4, deepseek) — failed (CLI text-only in this env).
  - T-003 (dev2, codex) — planner refused prod edits; produced `.claude/team/plans/T-003.md` + [[architecture/A-001-rock-paper-scissors-component]].
  - T-005 (dev1, codex) — shipped per A-001.
  - T-006 (dev2, codex) — cross-component review confirmed compliance.

## Decisions
- Implementation contract pinned in [[architecture/A-001-rock-paper-scissors-component]].
- Single component, `useState` for `scores`, `lastRound`.
- Random opponent: `CHOICES[Math.floor(Math.random() * 3)]`.
- Matchup table: rock>scissors, paper>rock, scissors>paper.
- No styling framework — minimal inline styles consistent with `TicTacToe.jsx`.

## Changelog
- 2026-05-17: created (leader, run 20260517-231455).
- 2026-05-17: architecture contract A-001 authored by dev2 (T-003).
- 2026-05-17: shipped — `src/games/RockPaperScissors.jsx` landed via T-005 (dev1). Reviewed under T-006 (dev2).
- 2026-05-18 (run 20260518-081736, T-002): added standalone HTML port at `src/games/RockPaperScissors.html` — React 18 prod build + Babel standalone via unpkg CDN, mounts via `ReactDOM.createRoot`, inline `<style>` block. All `WINNING_MATCHUPS` / `INITIAL_SCORES` / `getRoundResult` semantics identical to the JSX. **First successful deepseek (dev4) file-write task since the BL-02 fix.** Consumed by [[features/F-003-game-dashboard]].
