# .claude/memory/ — Obsidian-style memory vault

Long-lived knowledge for the agent team. Pair this folder with the per-run
shared task list at `.claude/team/tasks.md`:

- **tasks.md** = what we're doing now, ephemeral.
- **memory/** = what we've learned, durable.

## Opening as an Obsidian vault

Open `.claude/memory/` as a vault in Obsidian. Wikilinks (`[[bugs/B-007]]`)
will resolve. Graph view groups by folder.

## Conventions

See `CLAUDE.md` "Obsidian memory vault" section for full rules:

- Note types: architecture / features / fixes / bugs.
- ID prefixes: `A-` / `F-` / `X-` / `B-`.
- Filename: `<id>-<kebab-slug>.md`.
- Frontmatter is required — copy from `_templates/<type>.md`.
- Write access: leader, dev2, dev5. Others read-only.

## Per-section MOCs

Each folder has a `_moc.md` that lists notes in that section. Update its table
when you add a note (or run the maintenance script, see below).

## Maintenance

If MOC tables drift from reality, the leader can regenerate them by scanning
the folder for files matching the type's prefix and rewriting the table.
There's no automation yet — it's a manual chore for the leader during
verification.
