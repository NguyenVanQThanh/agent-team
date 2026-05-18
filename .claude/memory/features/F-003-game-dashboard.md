---
type: feature
id: F-003
title: Game Dashboard (HTML landing page for the mini-games)
created: 2026-05-18
updated: 2026-05-18
status: shipped
tags: [feature, html, dashboard, mini-game]
related: [T-003, F-001, F-002]
owner: dev5
authored_by: leader
---

# F-003 — Game Dashboard

## Goal
Give the user a single landing page (`src/games/dashboard.html`) that lets them switch between the standalone HTML mini-games shipped under [[F-001-tic-tac-toe]] and [[F-002-rock-paper-scissors]]. Must work via `file://` (double-click) with all three files colocated in `src/games/`.

## Acceptance
- [x] Self-contained single HTML file at `src/games/dashboard.html` — no build step, no external dependencies beyond what the embedded games already CDN-load.
- [x] Header reads "🎮 Game Dashboard".
- [x] Two clickable cards: "Tic Tac Toe" and "Rock Paper Scissors".
- [x] Clicking a card swaps the card grid for an `<iframe>` pointed at the sibling HTML file (relative path → works on `file://`).
- [x] Back button + Esc key return to the dashboard and unload the iframe (sets `src="about:blank"` so embedded React unmounts cleanly).
- [x] Clean modern look — dark theme with radial gradients, CSS Grid `auto-fit minmax(260px, 1fr)`, hover/focus-visible affordances, mobile breakpoint at 540px.
- [x] Pure HTML/CSS/JS — no React in the dashboard itself.

## Plan / Tasks
- Run 20260518-081736 → T-003 (dev5, opus). Done first try, no re-routing.
- Sibling: T-001 (dev1, codex) and T-002 (dev4, deepseek) shipped the HTML ports the dashboard embeds.

## Implementation
- File: `src/games/dashboard.html`
- Card targets are encoded in `data-src` attributes on each card `<button>`, looked up via `querySelectorAll(".card[data-src]")` and wired to a single `openGame(src, label)` function.
- `showDashboard()` clears `frame.src` to `about:blank` so the embedded React app fully unmounts (important when bouncing between games — keeps memory + listeners clean).
- `history.replaceState` is used (not `pushState`) so reloading the file:// URL always lands on the dashboard view — sidesteps back-button quirks with file:// origins.

## Decisions
- **Iframe over `window.location` navigation.** Keeps the chrome (header + Back button) always visible and avoids losing the dashboard state when the user comes back. Also dodges any cross-document scripting issues that file:// browsers tend to be strict about.
- **Sibling-relative `data-src`.** Pinning to bare filenames (`TicTacToe.html`, not `./TicTacToe.html` or `src/games/...`) is what lets all three files travel as a self-contained folder.
- **No router / hash routing.** Two games and a dashboard don't need it; a simple `dashboard.hidden` toggle is clearer.

## Changelog
- 2026-05-18: created (leader, run 20260518-081736).
- 2026-05-18: shipped — `src/games/dashboard.html` landed via T-003 (dev5, opus).
