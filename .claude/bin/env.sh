# .claude/bin/env.sh — project-local env for the agent team.
# Sourced automatically by team scripts (_runner.sh, spawn-team.sh, team-doctor.sh).
# Edit values to fit your install; do NOT commit secrets here (commit safe).

# ---- 9router gateway (OPTIONAL) -------------------------------------------
# Khi USE_9ROUTER=1, mọi CLI con trỏ base-url về 9router proxy thay vì gọi
# thẳng provider. Lợi ích: RTK -20..40% token + fallback tầng khi hết quota.
# Mặc định USE_9ROUTER=0 → hành vi y hệt trước (không cần 9router cài sẵn).
#
# Kill switch: đặt USE_9ROUTER=0 (hoặc bỏ export) để quay lại gọi thẳng.
# Key: để ở .claude/bin/env.local.sh (gitignored), KHÔNG commit vào đây.
# Gemini (dev11) KHÔNG route qua 9router (rủi ro ban account free-tier).
#
# Dùng 127.0.0.1, KHÔNG dùng localhost (tránh lỗi resolve IPv6 trên một số OS).
: "${USE_9ROUTER:=0}"
: "${NINEROUTER_HOST:=http://127.0.0.1:20128}"
: "${NINEROUTER_KEY:=}"

if [ "${USE_9ROUTER:-0}" = "1" ]; then
  # Claude variants (dev5/6/7/8/9/14)
  : "${ANTHROPIC_BASE_URL:=$NINEROUTER_HOST/v1}"
  : "${ANTHROPIC_API_KEY:=$NINEROUTER_KEY}"
  # Codex / OpenAI (dev1/2/12/13)
  : "${OPENAI_BASE_URL:=$NINEROUTER_HOST/v1}"
  : "${OPENAI_API_KEY:=$NINEROUTER_KEY}"
  # DeepSeek OpenAI-compatible (dev3/4/10) — tên biến theo CLI version bạn dùng
  : "${DEEPSEEK_BASE_URL:=$NINEROUTER_HOST/v1}"
  : "${DEEPSEEK_API_KEY:=$NINEROUTER_KEY}"
  export ANTHROPIC_BASE_URL ANTHROPIC_API_KEY \
         OPENAI_BASE_URL    OPENAI_API_KEY    \
         DEEPSEEK_BASE_URL  DEEPSEEK_API_KEY
fi
# ---------------------------------------------------------------------------

# Source machine-local overrides (secrets, USE_9ROUTER, NINEROUTER_KEY…).
# File gitignored — tạo lần đầu: cp .claude/bin/env.local.sh.example .claude/bin/env.local.sh
_local_env="$( cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd )/env.local.sh"
[ -f "$_local_env" ] && source "$_local_env"

# ---- Opus backing for dev5 (implementer) + dev14 (reviewer/security gate) ----
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
export CODEX_FLAGS CODEX_FLAGS_DEV1 CODEX_FLAGS_DEV2 CODEX_FLAGS_DEV12 CODEX_FLAGS_DEV13
export DEEPSEEK_FLAGS
export HAIKU_BIN HAIKU_FLAGS SONNET_BIN SONNET_FLAGS GEMINI_BIN GEMINI_FLAGS

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
  [dev12]="S M"    [dev13]="L XL"
  [dev14]="L XL"
)
export DEV_SIZES
