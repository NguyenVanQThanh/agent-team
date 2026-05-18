# .claude/bin/env.sh — project-local env for the agent team.
# Sourced automatically by team scripts (_runner.sh, spawn-team.sh, team-doctor.sh).
# Edit values to fit your install; do NOT commit secrets here (commit safe).

# ---- Opus backing for dev5 ----
# Use Claude Code as the Opus engine (most users won't have a standalone `opus`).
# Set to a different binary if you have one.
: "${OPUS_BIN:=claude --model opus}"
: "${OPUS_FLAGS:=--dangerously-skip-permissions -p}"

# ---- Codex CLI (dev1, dev2, dev12, dev13) ----
# Codex CLI v0.130+ supports `exec` for non-interactive runs.
# Reasoning level ladder per dev (model gpt-5.5 picker shows: low / medium / high / xhigh):
#   dev12 = low       (smoke / lint / quick verify)        — fast, cheap
#   dev1  = medium    (general coder, refactor M/L)         — default workhorse
#   dev2  = high      (module planner, architecture scribe) — reasoning-heavy, low output
#   dev13 = xhigh     (senior + tournament partner w/ dev5) — hardest tasks
# If your Codex CLI rejects "xhigh", try "high" or check `codex --help` for the
# accepted values of -c model_reasoning_effort.
_CODEX_BASE='exec --skip-git-repo-check --dangerously-bypass-approvals-and-sandbox -c model="gpt-5.5"'

# Fallback (used if no per-dev override is set).
: "${CODEX_FLAGS:=$_CODEX_BASE -c model_reasoning_effort=\"medium\"}"

# Per-dev overrides (picked up by _runner.sh via CODEX_FLAGS_<DEV>).
: "${CODEX_FLAGS_DEV1:=$_CODEX_BASE -c model_reasoning_effort=\"medium\"}"
: "${CODEX_FLAGS_DEV2:=$_CODEX_BASE -c model_reasoning_effort=\"high\"}"
: "${CODEX_FLAGS_DEV12:=$_CODEX_BASE -c model_reasoning_effort=\"low\"}"
: "${CODEX_FLAGS_DEV13:=$_CODEX_BASE -c model_reasoning_effort=\"xhigh\"}"

# ---- DeepSeek CLI / TUI (dev3, dev4, dev10) ----
# `exec --auto` = agentic mode with write_file + exec_shell tools (v0.8.x+).
: "${DEEPSEEK_FLAGS:=exec --auto}"

# ---- Claude Haiku (dev6, dev7) ----
# Add --dangerously-skip-permissions manually if you want fully non-interactive mode.
: "${HAIKU_BIN:=claude --model haiku}"
: "${HAIKU_FLAGS:=-p}"

# ---- Claude Sonnet (dev8, dev9) ----
# Add --dangerously-skip-permissions manually if you want fully non-interactive mode.
: "${SONNET_BIN:=claude --model sonnet}"
: "${SONNET_FLAGS:=-p}"

# ---- Gemini CLI (dev11 — research pre-phase) ----
: "${GEMINI_BIN:=gemini}"
: "${GEMINI_FLAGS:=}"

# Export so child processes (CLIs) see them.
export OPUS_BIN OPUS_FLAGS
export CODEX_FLAGS CODEX_FLAGS_DEV1 CODEX_FLAGS_DEV2 CODEX_FLAGS_DEV12 CODEX_FLAGS_DEV13
export DEEPSEEK_FLAGS
export HAIKU_BIN HAIKU_FLAGS SONNET_BIN SONNET_FLAGS GEMINI_BIN GEMINI_FLAGS
