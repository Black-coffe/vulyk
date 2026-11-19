---
story: tails-1115-15
status: done
returned: DONE
worker: worker-code
model: opus
wave: 7
blocked_by: []
narrow: true
---

# Repair round 2

## Goal
Make the asks and findings council round 2 left RED pass, and change nothing else.

## Requirements
> 10. Every fix that code can check gets a failing test with the original case and a neighbour form; all suites green.

## Findings
ASK 10: RED - every code-checkable fix has a failing test with a neighbour; suites green - run: grep -rn "disable-model-invocation" over every sh, py, js and yml file saw: no hit. The fix that /vulyk-update is owner-only is one frontmatter line in .claude/commands/vulyk-update.md and nothing checks it: dropping the line passes every gate. Sibling declarative fixes do have tests (action SHA pins, switchModelsOnFlag). Every other fix I sampled has the original case and a neighbour, and all 12 test runs above exited 0
1. tests/defects.test.sh:831 [regression] suite defects is red on the head (it sits outside the narrow round's steps 3 and 8, so the round's log does not show it): its five `human-check --commit` checks (:838-:845) must pass now that scripts/human-check.sh:166 refuses when the repo it runs in holds no `scripts/redact.sh`, since the fixture repo built at :822 holds none and runs `$SRC/scripts/human-check.sh`, so the call ends REFUSED, exit 1, with nothing committed - repro: `bash tests/defects.test.sh` -> five `::error::human-check --commit ...` lines, `defects.test.sh: FAILED`, exit 1; base: `git show 690d0ab9:scripts/human-check.sh` lines 165-173 take `else SAFE_NOTE="$NOTE"`, and `PART defects ok 187s` at docs/specs/tails-1115/council/round-1/suite.log:55

- Owner, 2026-11-17, after round 2 (the last under his rule for this repo): «Чиню сам, без раунда 3 (Рекомендую)»;
  the UNASKED items and the minors: «Всё на 0.55 (Рекомендую)». Test-only repair, so no red mark: (1) the
  `human-check --commit` fixture repo in `tests/defects.test.sh` gets a copy of `scripts/redact.sh` (the refusal
  without it is the fix of round 1, and stays); (2) one check in `tests/maintenance.test.sh` part upkeep that
  `.claude/commands/vulyk-update.md` carries `disable-model-invocation: true` in its frontmatter, with a neighbour:
  the same check fails on a copy without the line. Nothing else changes; the full suite runs once before merge.

## Acceptance criteria
- [ ] The class card under docs/defects/ (its quote, Never line or check:) is added or updated in the same commit as the fix.

## Files
- tests/defects.test.sh
- tests/maintenance.test.sh

## Implementation notes
- tests/defects.test.sh: the `human-check --commit` fixture repo gets `scripts/redact.sh` copied in before its first commit; the refusal in scripts/human-check.sh stays.
- tests/maintenance.test.sh part upkeep: `owner_only` reads the frontmatter only; checks /vulyk-update.md holds `disable-model-invocation: true`, and a copy with the line dropped fails it (neighbour).
- No docs/defects card edited: the card file is outside `## Files` and the Owner line says nothing else changes.

## Verification
`bash tests/defects.test.sh && bash tests/intake.test.sh`
`bash tests/maintenance.test.sh --part upkeep`
