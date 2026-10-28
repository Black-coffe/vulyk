---
story: prompt-check-03
status: todo
returned:
worker: worker-code
model: opus
wave: 3
blocked_by: []
red: required
red_reason:
---

# Repair round 1

## Goal
Make the asks and findings council round 1 left RED pass, and change nothing else.

## Requirements
> 5. Линтер работает в CI и close-story.

## Findings
1. scripts/prompt-check.py:108 [ask 5] a `--touched` path written with a `./` prefix must still own its findings: `lstrip("./")` strips the leading dot of `./.claude/...` too, so a story whose `## Files` lists `./.claude/commands/x.md` (a form close-story's own trigger at scripts/cycle.sh:2339 accepts) sees its drift as `warn` and closes with exit 0 - repro in a fixture copy with a seeded `--no-such-flag` in `.claude/commands/vulyk-plan.md`: `bash scripts/prompt-check.sh --touched .claude/commands/vulyk-plan.md` exits 1, `bash scripts/prompt-check.sh --touched ./.claude/commands/vulyk-plan.md` prints the same finding as `warn` and exits 0

## Files
- scripts/prompt-check.sh
- scripts/prompt-check.py
- tests/maintenance.test.sh
- docs/architecture.md
- scripts/cycle.sh
- tests/cycle.test.sh
- .github/workflows/ci.yml
- docs/command-reference.md
- CHANGELOG.md

## Verification
`bash tests/maintenance.test.sh`
`bash tests/cycle.test.sh`
