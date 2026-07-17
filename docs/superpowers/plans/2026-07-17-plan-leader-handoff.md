# Plan-to-Leader Orchestration Handoff Implementation Plan

> **For agentic workers:** Hand this plan back to the agent-team **leader**, which slices it into sized rows in `.claude/team/tasks.md` and spawns devs in parallel via `.claude/bin/spawn-team.sh`. Do NOT self-dispatch subagents. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Require user approval of the plan, leader-created orchestration, and user-approved dev selection before spawning.

**Architecture:** Keep the existing file-driven leader architecture. Synchronize the contract in the root instructions, leader persona, vendored workflow docs, and user guide; add a shell contract test that checks the handoff markers and ordering.

**Tech Stack:** Markdown instructions and POSIX shell tests.

## Global Constraints

- The leader remains the only orchestration layer.
- Every `spawn-team.sh` call still requires at least two distinct devs.
- No `.env*` or secret files may be read or modified.
- Do not add runtime dependencies or a second orchestration mechanism.

---

### Task 1: Add the workflow contract test

**Files:**
- Create: `tests/test_plan_leader_handoff.sh`

**Interfaces:**
- Consumes: `AGENTS.md`, `CLAUDE.md`, `.claude/agents/leader.md`, `.claude/skills/writing-plans/SKILL.md`, `docs/USING-THE-TEAM.md`.
- Produces: exit 0 only when each document contains the required handoff markers and the leader guide orders dev approval before spawning.

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
required_files=(
  "$ROOT/AGENTS.md"
  "$ROOT/CLAUDE.md"
  "$ROOT/.claude/agents/leader.md"
  "$ROOT/.claude/skills/writing-plans/SKILL.md"
  "$ROOT/docs/USING-THE-TEAM.md"
)

for file in "${required_files[@]}"; do
  grep -Fq "plan approval" "$file"
  grep -Fq "dev roster approval" "$file"
done

leader="$ROOT/.claude/agents/leader.md"
plan_line=$(grep -nF "plan approval" "$leader" | head -n1 | cut -d: -f1)
roster_line=$(grep -nF "dev roster approval" "$leader" | head -n1 | cut -d: -f1)
spawn_line=$(grep -nF "spawn-team.sh" "$leader" | awk -F: -v r="$roster_line" '$1 > r { print $1; exit }')

test -n "$plan_line"
test -n "$roster_line"
test -n "$spawn_line"
test "$plan_line" -lt "$roster_line"
test "$roster_line" -lt "$spawn_line"

printf '%s\n' "plan-leader-handoff contract: PASS"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/test_plan_leader_handoff.sh`
Expected: FAIL because the current documents do not contain the exact `dev roster approval` contract.

### Task 2: Synchronize the leader handoff rules

**Files:**
- Modify: `AGENTS.md`
- Modify: `CLAUDE.md`
- Modify: `.claude/agents/leader.md`
- Modify: `.claude/skills/writing-plans/SKILL.md`
- Modify: `docs/USING-THE-TEAM.md`

**Interfaces:**
- Consumes: the approved design in `docs/superpowers/specs/2026-07-17-plan-leader-handoff-design.md`.
- Produces: one consistent protocol with explicit user gates and no automatic execution after plan approval.

- [ ] **Step 1: Add the protocol text**

Add the same ordered contract to each workflow document: plan approval first; then leader creates orchestrator/tasks; then the leader asks for dev roster approval; only then may `spawn-team.sh` run. State that missing/declined roster means wait, not automatic spawn or self-execution.

- [ ] **Step 2: Re-read all modified documents**

Run: `rg -n "plan approval|dev roster approval|spawn-team.sh|self-execut" AGENTS.md CLAUDE.md .claude/agents/leader.md .claude/skills/writing-plans/SKILL.md docs/USING-THE-TEAM.md`
Expected: every file contains the handoff contract, and leader spawning references occur after the roster-approval rule in the workflow section.

### Task 3: Verify the synchronized contract

**Files:**
- Test: `tests/test_plan_leader_handoff.sh`

**Interfaces:**
- Consumes: all Task 2 documents.
- Produces: a passing regression check for future workflow edits.

- [ ] **Step 1: Run the contract test**

Run: `bash tests/test_plan_leader_handoff.sh`
Expected: `plan-leader-handoff contract: PASS` and exit code 0.

- [ ] **Step 2: Check the final diff**

Run: `git diff --check`
Expected: no whitespace errors.

- [ ] **Step 3: Commit the implementation**

```bash
git add AGENTS.md CLAUDE.md .claude/agents/leader.md .claude/skills/writing-plans/SKILL.md docs/USING-THE-TEAM.md tests/test_plan_leader_handoff.sh
git commit -m "feat: gate plan execution on leader and dev approval"
```
