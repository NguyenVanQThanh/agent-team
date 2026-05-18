import { useState } from "react";

const CHOICES = ["rock", "paper", "scissors"];

const WINNING_MATCHUPS = {
  rock: "scissors",
  paper: "rock",
  scissors: "paper",
};

const INITIAL_SCORES = {
  player: 0,
  computer: 0,
  draws: 0,
};

function getChoiceLabel(choice) {
  return choice.charAt(0).toUpperCase() + choice.slice(1);
}

function getComputerChoice() {
  return CHOICES[Math.floor(Math.random() * CHOICES.length)];
}

function getRoundResult(playerChoice, computerChoice) {
  if (playerChoice === computerChoice) {
    return "Draw";
  }

  return WINNING_MATCHUPS[playerChoice] === computerChoice
    ? "You win"
    : "Computer wins";
}

export default function RockPaperScissors() {
  const [scores, setScores] = useState(INITIAL_SCORES);
  const [lastRound, setLastRound] = useState(null);

  function handleChoice(playerChoice) {
    const computerChoice = getComputerChoice();
    const result = getRoundResult(playerChoice, computerChoice);

    setLastRound({
      playerChoice,
      computerChoice,
      result,
    });

    setScores((currentScores) => {
      if (result === "Draw") {
        return {
          ...currentScores,
          draws: currentScores.draws + 1,
        };
      }

      if (result === "You win") {
        return {
          ...currentScores,
          player: currentScores.player + 1,
        };
      }

      return {
        ...currentScores,
        computer: currentScores.computer + 1,
      };
    });
  }

  function restartGame() {
    setScores(INITIAL_SCORES);
    setLastRound(null);
  }

  return (
    <section style={styles.container} aria-label="Rock Paper Scissors">
      <div style={styles.status} aria-live="polite">
        {lastRound ? lastRound.result : "Choose your play"}
      </div>

      <div style={styles.choices} aria-label="Player choices">
        {CHOICES.map((choice) => (
          <button
            key={choice}
            type="button"
            style={styles.choice}
            onClick={() => handleChoice(choice)}
          >
            {getChoiceLabel(choice)}
          </button>
        ))}
      </div>

      <div style={styles.scoreboard} aria-live="polite">
        <div>Player: {scores.player}</div>
        <div>Computer: {scores.computer}</div>
        <div>Draws: {scores.draws}</div>
      </div>

      {lastRound ? (
        <div style={styles.round} aria-live="polite">
          <div>You picked: {getChoiceLabel(lastRound.playerChoice)}</div>
          <div>Computer picked: {getChoiceLabel(lastRound.computerChoice)}</div>
        </div>
      ) : null}

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
  choices: {
    display: "flex",
    flexWrap: "wrap",
    gap: "8px",
    justifyContent: "center",
  },
  choice: {
    border: "1px solid #222",
    background: "#fff",
    color: "#111",
    cursor: "pointer",
    font: "inherit",
    fontWeight: 700,
    padding: "10px 14px",
  },
  scoreboard: {
    display: "flex",
    flexWrap: "wrap",
    gap: "12px",
    justifyContent: "center",
    fontWeight: 700,
  },
  round: {
    display: "grid",
    gap: "4px",
    justifyItems: "center",
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
