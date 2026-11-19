---
story: narrow-repair-1115-01
spec: narrow-repair-1115
status: done
returned: DONE
tier: 3
worker: worker-code
model: opus
wave: 1
blocked_by: []
red: required
red_reason: a repair story carries only its findings' rows
red_verified_at: 2026-11-15T19:14:43Z 3a74b11d90cdf93d54b8b9a8f1d297b6ed55c06b2b80fd01380bdcff7ed0be2a
---

# A repair story carries its findings' files and rows, whatever their number

## Goal
`cycle.sh repair` writes a scoped repair story for every RED round: the files its findings name and only the
verification rows that cover them. A new function says whether the round after it will be narrow or full.
`model: opus`: judgment-heavy rewrite of `cmd_repair` inside a 3000-line script that closes its own story.

## Requirements
> 1. A repair after a round where the other asks were green re-checks only what it repaired: the findings' own tests, the suite parts covering the files it touched, a review of its diff, and the owner's acceptance. No new full round, whatever the number of files, unless an ask was red for a design fault.
> 2. A repair story carries only its findings' verification rows, never the union of every earlier story's rows.
> 7. Every rule above has a failing test with the original case (the audit-fixes-1113 repair) and a neighbour form.

## Files
- scripts/cycle.sh
- tests/council.test.sh
- tests/cycle.test.sh

## Non-goals
- Do not touch `open-round`, `build_round`, `suite`, `carry_seats` or `judge`: story 03 switches the round over.
- Keep `narrow_file`, the `narrow.round-<n>` record and `narrow_round_holds` working exactly as they are: the old
  one-file path must stay green until story 03 removes it.
- Do not change `finding_paths`' parsing, `repair_unmarks`, the story's `model: opus`, `worker:` or `wave:` rules.
- No edit to `scripts/lib.sh` or `scripts/symbol-map.*` (story 02 edits symbol-map in this wave; `--exact` output
  stays byte-identical).

## Map slice
`memory/map/cycle-state.md` "Repair (ADR-013 D4)", "Seats and the verdict"; `memory/map/cycle.md` "Verbs" (approved
version, `revise`); `memory/map/scripts-checks.md` "Tests" (parts).

## Acceptance criteria
- [ ] Contract S1 of plan.md: new functions `round_scope`, `repair_scope_paths`, `repair_scope_rows` in
      `scripts/cycle.sh`, each with a header comment; `cmd_repair` calls them.
- [ ] `## Files` of every repair story = each existing path the findings name, each path's `exact` tests, and
      `docs/defects/*`. A red ask whose findings name no path adds the `## Files` of the done stories that quote that
      ask. Only when no item yields a path is it the union of today, with one stderr line saying so.
- [ ] `## Verification` = the lines of the done stories whose `## Files` match one of those paths (deduplicated,
      `repeat:` dropped); for a pathless red ask, the lines of the stories that quote it. Never every story's lines.
      Nothing tied: `none — reviewed by lead-review`.
- [ ] The story says `narrow: true` exactly when `round_scope` answers `narrow`; one RED item or ten, one file or
      forty. After a reopened `half` or `no-progress` escalation it answers `full design` and the line is absent.
- [ ] Original case, new part `repair-scope`: a fixture shaped like the audit-fixes-1113 round-1 repair (several done
      stories with their own files and rows; a RED round with review findings on two asks, each naming a path, one
      `[regression]` finding naming a test file, red PART lines). The repair story names those paths and their
      tests, carries the rows of the stories that named them, and none of an unrelated story's.
- [ ] Neighbour form: the round-3 repair (no ask red, one `[regression]` finding naming a test file, one PART
      line): its file, its stories' rows. Second neighbour: a red ask from a blind seat's `ASK <n>: RED` line alone.
- [ ] Each new case fails on HEAD before the implementation; say so in the notes. Existing council parts that pin
      the union or the one-file rule are updated in this file and named in the notes.
- [ ] Notes end with one `CHANGELOG:` line.

## Verification
`bash tests/council.test.sh --part repair-scope`
`bash tests/cycle.test.sh --part red2`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each -->
- `scripts/cycle.sh`: new `round_scope`, `repair_scope_paths`, `repair_scope_rows` and helper `repair_ask_stories` (the stories serving a pathless RED ask), each with a header; `cmd_repair` writes `## Files` / `## Verification` from them and `narrow: true` from `round_scope`; `repair_verification` and `verify_lines_hitting` (now unused) removed.
- `narrow_file`, the `narrow.round-<n>` record and `narrow_round_holds` are untouched: the one-file record is still written beside the new scope.
- `round_scope` reads HEAD's `memory/stats/council.jsonl` and `council/REOPEN` via `git show` (committed records only); `full design` needs both the half/no-progress ESCALATE row and a REOPEN line for the round.
- `repair_scope_paths` exits 1 on the union fallback; then rows are `none — reviewed by lead-review` and no card acceptance line is written (r18rp's expected text).
- Red first: `stamp-red` on HEAD's cycle.sh exited 1 (`--part repair-scope` printed the red_reason; red2 failed on redrq).
- Pins updated in tests/council.test.sh: verbs2 nrf, verbs3 nb_full, roster2 r18rp, advance r18vf/r18vg (fixture files created), suite2 nxf/nxi; tests/cycle.test.sh red2 redrq.
- Also ran solo.test.sh and e2e.test.sh: green.
- CHANGELOG: `cycle.sh repair` scopes every repair story to its findings' files, their exact tests and only the rows of the stories that named them, and writes `narrow: true` from the new `round_scope`.

## Findings
<!-- a repair story arrives with the round's findings here, verbatim - each is a condition to satisfy. -->
- NEEDS_CONTEXT (builder, before any edit): the criterion "the story says `narrow: true` exactly when `round_scope`
  answers `narrow`" breaks a pin outside `## Files`: `tests/cycle.test.sh --part red2` (lines 2362-2367, case
  `redrq`) asserts that a Tier 2 repair whose finding names no path writes frontmatter lines 1-9 byte for byte with
  no `narrow: true` ("a finding with no path adds no narrow: true"). Under `round_scope` that round (RED, no
  reopened `half`/`no-progress`) answers `narrow`, so the new code writes `narrow: true` and that case goes red.
  Question: add `tests/cycle.test.sh` to `## Files` (with its row `bash tests/cycle.test.sh --part red2` in
  `## Verification`) so this story updates that pin, or should the pin move to a later story? No other pin outside
  `tests/council.test.sh` was found by grep over cycle/e2e/solo/driver/maintenance tests (e2e's narrow case is a
  one-file repair and stays green). Inside `tests/council.test.sh` these parts pin the union or the one-file rule
  and will be updated here: `verbs2` (nrf), `verbs3` (nb_full), `roster2` (r18rp exact text), `advance`
  (r18vf/r18vg: needs its fixture files created, and the no-path fallback becomes `none — reviewed by lead-review`),
  `suite2` (nxf, nxi).
- Queen answer 2026-11-15 (NEEDS_CONTEXT): `tests/cycle.test.sh` joins this story's `## Files` with the row `bash tests/cycle.test.sh --part red2`; update the `redrq` case here, and the listed `tests/council.test.sh` cases (verbs2 nrf, verbs3 nb_full, roster2 r18rp, advance r18vf/r18vg, suite2 nxf/nxi) in this story, before stamp-red.
- NEEDS_CONTEXT (builder, 2026-11-15, second dispatch): `stamp-red` exits 3 `paused: Andrei · revise story 04 ...`
  (PAUSE since 18:48:21Z, still present after ~25 min of waiting). State: both test files are written in the tree,
  uncommitted, not yet stamped (new council part `repair-scope`; verbs2 nrf, verbs3 nb_full, roster2 r18rp, advance
  r18vf/r18vg, suite2 nxf/nxi and cycle red2 redrq updated). On HEAD's cycle.sh `--part repair-scope` prints the
  red_reason 8 times and red2 fails on redrq. No implementation edit is in the tree. Resume: `/vulyk-resume`, then
  re-dispatch; the builder goes straight to stamp-red.

## Red receipt
- command: bash tests/council.test.sh --part repair-scope
- exit: 1
- tests: 3a74b11d90cdf93d54b8b9a8f1d297b6ed55c06b2b80fd01380bdcff7ed0be2a (tests/council.test.sh, tests/cycle.test.sh)
- impl: aac6103baf5e0c7002268d339caaa010b523fa6c356828bb4ff59bbe9c7c0608
- stamped: 2026-11-15T19:14:43Z

```
::error::a repair story carries only its findings' rows - the original case: narrow: true, the three paths and docs/defects/*, the rows of alpha and beta (deduplicated, repeat: dropped), none of gamma's: story=---
::error::a repair story carries only its findings' rows - findings: ---
::error::a repair story carries only its findings' rows - neighbour, no ask red: the one test file, its story's rows: story=---
- app/alpha.sh
- app/beta.sh
- tests/beta.test.sh
- app/gamma.sh

  ## Verification
`echo alpha-row`
`echo beta-row`
`echo gamma-row` stderr=
::error::a repair story carries only its findings' rows - union stderr: 
```
- NEEDS_CONTEXT (builder, 2026-11-15, third dispatch): red receipt written (stamp-red exit 0), implementation done in
  `scripts/cycle.sh`; repair-scope, red2, verbs2, verbs3, roster2, advance, suite2, solo and e2e green locally. Then
  `close-story` exits 3 `paused: Andrei · revise story 04 again ...` (PAUSE 2026-11-15T19:22:04Z, set after the
  receipt). Nothing committed. Resume: clear the pause, re-dispatch; the builder sets `returned: DONE` and runs close-story.
