/**
 * @file        minesweeper.js
 * @description Vanilla-JS Minesweeper engine + DOM renderer. Three difficulties
 *              (Beginner / Intermediate / Expert), left-click reveal,
 *              right-click flag, first-click is always safe (board regenerated
 *              if the first click would hit a mine or non-zero cell), timer,
 *              mine counter, smiley reset, score system (+10/reveal,
 *              +50/correct-flag-on-win, +time-bonus), and win/lose overlay.
 *
 * @createdAt   2026-05-20
 * @createdBy   leader
 * @updatedAt   2026-05-20
 * @updatedBy   dev9
 */

(function () {
  "use strict";

  const DIFFICULTIES = {
    beginner:     { rows: 9,  cols: 9,  mines: 10 },
    intermediate: { rows: 16, cols: 16, mines: 40 },
    expert:       { rows: 16, cols: 30, mines: 99 }
  };

  const state = {
    rows: 0,
    cols: 0,
    mines: 0,
    grid: [],          // [r][c] = { mine, revealed, flagged, adjacent }
    started: false,    // true after the first successful click
    over: false,
    won: false,
    flagsPlaced: 0,
    revealedCount: 0,
    timer: 0,
    timerHandle: null,
    score: 0
  };

  /**
   * createEmptyGrid — Allocate a rows×cols grid of fresh cells.
   *
   * Process:
   *   1. For each row r, build an inner array of cols cells
   *   2. Each cell starts as {mine:false, revealed:false, flagged:false, adjacent:0}
   *
   * @param  rows  number of rows
   * @param  cols  number of columns
   * @returns      2D array of cell objects
   */
  function createEmptyGrid(rows, cols) {
    // 1. Allocate row-by-row
    const g = new Array(rows);
    for (let r = 0; r < rows; r++) {
      // 2. Fill each row with default cells
      g[r] = new Array(cols);
      for (let c = 0; c < cols; c++) {
        g[r][c] = { mine: false, revealed: false, flagged: false, adjacent: 0 };
      }
    }
    return g;
  }

  /**
   * placeMinesAvoiding — Scatter `mines` mines into the grid, but never on the
   * `safe` cell (the player's first click) nor its immediate neighbours.
   *
   * Process:
   *   1. Build the set of forbidden coordinates (safe cell + its 8 neighbours)
   *   2. Shuffle a pool of legal coordinates
   *   3. Plant a mine in the first `mines` entries of the shuffled pool
   *   4. Recompute the `adjacent` count for every non-mine cell
   *
   * @param  safeR  row of the first-click safe cell
   * @param  safeC  col of the first-click safe cell
   */
  function placeMinesAvoiding(safeR, safeC) {
    // 1. Build forbidden set
    const forbidden = new Set();
    for (let dr = -1; dr <= 1; dr++) {
      for (let dc = -1; dc <= 1; dc++) {
        forbidden.add(`${safeR + dr},${safeC + dc}`);
      }
    }

    // 2. Build the legal pool and shuffle (Fisher–Yates)
    const pool = [];
    for (let r = 0; r < state.rows; r++) {
      for (let c = 0; c < state.cols; c++) {
        if (!forbidden.has(`${r},${c}`)) pool.push([r, c]);
      }
    }
    for (let i = pool.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [pool[i], pool[j]] = [pool[j], pool[i]];
    }

    // 3. Plant mines
    const toPlace = Math.min(state.mines, pool.length);
    for (let i = 0; i < toPlace; i++) {
      const [r, c] = pool[i];
      state.grid[r][c].mine = true;
    }

    // 4. Recompute adjacency counts
    for (let r = 0; r < state.rows; r++) {
      for (let c = 0; c < state.cols; c++) {
        if (state.grid[r][c].mine) continue;
        let n = 0;
        for (let dr = -1; dr <= 1; dr++) {
          for (let dc = -1; dc <= 1; dc++) {
            if (dr === 0 && dc === 0) continue;
            const nr = r + dr, nc = c + dc;
            if (nr >= 0 && nr < state.rows && nc >= 0 && nc < state.cols && state.grid[nr][nc].mine) n++;
          }
        }
        state.grid[r][c].adjacent = n;
      }
    }
  }

  /**
   * floodReveal — Reveal a cell and, if it has zero adjacent mines, cascade
   * out to all reachable zero-cells and their neighbouring number cells.
   *
   * Process:
   *   1. Iterative BFS from (r, c) using a queue
   *   2. Skip already-revealed or flagged cells
   *   3. Reveal each popped cell; award +10 score; if adjacent==0 push 8 neighbours
   *
   * @param  r  starting row
   * @param  c  starting col
   */
  function floodReveal(r, c) {
    // 1. BFS queue
    const queue = [[r, c]];
    while (queue.length) {
      const [cr, cc] = queue.shift();
      const cell = state.grid[cr][cc];
      // 2. Skip already-handled cells
      if (cell.revealed || cell.flagged) continue;
      // 3. Reveal, award score, and possibly cascade
      cell.revealed = true;
      state.revealedCount++;
      state.score += 10;
      if (cell.adjacent === 0 && !cell.mine) {
        for (let dr = -1; dr <= 1; dr++) {
          for (let dc = -1; dc <= 1; dc++) {
            if (dr === 0 && dc === 0) continue;
            const nr = cr + dr, nc = cc + dc;
            if (nr >= 0 && nr < state.rows && nc >= 0 && nc < state.cols) {
              queue.push([nr, nc]);
            }
          }
        }
      }
    }
  }

  /**
   * checkWin — Has every non-mine cell been revealed?
   * @returns true if the player has won
   */
  function checkWin() {
    const totalSafe = state.rows * state.cols - state.mines;
    return state.revealedCount >= totalSafe;
  }

  /**
   * handleLeftClick — Player left-clicked a cell.
   *
   * Process:
   *   1. Ignore if game over or cell flagged/already revealed
   *   2. If this is the very first click, generate mines avoiding it and start the timer
   *   3. If the clicked cell is a mine → lose (reveal all mines, stop timer)
   *   4. Otherwise flood-reveal from the cell (+10 per revealed cell)
   *   5. Check for win; if won: +50 per correctly-flagged mine + max(0,500-3*timer) bonus
   *
   * @param  r  row clicked
   * @param  c  col clicked
   */
  function handleLeftClick(r, c) {
    if (state.over) return;
    const cell = state.grid[r][c];
    // 1. Ignore flagged or already revealed
    if (cell.flagged || cell.revealed) return;

    // 2. First click: place mines & start timer
    if (!state.started) {
      placeMinesAvoiding(r, c);
      state.started = true;
      startTimer();
    }

    // 3. Mine hit → game over
    if (cell.mine) {
      cell.revealed = true;
      state.over = true;
      state.won = false;
      stopTimer();
      revealAllMines();
      render();
      showOverlay("💥 Boom! You hit a mine.", false);
      return;
    }

    // 4. Safe → cascade reveal
    floodReveal(r, c);

    // 5. Win check; compute bonuses before auto-flagging remaining mines
    if (checkWin()) {
      state.over = true;
      state.won = true;
      stopTimer();
      // 5a. +50 per mine the player correctly flagged (before auto-flag sweep)
      let correctFlags = 0;
      for (let rr = 0; rr < state.rows; rr++) {
        for (let cc = 0; cc < state.cols; cc++) {
          if (state.grid[rr][cc].mine && state.grid[rr][cc].flagged) correctFlags++;
        }
      }
      state.score += correctFlags * 50;
      // 5b. Time bonus: +max(0, 500-3*timer)
      state.score += Math.max(0, 500 - 3 * state.timer);
      // Auto-flag remaining mines for cosmetic win state
      for (let rr = 0; rr < state.rows; rr++) {
        for (let cc = 0; cc < state.cols; cc++) {
          if (state.grid[rr][cc].mine && !state.grid[rr][cc].flagged) {
            state.grid[rr][cc].flagged = true;
            state.flagsPlaced++;
          }
        }
      }
      render();
      showOverlay(`🎉 You cleared the field in ${state.timer}s!`, true);
      return;
    }

    render();
  }

  /**
   * handleRightClick — Player right-clicked: toggle a flag.
   *
   * Process:
   *   1. Ignore if game over or cell already revealed
   *   2. Toggle the flagged bit and update flag counter
   *
   * @param  r  row clicked
   * @param  c  col clicked
   */
  function handleRightClick(r, c) {
    if (state.over) return;
    const cell = state.grid[r][c];
    // 1. No flagging revealed cells
    if (cell.revealed) return;
    // 2. Toggle
    cell.flagged = !cell.flagged;
    state.flagsPlaced += cell.flagged ? 1 : -1;
    render();
  }

  function revealAllMines() {
    for (let r = 0; r < state.rows; r++) {
      for (let c = 0; c < state.cols; c++) {
        if (state.grid[r][c].mine) state.grid[r][c].revealed = true;
      }
    }
  }

  function startTimer() {
    stopTimer();
    state.timer = 0;
    updateTimerUI();
    state.timerHandle = setInterval(() => {
      state.timer++;
      if (state.timer > 999) state.timer = 999;
      updateTimerUI();
    }, 1000);
  }

  function stopTimer() {
    if (state.timerHandle != null) {
      clearInterval(state.timerHandle);
      state.timerHandle = null;
    }
  }

  function updateTimerUI() {
    document.getElementById("timer").textContent = String(state.timer).padStart(3, "0");
  }

  function updateMineCountUI() {
    const remaining = state.mines - state.flagsPlaced;
    document.getElementById("mine-count").textContent = String(remaining).padStart(3, "0");
  }

  function updateScoreUI() {
    document.getElementById("score-display").textContent = String(state.score).padStart(4, "0");
  }

  function showOverlay(msg, won) {
    const ov = document.getElementById("overlay");
    ov.querySelector(".overlay-msg").textContent = msg;
    document.getElementById("overlay-score").textContent = `Score: ${state.score}`;
    ov.classList.toggle("win", won);
    ov.classList.toggle("lose", !won);
    ov.classList.remove("hidden");
    document.getElementById("smiley").textContent = won ? "😎" : "😵";
  }

  function hideOverlay() {
    document.getElementById("overlay").classList.add("hidden");
    document.getElementById("smiley").textContent = "🙂";
  }

  /**
   * newGame — Reset state and rebuild the empty board for the current
   * difficulty. Mines are not placed until the first click.
   *
   * Process:
   *   1. Stop any running timer
   *   2. Read the selected difficulty from the dropdown
   *   3. Reset all state fields and allocate a fresh empty grid
   *   4. Update mine-count + timer UI, hide overlay, render the board
   */
  function newGame() {
    // 1. Stop any in-flight timer
    stopTimer();
    // 2. Read difficulty
    const diff = document.getElementById("difficulty").value;
    const cfg = DIFFICULTIES[diff] || DIFFICULTIES.beginner;
    // 3. Reset state
    state.rows = cfg.rows;
    state.cols = cfg.cols;
    state.mines = cfg.mines;
    state.grid = createEmptyGrid(state.rows, state.cols);
    state.started = false;
    state.over = false;
    state.won = false;
    state.flagsPlaced = 0;
    state.revealedCount = 0;
    state.timer = 0;
    state.score = 0;
    // 4. Refresh UI
    updateTimerUI();
    updateMineCountUI();
    updateScoreUI();
    hideOverlay();
    buildBoard();
    render();
  }

  function buildBoard() {
    const board = document.getElementById("board");
    board.innerHTML = "";
    board.style.gridTemplateColumns = `repeat(${state.cols}, 28px)`;
    for (let r = 0; r < state.rows; r++) {
      for (let c = 0; c < state.cols; c++) {
        const div = document.createElement("div");
        div.className = "cell";
        div.dataset.r = r;
        div.dataset.c = c;
        div.addEventListener("click", (e) => {
          e.preventDefault();
          handleLeftClick(r, c);
        });
        div.addEventListener("contextmenu", (e) => {
          e.preventDefault();
          handleRightClick(r, c);
        });
        board.appendChild(div);
      }
    }
  }

  function render() {
    const board = document.getElementById("board");
    const children = board.children;
    for (let r = 0; r < state.rows; r++) {
      for (let c = 0; c < state.cols; c++) {
        const cell = state.grid[r][c];
        const el = children[r * state.cols + c];
        el.classList.toggle("revealed", cell.revealed);
        el.classList.toggle("flagged", cell.flagged && !cell.revealed);
        el.classList.toggle("mine", cell.revealed && cell.mine);
        el.textContent = "";
        el.removeAttribute("data-n");
        if (cell.revealed) {
          if (cell.mine) {
            el.textContent = "💣";
          } else if (cell.adjacent > 0) {
            el.textContent = String(cell.adjacent);
            el.dataset.n = String(cell.adjacent);
          }
        } else if (cell.flagged) {
          el.textContent = "🚩";
        }
      }
    }
    updateMineCountUI();
    updateScoreUI();
  }

  // Wire up UI on DOM ready
  document.addEventListener("DOMContentLoaded", () => {
    document.getElementById("difficulty").addEventListener("change", newGame);
    document.getElementById("smiley").addEventListener("click", newGame);
    // Block the browser's contextmenu on the whole board area
    document.getElementById("board").addEventListener("contextmenu", (e) => e.preventDefault());
    newGame();
  });
})();
