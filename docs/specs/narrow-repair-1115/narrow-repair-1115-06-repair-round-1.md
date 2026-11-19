---
story: narrow-repair-1115-06
status: done
returned: DONE
worker: worker-code
model: opus
wave: 4
blocked_by: []
narrow: true
red: required
red_reason: a repair round 1 finding still holds
red_verified_at: 2026-11-15T23:02:29Z e6bcf68615e3d6bbe7613fe90c757b8718caf4cf92d335a2db572b5b3a0cab30
---

# Repair round 1

## Goal
Make the asks and findings council round 1 left RED pass, and change nothing else.

## Requirements
> 9. The defect gate of close-story never runs a card's check on the library's own fixtures and terms files (`docs/defects/**/*.fixture`, `*.terms`, `fixtures/`), which are red by design, so a story whose `## Files` holds `docs/defects/*` can close (framework defect met mid-build on 2026-11-16: repair story 06 refused on `host-internals-in-public-repo.terms`).
> 1. A repair after a round where the other asks were green re-checks only what it repaired: the findings' own tests, the suite parts covering the files it touched, a review of its diff, and the owner's acceptance. No new full round, whatever the number of files, unless an ask was red for a design fault.
> 5. At plan time the tests that mention a story's files are added to its lists automatically, so a story's own rows cover its files.
> 8. A story's sections (`## Files`, `## Verification` and the rest) are read outside fenced code blocks only, so a red receipt's captured test output can never add a line to them (framework defect met mid-build on 2026-11-15: story 01's receipt held a fixture's `## Verification` and `advance` refused the wave).

## Findings
- Queen answer 2026-11-16 (NEEDS_CONTEXT, defect gate): fix the root in `block_card_gate` (scripts/cycle.sh): drop the library's own `*.fixture`, `*.terms` and `fixtures/` files under the defects dir before `defects-check.sh --files`; test in `tests/council.test.sh` part `repair-scope`: a repair story with `docs/defects/*` and a card whose terms file holds a term closes (original), and a real product file holding the term still fails the gate (neighbour). The terms file and the card stay as they are.
ASK 1: RED - a repair re-checks only what it repaired - run: 2 gate rows, round 1 RED (review, asks 1,2; both steps ok) -> repair -> round 2 narrow (rerun= empty, "SUITE: none - narrow repair round"), review BLOCK on a new finding -> second repair -> open-round + suite saw: round 3 ROUND "narrow=1 asks=3 rerun=all", both steps run, "SUITE: ok 1s - narrow repair round, steps all of 2 - the step count changed (round 2: 0, now 2)". No step was red and the count never changed: round_rerun reads the steps=0 header of a no-step narrow log as a changed count, so every second repair after a no-step narrow round re-runs the whole gate. The rest holds: a 7-file repair gave narrow=1 asks=1,2 rerun=2, one step run; a reopened half gives full=design.
ASK 5: RED - plan-time tests that mention a story's files join its lists - run: bash scripts/symbol-map.sh [--exact] scripts/ship-check.sh, scripts/cycle.sh, scripts/wave-check.sh, scripts/human-check.sh, scripts/symbol-map.py saw: ship-check.sh, wave-check.sh, human-check.sh, symbol-map.py have no `exact` test; tests/cycle.test.sh (line 58 copies ship-check.sh and runs it) is only `textual` for ship-check.sh and for cycle.sh (cycle.sh's one exact test is council.test.sh). --fill-tests adds `exact` hits only (its header; its test "a textual hit is never added"), so in this repo, where tests copy a script and run it, a story on ship-check.sh gets no test and no row: its own rows do not cover its file. Only the sourced form (lib.sh: 14 exact tests) is covered. Not run end to end: the git guard denied `git add` in my temp fixture, and untracked files map to nothing.
ASK 8: RED - sections read outside fenced blocks only; captured output can never add a line - run: a red: required story whose test prints "expected done", a "```" line, "## Verification", "`echo alpha-row`", "## Files", "- app/two.sh"; cycle.sh stamp-red, then cycle.sh advance saw: stamp-red exit 0 writes the output verbatim inside its own ``` fence; advance exit 2 "verification not in ## Commands: echo alpha-row" - the wave is refused, the brief's own symptom. The same output without the fence line: advance build:1. Hand-written ````-around-``` and "```sh" inside a fence leak too (advance exit 2; scope-check "declared 2"); a ~~~ fence, an indented fence and an indented block are read correctly. The reader toggles on every fence line and stamp-red takes the last 10 output lines unescaped, so an odd fence line in captured output reopens the sections.
1. tests/council.test.sh:4220 [regression] suite `council`, part `roster`, check "carry: a regressions-only repair must carry" is red: the case and the round contract must agree on what round 2 holds after a repair of regressions only (head: scripts/cycle.sh:3468 freezes `seats=review` when `asks=` is empty and :3487 carries nothing into a narrow round, so round-2 holds only `ROUND`) - base: `git show d5ba99ad:scripts/cycle.sh` line 3460 carried the GREEN blind seats into that round and the same check (base tests/council.test.sh:4232-4236) held - repro: `bash tests/council.test.sh --part roster` (exit 1 when rerun alone on the head, this one check red, every other check of the part ok)
1. scripts/cycle.sh:4701 [ask 1] the round after a repair of a narrow round whose gate ran no step must re-run only the steps that were red, never every step: that round's log is `head=<h> steps=0` + `SUITE: none - narrow repair round` (scripts/cycle.sh:3992), `round_rerun` compares that `steps=0` with the live step count and answers `all`, so a second repair in a row (round 1 RED on a seat or the review with a green gate, round 2 narrow and RED again) opens round 3 with `rerun=all` and the reason "the step count changed (round 2: 0, now 10)"; no case in `round-scope` repairs a round that ended `SUITE: none` (card full-round-for-a-narrow-fix, Never 3) - repro: `printf 'head=abc steps=0\n' | sed -n 's/.* steps=\([0-9][0-9]*\).*/\1/p'` prints 0, `bash tests/full-suite.sh --steps` prints 10
2. scripts/trace-check.sh:76 [ask 8] every reader of a story's sections must skip fenced lines, not only the three scripts story 03 named (no `## Descoped` line narrows the ask): scripts/trace-check.sh:76 and :119 still read a `> ` line under a fenced `## Requirements`, scripts/symbol-map.py:99 (`story_files`, the `--story` scope) still reads a path under a fenced `## Files`, and `section()` of the new `--fill-tests` (scripts/symbol-map.py:543) keeps no fence state - repro: a story whose `## Red receipt` fence holds `## Requirements` and `> 9. A fixture ask that the brief never held at all.` makes `bash scripts/trace-check.sh <spec>` print "2 quotes; backward: 1 unfound" (1 quote, 0 unfound with the fence removed); `story_files` on a story with a fenced `## Files` + `- scripts/redact.sh` returns `['scripts/symbol-map.sh', 'scripts/redact.sh']`
- [regression] PART council:roster FAIL 163s cap 300s
- NEEDS_CONTEXT (worker, 2026-11-15): ASK 8 is RED also on hand-written nested fences (a ```` fence around ``` lines, a ```sh line inside a fence) with `scope-check "declared 2"` as its evidence. The root fix is one fence rule for every story-section reader (a fence closes only on the same character, at least as long, with no info string) plus stamp-red escaping fence lines in the captured output. Two of those readers are outside `## Files`: `scripts/scope-check.sh:66` (`files_of`) and `scripts/wave-check.sh:107,119` (`files_of`, `verify_of`; cycle.sh:2139 says its parser is a verbatim mirror of wave-check.sh). Without them, cycle.sh and wave-check.sh would read the same story two ways, and scope-check would keep reading `declared 2`. Question: add `scripts/scope-check.sh` and `scripts/wave-check.sh` to `## Files`? If yes, also add `bash tests/council.test.sh --part roster` to `## Verification`, because regression finding 1 is in that part and no row runs it now. The new fence cases would go in council.test.sh `round-scope`. If no, say which narrower reading of ASK 8 holds (for example: only the red receipt's captured output is made inert, and the hand-written nested fences are left as the Minor).
- Queen answer 2026-11-15 (NEEDS_CONTEXT): yes - scripts/scope-check.sh and scripts/wave-check.sh join `## Files` and `bash tests/council.test.sh --part roster` joins `## Verification`; one fence rule shared by every section reader (cycle.sh, wave-check.sh, scope-check.sh, trace-check.sh, symbol-map.py), and stamp-red makes captured output inert. The full reading of ask 8, not the narrower one.
- NEEDS_CONTEXT (worker, 2026-11-16): close-story exit 4 "defect card host-internals-in-public-repo fails on docs/defects/host-internals-in-public-repo.terms" (line 2: a private term from the private lists). That file is unmodified in this tree (last commit 509bf95a), not this story's edit; the card's verdict on it needs a decision. Scope-check passed (declared 11, changed 10, out of scope 0); round-scope and symbol-map.test.sh green when run alone.

## Acceptance criteria
- [ ] The class card under docs/defects/ (its quote, Never line or check:) is added or updated in the same commit as the fix.

## Files
- tests/council.test.sh
- scripts/scope-check.sh
- scripts/wave-check.sh
- scripts/cycle.sh
- scripts/trace-check.sh
- scripts/symbol-map.sh
- scripts/symbol-map.py
- tests/symbol-map.test.sh
- .claude/commands/vulyk-plan.md
- .claude/agents/queen-planner.md
- docs/defects/*

## Verification
`bash tests/council.test.sh --part roster`
`bash tests/council.test.sh --part repair-scope`
`bash tests/cycle.test.sh --part red2`
`git ls-files '*.sh' | xargs -n1 bash -n`
`bash tests/symbol-map.test.sh`
`bash tests/e2e.test.sh`
`bash tests/council.test.sh --part round-scope`
`bash tests/council.test.sh --part seats`
`bash tests/cycle.test.sh --part merge-gate`
`bash tests/cycle.test.sh --part ship`

## Implementation notes
- scripts/cycle.sh: FENCE_AWK (one fence rule) used by verify_of, files_of, red_gate, stamp-red, repair_touched_asks, story_req_lines; stamp-red fences the captured output one backtick longer than its longest run.
- scripts/cycle.sh: gate_log_round skips `SUITE: none - narrow repair round` logs; round_rerun and suite_narrow_verdict compare the step count with the last round that ran steps (ask 1, finding 1).
- scripts/wave-check.sh, scripts/scope-check.sh, scripts/trace-check.sh: the same FENCE_AWK line, byte for byte (round-scope compares them).
- scripts/symbol-map.py: fence_mask for story_files and --fill-tests section(); a script run by bash/sh/exec (literal or a variable set to its path) is an `exact` hit; a .py's runners include its bash wrapper's runners (ask 5).
- scripts/symbol-map.sh, .claude/commands/vulyk-plan.md: wording for the new exact hit; docs/defects/full-round-for-a-narrow-fix.md: the round-1 gaps and the Never line.
- Regression finding 1 (roster carry) is covered by the roster row; the round-scope cases were green before close.
- scripts/cycle.sh block_card_gate: drops the defects dir's *.fixture, *.terms and fixtures/ files before defects-check.sh --files (Queen answer 2026-11-16); tests/council.test.sh repair-scope: original (defects dir story closes) and neighbour (product file with the term fails); test re-stamped red before the fix.

## Red receipt
- command: bash tests/council.test.sh --part repair-scope
- exit: 1
- tests: e6bcf68615e3d6bbe7613fe90c757b8718caf4cf92d335a2db572b5b3a0cab30 (tests/council.test.sh, tests/symbol-map.test.sh)
- impl: d7e021919f51200f1f6c9a16b89bf6338bf43cdc8d44cd37dcaa4d1297fc98c2
- stamped: 2026-11-15T23:02:29Z

```
::error::a repair round 1 finding still holds - defect gate, original: exit=4 out=cycle: close-story - note: no approved record for docs/specs/dgs/dgs-02-lib.md; its working copy stands
  ok    one stderr line says the union was taken
narrow-repair-1115 (ask 9): the defect gate never runs a card's check on the library's own fixtures and terms files
::error::a repair round 1 finding still holds - defect gate, original: exit=4 out=cycle: close-story - note: no approved record for docs/specs/dgs/dgs-02-lib.md; its working copy stands
cycle: close-story - note: Tier unset keeps no claim head: the scope check counts the uncommitted diff only
scope-check: dgs-02-lib - declared 2, changed 0, out of scope 0
dg fails on dfx/defects/dg.terms: 
dg fails on dfx/defects/fixtures/dg-case.txt: 
cycle: close-story - defect card dg fails on dfx/defects/dg.terms
{"ok":false,"verb":"close-story","exit":4,"next":"repair","error":"defect card dg fails on dfx/defects/dg.terms","now":1794783014}
  ok    the neighbour: a product file holding the term still fails the gate
```
