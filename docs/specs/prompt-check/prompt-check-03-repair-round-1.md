---
story: prompt-check-03
status: done
returned: DONE
worker: worker-code
model: opus
wave: 3
blocked_by: []
red: required
red_reason: ::error::prompt-check --touched: a ./-prefixed touched prompt still owns its finding (round 1 major 1)
red_verified_at: 2026-10-28T18:55:59Z 845025a31337a6b080dc33c5b3fe7289159c57ed78734e447fa55de40712973d
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

## Implementation notes
- Finding 1: `--touched` drops a leading `./` as a prefix (loop), never `lstrip("./")`; test: `--touched ./.claude/commands/vulyk-plan.md` exits 1.
- Plan delta (side-agent note): in a hive an AGENTS name without a file is a `warn` (upgrade keeps host deletions); test: a hive with `worker-test.md` removed exits 0 with the warn line. VULYK repo unchanged (the `nofile` case still exits 1).
- Round 1 minors left for the next circle (plan.md `## Plan deltas`).

## Verification
`bash tests/maintenance.test.sh`
`bash tests/cycle.test.sh`

## Red receipt
- command: bash tests/maintenance.test.sh
- exit: 1
- tests: 845025a31337a6b080dc33c5b3fe7289159c57ed78734e447fa55de40712973d (tests/cycle.test.sh, tests/maintenance.test.sh)
- impl: 50172b08b23fc2e8747aadc12095afb77480af1e5e3645b997693ae66cadf107
- stamped: 2026-10-28T18:55:59Z

```
        exit=0;
::error::prompt-check: a framework agent a hive deleted exits 0 (upgrade keeps host deletions) - expected 'exit=0;' in:
        prompt-check: error scripts/telemetry.sh:1: telemetry: AGENTS names worker-test, but .claude/agents/worker-test.md does not exist
        prompt-check: 1 error(s)
        exit=1;
::error::prompt-check: the hive deletion is a warn line - expected 'prompt-check: warn scripts/telemetry.sh:1: telemetry: AGENTS names worker-test' in:
        prompt-check: error scripts/telemetry.sh:1: telemetry: AGENTS names worker-test, but .claude/agents/worker-test.md does not exist
        prompt-check: 1 error(s)
        exit=1;
maintenance.test.sh: 205 checks, 3 failed
```
