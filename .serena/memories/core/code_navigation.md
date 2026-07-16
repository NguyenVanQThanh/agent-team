# Code Navigation

The repository is primarily a shell-and-Markdown orchestration project.

- Runner entry points live under `.claude/bin/`.
- Team roles and task protocol live under `.claude/team/`.
- Durable memory lives under `.claude/memory/`.
- Serena project configuration lives in `.serena/project.yml`.
- Smoke tests live under `tests/`.

When a change crosses runner, task, or memory boundaries, inspect the related
README and project rules before editing. Preserve the separation between
runtime artifacts and committed configuration.
