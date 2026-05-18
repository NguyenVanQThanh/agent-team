---
type: architecture
id: A-001
title: Rock Paper Scissors component contract
created: 2026-05-17
updated: 2026-05-17
status: active
tags: [architecture, react, game]
related: [T-003, F-002]
authored_by: dev2
---

# A-001 - Rock Paper Scissors component contract

## Context
The team needs a rerouted implementation plan for `src/games/RockPaperScissors.jsx` after the original DeepSeek implementer could not write files in this environment. The existing game area currently contains `src/games/TicTacToe.jsx`, which establishes a local pattern: self-contained React component, pure hooks, no external dependencies, and minimal inline styles.

## Decision
`RockPaperScissors.jsx` should be a single default-exported React component with no props and no dependencies beyond React hooks. It should keep scores and last-round state locally, compute the computer pick with `Math.random()`, and resolve rounds through a small matchup table:

- `rock` beats `scissors`
- `paper` beats `rock`
- `scissors` beats `paper`

The UI should expose three choice buttons, score counters for player/computer/draws, last picks, round result, and a restart button that clears both scores and the current round.

## Consequences
This keeps the mini-game portable and consistent with the Tic Tac Toe component. The trade-off is that randomness is embedded in the component, so deterministic unit testing would require extracting or injecting the random choice later if formal tests are added.

## Alternatives considered
- Shared game framework: unnecessary for two small standalone mini-games.
- External state/store: unnecessary; local `useState` covers the component contract.
- Prop-driven randomizer: more testable, but premature for the current acceptance and self-contained-file requirement.

## Links
- Related: [[features/F-002-rock-paper-scissors]]
- Planned by: `.claude/team/plans/T-003.md`

