# .claude/bin/env.sh — project-local env for the agent team.
# Sourced automatically by team scripts (_runner.sh, spawn-team.sh, team-doctor.sh).
# Edit values to fit your install; do NOT commit secrets here (commit safe).

# ---- Per-machine secrets / overrides (gitignored, NOT committed) ----
# Put real API keys (e.g. DEEPSEEK_API_KEY) and any local overrides in
# env.local.sh next to this file. It is sourced FIRST so its values win over
# the `: "${VAR:=default}"` fallbacks below. See env.local.sh.example.
_env_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
[ -f "$_env_dir/env.local.sh" ] && . "$_env_dir/env.local.sh"
unset _env_dir

# ---- Opus backing for dev5 (implementer) + dev14 (reviewer/security gate) ----
# Use Claude Code as the Opus engine (most users won't have a standalone `opus`).
# Set to a different binary if you have one.
: "${OPUS_BIN:=claude --model opus}"
: "${OPUS_FLAGS:=--dangerously-skip-permissions -p}"

# ---- Codex CLI (dev1, dev2, dev12, dev13, dev15, dev16) ----
# All Codex teammates use medium reasoning. Luna is the S/M lane; Terra is the
# M/L lane. M is intentionally an overlap so the leader can route simple local
# work to Luna and multi-file or architectural work to Terra.
_CODEX_BASE='exec --skip-git-repo-check --dangerously-bypass-approvals-and-sandbox'
_CODEX_LUNA="$_CODEX_BASE -c model=\"gpt-5.6-luna\" -c model_reasoning_effort=\"medium\""
_CODEX_TERRA="$_CODEX_BASE -c model=\"gpt-5.6-terra\" -c model_reasoning_effort=\"medium\""

: "${CODEX_FLAGS:=$_CODEX_LUNA}"
: "${CODEX_FLAGS_DEV1:=$_CODEX_LUNA}"
: "${CODEX_FLAGS_DEV2:=$_CODEX_TERRA}"
: "${CODEX_FLAGS_DEV12:=$_CODEX_LUNA}"
: "${CODEX_FLAGS_DEV13:=$_CODEX_TERRA}"
: "${CODEX_FLAGS_DEV15:=$_CODEX_LUNA}"
: "${CODEX_FLAGS_DEV16:=$_CODEX_TERRA}"

# ---- CodeWhale / DeepSeek TUI (dev3, dev4, dev10) ----
# Empty DEEPSEEK_BIN enables automatic resolution: codewhale, then deepseek-tui.
# Set DEEPSEEK_BIN locally to override the detected command, including its flags.
: "${DEEPSEEK_BIN:=}"
# `exec --auto` = agentic mode with write_file + exec_shell tools (v0.8.x+).
: "${DEEPSEEK_FLAGS:=exec --auto}"

# ---- Claude Haiku (dev6, dev7) ----
# NOTE: --dangerously-skip-permissions is REQUIRED for headless runs.
# Without it, every file write triggers an interactive permission prompt
# that hangs in non-interactive mode and the CLI silently exits with no
# work done (see B-001 2026-05-20).
: "${HAIKU_BIN:=claude --model haiku}"
: "${HAIKU_FLAGS:=--dangerously-skip-permissions -p}"

# ---- Claude Sonnet (dev8, dev9) ----
# NOTE: --dangerously-skip-permissions is REQUIRED for headless runs.
# Without it, every file write triggers an interactive permission prompt
# that hangs in non-interactive mode and the CLI silently exits with no
# work done (see B-001 2026-05-20).
: "${SONNET_BIN:=claude --model sonnet}"
: "${SONNET_FLAGS:=--dangerously-skip-permissions -p}"

# ---- Gemini CLI (dev11 — research pre-phase) ----
: "${GEMINI_BIN:=gemini}"
: "${GEMINI_FLAGS:=}"

# Export so child processes (CLIs) see them.
export OPUS_BIN OPUS_FLAGS
export CODEX_FLAGS CODEX_FLAGS_DEV1 CODEX_FLAGS_DEV2 CODEX_FLAGS_DEV12 CODEX_FLAGS_DEV13 CODEX_FLAGS_DEV15 CODEX_FLAGS_DEV16
export DEEPSEEK_BIN DEEPSEEK_FLAGS
export HAIKU_BIN HAIKU_FLAGS SONNET_BIN SONNET_FLAGS GEMINI_BIN GEMINI_FLAGS

# ---- Local tool bin: RTK (tier-0 command-output compression) ----
# Make rtk visible to every team CLI regardless of the inherited PATH.
# rtk.exe is installed to ~/.local/bin (see README "Command-Output Compression").
export PATH="$HOME/.local/bin:$PATH"

# ---- Per-dev size brackets (used by claim-task.sh in pool mode) ----
# Each dev only claims tasks whose size= matches one of its bracket sizes.
# Mirrors the routing table in .claude/agents/leader.md — keep in sync.
declare -A DEV_SIZES=(
  [dev1]="M L"     [dev2]="M L"
  [dev3]="S M"     [dev4]="S M"
  [dev5]="XL"
  [dev6]="M"       [dev7]="M"
  [dev8]="L"       [dev9]="L"
  [dev10]="M"      [dev11]="M"
  [dev12]="S M"    [dev13]="M L"
  [dev15]="S M"    [dev16]="M L"
  [dev14]="L XL"
)
export DEV_SIZES
