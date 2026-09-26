---
paths:
  - ".claude/rules/**"
---

# Path-scoped rules

Rules here load only when work touches the paths they declare, which keeps the constitution lean.
`/vulyk-bootstrap` seeds rules for your stack; `/vulyk-evolve` proposes new ones from observed friction.

Convention: one file per area (`api.md`, `ui.md`, `infra.md`, `db.md`). Each opens with YAML frontmatter
whose `paths:` list names the globs it governs; a file without it loads into every session and every
agent. Then short imperative rules. A rule earns its place by being project-specific: if it would apply
to any repository, it is too generic to live here.
