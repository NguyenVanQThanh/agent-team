---
type: feature
id: F-001
title: Tic Tac Toe mini-game
created: 2026-05-17
updated: 2026-05-18
status: shipped
tags: [feature, react, game, mini-game, html-port]
related: [T-001, T-001-r2, F-003]
owner: dev1
authored_by: leader
---

# F-001 — Tic Tac Toe mini-game

## Goal
Ship a self-contained two-player Tic Tac Toe React component (`src/games/TicTacToe.jsx`) the user can drop into any React app.

## Acceptance
- [x] Default-exported `TicTacToe` component, pure React + hooks (no extra deps).
- [x] 3x3 board, alternating X/O turns, click-to-place.
- [x] Detects all 8 winning lines and draw state.
- [x] Status line shows "Next: X/O", "Winner: X/O", or "Draw".
- [x] Restart button resets the board and turn.
- [x] File is valid JSX and renders without runtime errors.

## Plan / Tasks
- Run 20260517-231455 → T-001 (dev1, codex). Verified again under T-004 / T-006.

## Implementation
- File: `src/games/TicTacToe.jsx`
- State: `useState(board)` + `useState(nextPlayer)`; `useMemo(getWinner)` over 8 winning lines; `isDraw = !winner && board.every(Boolean)`.

## Decisions
- No state management library; `useState` is plenty for a 9-cell board.
- No styling framework required — minimal inline styles or plain class names; the user will style on integration.
- No tests in this run (repo has no test infra yet); dev1's smoke is a re-read + JSX sanity check.

## Changelog
- 2026-05-17: created (leader, run 20260517-231455).
- 2026-05-17: shipped — `src/games/TicTacToe.jsx` landed via T-001 (dev1). Cross-reviewed under T-006 (dev2).
- 2026-05-18 (run 20260518-081736, T-001): added standalone HTML port at `src/games/TicTacToe.html` — React 18 + Babel standalone via unpkg CDN, mounts via `ReactDOM.createRoot`, polished inline `<style>` (responsive board, focus-visible outlines). Logic preserved verbatim from the JSX. Consumed by [[features/F-003-game-dashboard]].
