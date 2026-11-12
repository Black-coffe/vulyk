---
story: busy-no-transcripts-02
status: todo
returned:
worker: worker-code
model: opus
wave: 2
blocked_by: []
narrow: true
red: required
red_reason:
---

# Repair round 1

## Goal
Make the asks and findings council round 1 left RED pass, and change nothing else.

## Requirements
> 1. `hives-behind.sh --busy <hive>`: a hive with no transcript folder under any root is `idle`, with a reason that says no session has run there, as long as at least one hive in the registry resolves to a transcript folder; when none does (or there is no registry), it stays `unknown` (exit 1). DRIVER, fresh-transcript and subfolder checks are unchanged. Tests cover both cases.

## Findings
1. scripts/hives-behind.sh:151 [ask 1] `naming_proven` must count only a registry line that names a hive path as proof: a line whose path is empty (spaces or a tab only, or ` | hold 2026-11-19 x`) gives an empty slug, `[ -d "$r/projects/" ]` is true for every root, and a folderless hive reads `idle` (exit 0) although no registered hive resolves to a transcript folder, where the ask says it stays `unknown` (exit 1) - repro: `R=$(mktemp -d); mkdir -p $R/r/projects $R/h; printf '%s\n   \n' $R/h > $R/reg; VULYK_HIVES_FILE=$R/reg VULYK_SESSION_ROOTS=$R/r bash scripts/hives-behind.sh --busy $R/h; echo $?` prints `idle no session transcript folder for ... (no Claude Code session has run there)` and `0` (the same registry without the blank-looking line prints `unknown ...` and `1`; the base 40d1f374 prints `unknown` for both); the tests need a case of this shape next to the two they have.

## Acceptance criteria
- [ ] The class card under docs/defects/ (its quote, Never line or check:) is added or updated in the same commit as the fix.

## Files
- 1.
- docs/defects/*

## Verification
`bash tests/maintenance.test.sh`
