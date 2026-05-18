#!/usr/bin/env bash
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
         .claude/bin/team-tui.sh \
         .claude/team/tasks.md \
         AGENTS.md \
         CLAUDE.md; do
  if [[ -f "$REPO/$f" ]]; then
    ok "$f"
  else
    bad "$f (missing)"
  fi
done

for d in .claude/team/personas .claude/team/status .claude/team/runs \
         .claude/memory/architecture .claude/memory/features \
         .claude/memory/fixes .claude/memory/bugs; do
  if [[ -d "$REPO/$d" ]]; then
    ok "$d/"
  else
    bad "$d/ (missing)"
  fi
done

# Personas
for p in dev1 dev2 dev3 dev4 dev5; do
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
    v="$($bin $version_flag 2>&1 | head -1 | tr -d '\r')" || v="(version check failed)"
    ok "$label: ${bin} found  ${BLUE}[${v}]${NC}"
    return 0
  else
    bad "$label: ${bin} NOT on PATH"
    return 1
  fi
}

header "CLI binaries"

codex_ok=0; deepseek_ok=0; opus_ok=0

check_cli "Codex   (dev1/dev2)" codex --version    && codex_ok=1
check_cli "DeepSeek(dev3/dev4)" deepseek --version && deepseek_ok=1

# Opus may be `opus` or "claude --model opus"
OPUS_BIN="${OPUS_BIN:-opus}"
opus_first="${OPUS_BIN%% *}"
if command -v "$opus_first" >/dev/null 2>&1; then
  v="$($opus_first --version 2>&1 | head -1 | tr -d '\r')" || v="?"
  ok "Opus    (dev5)      $OPUS_BIN found  ${BLUE}[${v}]${NC}"
  opus_ok=1
else
  bad "Opus    (dev5)      $opus_first NOT on PATH"
  note "set OPUS_BIN env, e.g.: export OPUS_BIN=\"claude --model opus\""
fi

# ------- auth / API keys -------

header "Authentication"

# DeepSeek: DEEPSEEK_API_KEY or ~/.deepseek/config.toml
if [[ -n "${DEEPSEEK_API_KEY:-}" ]]; then
  ok "DEEPSEEK_API_KEY set in env (${#DEEPSEEK_API_KEY} chars)"
elif [[ -f "$HOME/.deepseek/config.toml" ]] && grep -q "api_key" "$HOME/.deepseek/config.toml" 2>/dev/null; then
  ok "DeepSeek config at ~/.deepseek/config.toml has api_key"
else
  warn "no DEEPSEEK_API_KEY and no api_key in ~/.deepseek/config.toml"
  note "run:  deepseek-tui login    or    export DEEPSEEK_API_KEY=..."
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

  probe() {
    local label="$1" cmd="$2"
    local out ec
    out=$(timeout 15 bash -c "$cmd" 2>&1)
    ec=$?
    if (( ec == 0 )); then
      ok "$label responded"
      note "first line: $(echo "$out" | head -1 | cut -c1-80)"
    else
      bad "$label failed (exit $ec)"
      note "stderr: $(echo "$out" | tail -1 | cut -c1-100)"
    fi
  }

  (( codex_ok ))    && probe "codex"    "codex exec --skip-git-repo-check 'say hello in 5 words' 2>&1 || codex -p 'say hello in 5 words' 2>&1 || codex 'say hello in 5 words' 2>&1" \
                   || note "skip codex probe (binary missing)"
  (( deepseek_ok )) && probe "deepseek" "deepseek -p 'say hello in 5 words' 2>&1 || deepseek 'say hello in 5 words' 2>&1" \
                   || note "skip deepseek probe (binary missing)"
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
