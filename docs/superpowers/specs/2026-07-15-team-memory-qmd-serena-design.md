# Team Memory: QMD + Serena Design

**Status:** proposed

## Goal

Add semantic retrieval and code-aware navigation to the existing agent-team memory workflow while preserving `.claude/memory/` as the only durable memory store. RTK remains the sole token-optimisation layer; Headroom remains excluded.

## Decisions

- `.claude/memory/` remains the source of truth for architecture, features, bugs, fixes, and team decisions.
- QMD is a local, rebuildable semantic index over approved vault content. It never replaces or writes canonical notes.
- Serena is an MCP service for code-symbol retrieval, reference discovery, and semantic edits. Its own memory facility is disabled or restricted to disposable project-local operational hints; it is not a second decision store.
- RTK remains responsible for shell-command output compaction. No API proxy or Headroom component is reintroduced.
- The existing leader, task table, three-phase lifecycle, and dev10 memory-scribe role stay authoritative. No external orchestration is added.

## Scope

### In scope

- Install/bootstrap QMD in a reproducible way on supported developer machines.
- Register QMD as an MCP server where the agent client supports MCP.
- Index only `.claude/memory/` and explicitly selected team documentation; exclude runs, logs, worktrees, secrets, and generated files.
- Add a small retrieval contract for agents: query first, read canonical Markdown only when needed, and fall back to `rg` if QMD is unavailable.
- Add Serena as an optional, project-scoped MCP server for symbol-level code retrieval and refactoring.
- Define lifecycle ownership and guardrails that prevent duplicate or conflicting memory writes.
- Add preflight, smoke-test, observability, and rollback procedures.

### Out of scope

- Migrating to a separate Obsidian Mind vault.
- Syncing personal notes, meetings, people, performance records, Slack, or calendar data.
- Replacing dev10 or the existing `.claude/memory/` schemas and write permissions.
- Enabling Headroom, changing LLM API endpoints, or adding a proxy.
- Automatic use of Serena memory as a durable knowledge base.

## Target Architecture

```text
Canonical Markdown vault (.claude/memory/)
           │
           ├── QMD index (local, disposable) ──> QMD MCP query/get
           │                                      │
           │                                      └── targeted context to agents
           │
           └── dev10 / authorised roles write and curate notes

Repository source ──> Serena MCP ──> symbol search / references / semantic edits

Shell commands ──> RTK ──> compact command results
```

## Components and Responsibilities

### Vault and lifecycle

The current `.claude/memory/` hierarchy and YAML frontmatter conventions remain unchanged. The leader creates feature records, authorised senior roles record architectural/fix/bug notes, and dev10 performs post-phase synthesis. Session startup may retrieve a small, relevant set of vault excerpts, but must never load the whole vault.

### QMD

QMD indexes a named collection rooted at `.claude/memory/`. The index is machine-local and excluded from Git. QMD is updated after the post-phase memory write and before a session asks a memory question. Retrieval returns a short ranked list; agents must then open the canonical note(s) by path. If QMD cannot start, the workflow continues with `rg` over the vault and no memory-writing behavior changes.

### Serena

Serena is started per repository/project using its Codex/agent-compatible MCP context. It is used for code understanding and safe symbol-aware edits, not for policy or organizational recall. The server is optional: workflows fall back to `rg`, built-in file tools, and existing editor commands when Serena or a language server is unavailable. Serena-specific memory is disabled by default to prevent two durable memory stores.

### RTK

RTK continues to compact outputs from shell commands. Commands requiring complete raw evidence (for example, failed tests, diagnostics, migration output, or security investigation) must retain RTK's full-output retrieval path. No QMD or Serena action is routed through RTK as a substitute for semantic retrieval.

## Data and Retrieval Rules

1. Agents retrieve by semantic query before scanning the entire vault.
2. Search results are pointers, not source material: canonical Markdown is the authority.
3. Only authorised roles write canonical memory notes under the existing policy.
4. Every new durable note must use existing frontmatter, IDs, and Obsidian links.
5. QMD index paths and cache data stay outside the committed vault.
6. Serena can inspect repository code but cannot become the persistent store for decisions, bugs, or fixes.

## Configuration Strategy

Configuration must be checked into the repository only when it contains no credentials and works from an absolute or deterministically derived workspace path. A bootstrap script discovers QMD and Serena executables, creates/updates local index data, validates MCP configuration, and reports actionable fallbacks. Machine-specific locations belong in ignored local configuration files, never in tracked secret files.

Agent integrations are staged in this order:

1. Codex: QMD and Serena MCP entries plus existing RTK instructions.
2. Claude: equivalent MCP entries/hook-compatible retrieval guidance.
3. Gemini: QMD/Serena only where its MCP support is verified; otherwise document the safe fallback.
4. DeepSeek and other workers: retain vault + `rg` access until their MCP behavior is verified.

## Error Handling and Rollback

- Missing QMD, failed embedding download, corrupt index, or unavailable MCP server: log a concise warning and use `rg`; do not block a team run.
- Missing Serena or unsupported language server: use normal file/search tools; do not block a team run.
- QMD returns irrelevant context: read the named canonical note only after validation; use `rg` when ranking is inadequate.
- Any regression in startup time, token use, or task success: disable the relevant MCP entry or bootstrap flag while retaining the vault untouched.
- Full rollback removes only QMD/Serena configuration and local indexes. No canonical Markdown memory is deleted or transformed.

## Verification and Success Criteria

The implementation is accepted only if all conditions hold:

1. A fresh supported Windows environment can bootstrap QMD and create the named collection without credentials.
2. A semantic query for a known architecture/bug decision returns the correct vault note among the top results; the fallback `rg` command finds the same note when QMD is disabled.
3. The QMD index excludes `.claude/team/runs/`, worktrees, and forbidden environment files.
4. Serena can activate the repository, locate a known symbol and its references, and complete an editor-safe smoke action or cleanly report its fallback.
5. A normal `spawn-team.sh` flow still completes with RTK enabled and without Headroom configuration or API proxy variables.
6. No tracked configuration stores credentials, local embedding models, SQLite indexes, or generated runtime data.
7. Measurements record QMD query latency, retrieval relevance on a fixed fixture set, Serena activation latency, and RTK gain before/after; no unsupported token-saving claim is made for QMD or Serena.

## Implementation Phases

1. Baseline and fixtures: document current memory flow, select non-sensitive fixture notes and establish RTK/team-run baseline.
2. QMD: add bootstrap, collection configuration, ignore rules, MCP registration, fallback guidance, and tests.
3. Serena: add project-scoped configuration, safe activation checks, tool guidance, and fallback tests.
4. Lifecycle integration: update leader/dev guidance so post-phase writes trigger index refresh and session startup performs bounded retrieval.
5. Validation and rollout: test each supported CLI, document operational steps, measure results, and provide a one-command rollback.

## Non-Goals and Future Decisions

This design intentionally does not import full Obsidian Mind workflows. Personal productivity features can be evaluated later in a separate vault, with a defined one-way export contract if team-relevant decisions need to enter `.claude/memory/`. Semantic search within Serena's own memory should be reconsidered only when Serena ships a stable implementation and a clear no-duplication policy can be preserved.
