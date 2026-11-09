---
story: ab-run-fixes-10
status: done
returned: DONE
worker: worker-code
model: opus
wave: 5
blocked_by: []
red: required
red_reason: checkpoint: after a wave, before the next build wave, the claim released - got
red_verified_at: 2026-11-09T00:01:52Z d11eb826808dad46f0730fcc8152953483bf921b77ad937e411e65b682106a80
---

# Repair round 1

## Goal
Make the asks and findings council round 1 left RED pass, and change nothing else.

## Requirements
> 9. Главная сессия не простаивает дольше часа во время сборки, чтобы кэш не умирал.

## Findings
1. tests/cycle.test.sh:1392 [regression] the round's suite must be green on the head: `cycle:red` and `e2e:red` fail because contract C5 now writes `narrow: true` into a one-item, one-file repair story and makes round 2 review-only, while the untouched assertions at tests/cycle.test.sh:1392 (unmarked repair frontmatter byte for byte) and tests/e2e.test.sh:238 (round 2's `opus.md` carried) still assert the pre-C5 shape; both passed against the base `cmd_repair`, which wrote no `narrow:` line (`git show 84ad342:scripts/cycle.sh`) - repro: `bash tests/cycle.test.sh --part red` (`::error::unmarked repair frontmatter changed: ... narrow: true`) and `bash tests/e2e.test.sh --part red` (`::error::red: round 2's intent seat is marked carried`).
1. .claude/workflows/vulyk-cycle.js:119 [ask 9] the driver checkpoint must read its clock from a field the live clerk lines really carry: `ask()` reads `parsed.now` at the top level, but `advance` (scripts/cycle.sh:3982) and `suite` (scripts/cycle.sh:3172), the only verbs the loop calls before `release`, put `now` only inside `status`, so `verbNow` stays NaN, `boundary()` never throws and the 50-minute checkpoint cannot fire in a real run; the driver test's fake advance lines (tests/driver.test.sh, the C10 block, `at({... status: st}, T0)`) place `now` at the top level, unlike the real line - repro: `grep -n '"verb":"advance"\|"verb":"suite"' scripts/cycle.sh` (no `now` key on either printf) against `grep -n 'parsed.now' .claude/workflows/vulyk-cycle.js`.
2. docs/defects/INDEX.md:7 [regression] the Law 6 gate must be green: `bash scripts/defects-check.sh` exits 1 on the head with `RED: index stale` (the index counts how-to 2 while the cards hold 3 after story 07 added a How-to line to docs/defects/shell-needs-gnu-or-bash4.md without regenerating INDEX.md); on the base the index is fresh (`git archive 84ad342 docs/defects | tar -x -C <tmp>; DEFECTS_DIR=<tmp>/docs/defects bash scripts/defects-index.sh --check` exits 0) - repro: `bash scripts/defects-check.sh; echo $?`.
- [regression] PART e2e:red FAIL 35s cap 300s
- [regression] PART cycle:red FAIL 92s cap 300s

## Files
- scripts/model-profile.sh
- tests/model-profile.test.sh
- .claude/commands/vulyk-models.md
- .claude/agents/lead-review.md
- .claude/agents/worker-code.md
- .claude/agents/worker-test.md
- docs/model-cascade.md
- docs/token-economy.md
- docs/adr/020-*.md
- .claude/commands/vulyk-plan.md
- templates/grill.md
- templates/plan.md
- docs/adr/022-*.md
- docs/cycle.md
- docs/command-reference.md
- README.md
- scripts/cycle.sh
- tests/cycle.test.sh
- tests/e2e.test.sh
- tests/council.test.sh
- docs/adr/029-*.md
- .claude/workflows/vulyk-cycle.js
- tests/driver.test.sh
- .claude/commands/vulyk-build.md
- .claude/commands/vulyk-review.md
- docs/defects/full-round-for-a-narrow-fix.md
- docs/defects/full-round-for-a-narrow-fix.original.fixture
- docs/defects/full-round-for-a-narrow-fix.neighbour.fixture
- docs/defects/INDEX.md
- docs/adr/013-light-vulyk.md
- .claude/commands/vulyk-bootstrap.md
- bootstrap/interview.md
- .claude/hooks/handoff.py
- .claude/hooks/session-start-brief.sh
- install.sh
- tests/maintenance.test.sh
- tests/telemetry.test.sh
- docs/getting-started.md
- docs/telemetry.md
- docs/hooks-reference.md
- docs/defects/shell-needs-gnu-or-bash4.md

## Verification
`bash tests/model-profile.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`
`bash tests/maintenance.test.sh`
`bash tests/cycle.test.sh --part close`
`bash tests/cycle.test.sh --part gates`
`bash tests/council.test.sh --part suite`
`bash tests/council.test.sh --part roster`
`bash tests/council.test.sh --part seats`
`bash tests/council.test.sh --part verbs`
`bash tests/driver.test.sh`
`bash scripts/defects-check.sh docs/defects/full-round-for-a-narrow-fix.md`
`bash tests/cycle.test.sh --part manual`
`bash tests/cycle.test.sh --part safety`
`bash tests/council.test.sh --part driver`
`bash tests/telemetry.test.sh --part install`
`bash scripts/py.sh -m py_compile .claude/hooks/*.py`
`bash tests/council.test.sh --part advance`

## Red receipt
- command: bash tests/driver.test.sh
- exit: 1
- tests: d11eb826808dad46f0730fcc8152953483bf921b77ad937e411e65b682106a80 (tests/council.test.sh, tests/cycle.test.sh, tests/driver.test.sh, tests/maintenance.test.sh, tests/model-profile.test.sh, tests/telemetry.test.sh)
- impl: b2b4cb7762bb680f34427f4dbcd61cb6f194536184b4cde649434d1536993494
- stamped: 2026-11-09T00:01:52Z

```
::error::checkpoint: after a wave, before the next build wave, the claim released - got {"result":"","seq":"advance docs/specs/demo --stamp 0123456789abcdef --claim | advance docs/specs/demo --stamp 0123456789abcdef | advance docs/specs/demo --stamp 0123456789abcdef | status docs/specs/demo --json | release docs/specs/demo 0123456789abcdef"}
::error::checkpoint: after a wave, before the gate and the seats - got {"result":"","s":1}
::error::checkpoint: after one gate step, before the next - got {"result":{"spec":"docs/specs/demo","slug":"demo","stage":"04","tier":3,"branch":"vulyk/demo","head":"h1","wave_stories":[],"round":1,"court":"/abs/.vulyk/court/demo","round_dir":"docs/specs/demo/council/round-1","since":null,"seat_attempt":{"review":1},"seats":["review"],"red":[],"next":"dispatch:review","now":1762700000,"stop":{"verb":"suite","error":"suite not done after 32 calls"},"fallbacks":[]},"s":32}
::error::checkpoint: after the gate finished, before the seat dispatch - got {"result":"","s":1,"d":1}
  ok    checkpoint: a terminal state returns as itself, no checkpoint
::error::checkpoint: 50 min after launched_at by the verb clock, the default fires - got ""
  ok    checkpoint: 49 min, the default does not fire
  ok    checkpoint: no launched_at, no time source - the checkpoint does not fire and the driver runs on
  ok    checkpoint: no `now` in any verb answer - the checkpoint does not fire
  ok    no queen-planner dispatch in any scenario
113 passed, 5 failed
```

## Implementation notes
- tests/driver.test.sh: C10 fake advance and suite lines now carry `now` inside `status` only, the real shape (cmd_status prints it; advance/suite printf no top-level `now`); red before the fix (5 checkpoint checks).
- .claude/workflows/vulyk-cycle.js: `ask()` reads the top-level `now` (emit() lines), else `status.now` (advance, suite). Chose the driver fallback over adding `now` to two printfs: one place, covers every carried-status line.
- tests/cycle.test.sh: the unmarked-repair frontmatter check compares 10 lines byte for byte, `narrow: true` being C5's one added line (the fixture is one ask, one file).
- tests/e2e.test.sh: round 2 after the narrow repair asserts the C5 shape (story marked narrow, ROUND seats=review + narrow=1, no opus.md, suite log `SUITE: none - narrow repair round`) instead of a carried intent seat.
- docs/defects/INDEX.md: regenerated with scripts/defects-index.sh (how-to 3); defects-check exits 0.
- Review Minors not taken.
