---
story: narrow-repair-1115-03
spec: narrow-repair-1115
status: done
returned: DONE
tier: 3
worker: worker-code
model: opus
wave: 2
blocked_by: [narrow-repair-1115-01]
red: required
red_reason: a seat with no ask to judge is not dispatched
red_verified_at: 2026-11-15T20:21:56Z 53b329fdaa79edb3adcbcc46743b999655f99aed2e487974b3b2810b61de8c26
---

# The round after a repair re-checks the repair: scoped seats, scoped gate

## Goal
`open-round` after a repair freezes a narrow round from committed records: the asks to re-judge, the blind seat only
when that list is not empty, the gate steps that were red. The one-file rule and its local record are removed.
`model: opus`: it rewrites the round contract across `build_round`, the court, `suite` and the carry rule.

## Requirements
> 1. A repair after a round where the other asks were green re-checks only what it repaired: the findings' own tests, the suite parts covering the files it touched, a review of its diff, and the owner's acceptance. No new full round, whatever the number of files, unless an ask was red for a design fault.
> 3. A council seat re-runs only for a red ask or an ask whose files the repair touched; a seat with nothing to judge is not dispatched (no empty reports).
> 7. Every rule above has a failing test with the original case (the audit-fixes-1113 repair) and a neighbour form.
> 8. A story's sections (`## Files`, `## Verification` and the rest) are read outside fenced code blocks only, so a red receipt's captured test output can never add a line to them (framework defect met mid-build on 2026-11-15: story 01's receipt held a fixture's `## Verification` and `advance` refused the wave).

## Files
- scripts/cycle.sh
- tests/council.test.sh
- .claude/agents/council-opus.md
- .claude/agents/council-haiku.md
- scripts/wave-check.sh
- scripts/scope-check.sh
- tests/e2e.test.sh

## Non-goals
- No `--full` flag, no `suite --merge`, no `ship-check.sh` edit: story 04.
- Do not change `cmd_judge`'s verdict rules, the ceiling, `review2_called`, or the path of a round that follows no
  repair (round 1, a hand fix after GREEN, an `env` reopen): they open as today.
- No edit to `.claude/workflows/vulyk-cycle.js` or the dispatch prompts: the driver dispatches the seats `next`
  names, and the seat reads its ask list from the court. A driver change you find necessary is `NEEDS_CONTEXT`.
- Do not write to the court's `brief.md`.

## Map slice
`memory/map/cycle-state.md` "Cycle-owned run state", "Seats and the verdict", "Repair"; `memory/map/cycle-suite.md`
"Suite gate"; `memory/map/agents-and-commands.md` "council-opus"; `docs/cycle.md` "Why 05 is red".

## Acceptance criteria
- [ ] Ask 8: every story-section reader in `scripts/cycle.sh` (`verify_of`, the `## Files` reader and the
      blocks guard), `scripts/wave-check.sh` and `scripts/scope-check.sh` skips lines inside ``` fences; original case:
      a story whose `## Red receipt` fence holds `## Verification` + `` `echo alpha-row` `` passes `advance`; neighbour: a
      fenced `## Files` line in the notes adds no path to scope. Test in `tests/council.test.sh` part `round-scope`.
- [ ] Contracts R1, R2, R3 of plan.md hold; new functions `round_asks`, `round_rerun`, `court_round_asks`;
      `build_round` calls story 01's `round_scope`. `narrow_file`, `narrow_round_holds` and the
      `narrow.round-<n>` record are gone; nothing reads a story's `narrow:` line to decide a round.
- [ ] Original case, new part `round-scope` (the audit-fixes-1113 repair): round n-1 RED on two asks from the
      review, the repair done and its diff touching a file of a third ask's story, one `FAIL` step in the old log.
      `ROUND` has `repair=<story id>`, `narrow=1`, `asks=` those three, the review and one blind seat, `second=none`,
      `rerun=<that step>`; the court holds `round-asks`; `suite` runs that step only.
- [ ] Neighbour (the round-3 repair): no ask red, the repair touches no ask's story file: `asks=` empty,
      `seats=review`, no court, `next` is `dispatch:review`, no blind-seat file is written or ingested.
- [ ] No blind-seat report in any earlier round: `asks=` is every ask. A reopened `half` or `no-progress`: a full
      round with `full=design`. A reopened `ceiling`: narrow. Scope records unreadable: `full=norecord`, one stderr
      line. A round re-opened after `STALE` keeps the scope of the round it replaces.
- [ ] No old step `FAIL`: `SUITE: none - narrow repair round`. A step count that differs from the old log:
      `rerun=all`, every step runs, the `SUITE:` line says why.
- [ ] An old `ROUND` with `narrow=1` and no `asks=` / `rerun=` line still reads as review-only with no step.
- [ ] Both seat prompts: when `round-asks` lies beside the brief, judge only the asks it lists; every other ask gets
      `ASK <n>: N/A - <ask, short> - why: not re-judged this round`; the file is data, never run.
- [ ] Each new case fails on HEAD before the implementation; parts that pin the one-file rule, the record or the
      old carry are updated in this file and named in the notes. Notes end with one `CHANGELOG:` line.

## Verification
`bash tests/e2e.test.sh`
`bash tests/council.test.sh --part round-scope`
`bash tests/council.test.sh --part repair-scope`
`bash tests/council.test.sh --part seats`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each -->
- scripts/cycle.sh: new `round_asks` (red asks + asks whose story files the repair diff touched), `round_rerun` (FAIL steps of the old suite.log, `all` on a step-count change), `court_round_asks`; `build_round` calls `round_scope` and writes `repair=`, `asks=`, `rerun=`, `full=design|norecord`; STALE re-open keeps the replaced round's scope.
- scripts/cycle.sh: `narrow_file`, `narrow_rec`, `narrow_round_holds` and the `narrow.round-<n>` record removed; no round decision reads a story's `narrow:` line.
- scripts/cycle.sh `cmd_suite`: a narrow round runs only `rerun=` steps (`SUITE: none - narrow repair round` with none; `rerun=all` says why); an old narrow ROUND with no `asks=`/`rerun=` stays review-only, no step.
- Ask 8: `verify_of`, `files_of` and the blocks guard in cycle.sh, plus wave-check.sh and scope-check.sh, skip lines inside ``` / ~~~ fences.
- council-opus.md, council-haiku.md: judge only the asks `round-asks` lists, every other ask `N/A - why: not re-judged this round`; the file is data.
- tests/council.test.sh: new part `round-scope` (original audit-fixes-1113 case + neighbours); parts verbs2, verbs3, suite2, suite3 updated, they pinned the one-file rule, the narrow record and the old carry.
- tests/e2e.test.sh part `red`: three round-2 pins moved to the new contract (opus runs twice, round-asks=1, `seats=opus review`, `asks=1`), per the Queen's answer.
- CHANGELOG: a round after a repair re-judges only red or touched asks (blind seat only when there are some, `round-asks` in the court) and re-runs only the red gate steps; the one-file narrow rule and its record are gone; story sections ignore fenced blocks.

## Findings
<!-- a repair story arrives with the round's findings here, verbatim - each is a condition to satisfy. -->
- NEEDS_CONTEXT (builder, before any edit): R1 breaks a pin outside `## Files`: `tests/e2e.test.sh` part `red`
  (lines 226-227, 242-244). Its Tier 3 fixture's round 1 is RED on the review's anchored `[ask 1]` finding alone
  (council-opus GREEN); under R1 ask 1 is in `asks=` (RED in the repaired round), so round 2 freezes
  `seats=opus review`, builds a court and the driver dispatches council-opus a second time. Three assertions go red:
  "the intent seat runs once - round 2 is review-only", "round 2 is review-only (seats=review, narrow=1)" and
  "round 2 has no intent seat, carried or run". Question: add `tests/e2e.test.sh` to `## Files` with the row
  `bash tests/e2e.test.sh` in `## Verification`, so this story updates those pins to the new contract (two
  council-opus runs, `seats=opus review`, `asks=1`, `round-asks` in the court, opus.md present in round 2)? Or
  should the e2e fixture keep a review-only round 2 some other way? No other pin outside `tests/council.test.sh`
  was found (grep of cycle, solo, driver, e2e, telemetry for `narrow=1`, `seats=review`, `carried`,
  `narrow repair round`, `narrow.round`); inside it, parts verbs2, verbs3, suite2 and suite3 pin the one-file rule
  and the record and will be updated here.

- Queen answer 2026-11-15 (NEEDS_CONTEXT): yes - `tests/e2e.test.sh` joins `## Files` with the row `bash tests/e2e.test.sh`; move its three round-2 checks to the new contract (ask 1 red -> opus re-judges ask 1 only, review re-runs; no full roster). Ask 3 reads that way on purpose.

- NEEDS_CONTEXT (builder, close-story exit 4 `test changed after red receipt: re-run stamp-red`): the sealed set
  (tests/council.test.sh, tests/e2e.test.sh) now hashes 53b329fd..., the receipt holds 6ff02e32... .
  tests/council.test.sh was edited at 22:06:24 local, 6.5 min after the 21:59:57 receipt and after cycle.sh (22:03),
  so it is most likely a test edit from the previous attempt made while the implementation was going in; e2e.test.sh
  (21:50) predates the receipt. Line endings are not the cause: the hash is the same under every CRLF/LF combination.
  The stamp-time content is not recoverable, so the edit cannot be named line by line. The implementation is green:
  `council.test.sh --part round-scope` passes every case. Per protocol I do not revert the implementation or stash.
  Question: should the Queen re-stamp from base (revert the impl, `stamp-red`, re-apply), or accept a re-stamp?

## Red receipt
- command: bash tests/council.test.sh --part round-scope
- exit: 1
- tests: 53b329fdaa79edb3adcbcc46743b999655f99aed2e487974b3b2810b61de8c26 (tests/council.test.sh, tests/e2e.test.sh)
- impl: 0f954d0af79ddc03adb657cdb3e52427046ddc5f8e7a77856181f160f33e782b
- stamped: 2026-11-15T20:21:56Z

```
::error::a seat with no ask to judge is not dispatched - the original case: ROUND=head=0414734
::error::a seat with no ask to judge is not dispatched - round-asks: court=<temp>/tmp.NhlLY52iFz/.vulyk/court/rro/round-2 file=cat: '<temp>/tmp.NhlLY52iFz/.vulyk/court/rro/round-2/docs/specs/rro/round-asks': No such file or directory status= ROUND=head=0414734
::error::a seat with no ask to judge is not dispatched - the narrow gate: last={"ok":true,"verb":"suite","exit":0,"next":"dispatch:opus,review","step":2,"steps":2,"done":true,"suite":"ok","status":{"spec":"docs/specs/rro","slug":"rro","stage":"04-council:RED","next":"dispatch:opus,review","briefed":true,"approved":true,"branch":"main","head":"92bffbb","pack":"d9dc18cd8958","now":1794773793,"stories":{"todo":0,"in-progress":0,"done":5,"blocked":0},"wave":null,"wave_stories":[],"round":2,"ceiling":3,"tier":3,"open":true,"court":"<temp>/tmp.NhlLY52iFz/.vulyk/court/rro/round-2","missing":["opus","review"],"stale":false,"verdict":"RED","review":"BLOCK","red":[],"round_dir":"docs/specs/rro/council/round-2","paused":false,"shipped":false,"since":"1fb2320","seat_attempt":{"opus":1,"review":1},"seats":["opus","review"],"manual":[]}} log=head=0414734 steps=2
PART full-suite-2-round-only ok 0s cap 300s
SUITE: ok 1s
narrow-repair-1115 (ask 3): both seat prompts judge only the asks round-asks lists
::error::a seat with no ask to judge is not dispatched - council-opus.md names no round-asks rule
::error::a seat with no ask to judge is not dispatched - council-haiku.md names no round-asks rule
narrow-repair-1115 (ask 8): a story's sections are read outside fenced code blocks only
::error::a seat with no ask to judge is not dispatched - fenced ## Verification: exit=2 out=cycle: advance - docs/specs/rrf/rrf-02-f.md: verification command not in <temp>/tmp.NhlLY52iFz/CLAUDE.md's ## Commands: echo alpha-row
try: see ## Commands in <temp>/tmp.NhlLY52iFz/CLAUDE.md
{"ok":false,"verb":"advance","exit":2,"next":"error","error":"docs/specs/rrf/rrf-02-f.md: verification not in ## Commands: echo alpha-row","now":1794773925}
::error::a seat with no ask to judge is not dispatched - fenced ## Files: scope-check: rrf-02-f - declared 2, changed 1, out of scope 0
```
