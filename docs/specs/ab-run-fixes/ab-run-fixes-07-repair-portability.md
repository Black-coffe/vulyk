---
story: ab-run-fixes-07
spec: ab-run-fixes
status: todo
returned:
tier: 3
worker: worker-code
model: opus
wave: 3
blocked_by: []
---

# cycle.sh: the portability gate green again (comments out of a `$( )`, the array idiom)

## Goal
Story 06 cannot close: `bash scripts/portability-check.sh` reports 3 hits in committed `scripts/cycle.sh`
(HEAD e1b2597), lines from stories 04 and 05. Make the gate green at the root, without loosening it.
Ruling: `docs/specs/ab-run-fixes/council/architect-06.md`, ADR-031.

## Requirements
1. `cycle.sh:3532` (story 05, `claim_leftover`): write the house idiom `for p in ${PP[@]+"${PP[@]}"}; do`.
2. `cycle.sh:3799` and `3818` (story 04, the NARROW block in `cmd_repair`) are symptoms, not the defect: the five
   comment lines inside the `findings="$( ... )"` body (about 3767-3768, 3773, 3775-3776) are read as code by the
   scanner; their apostrophes and `(judge's override)` leave the substitution open. Move those comments out of the
   `$( )` body to just above the line that opens `findings="$(`, with one lead-in line such as
   `# findings, in order: seat RED asks; anchored review findings; red gate parts; owner REJECTED`.
   Do not change lines 3799 or 3818, and add no `# portable:` bypass anywhere.
3. `docs/defects/shell-needs-gnu-or-bash4.md`: one How-to line: a comment inside a `$( )` body is code to the gate
   (and likely to bash 3.2); put the comment above the line that opens the substitution.

## Files
- scripts/cycle.sh
- docs/defects/shell-needs-gnu-or-bash4.md

## Non-goals
- No change to `scripts/portability-check.sh` (a `comment-in-subst` rule is a later follow-up, ADR-031).
- No change to story 06's files or its working-tree edits; no behaviour change in `claim_leftover` or `cmd_repair`.

## Map slice
`scripts/cycle.sh`: `claim_leftover` (around 3520-3540), `cmd_repair` NARROW block (around 3760-3830).

## Acceptance criteria
- `bash scripts/portability-check.sh` prints its ok line on the whole tree (`tests/maintenance.test.sh` runs it: `portability-check: the tree exits 0`).
- `claim_leftover`: a rename line still yields two paths; `cmd_repair` output unchanged (same story text).
- The card gains exactly one How-to line; its `check:` stays.

## Verification
`bash tests/maintenance.test.sh`
`bash tests/driver.test.sh`
`bash tests/council.test.sh --part verbs`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes

## Findings
