# Agent Workflow

The leader plans work, writes `.claude/team/tasks.md`, and launches workers
through `.claude/bin/spawn-team.sh`. Workers report through
`.claude/team/status/` and run artifacts are stored under
`.claude/team/runs/`.

The canonical team memory is `.claude/memory/`. Serena must not become a
second store for architecture, features, bugs, fixes, or team decisions.
Use the existing role-based write policy before changing durable notes.

Serena is used for symbol-level code navigation, references, diagnostics, and
safe semantic edits. Built-in CLI tools remain appropriate for ordinary shell
commands and small text operations.
