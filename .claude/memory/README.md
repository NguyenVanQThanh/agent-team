# .claude/memory/ — Obsidian-style memory vault

Long-lived knowledge for the agent team. Pair this folder with the per-run
shared task list at `.claude/team/tasks.md`:

- **tasks.md** = what we're doing now, ephemeral.
- **memory/** = what we've learned, durable.

## Opening as an Obsidian vault

Open `.claude/memory/` as a vault in Obsidian. Wikilinks (`[[bugs/B-007]]`)
will resolve. Graph view groups by folder.

## Folder layout

```
.claude/memory/
  _index.md           # root Map of Content — links to everything
  _templates/         # frontmatter templates for each note type
  architecture/       # ADRs, module plans, service contracts  (A-NNN)
  features/           # feature briefs and status              (F-NNN)
  fixes/              # fix write-ups linked to bug notes      (X-NNN)
  bugs/               # bug reports — symptoms, repro, severity (B-NNN)
  user-prefs/         # leader notes on user preferences       [gitignored]
```

## Note conventions

See `CLAUDE.md` "Obsidian memory vault" section for full rules:

- Note types: `architecture` / `features` / `fixes` / `bugs`.
- ID prefixes: `A-` / `F-` / `X-` / `B-`. Filenames: `<id>-<kebab-slug>.md`.
- Frontmatter is required — copy from `_templates/<type>.md`.
- Cross-link with wikilinks: `[[architecture/A-001-event-bus]]`, `[[bugs/B-007]]`.

## Write access

| Who    | Can write to                              |
|--------|-------------------------------------------|
| leader | `features/`, `_index.md`, `user-prefs/`   |
| dev2   | `architecture/`                           |
| dev5   | `architecture/`, `fixes/`, `bugs/`        |
| dev10  | `bugs/`, `fixes/`, `features/`            |
| others | read-only                                 |

dev10 (DeepSeek, post-phase) is the primary memory scribe after each main batch.
dev5 (Opus) writes directly only on XL tasks where it authors the fix itself.

## Per-section MOCs

Each folder has a `_moc.md` that lists notes in that section. The writing dev
is responsible for adding a row to the MOC when creating a note. If MOC tables
drift from reality, the leader can regenerate them by scanning for files matching
the type prefix and rewriting the table.

## What is gitignored

Vault note files (`A-*.md`, `F-*.md`, `X-*.md`, `B-*.md`) are **gitignored** —
they are project-specific content that stays local to each deployment. Only the
structural files are committed to the template branch:

- `_index.md`, `_templates/`, `_moc.md` files, `.gitkeep` markers, `README.md`

`user-prefs/` is also gitignored (personal, never commit).
