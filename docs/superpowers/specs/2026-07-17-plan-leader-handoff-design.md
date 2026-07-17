# Plan-to-Leader Orchestration Handoff

## Goal

Make every plan-driven task stop at an explicit orchestration gate: after the user approves the plan, the plan is handed to the agent-team leader; the leader creates the orchestrator/task breakdown and asks the user which devs to spawn before any dev is launched.

## Current context

The repository already identifies the leader as the single orchestration layer and the vendored `writing-plans` skill says that plans are handed to the leader. The missing behavior is an explicit, user-visible gate that prevents plan execution or spawning before leader handoff and dev selection.

## Design

1. Update the shared workflow contract in `AGENTS.md`, `CLAUDE.md`, `.claude/agents/leader.md`, and `docs/USING-THE-TEAM.md`.
2. Make the handoff protocol explicit and ordered: plan → user plan approval → leader orchestrator → user dev-selection approval → `spawn-team.sh`.
3. Preserve existing routing rules, the minimum-two-dev rule, self-handle rules, and the leader's authority to slice tasks. A user may select named devs; if no list is supplied, the leader proposes a roster and waits.
4. Add a shell contract test that verifies the required handoff language and ordering in the workflow documents. This is documentation/config behavior, so no production runtime code or dependencies are introduced.

## Acceptance criteria

- No plan-driven task is described as self-executing after plan approval.
- The leader is explicitly responsible for converting the plan into orchestrator/tasks.
- The leader must ask for and receive the user's dev roster approval before spawning.
- A declined or missing roster does not trigger an automatic spawn or leader self-execution.
- Existing team constraints remain documented and the contract test passes.

## Alternatives considered

- **Only update `writing-plans`:** small diff, but leader/docs can still instruct an older flow. Rejected because the contract would remain inconsistent.
- **Add an executable queue/approval service:** stronger enforcement, but unnecessary for this repository's file-driven workflow and adds runtime complexity. Rejected.
- **Synchronize the written workflow contract:** recommended; it matches the existing architecture and can be checked without adding infrastructure.
