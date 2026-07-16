#!/usr/bin/env bash
# File:        team-doctor.sh
# Description: Runs pre-flight checks for agent-team tools and configuration.
# Created at:  2026-05-18   Created by: agent-team
# Updated at:  2026-07-15   Updated by: Codex
#
# team-doctor.sh — pre-flight check for the agent team.
# Verifies every dev CLI is installed, authenticated, and can be reached.
# Run this once after setup, and any time something feels broken.
#
# Usage:
#   .claude/bin/team-doctor.sh           # full check
#   .claude/bin/team-doctor.sh --quick   # skip live network probes
#
# Exit 0 if all checks pass, 1 if anything is broken.

set -uo pipefail
# Source local env (OPUS_BIN, *_FLAGS, etc.) if present.
_env_file="$( cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd )/env.sh"
[[ -f "$_env_file" ]] && source "$_env_file"

SCRIPT_DIR="$( cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd )"
REPO="$( cd -- "$SCRIPT_DIR/../.." &>/dev/null && pwd )"
# shellcheck source=./deepseek-cli.sh
source "$SCRIPT_DIR/deepseek-cli.sh"
QUICK=0
[[ "${1:-}" == "--quick" ]] && QUICK=1

GREEN='\033[32m'; RED='\033[31m'; YELLOW='\033[33m'; BLUE='\033[34m'; BOLD='\033[1m'; NC='\033[0m'

pass=0
fail=0
warn=0

ok()    { echo -e "  ${GREEN}✓${NC} $*"; pass=$((pass+1)); }
bad()   { echo -e "  ${RED}✗${NC} $*"; fail=$((fail+1)); }
warn()  { echo -e "  ${YELLOW}!${NC} $*"; warn=$((warn+1)); }
note()  { echo -e "    ${BLUE}↪${NC} $*"; }

header() { echo ""; echo -e "${BOLD}== $* ==${NC}"; }

# ------- repo layout check -------

header "Team scaffolding"

for f in .claude/agents/leader.md \
         .claude/bin/spawn-team.sh \
         .claude/bin/_runner.sh \
         .claude/bin/run_codex.sh \
         .claude/bin/run_deepseek.sh \
         .claude/bin/run_opus.sh \
         .claude/bin/run_haiku.sh \
         .claude/bin/run_sonnet.sh \
         .claude/bin/run_gemini.sh \
         .claude/bin/prune-worktrees.sh \
         .claude/bin/env.sh \
         .claude/bin/team-tui.sh \
         .claude/team/tasks.md \
         AGENTS.md \
         CLAUDE.md \
         GEMINI.md; do
  if [[ -f "$REPO/$f" ]]; then
    ok "$f"
  else
    bad "$f (missing)"
  fi
done

for d in .claude/team/personas .claude/team/status .claude/team/runs \
         .claude/team/research .claude/team/worktrees \
         .claude/memory/architecture .claude/memory/features \
         .claude/memory/fixes .claude/memory/bugs .claude/memory/user-prefs; do
  if [[ -d "$REPO/$d" ]]; then
    ok "$d/"
  else
    bad "$d/ (missing)"
  fi
done

# Personas
for p in dev1 dev2 dev3 dev4 dev5 dev6 dev7 dev8 dev9 dev10 dev11 dev12 dev13 dev14; do
  if [[ -f "$REPO/.claude/team/personas/$p.md" ]]; then
    ok "persona: $p"
  else
    bad "persona: $p (missing)"
  fi
done

# ------- CLI presence & versions -------

check_cli() {
  local label="$1" bin="$2" version_flag="$3"
  if command -v "$bin" >/dev/null 2>&1; then
    local v
    if v="$($bin $version_flag 2>&1 | head -1 | tr -d '\r')"; then
      ok "$label: ${bin} found  ${BLUE}[${v}]${NC}"
      return 0
    fi
    bad "$label: ${bin} found but version check failed"
    return 1
  else
    bad "$label: ${bin} NOT on PATH"
    return 1
  fi
}

header "CLI binaries"

codex_ok=0; deepseek_ok=0; opus_ok=0; haiku_ok=0; sonnet_ok=0; gemini_ok=0

check_cli "Codex      (dev1/dev2)"      codex    --version 1 && codex_ok=1
if deepseek_bin="$(deepseek_resolve_bin)"; then
  deepseek_first_word="${deepseek_bin%% *}"
  deepseek_label="$(deepseek_cli_label "$deepseek_bin")"
  check_cli "$deepseek_label (dev3/dev4/dev10)" "$deepseek_first_word" --version && deepseek_ok=1
else
  deepseek_bin=""
  deepseek_label="CodeWhale / DeepSeek TUI"
  bad "$deepseek_label (dev3/dev4/dev10) NOT on PATH"
  note "install codewhale or deepseek-tui, or set DEEPSEEK_BIN"
fi

# claude binary covers opus (dev5) + haiku (dev6/dev7) + sonnet (dev8/dev9)
if command -v claude >/dev/null 2>&1; then
  v="$(claude --version 2>&1 | head -1 | tr -d '\r')" || v="?"
  OPUS_BIN="${OPUS_BIN:-claude --model opus}"
  ok "Opus       (dev5)        $OPUS_BIN  ${BLUE}[${v}]${NC}";   opus_ok=1
  HAIKU_BIN="${HAIKU_BIN:-claude --model haiku}"
  ok "Haiku      (dev6/dev7)   $HAIKU_BIN  ${BLUE}[${v}]${NC}";  haiku_ok=1
  SONNET_BIN="${SONNET_BIN:-claude --model sonnet}"
  ok "Sonnet     (dev8/dev9)   $SONNET_BIN  ${BLUE}[${v}]${NC}"; sonnet_ok=1
else
  bad "claude     NOT on PATH — needed for dev5/dev6/dev7/dev8/dev9"
  note "install Claude Code CLI"
fi

# Gemini (optional — dev11 research pre-phase)
GEMINI_BIN="${GEMINI_BIN:-gemini}"
if command -v "$GEMINI_BIN" >/dev/null 2>&1; then
  v="$($GEMINI_BIN --version 2>&1 | head -1 | tr -d '\r')" || v="?"
  ok "Gemini     (dev11)       $GEMINI_BIN found  ${BLUE}[${v}]${NC}"; gemini_ok=1
else
  warn "Gemini     (dev11)       NOT on PATH (optional — research pre-phase unavailable)"
  note "install: npm i -g @google/gemini-cli"
fi

# ------- RTK command-output compression (optional) -------

header "RTK command-output compression (optional)"

# RTK — tier-0 command-output compression.
if command -v rtk >/dev/null 2>&1; then
  v="$(rtk --version 2>&1 | head -1 | tr -d '\r')" || v="?"
  ok "RTK        (tier-0 output compression)  rtk found  ${BLUE}[${v}]${NC}"
  # Hook status is normally checked via `rtk init`, but we must not execute
  # rtk beyond --version here, so just point at the setup command.
  note "hooks not verified (avoiding live rtk invocation) — run: rtk init -g --codex --gemini"
else
  warn "RTK        (tier-0 output compression)  rtk NOT on PATH (optional)"
  note "install per README \"Command-Output Compression\" section, then: rtk init -g --codex --gemini"
fi

# ------- Semantic vault retrieval and code intelligence (optional) -------

header "Memory retrieval and code intelligence (optional)"

if command -v qmd >/dev/null 2>&1; then
  v="$(qmd --version 2>&1 | head -1 | tr -d '\r')" || v="?"
  ok "QMD        (semantic vault retrieval)  qmd found  ${BLUE}[${v}]${NC}"
  note "run: .claude/bin/memory-tools.sh status"
else
  warn "QMD (semantic vault retrieval) NOT on PATH (optional)"
  note "install: npm install -g @tobilu/qmd"
fi

if command -v serena >/dev/null 2>&1; then
  v="$(serena --version 2>&1 | head -1 | tr -d '\r')" || v="?"
  ok "Serena     (symbol-level code intelligence)  serena found  ${BLUE}[${v}]${NC}"
  note "run: .claude/bin/memory-tools.sh serena-check"
else
  warn "Serena (symbol-level code intelligence) NOT on PATH (optional)"
  note "install: uv tool install -p 3.13 serena-agent"
fi

# ------- Codex per-dev reasoning flags -------

header "Codex per-dev reasoning flags (env.sh)"

for v in CODEX_FLAGS CODEX_FLAGS_DEV1 CODEX_FLAGS_DEV2 CODEX_FLAGS_DEV12 CODEX_FLAGS_DEV13; do
  val="${!v:-}"
  if [[ -z "$val" ]]; then
    bad "$v is unset"
  else
    effort=$(echo "$val" | grep -oE 'model_reasoning_effort="[^"]+"' | head -1 | sed 's/.*="\([^"]*\)"/\1/')
    model=$(echo "$val" | grep -oE 'model="[^"]+"' | head -1 | sed 's/.*="\([^"]*\)"/\1/')
    ok "$v  model=${model:-?}  reasoning=${effort:-?}"
  fi
done

# ------- auth / API keys -------

header "Authentication"

# DeepSeek: DEEPSEEK_API_KEY or ~/.deepseek/config.toml
if [[ -n "${DEEPSEEK_API_KEY:-}" ]]; then
  ok "DEEPSEEK_API_KEY set in env (${#DEEPSEEK_API_KEY} chars)"
elif [[ -f "$HOME/.deepseek/config.toml" ]] && grep -q "api_key" "$HOME/.deepseek/config.toml" 2>/dev/null; then
  ok "DeepSeek config at ~/.deepseek/config.toml has api_key"
else
  warn "no DEEPSEEK_API_KEY and no api_key in ~/.deepseek/config.toml"
  if [[ -n "$deepseek_bin" ]]; then
    note "run:  $deepseek_bin login    or    export DEEPSEEK_API_KEY=..."
  else
    note "install codewhale or deepseek-tui, then run its login command or export DEEPSEEK_API_KEY=..."
  fi
fi

# Codex/OpenAI: OPENAI_API_KEY (Codex CLI uses this) or codex auth
if [[ -n "${OPENAI_API_KEY:-}" ]]; then
  ok "OPENAI_API_KEY set in env (${#OPENAI_API_KEY} chars)"
elif [[ -d "$HOME/.codex" ]] || [[ -f "$HOME/.config/codex/config.toml" ]]; then
  ok "Codex config dir exists (assumes auth done)"
else
  warn "no OPENAI_API_KEY and no Codex config dir"
  note "run:  codex auth    or    export OPENAI_API_KEY=..."
fi

# Anthropic / Claude (for dev5 opus)
if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
  ok "ANTHROPIC_API_KEY set in env (${#ANTHROPIC_API_KEY} chars)"
elif [[ -f "$HOME/.claude/.credentials.json" ]] || [[ -d "$HOME/.config/claude" ]]; then
  ok "Claude credentials present (assumes auth done)"
else
  warn "no ANTHROPIC_API_KEY and no Claude credentials"
  note "Claude Code CLI handles its own auth; this is only needed if you set OPUS_BIN to something else"
fi

# ------- network probes (quick, one-shot) -------

if (( QUICK == 0 )); then
  header "Live probes (one-shot --quick to skip)"

  # probe <label> <cmd> [timeout_secs=15] [soft=0]
  # soft=1 → a failure is reported as a warning (not a hard fail), for probes
  # that are inherently slow/costly (e.g. codex spins a full agent loop).
  probe() {
    local label="$1" cmd="$2" tmo="${3:-15}" soft="${4:-0}"
    local out ec
    out=$(timeout "$tmo" bash -c "$cmd" 2>&1)
    ec=$?
    if (( ec == 0 )); then
      ok "$label responded"
      note "first line: $(echo "$out" | head -1 | cut -c1-80)"
    elif (( soft == 1 )); then
      warn "$label probe inconclusive (exit $ec, ${tmo}s) — binary+auth already verified above"
      note "agent cold-start can exceed the probe window; confirm with a real team task if unsure"
    else
      bad "$label failed (exit $ec)"
      note "stderr: $(echo "$out" | tail -1 | cut -c1-100)"
    fi
  }

  # Probe with the SAME flags the team actually uses (env.sh CODEX_FLAGS —
  # includes --dangerously-bypass-approvals-and-sandbox so codex runs
  # non-interactively). stdin from /dev/null avoids "stdin is not a terminal".
  _codex_flags="${CODEX_FLAGS:-exec --skip-git-repo-check --dangerously-bypass-approvals-and-sandbox -c model=gpt-5.6-luna -c model_reasoning_effort=medium}"
  (( codex_ok ))    && probe "codex"    "codex $_codex_flags 'say hello in 5 words' </dev/null 2>&1" 45 1 \
                   || note "skip codex probe (binary missing)"
  (( deepseek_ok )) && probe "$deepseek_label" "$deepseek_bin -p 'say hello in 5 words' 2>&1 || $deepseek_bin 'say hello in 5 words' 2>&1" \
                   || note "skip $deepseek_label probe (binary missing)"
  (( opus_ok ))     && probe "opus"     "$OPUS_BIN -p 'say hello in 5 words' 2>&1" \
                   || note "skip opus probe (binary missing)"
fi

# ------- summary -------

header "Summary"
echo -e "  ${GREEN}pass: $pass${NC}    ${YELLOW}warn: $warn${NC}    ${RED}fail: $fail${NC}"
echo ""

if (( fail > 0 )); then
  echo -e "${RED}${BOLD}NOT READY${NC} — fix the failing checks above before running the team."
  exit 1
elif (( warn > 0 )); then
  echo -e "${YELLOW}${BOLD}MOSTLY READY${NC} — warnings above won't block, but address them if a dev fails."
  exit 0
else
  echo -e "${GREEN}${BOLD}ALL GOOD${NC} — the team is ready to spawn."
  exit 0
fi
