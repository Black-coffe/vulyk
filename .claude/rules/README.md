# Path-scoped rules

Rules here load only when work touches their declared paths - this keeps CLAUDE.md lean and context cheap.
`/vulyk-bootstrap` seeds rules for your stack; `/vulyk-evolve` proposes new ones from observed friction.

Convention: one file per area (`api.md`, `ui.md`, `infra.md`, `db.md`), each starting with a `paths:` line
declaring what it governs, then short imperative rules. A rule earns its place by being project-specific:
if it would apply to any random repository, it is too generic to live here.
