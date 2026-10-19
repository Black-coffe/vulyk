---
paths:
  - ".claude/rules/**"
---

# Path-scoped rules

Rules here load only when work touches the paths they declare, which keeps the constitution lean.
`/vulyk-bootstrap` seeds rules for your stack; `/vulyk-evolve` proposes new ones from observed friction.

Convention: one file per area (`api.md`, `ui.md`, `infra.md`, `db.md`). Each opens with YAML frontmatter
whose `paths:` list names the globs it governs; a file without it loads into every session and every
agent. Then short imperative rules; `templates/rule-example.md` shows the shape. A rule earns its place
by being project-specific: if it would apply to any repository, it is too generic to live here.

The split: rules bound to files keep `paths:` and load on touch; rules bound to nothing go to `always.md`
(no frontmatter, at most 40 lines, capped by `tests/maintenance.test.sh`). A project rule about code or
process is a card in `docs/defects/`, delivered by the hook before a matching action, not a rules file.
