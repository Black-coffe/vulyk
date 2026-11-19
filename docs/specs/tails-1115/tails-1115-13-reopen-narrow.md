---
story: tails-1115-13
spec: tails-1115
status: done
returned: DONE
tier: 3
worker: worker-code
model: opus
wave: 4
blocked_by: [tails-1115-01]
red: required
red_reason: a reopened no-progress round is narrow
red_verified_at: 2026-11-17T14:01:01Z 6d70c3169118eaeb3e51eeece685f1983d7553cff6385330b8a4262642cd73f5
---

# Reopen: a repeated red gets a narrow round, a full one only on the owner's word

## Goal
The owner's 2026-11-16 choice «Узко, полный по вашему слову (Рекомендую)» on ADR-040 D1. Today `round_scope`
(`scripts/cycle.sh`) answers `full design` for any round that escalated as `half` or `no-progress` once the owner
reopened it. After this story:
1. A reopened `no-progress` answers `narrow`. Its `asks=` holds every ask red in the repaired round (seat or
   review) and every touched one, as for any narrow round, so a repeated red can never drop out of scope.
2. `cycle.sh reopen <spec> "<decision>" --full` records the owner's word that it is a design fault (a `full`
   field on the round's `council/REOPEN` line); `round_scope` then answers `full design`, whatever the reason.
3. A reopened `half` stays `full design`, with or without `--full`.
4. ADR-040 carries a dated amendment (D1); card `full-round-for-a-narrow-fix` says the same in its Never/Allowed
   lines (keep every owner quote and fixture as it is); `/vulyk-build` Terminal `escalated` and `/vulyk-review`
   name `--full` as the owner's design-fault word, never added without it.

`model: opus`: a judgment change in the round contract of a 5000-line script. Marked red: a branch that decides
whether the next round is full.

## Requirements
> 13. A reopened `no-progress` escalation gets a narrow round (the reviewer on the repair's diff, the blind seat over every red ask and every touched one); a full round follows only when the owner says at reopen that it is a design fault (`cycle.sh reopen ... --full`); a reopened `half` stays a full round.
> 10. Every fix that code can check gets a failing test with the original case and a neighbour form; all suites green.

## Files
- scripts/cycle.sh
- tests/council.test.sh
- docs/adr/040-repair-rechecks-what-it-repaired.md
- docs/defects/full-round-for-a-narrow-fix.md
- .claude/commands/vulyk-build.md
- .claude/commands/vulyk-review.md
- tests/solo.test.sh

## Non-goals
- Touch only `round_scope`, `cmd_reopen` and the usage line; not `close-story`, `red_gate`, the run-state helpers
  or anything guards-1115 owns.
- `full=asked` (`open-round --full`) and `full=norecord` keep their meaning.
- An old `council/REOPEN` line with no `full` field reads as no `--full`.
- Edit `tests/council.test.sh` only in parts `round-scope`, `round-scope2` and `repair-scope`; `tests/solo.test.sh`
  only where it pins `reopen`. `tests/cycle.test.sh` is story 09's this wave: run its `bsd` part (it calls `reopen`),
  never edit it; a pin there that breaks is `NEEDS_CONTEXT`.
- `docs/cycle.md` is story 11's: leave a `DOCS:` line for it.

## Map slice
`memory/map/cycle-state.md` → "Repair (ADR-013 D4)", "Seats and the verdict"; `memory/map/cycle.md` → Verbs
(`reopen`).

## Acceptance criteria
- [ ] Original case (narrow-repair-1115 round 2): a round that escalated `no-progress` on asks 5 and 8, reopened
  without `--full`, opens a round with `narrow=1`, `asks=` holding 5 and 8, and no `full=` line. The label contains
  `a reopened no-progress round is narrow`.
- [ ] Neighbours: the same round reopened with `--full` opens `full=design`; a reopened `half` opens `full=design`
  with or without `--full`; a reopened `ceiling` stays narrow; a REOPEN line written before this release (no
  `full` field) on a `no-progress` row reads as narrow.
- [ ] `cycle.sh reopen` with `--full` on a non-ESCALATE row is refused as today; `--full` twice for one round is
  idempotent.
- [ ] `bash scripts/defects-check.sh` stays green, with the card's fixtures still failing its check.
- [ ] Every new case fails on HEAD; the notes list them.

## Verification
`bash tests/council.test.sh --part round-scope`
`bash tests/council.test.sh --part round-scope2`
`bash tests/council.test.sh --part repair-scope`
`bash tests/solo.test.sh`
`bash tests/cycle.test.sh --part bsd`
`bash scripts/defects-check.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each. End with one `CHANGELOG:` line
and a `DOCS: <file> - <sentence>` line for each doc sentence story 11 must change (docs/cycle.md). -->
- scripts/cycle.sh: `round_scope` answers `full design` for a reopened round whose REOPEN line has `full=1` (any reason) or whose reason is `half`; a reopened `no-progress` is narrow. `cmd_reopen` takes `--full` (dispatcher parses it), writes `round=<n> full=0|1 · <ts>`, a later `--full` upgrades the round's line in place; usage line names `[--full]`.
- Decision: a plain reopen writes `full=0` explicitly so a pre-release line (no field) is a distinct, tested form; it reads as `full=0`.
- tests/council.test.sh: shared helpers gain `RR_REOPEN_FULL`, `RNL`, `rnp_fail`, `rnp_narrow`; part round-scope gains the no-progress chain (original, old REOPEN line, --full twice); round-scope2 gains half --full, ceiling --full, --full refusal (split so neither part grows by five fixture chains).
- Fixture shape: the original case uses asks 1 and 2 (the round-scope fixture spec has 4 asks), not 5 and 8.
- Failing on HEAD (red log): original, old REOPEN line, --full (full=design + idempotency), ceiling --full. Passing on HEAD by nature: half --full (half was already full) and the non-ESCALATE refusal (unchanged guard) - kept as neighbours that pin today's behaviour.
- The old-line neighbour is read at `repair` time (the repair story's `narrow: true` line is round_scope's answer), then the new line is put back before round 3 opens - saves one fixture chain.
- docs/adr/040: dated D1 amendment + an inline pointer in D1; card Never/Allowed lines reworded, quotes and fixtures untouched; vulyk-build/vulyk-review name `--full` as the owner's word.
- tests/solo.test.sh: no edit needed (its reopen pin still passes).
- Timing (this Windows box, two parts in parallel): round-scope 211 s, round-scope2 167 s.
CHANGELOG: `cycle.sh reopen --full` records the owner's design-fault word; a reopened `no-progress` escalation now gets a narrow round over every repeated red ask, not a full one (ADR-040 D1 amendment).
DOCS: docs/cycle.md - the `reopen` verb takes `--full` (owner's design-fault word, `full=1` on the council/REOPEN line); the round after a reopened `no-progress` is narrow, `full=design` only for a reopened `half` or a `--full` reopen.

## Findings
<!-- a repair story arrives with the round's findings here, verbatim - each is a condition to satisfy. -->
- close-story exit 4: `edited outside ## Files: memory/map/agents-and-commands.md, memory/map/cycle-close.md,
  memory/map/cycle-repair.md, memory/map/cycle-state.md, memory/map/cycle.md, memory/memory.md - committed since the
  claim head 8bdd6ac0`. None are this story's edits: they are the Queen's commit 4658299b ("docs(map): slices within
  80 lines and 130 chars (tails-1115 Queen step before wave 4)"), landed after the claim head. Needs the claim head
  moved past 4658299b (or that commit excluded from scope), then close-story re-run; the story's work is complete and
  its verification parts were green before close.

## Red receipt
- command: bash tests/council.test.sh --part round-scope
- exit: 1
- tests: 6d70c3169118eaeb3e51eeece685f1983d7553cff6385330b8a4262642cd73f5 (tests/council.test.sh, tests/solo.test.sh)
- impl: 49664bcbf7b8c3095095d32694ede7977e4a33cf1efe540c9758e469d05a88cc
- stamped: 2026-11-17T14:01:01Z

```
::error::a reopened no-progress round is narrow - no --full: ROUND=head=4111c27
::error::a reopened no-progress round is narrow - old REOPEN line: repair story docs/specs/rnp/rnp-06-repair-round-2.md: ---
::error::a reopened no-progress round is narrow - --full: exit=0 ROUND=head=d027884
pack=c2141314b43f
opened=2026-11-17T13:53:13Z
court=<temp>/tmp.r2rX5IyhzP/.vulyk/court/rnf/round-3
ceiling=6
tier=3
seats=opus review
since=41aa4f0
repair=rnf-06
full=design files=ROUND  out={"ok":true,"verb":"open-round","exit":0,"next":"dispatch:opus,review","now":1794923594,"status":{"spec":"docs/specs/rnf","slug":"rnf","stage":"04-council:ESCALATE","next":"dispatch:opus,review","briefed":true,"approved":true,"branch":"main","head":"f5c2f7c","pack":"c2141314b43f","now":1794923594,"stories":{"todo":0,"in-progress":0,"done":6,"blocked":0},"wave":null,"wave_stories":[],"round":3,"ceiling":6,"tier":3,"open":true,"court":"<temp>/tmp.r2rX5IyhzP/.vulyk/court/rnf/round-3","missing":["opus","review"],"stale":false,"verdict":"ESCALATE","review":"BLOCK","red":[],"round_dir":"docs/specs/rnf/council/round-3","paused":false,"shipped":false,"since":"41aa4f0","seat_attempt":{"opus":1,"review":1},"seats":["opus","review"],"manual":[]}} stderr= REOPEN=round=2 · 2026-11-17T13:53:02Z ceil=6/6
  ok    no committed record: full=norecord, one stderr line
```
