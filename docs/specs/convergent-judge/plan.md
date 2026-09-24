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
- **A9 - a STALE fold is not a judged round (repair, 2026-09-24):** the ceiling of ask 1 counts verdicts, not dispatches. ADR-001's invariant "STALE rounds with a seat file count toward the ceiling" is reversed by story 05 - an owner's mid-round commit costs the seats' tokens but never a tier's only verdict. Needs the owner's nod: it is a contract change on the record.
- **A10 - review minors folded, not cut (repair, 2026-09-24):** minors 3, 4, 6 (cycle.sh comment, ADR-001 ceiling numbers, tag scope) ride in story 05 and minor 5 (driver banner, two docs) in story 06 because each sits in a file that story already owns this wave and each is ask-1/ask-3 residue, not new work. Minors 7-12 go to `/vulyk-ship` step 5 untouched. Strike any fold the Queen disagrees with before dispatch.

## Stories

**Wave 1**
- `convergent-judge-01` — tier-scaled ceiling in `open-round`, `status` and `reopen`; constitution and cycle doc wording. (opus)
- `convergent-judge-03` — installer skips `council.jsonl`; `--upgrade` removes seeded `autonomous-cycle` rows. (opus)

**Wave 2**
- `convergent-judge-02` — anchored BLOCK: `lead-review` contract (major blocks, anchor tags), `judge` parses anchors and writes `review_asks`, repair and ship commands follow; ADR-001 amended. (opus)

**Wave 3**
- `convergent-judge-04` — `no-progress` escalation in `judge`, ADR-001 reason enum. (opus)

**Wave 4** (repair, round 1)
- `convergent-judge-05` — ceiling counts judged rounds, a STALE fold burns none (review major 1); anchor tags read only on critical/major list lines (minor 6); ADR-001, `reopen` comment and `docs/cycle.md` lose every flat 3 (minors 3, 4). (opus)
- `convergent-judge-06` — Workflow driver's repair prompt carries the same anchor rule as vulyk-build.md:101 (review major 2); driver banner, `docs/pipeline.md`, `docs/architecture.md` lose "ceiling 3" (minor 5). (opus)

## Contracts
- `tier_ceiling <tier>` (cycle.sh, story 01): prints 1, 2, 3 or 3 for tiers 1-4; the one place the mapping lives. Story 04 does not call it.
- **Judged rounds** (cycle.sh, story 05): the ceiling C is compared against the number of this spec's `council.jsonl` rows whose `verdict` is not `STALE` - ESCALATE rows count, STALE rows never do. `open-round` escalates `ceiling` iff judged >= C; `judge` turns a RED into ESCALATE `ceiling` iff judged + 1 >= C. `status`'s `round` stays the `round-*` directory count. `reopen` still raises C by `tier_ceiling`.
- `review.md` finding line (story 02, scope fixed by story 05): a list line (`- `, `* `, `N. `) between a `## Critical` or `## Major` heading (case-insensitive) and the next `## ` heading, carrying `[ask N]`, `[regression]` or `[unanchored]`. The judge's anchor read is exactly this - a tag in prose, in a header, or under any other heading is text, never an anchor. This line is the single statement of the rule; ADR-001 D4 and `lead-review.md` point at it.
- `council.jsonl` row (story 02 writes, story 04 reads): new key `review_asks:[n,...]` right after `red_unevidenced`; note text `review BLOCK unanchored` when the downgrade fires.
- `escalate` reason enum (story 04): `ceiling|half|env|no-progress`.
- **Repair prompt** (story 06): both drivers hand `queen-planner` the vulyk-build.md:101 sentence - one story per critical and per major finding whose fix is local and that carries `[ask N]` (N in the brief's `## Asks`) or `[regression]`; an `[unanchored]` finding never becomes a story, it waits for `/vulyk-ship` step 5; never phrased as addressing asks that are not there.

## Integration gate
`git ls-files '*.sh' | xargs -n1 bash -n && bash tests/council.test.sh && bash tests/cycle.test.sh && bash tests/driver.test.sh && bash tests/telemetry.test.sh`

## Descoped

*(empty)*

## Plan deltas
- **2026-09-24, repair after round 1 (review BLOCK, no ask numbered).** Trigger: `council/round-1/review.md` - two majors, both tagged `[unanchored]`; the ledger row shows `review_asks:[]`, `note:""`, yet `review:"BLOCK"` held: `review_has_regression` matched the literal `[regression]` the reviewer wrote in prose (its own minor 6), so the round judged RED instead of the PASS-with-note story 02 intended. Decision: two stories in wave 4 - 05 (major 1 + minors 3, 4, 6) and 06 (major 2 + minor 5); disjoint files; minors 7-12 to ship notes. Tradeoffs: (05) chose "ceiling counts judged rounds" over "document that a STALE fold burns a round" - the latter keeps ADR-001's invariant but lets a Tier 1 spec escalate with no verdict on record, which is the owner's complaint ("принимай решение ты") reproduced with zero evidence; (06) chose copying vulyk-build.md:101 verbatim into the driver over extracting the sentence into a shared file both read - one sentence does not pay for a new file and a loader in a logic-free driver. Assumptions A9, A10 added. Contract "review.md finding line" narrowed from the body-wide regex to critical/major list lines. Open: the reviewer's `[unanchored]` tags mean vulyk-build.md:101 would have cut nothing here; the harness prompt (old wording) asked for one story per major and both majors tie to asks 1 and 3 verbatim, so they were cut - the Queen decides whether that stands. After ship, `memory/map/cycle.md` "Staleness / ceiling" (rows 73-77) is stale and needs the librarian.

**Approved:** Andrei, 2026-09-23
**Briefed:** <written by scripts/cycle.sh briefed>
**Branch:** vulyk/convergent-judge
**Checked:** <written by scripts/human-check.sh>
**Council:** RED round 1, 2026-09-24, at b29c46d, pack 69dc98d46660
**Council:** ESCALATE round 2, 2026-09-24, at d89806b, pack 437cadda76db
**Shipped:** <written by scripts/ship-check.sh --record>

## Needs a human
- reason: ceiling · round 2 · 2026-09-24
- seats: docs/specs/convergent-judge/council/round-2/
