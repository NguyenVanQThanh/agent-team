# Serena Memory Maintenance

This project uses a hybrid memory boundary.

## Canonical ownership

- Durable team knowledge belongs in `.claude/memory/`.
- Serena memories contain only concise, project-local operational context.
- Do not copy architecture, bug, fix, feature, or team-decision notes into
  Serena memories.

## Serena memory style

- Keep each memory focused on one topic.
- Prefer links to canonical files over copied prose.
- Use `mem:` references when linking another Serena memory.
- Update a memory when commands, project structure, or workflow changes.
- Archive obsolete operational notes under `_archive/` rather than deleting
  history without review.

## Review boundary

Before writing durable knowledge, use the role and folder policy documented in
`.claude/memory/README.md` and `.claude/memory/_index.md`.
