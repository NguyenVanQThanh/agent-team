/**
 * @file        fruitbox.js
 * @description Vanilla-JS FruitBox game. A grid of numbered apples (1-9). The
 *              player drags a rectangle over apples; if the apples covered by
 *              the rectangle sum to exactly 10, those apples are removed and
 *              the player scores one point per apple captured. Includes a
 *              countdown timer, score, remaining-apple counter, and a
 *              "Light Colors" palette toggle.
 *
 * @createdAt   2026-05-20
 * @createdBy   leader
 * @updatedAt   2026-05-20
 * @updatedBy   dev8
 */

(function () {
  "use strict";

  const ROWS = 10;
  const COLS = 17;
  const CELL = 50;             // px, kept in sync with .apple width/height in CSS
  const GAME_SECONDS = 60;     // 1-minute round

  const state = {
    grid: [],                  // grid[r][c] = value 1..9, or 0 if cleared
    score: 0,
    remaining: ROWS * COLS,
    timeLeft: GAME_SECONDS,
    timerHandle: null,
    over: false,
    drag: null                 // {startX, startY, curX, curY} in board-local coords, or null
  };

  /**
   * makeBoard — Populate the grid with random apple values 1-9.
   *
   * Process:
   *   1. Allocate a fresh ROWS×COLS array
   *   2. Fill each slot with Math.floor(Math.random()*9)+1
   */
  function makeBoard() {
    // 1. Allocate
    state.grid = new Array(ROWS);
    for (let r = 0; r < ROWS; r++) {
      // 2. Fill with random 1..9
      state.grid[r] = new Array(COLS);
      for (let c = 0; c < COLS; c++) {
        state.grid[r][c] = Math.floor(Math.random() * 9) + 1;
      }
    }
    state.remaining = ROWS * COLS;
  }

  function buildDOM() {
    const board = document.getElementById("board");
    board.innerHTML = "";
    board.style.gridTemplateColumns = `repeat(${COLS}, ${CELL}px)`;
    board.style.gridTemplateRows = `repeat(${ROWS}, ${CELL}px)`;
    for (let r = 0; r < ROWS; r++) {
      for (let c = 0; c < COLS; c++) {
        const div = document.createElement("div");
        div.className = "apple";
        div.dataset.r = r;
        div.dataset.c = c;
        board.appendChild(div);
      }
    }
    // Re-create rubberband after innerHTML wipe; must be absolute so it sits
    // above the grid cells without consuming a grid slot.
    const rb = document.createElement("div");
    rb.id = "rubberband";
    board.appendChild(rb);
  }

  function render() {
    const board = document.getElementById("board");
    const children = board.children;
    for (let r = 0; r < ROWS; r++) {
      for (let c = 0; c < COLS; c++) {
        const v = state.grid[r][c];
        const el = children[r * COLS + c];
        if (v === 0) {
          el.classList.add("empty");
          el.textContent = "";
        } else {
          el.classList.remove("empty");
          el.textContent = String(v);
        }
      }
    }
    document.getElementById("score").textContent = String(state.score);
    document.getElementById("remaining").textContent = String(state.remaining);
    document.getElementById("timer").textContent = formatTime(state.timeLeft);
  }

  function formatTime(secs) {
    const m = Math.floor(secs / 60);
    const s = secs % 60;
    return `${m}:${String(s).padStart(2, "0")}`;
  }

  /**
   * cellsInsideRect — Return all (r,c) cells whose center lies inside the
   * given selection rectangle (coordinates are relative to the board).
   *
   * Process:
   *   1. Normalize rect so x1<=x2 and y1<=y2
   *   2. Convert rect bounds to a row/col range using the cell size
   *   3. Walk that sub-grid; include any non-empty cell whose center is in the rect
   *
   * @param  rect  {x1,y1,x2,y2} in board-local pixels
   * @returns      Array of [r,c]
   */
  function cellsInsideRect(rect) {
    // 1. Normalize
    const x1 = Math.min(rect.x1, rect.x2);
    const x2 = Math.max(rect.x1, rect.x2);
    const y1 = Math.min(rect.y1, rect.y2);
    const y2 = Math.max(rect.y1, rect.y2);

    // 2. Row/col bounds
    const cStart = Math.max(0, Math.floor(x1 / CELL));
    const cEnd = Math.min(COLS - 1, Math.floor(x2 / CELL));
    const rStart = Math.max(0, Math.floor(y1 / CELL));
    const rEnd = Math.min(ROWS - 1, Math.floor(y2 / CELL));

    // 3. Test cell centers
    const hits = [];
    for (let r = rStart; r <= rEnd; r++) {
      for (let c = cStart; c <= cEnd; c++) {
        if (state.grid[r][c] === 0) continue;
        const cx = c * CELL + CELL / 2;
        const cy = r * CELL + CELL / 2;
        if (cx >= x1 && cx <= x2 && cy >= y1 && cy <= y2) {
          hits.push([r, c]);
        }
      }
    }
    return hits;
  }

  function updateRubberband(rect) {
    const rb = document.getElementById("rubberband");
    if (!rect) { rb.style.display = "none"; return; }
    const x1 = Math.min(rect.x1, rect.x2);
    const x2 = Math.max(rect.x1, rect.x2);
    const y1 = Math.min(rect.y1, rect.y2);
    const y2 = Math.max(rect.y1, rect.y2);
    rb.style.display = "block";
    rb.style.left = x1 + "px";
    rb.style.top = y1 + "px";
    rb.style.width = (x2 - x1) + "px";
    rb.style.height = (y2 - y1) + "px";
  }

  function highlightCells(cells) {
    document.querySelectorAll(".apple.selected").forEach(e => e.classList.remove("selected"));
    const board = document.getElementById("board");
    for (const [r, c] of cells) {
      const el = board.children[r * COLS + c];
      el.classList.add("selected");
    }
  }

  /**
   * commitSelection — Finalize the drag: if the selected apples sum to 10,
   * clear them and award one point per apple. Otherwise do nothing.
   *
   * Process:
   *   1. Compute the cells under the current rectangle
   *   2. Sum their values
   *   3. If sum == 10: zero out those cells, bump score, bump remaining counter
   *   4. Otherwise: leave the grid untouched
   *   5. If the board is fully cleared, refill it for endless play
   *
   * @param  rect  current drag rectangle
   */
  function commitSelection(rect) {
    // 1. Collect cells
    const cells = cellsInsideRect(rect);
    // 2. Sum
    let sum = 0;
    for (const [r, c] of cells) sum += state.grid[r][c];
    // 3 / 4. Score if sum is exactly 10
    if (sum === 10 && cells.length > 0) {
      for (const [r, c] of cells) {
        state.grid[r][c] = 0;
        state.remaining--;
      }
      state.score += cells.length;
      flashScore(cells.length);
    }
    // 5. Auto-refill once empty so the player can keep going
    if (state.remaining === 0) {
      makeBoard();
    }
    render();
  }

  function flashScore(delta) {
    const el = document.getElementById("score");
    el.classList.remove("bump");
    // Force reflow to restart animation
    void el.offsetWidth;
    el.classList.add("bump");
    el.title = `+${delta} apples`;
  }

  function startTimer() {
    stopTimer();
    state.timeLeft = GAME_SECONDS;
    state.timerHandle = setInterval(() => {
      state.timeLeft--;
      if (state.timeLeft <= 0) {
        state.timeLeft = 0;
        stopTimer();
        endGame();
      }
      render();
    }, 1000);
  }

  function stopTimer() {
    if (state.timerHandle != null) {
      clearInterval(state.timerHandle);
      state.timerHandle = null;
    }
  }

  function endGame() {
    state.over = true;
    const ov = document.getElementById("overlay");
    ov.querySelector(".overlay-msg").textContent = `⏰ Time! Final score: ${state.score}`;
    ov.classList.remove("hidden");
  }

  /**
   * newGame — Reset everything and start a fresh round.
   *
   * Process:
   *   1. Stop any in-flight timer
   *   2. Reset score, fill board, hide overlay
   *   3. Start the countdown timer
   *   4. Render
   */
  function newGame() {
    // 1. Stop timer
    stopTimer();
    // 2. Reset state
    state.score = 0;
    state.over = false;
    makeBoard();
    document.getElementById("overlay").classList.add("hidden");
    // 3. Timer
    startTimer();
    // 4. Render
    render();
  }

  function attachDrag() {
    const board = document.getElementById("board");

    function boardLocal(ev) {
      const rect = board.getBoundingClientRect();
      const cx = ev.touches ? ev.touches[0].clientX : ev.clientX;
      const cy = ev.touches ? ev.touches[0].clientY : ev.clientY;
      return { x: cx - rect.left, y: cy - rect.top };
    }

    function onDown(ev) {
      if (state.over) return;
      ev.preventDefault();
      const p = boardLocal(ev);
      state.drag = { x1: p.x, y1: p.y, x2: p.x, y2: p.y };
      updateRubberband(state.drag);
      highlightCells([]);
    }
    function onMove(ev) {
      if (!state.drag) return;
      ev.preventDefault();
      const p = boardLocal(ev);
      state.drag.x2 = p.x;
      state.drag.y2 = p.y;
      updateRubberband(state.drag);
      highlightCells(cellsInsideRect(state.drag));
    }
    function onUp(ev) {
      if (!state.drag) return;
      ev.preventDefault();
      commitSelection(state.drag);
      state.drag = null;
      updateRubberband(null);
      highlightCells([]);
    }

    board.addEventListener("mousedown", onDown);
    window.addEventListener("mousemove", onMove);
    window.addEventListener("mouseup", onUp);
    board.addEventListener("touchstart", onDown, { passive: false });
    window.addEventListener("touchmove", onMove, { passive: false });
    window.addEventListener("touchend", onUp);
  }

  document.addEventListener("DOMContentLoaded", () => {
    buildDOM();
    attachDrag();

    document.getElementById("new-game").addEventListener("click", newGame);

    document.getElementById("light-colors").addEventListener("change", (e) => {
      document.body.classList.toggle("light-colors", e.target.checked);
    });

    newGame();
  });
})();
