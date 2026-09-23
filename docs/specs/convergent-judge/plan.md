# Convergent council judge (plan)

**Tier:** 2 · **Spec slug:** `convergent-judge` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-001 (D4 verdict rule, the ROUND file, `council.jsonl` row shape, `reopen`), ADR-012 (gate model), `memory/map/cycle.md` (verdict rule, staleness/ceiling), personal memory `vulyk-install-sh-literal-cr-bytes` (install.sh carries literal CR bytes - binary-safe edits only, run the telemetry suite).
**Depends on:** v0.16.0 (`b36c0c2`); recon by `drone-scout`, 2026-09-23 (every `file:line` below is its).

## Goal
The judge stops counting rounds and starts measuring convergence. The ceiling follows the tier (1/2/3/3) instead of a flat 3; the same RED ask in two consecutive rounds escalates at once; a `lead-review` BLOCK only blocks when a blocking finding is anchored to a brief ask or a regression, and an unanchored one is recorded as PASS with its findings carried to the next circle; `lead-review` blocks on major as well as critical, so a PASS no longer smuggles product bugs past GREEN; and the installer stops shipping VULYK's own `council.jsonl`, cleaning the seeded `autonomous-cycle` rows out of hives on upgrade.

## Assumptions
- **A1 - tier to ceiling:** 1→1, 2→2, 3→3, 4→3, computed where `open-round` reads `council/CEILING` today (cycle.sh:1901) and in `status`'s default (:399). An existing `council/CEILING` file (written by `reopen`) still wins. `reopen` raises by the tier's ceiling, not by 3 (:2009-2016).
- **A2 - anchor syntax:** in `lead-review`'s report every critical or major finding carries exactly one tag on its line: `[ask N]`, `[regression]`, or `[unanchored]`. `judge` reads the body of `review.md` (not only its first line, :544-558): `VERDICT: BLOCK` with at least one `[ask N]` or `[regression]` tag stays BLOCK; `VERDICT: BLOCK` with none is recorded as review `PASS` and note `review BLOCK unanchored`. A tagged `[ask N]` naming an ask the brief does not have is treated as unanchored.
- **A3 - regression** means behaviour that worked on the branch's base and no longer does; `lead-review` names the base-side evidence (a test, a command) on the line. The judge checks only the tag, not the claim.
- **A4 - no-progress compares ask sets:** round N's set = seats' evidenced RED asks ∪ review's `[ask N]` anchors; round N-1's set is read from its `council.jsonl` row (`red` ∪ a new `review_asks` field). A non-empty intersection, when the round would otherwise be RED, gives `ESCALATE`, reason `no-progress`. It ranks after `half` and before `ceiling`. A STALE or ESCALATE N-1 row, or no N-1 row, never triggers it.
- **A5 - the new row field** `review_asks:[...]` is appended to the row (after `red_unevidenced`); older rows without it read as empty. ADR-001's row contract and reason enum (`ceiling|half|env|no-progress`) are amended in place.
- **A6 - "ship notes"** are the existing next-circle hand-off of `/vulyk-ship` step 5 (vulyk-ship.md:16), which today carries only `minor` findings; it will also carry every finding of an unanchored BLOCK. `/vulyk-build`'s repair row (vulyk-build.md:101) cuts stories only for anchored findings.
- **A7 - upgrade cleaning** touches only `memory/stats/council.jsonl` lines containing `"spec":"autonomous-cycle"`, only when `docs/specs/autonomous-cycle/` is absent in the target, and prints one line saying how many rows it removed. A new install gets no `council.jsonl` at all (`shippable` returns 2, as for `anomalies.jsonl`, install.sh:74). Other ledgers (`human`, `ship`, `scope`, `acceptance`) are out of scope.
- **A8 - the running `web-accounts-p0` build in wild-world-rpg** is not touched; hives pick this up on their next `/vulyk-update`.

## Stories

**Wave 1**
- `convergent-judge-01` — tier-scaled ceiling in `open-round`, `status` and `reopen`; constitution and cycle doc wording. (opus)
- `convergent-judge-03` — installer skips `council.jsonl`; `--upgrade` removes seeded `autonomous-cycle` rows. (opus)

**Wave 2**
- `convergent-judge-02` — anchored BLOCK: `lead-review` contract (major blocks, anchor tags), `judge` parses anchors and writes `review_asks`, repair and ship commands follow; ADR-001 amended. (opus)

**Wave 3**
- `convergent-judge-04` — `no-progress` escalation in `judge`, ADR-001 reason enum. (opus)

## Contracts
- `tier_ceiling <tier>` (cycle.sh, story 01): prints 1, 2, 3 or 3 for tiers 1-4; the one place the mapping lives. Story 04 does not call it.
- `review.md` finding line (story 02): a list line under a critical or major heading carrying `[ask N]`, `[regression]` or `[unanchored]`; the judge's anchor regex is `\[(ask [0-9]+|regression)\]`.
- `council.jsonl` row (story 02 writes, story 04 reads): new key `review_asks:[n,...]` right after `red_unevidenced`; note text `review BLOCK unanchored` when the downgrade fires.
- `escalate` reason enum (story 04): `ceiling|half|env|no-progress`.

## Integration gate
`git ls-files '*.sh' | xargs -n1 bash -n && bash tests/council.test.sh && bash tests/cycle.test.sh && bash tests/driver.test.sh && bash tests/telemetry.test.sh`

## Descoped

*(empty)*

## Plan deltas

**Approved:** <owner, date - stage 02, the unconditional gate. /vulyk-build refuses without this line.>
**Briefed:** <written by scripts/cycle.sh briefed>
**Branch:** <written by /vulyk-build before wave 1>
**Checked:** <written by scripts/human-check.sh>
**Council:** <written by scripts/cycle.sh judge/escalate>
**Shipped:** <written by scripts/ship-check.sh --record>
