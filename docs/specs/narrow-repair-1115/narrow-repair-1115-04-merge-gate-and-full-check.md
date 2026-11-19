---
story: narrow-repair-1115-04
spec: narrow-repair-1115
status: done
returned: DONE
tier: 3
worker: worker-code
model: opus
wave: 3
blocked_by: [narrow-repair-1115-03]
red: required
red_reason: a narrow green round is not merged without the full suite
red_verified_at: 2026-11-15T21:00:36Z 1db13bfdb7e06670bc7315b81d692519ec921775420210835a04d1295976061b
---

# The full suite once before a local merge; the full check on the owner's word

## Goal
`ship-check.sh` refuses a local merge until every suite step has run green on the branch head with no agent, and
`cycle.sh open-round --full` opens the full check of the whole project when the owner asks for it.
`model: opus`: a new gate in the ship path plus two verb modes and three command files.

## Requirements
> 4. The full suite, without agents, runs once before a local merge. A full check of the whole project runs, in the owner's words, when the major version goes up (0.5 -> 0.6 -> 0.7; 0.51 -> 0.52 is minor), about once a month, or when bugs or feedback come in - not on every repair and not on every minor public release. (This spec itself gets one full council round because the owner chose so for it on 2026-11-15, not as a rule.)
> 7. Every rule above has a failing test with the original case (the audit-fixes-1113 repair) and a neighbour form.

## Files
- scripts/cycle.sh
- scripts/ship-check.sh
- tests/cycle.test.sh
- .claude/commands/vulyk-ship.md
- .claude/commands/vulyk-build.md
- .claude/commands/vulyk-review.md

## Non-goals
- No rule that opens a full round by itself: not at a release, public or not, not by date, not by version. The
  commands offer it; only the owner's word runs it.
- No timer, reminder or maintenance-brief line for "once a month"; no version parser that decides what is major.
- Do not change the narrow-round code of story 03, `cmd_judge`, or the steps, parts and caps of the round's gate.
- Do not let the merge log stale a GREEN round, and never run a step while a round is open.
- No new status state for a red merge gate, and its cure is never a council round: fix what failed, then the whole
  suite runs once more without agents (owner 2026-11-15: «Весь набор ещё раз (Рекомендую)»). `open-round --full`
  stays the owner's explicit choice only.

## Map slice
`memory/map/cycle-suite.md` "Suite gate"; `memory/map/scripts.md` "Entry points" (`ship-check.sh`), "Key contracts"
(paperwork); `memory/map/commands-ship.md` "`/vulyk-ship`"; `memory/map/commands.md` "`/vulyk-build`", "`/vulyk-review`".

## Acceptance criteria
- [ ] Contracts M1, M2, F1 of plan.md hold; new functions `suite_merge` and `open_round_full` in `scripts/cycle.sh`.
- [ ] Original case, new part `merge-gate` (the audit-fixes-1113 shape: a repair, then a narrow GREEN round):
      `ship-check.sh` prints `suite: no full run at <sha7>` and NOT READY; after `cycle.sh suite <spec> --merge`
      has finished green it is ready, and a second call runs no step.
- [ ] Neighbour forms: a merge log keyed to an older head with a code commit after it is not accepted (paperwork
      after it is); a `**Checked:** ACCEPTED` spec with no full run is NOT READY the same way; a round that ran every
      step green on the head needs no merge run; a constitution with no `round-only` row passes as `suite: none`.
- [ ] A red merge run: NOT READY naming the red parts and the cure: fix them, then `cycle.sh suite <spec> --merge`
      again runs the whole suite on the new head (no agents); READY only when one full run on the head is all green.
      It never names `open-round --full`. Original case: a merge run with one red part, fixed, re-run whole and green;
      neighbour: the fix turns a previously green part red - still NOT READY, names that part.
- [ ] `open-round --full`: `ROUND` has `full=asked`, no `narrow=1`, every required seat with no carry, `since=` the
      branch base, no `round-asks` in the court, and `suite` runs every step. Without the flag nothing changes.
- [ ] `/vulyk-build` and `/vulyk-review`: at `green`, when ship-check asks for the merge run, run it step by step
      before «Выпускаем?»; a RED round is followed by a repair and a narrow round, in the words of plan.md's Goal.
- [ ] `/vulyk-ship`: the merge gate in step 1; at a major version bump it asks the owner once whether to run the
      full check first, and names the owner's three triggers; it never opens it unasked. `/vulyk-review <slug>
      --full` is the owner's way to run it.
- [ ] Each new case fails on HEAD before the implementation; existing `ship` cases stay green or are updated and
      named in the notes. Notes end with one `CHANGELOG:` line.

## Verification
`bash tests/cycle.test.sh --part merge-gate`
`bash tests/cycle.test.sh --part ship`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each -->
- `scripts/cycle.sh`: `suite_merge` (M1) and a shared `suite_run` that took cmd_suite's step body unchanged (label, log dir and `"merge":true` are its only new inputs); `suite_emit` takes an optional merge flag; `open_round_full` (F1) plus an `OPEN_FULL` branch in `build_round` (full=asked, since= merge-base, no carry); dispatch reads `--merge` / `--full`.
- `suite_merge` also refuses a tree dirty outside paperwork (exit 2): a run on uncommitted code would be keyed to a HEAD it did not test. A log whose head has only paperwork after it is resumed or a no-op, green or red; code after it replaces it.
- `open_round_full` refuses while another round is open (unless that one is itself full=asked), and when the branch base cannot be named: no silent fallback to round n-1's head.
- `scripts/ship-check.sh`: a `suite` line after `ci` (M2). It keeps its own copy of full_suite_row's round-only predicate over lib.sh `commands_rows`, since ship-check runs without cycle.sh (the ship part's fixture copies no cycle.sh). Merge log read before the round log, so a newer red merge run names its parts.
- Deviation from plan M2: the red line names the cure (`fix it, commit, then run ... suite <spec> --merge again`), not `open-round --full`, per this story's AC and Non-goals.
- Commands: `/vulyk-build` and `/vulyk-review` at `green` run the merge run before «Выпускаем?» and say the RED round -> repair -> narrow round line; `/vulyk-review --full` opens the full check; `/vulyk-ship` step 1 has the merge gate and the one major-bump question with the owner's three triggers.
- Tests: new part `merge-gate` in `tests/cycle.test.sh`; existing `ship` cases unchanged and green (its fixture has no constitution, so `suite: none`). The test got one post-receipt fix (the last READY check became a suite-line check: the fixture's code commits stale the council row); implementation reverted, re-stamped, re-applied.
- Surprise: `tests/council.test.sh --part roster` fails on HEAD before this story too (carry: a regressions-only repair must carry; story 03's narrow round carries nothing). Not touched.
- CHANGELOG: `cycle.sh suite <spec> --merge` runs the whole gate once, with no agent, before a local merge, and `ship-check.sh` refuses a merge without it (`suite:` line); `cycle.sh open-round <spec> --full` (`/vulyk-review <slug> --full`) opens the owner's full check.

## Findings
<!-- a repair story arrives with the round's findings here, verbatim - each is a condition to satisfy. -->

## Red receipt
- command: bash tests/cycle.test.sh --part merge-gate
- exit: 1
- tests: 1db13bfdb7e06670bc7315b81d692519ec921775420210835a04d1295976061b (tests/cycle.test.sh)
- impl: 3d23ba75cb7f72b0c2fa33210aea26c215c0708d7f65186298a23790072836bf
- stamped: 2026-11-15T21:00:36Z

```
::error::a narrow green round is not merged without the full suite - expected 'suite: no full run at a47e26c - run bash scripts/cycle.sh suite docs/specs/mg --merge' in:
::error::vulyk-ship step 1: a red merge gate is cured by a fix and the whole suite once more - 'never by a council round' is gone
::error::vulyk-ship: the major-version question - 'ask the owner once whether to run the full check first' is gone
::error::vulyk-ship: the owner's three triggers - 'a major version (0.5 -> 0.6), about once a month, or when bugs or feedback come in' is gone
::error::vulyk-ship: never unasked - 'never open it unasked' is gone
::error::vulyk-ship: the owner's way to run it - '`/vulyk-review <slug> --full`' is gone
::error::BUILDMD: the merge run before «Выпускаем?» - 'run `bash scripts/cycle.sh suite docs/specs/<slug> --merge --commit` step by step until `"done":true`, before «Выпускаем?»' is gone
::error::BUILDMD: a RED round is followed by a repair and a narrow round - 'A RED round is followed by a repair and a narrow round' is gone
::error::REVMD: the merge run before «Выпускаем?» - 'run `bash scripts/cycle.sh suite docs/specs/<slug> --merge --commit` step by step until `"done":true`, before «Выпускаем?»' is gone
::error::REVMD: a RED round is followed by a repair and a narrow round - 'A RED round is followed by a repair and a narrow round' is gone
::error::vulyk-review: --full opens the full check - 'cycle.sh open-round docs/specs/<slug> --full --commit --stamp $stamp`' is gone
```
