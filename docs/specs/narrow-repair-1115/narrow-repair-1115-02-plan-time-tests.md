---
story: narrow-repair-1115-02
spec: narrow-repair-1115
status: done
returned: DONE
tier: 3
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: a test that mentions a story file joins its lists
red_verified_at: 2026-11-15T18:38:42Z a24d758acf547a4513d3a968dd5840a550f9526db8bb15f728ad53de049bce82
---

# Plan time: the tests that mention a story's files join its lists

## Goal
One command, run by `/vulyk-plan` before the plan is committed, adds to every story the test files that mention its
`## Files` and a row that runs each of them, and refuses to pass while a listed test has no row.

## Requirements
> 5. At plan time the tests that mention a story's files are added to its lists automatically, so a story's own rows cover its files.
> 7. Every rule above has a failing test with the original case (the audit-fixes-1113 repair) and a neighbour form.

## Files
- scripts/symbol-map.sh
- scripts/symbol-map.py
- tests/symbol-map.test.sh
- .claude/commands/vulyk-plan.md
- .claude/agents/queen-planner.md

## Non-goals
- No new script file and no new `## Commands` row: the mode lives in `symbol-map.sh`, its cases in
  `tests/symbol-map.test.sh`.
- Existing output is byte-identical: `--exact`, `--story`, `--scope`, the section cap of 5 and the 1536-byte cap
  (story 01 and the workers read them). The new mode has its own, uncapped listing.
- Do not make `wave-check.sh` write anything; it stays report-only.
- Do not guess a part: a parted suite is a `pick` line for the planner, never an invented `--part`.
- Do not touch `scripts/cycle.sh`.

## Map slice
`memory/map/scripts-checks.md` "Entry points" (`symbol-map.sh`, `wave-check.sh`), "Tests";
`memory/map/commands.md` "`/vulyk-plan`"; `memory/map/agents-and-commands.md` "queen-planner".

## Acceptance criteria
- [ ] Contract T1 of plan.md: `bash scripts/symbol-map.sh --fill-tests <spec-dir>` reads every `status: todo` story
      that is not a repair story. For each non-test path in `## Files`, every test file of the map's `tests` section
      that mentions it as an `exact` hit is appended to `## Files` when absent; `textual` hits are never added
      (owner 2026-11-15: «Утверждаю все три, тесты exact (Рекомендую)»).
- [ ] For each test file in a story's `## Files` with no `## Verification` line naming it: a non-`round-only`
      `## Commands` cell that names the file and has no placeholder is appended as a row; a cell with a placeholder
      prints `symbol-map: <story>: pick a row for <test> (<cell>)`.
- [ ] Exit 0 only when every listed test of every story has a row; exit 1 with the `pick` lines otherwise; exit 2 on
      usage or no Python. A second run on a filled spec changes no byte.
- [ ] Frontmatter, the other sections and the order of existing lines are untouched; the constitution is found as
      `cycle.sh` finds it (`CLAUDE.vulyk.md`, else `CLAUDE.md`).
- [ ] Original case: a story naming a script whose behaviour a test in another suite mentions (the audit-fixes-1113
      shape: story 03's file, a pin in a suite the story did not name) gets that test file and its row.
- [ ] Neighbour forms: a mention in a parted suite gives the `pick` line and exit 1; a glob line in `## Files`; a
      story that already lists the test.
- [ ] `/vulyk-plan` step 7 runs the mode before `wave-check.sh` and `trace-check.sh` and settles every `pick` line
      and every new same-wave overlap before the plan commit. `queen-planner.md` says the Queen's step adds every
      mentioning test, so two stories whose files share a test do not share a wave.
- [ ] Notes end with one `CHANGELOG:` line.

## Verification
`bash tests/symbol-map.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each -->
- scripts/symbol-map.py: `--fill-tests <spec-dir>` (fill_tests, fill_story, commands_cells); the exact-importer loop of `block` moved into `exact_importers` unchanged, so the old modes print the same bytes.
- A listed test with no cell naming it at all prints `pick a row for <test> (no ## Commands cell names it)`; a story with tests but no `## Verification` prints a `no ## Verification section` line; both exit 1.
- Rows come from the first placeholder-free non-round-only cell naming the test; one appended row that names several listed tests covers them all. Line endings (CRLF) are kept.
- Probe on a copy of this spec (all stories set todo): only story 04 got `tests/council.test.sh` plus a pick line for its parted row; 0.35 s.
- scripts/symbol-map.sh: header usage only. vulyk-plan.md step 7 and queen-planner.md: the new step and the wave rule.
CHANGELOG: `symbol-map.sh --fill-tests <spec-dir>` adds to each todo story the tests that mention its files (`exact` hits) and a `## Commands` row for each, printing a `pick` line for a parted suite; `/vulyk-plan` step 7 runs it before wave-check.

## Findings
<!-- a repair story arrives with the round's findings here, verbatim - each is a condition to satisfy. -->

## Red receipt
- command: bash tests/symbol-map.test.sh
- exit: 1
- tests: a24d758acf547a4513d3a968dd5840a550f9526db8bb15f728ad53de049bce82 (tests/symbol-map.test.sh)
- impl: c09e9ffef441179a4c310b416a5934cb83990b79409c86d61f473f235ec61634
- stamped: 2026-11-15T18:38:42Z

```
::error::a test that mentions a story file joins its lists (## Files) - expected '- tests/ship.test.sh' in:
::error::a test that mentions a story file joins its lists (## Verification row) - expected '`bash tests/ship.test.sh`' in:
  ok    trace-autopsy: no repo frame says so
  ok    trace-autopsy: a build without src/ resolves by its two-part tail
  ok    trace-autopsy: no repo frame still names the ambiguous candidates
  ok    trace-autopsy: twelve frames fit in 8 lines (<= 15)
  ok    trace-autopsy: the overflow folds into a last '... N more' line
  ok    trace-autopsy: no argument exits 2
  ok    trace-autopsy: a brief outside any git repo exits 2
  ok    trace-autopsy: /vulyk-plan step 2 runs it
  ok    trace-autopsy: /vulyk-plan step 2 names autopsy.md
symbol-map.test.sh: 133 checks, 12 failed
```
