# .claude/bin/env.sh — project-local env for the agent team.
# Sourced automatically by team scripts (_runner.sh, spawn-team.sh, team-doctor.sh).
# Edit values to fit your install; do NOT commit secrets here (commit safe).

# ---- Opus backing for dev5 ----
# Use Claude Code as the Opus engine (most users won't have a standalone `opus`).
# Set to a different binary if you have one.
: "${OPUS_BIN:=claude --model opus}"
: "${OPUS_FLAGS:=--dangerously-skip-permissions -p}"

# ---- Codex CLI (dev1, dev2) ----
# Default: no extra flags. Codex CLI v0.130+ supports `exec` for non-interactive.
# If your Codex CLI needs a flag to skip approval prompts, set it here.
: "${CODEX_FLAGS:=exec --skip-git-repo-check --dangerously-bypass-approvals-and-sandbox}"

# ---- DeepSeek CLI / TUI (dev3, dev4) ----
# `deepseek` (the npm wrapper) accepts -p for one-shot and --yolo for auto-approve.
: "${DEEPSEEK_FLAGS:=-p --yolo}"

# Export so child processes (CLIs) see them.
export OPUS_BIN OPUS_FLAGS CODEX_FLAGS DEEPSEEK_FLAGS
