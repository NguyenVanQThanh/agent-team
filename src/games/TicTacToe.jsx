import { useMemo, useState } from "react";

const WINNING_LINES = [
  [0, 1, 2],
  [3, 4, 5],
  [6, 7, 8],
  [0, 3, 6],
  [1, 4, 7],
  [2, 5, 8],
  [0, 4, 8],
  [2, 4, 6],
];

const EMPTY_BOARD = Array(9).fill(null);

function getWinner(board) {
  for (const [a, b, c] of WINNING_LINES) {
    if (board[a] && board[a] === board[b] && board[a] === board[c]) {
      return board[a];
    }
  }

  return null;
}

export default function TicTacToe() {
  const [board, setBoard] = useState(EMPTY_BOARD);
  const [nextPlayer, setNextPlayer] = useState("X");

  const winner = useMemo(() => getWinner(board), [board]);
  const isDraw = !winner && board.every(Boolean);
  const status = winner
    ? `Winner: ${winner}`
    : isDraw
      ? "Draw"
      : `Next: ${nextPlayer}`;

  function handleSquareClick(index) {
    if (board[index] || winner || isDraw) {
      return;
    }

    setBoard((currentBoard) => {
      const nextBoard = [...currentBoard];
      nextBoard[index] = nextPlayer;
      return nextBoard;
    });
    setNextPlayer((currentPlayer) => (currentPlayer === "X" ? "O" : "X"));
  }

  function restartGame() {
    setBoard(EMPTY_BOARD);
    setNextPlayer("X");
  }

  return (
    <section style={styles.container} aria-label="Tic Tac Toe">
      <div style={styles.status} aria-live="polite">
        {status}
      </div>

      <div style={styles.board} role="grid" aria-label="Tic Tac Toe board">
        {board.map((value, index) => (
          <button
            key={index}
            type="button"
            style={styles.square}
            onClick={() => handleSquareClick(index)}
            aria-label={`Square ${index + 1}${value ? `, ${value}` : ""}`}
          >
            {value}
          </button>
        ))}
      </div>

      <button type="button" style={styles.restart} onClick={restartGame}>
        Restart
      </button>
    </section>
  );
}

const styles = {
  container: {
    display: "grid",
    gap: "12px",
    justifyItems: "center",
    fontFamily: "system-ui, sans-serif",
  },
  status: {
    fontSize: "1.25rem",
    fontWeight: 700,
  },
  board: {
    display: "grid",
    gridTemplateColumns: "repeat(3, 72px)",
    gridTemplateRows: "repeat(3, 72px)",
    gap: "6px",
  },
  square: {
    width: "72px",
    height: "72px",
    border: "1px solid #222",
    background: "#fff",
    color: "#111",
    cursor: "pointer",
    fontSize: "2rem",
    fontWeight: 700,
    lineHeight: 1,
  },
  restart: {
    border: "1px solid #222",
    background: "#f5f5f5",
    color: "#111",
    cursor: "pointer",
    font: "inherit",
    padding: "8px 14px",
  },
};
