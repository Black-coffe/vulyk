# Workflows (experimental)

Claude Code's deterministic Workflows feature (`.claude/workflows/*.js`) is still stabilizing across
versions. VULYK's pipelines therefore ship as slash commands (/vulyk-plan -> /vulyk-build -> /vulyk-review),
which implement the same plan -> fan-out -> review shape on every Claude Code 2.x install.

`feature.workflow.example.js` sketches the intended deterministic equivalent. Treat it as a reference
shape, verify the API against your Claude Code version's docs before enabling, and expect to adapt it.
Tracking: see the Roadmap in the root README.
