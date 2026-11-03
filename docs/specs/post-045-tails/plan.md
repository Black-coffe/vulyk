# Tails after 0.45.0 (plan)

**Tier:** 2 · **Spec slug:** `post-045-tails` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-029 (gate split), ADR-026 (CI before ship), ADR-016 (constitution byte cap), card `test-gate-one-long-limit`, card `safeguard-bypassable-or-late`
**Depends on:** 0.45.0 at `d65bb82`; round-4 opus UNASKED in `docs/specs/gate-split/council/round-4/opus.md`

## Goal
Close the five gate tails the round-4 judge found outside the asks of `gate-split`, and add the process check whose
absence let 0.45.0 reach main with red CI. Gate: a review recorded without the round's suite log is refused with a
reason that names `cycle.sh suite`, not re-asked; a legacy `SUITE: TIMEOUT` line is a red suite (repair) and
`VULYK_SUITE_TIMEOUT` is read nowhere; `suite-parts-check.sh` refuses a missing file; PART names lose the trailing
hyphen; a step killed at 590 s names the parts that never ended. Constitution: the `Cycle` row runs by part, within
the 7168 B cap. Ship: `ship-check.sh` wants a green CI run on the branch head where a CI can run, and says why it
skipped where it cannot.

## Assumptions
- Order of the owner's list: this spec first, then the `weekly-budget` rebase onto the new main and its repair round 3,
  then the host-adaptation study (`/vulyk-plan` step 0, a report). Neither of the last two is a story here.
- Ask 1: `record-seat` for `review`, with a round-only full-suite row and no finished `suite.log` keyed to the round's
  head, exits 2 (not 4, so it is not a re-ask) with `no suite.log for round N at head H - run cycle.sh suite <spec>
  first, then record the same report again`. No attempt file is written, so the same report records once the gate ran.
  `lead-review.md` no longer tells the reviewer to write `SUITE: none`: with no log, it says so under `## Minor`, and
  `record-seat` writes the gate's line. The reviewer-reported `SUITE: ok|FAIL|TIMEOUT <N>s` check (fast-verification-07)
  goes: with a log the log's line wins (as today), without one the report is refused.
- Ask 2 (owner: «Считать как FAIL»): `judge` reads a stored `SUITE: TIMEOUT` line as `SUITE: FAIL`: review BLOCK,
  repair, never `suite-timeout`. The `suite_secs`/`suite_budget` read and its `- suite:` note go, and so does every
  `VULYK_SUITE_TIMEOUT` read in `scripts/` and `tests/` (a grep for it finds only CHANGELOG/ADR history). Old
  `suite-timeout` rows (two in `weekly-budget`) keep their status/reopen paths, and `escalate --reason suite-timeout`
  stays a valid manual reason. ADR-029's line about the fallback is rewritten to say nothing reads it.
- Ask 3: `suite-parts-check.sh` on a path that is not a readable regular file exits 2 with `suite-parts-check: no such
  file: <path>`, as `portability-check.sh` does for a named missing file; a readable file with no PART line stays 0
  (the defect gate runs every block check on any argument, so an unrelated file must pass). The card's `## Known gap`
  is closed with a dated line.
- Ask 4: a Purpose-built PART name is trimmed of leading and trailing hyphens, so `Full suite (round-only)` gives
  `full-suite-round-only`; the duplicate-name count uses the same trimmed form.
- Ask 5: `tests/full-suite.sh --step K` prints `PARTS K/S: <name> ...` before it starts the step, and PART lines come
  out as each part ends (completion order, as its header already says), not in index order. When `cycle.sh suite`
  kills a stepped step at 590 s, the STEP line's note names every listed part with no PART line:
  `timed out after 590s - no end from: <names>`, and `suite_verdict` carries those names.
- Ask 6: the `Cycle` row becomes `` | Cycle | `bash tests/cycle.test.sh --part <topic>` | `` (+15 B); the whole run
  stays reachable through the round gate (full-suite runs cycle by part). Paid for by the VULYK-only label
  `Model profile tests` -> `Model profile` (-6 B; `tests/model-profile.test.sh:189` asserts that row). Result about
  7163 B, under the `-lt 7168` test. Laws and Routing untouched (ADR-016).
- Ask 7 (owner: «Пропуск с причиной»): a new ship-check line `ci`: no `.github/workflows/*.y*ml` -> `ci: not checked -
  no CI workflow in this repo` (ok); no `origin` remote on github.com -> `ci: not checked - no GitHub remote` (ok);
  otherwise `gh run list --commit <sha> --json status,conclusion,workflowName` (verified on gh 2.91.0 here) on HEAD,
  or on the newest commit with only paperwork since (`paperwork_only`, as the council line uses): every run completed
  `success` and at least one run -> ok; none, pending, or any other conclusion -> NOT READY naming it; `gh` absent or
  failing -> NOT READY `cannot confirm CI: <why>`, never a silent pass. ship-check stays exit 0 (it reports).
- Who starts branch CI (a side-agent note, model text, raised that VULYK's `ci.yml` runs only on main, PRs and
  `workflow_dispatch`): `/vulyk-ship` gains one step - when ship-check says no run for the head, the Queen pushes the
  branch and runs `gh workflow run <workflow> --ref <branch>` itself (owner rule: push/release are mine to run), then
  waits for it. `ci.yml` is not changed: a trigger on every branch push would spend a Linux+macOS run on each story
  commit. Rejected: a branch-push trigger in `ci.yml`. The owner can veto this at approval.
- `## Needs a human` (owner: «Её закрыли раунд 4 GREEN и ваша приёмка»): no work. It reached my next-circle draft
  because `/vulyk-ship` step 5 hands that section over "when it has one", resolved or not; changing that is not asked
  and is left out.
- Story verification: story 01 lands the `Cycle` row first, so story 03 can name `bash tests/cycle.test.sh --part ship`.
  Until 01 is closed, `wave-check.sh` reports that line as `verify-cell` (checked 2026-11-03); after 01 it is a cell.
  The alternative, the whole `bash tests/cycle.test.sh`, is the over-300 s run this spec removes.
- Brief lines with no story: the request's header line, «Открытых нет» and the `## Needs a human` line: no work asked.

## Stories
**Wave 1**
- `post-045-tails-01` — Cycle row by part, Model profile label trimmed, byte cap kept (ask 6)

**Wave 2**
- `post-045-tails-02` — gate tails: record-seat refusal, TIMEOUT as FAIL, missing file refused, PART names, hung part named (asks 1-5)
- `post-045-tails-03` — ship-check `ci` line and the `/vulyk-ship` branch-CI step (ask 7)

## Contracts
- none

## Integration gate
`bash tests/full-suite.sh` (the `Full suite steps (round-only)` row, run by `cycle.sh suite`)

## Descoped
*(empty)*

## Plan deltas

<!--
The lines below are the cycle's confirmation markers (docs/cycle.md); scripts/ship-check.sh reads them all.
There is no default tier: `cycle.sh open-round` refuses to open a round while the `**Tier:**` line above
is missing or unparsable.
-->
**Approved:** Andrei, 2026-11-03 (branch-CI step in /vulyk-ship kept: the Queen pushes the branch and runs `gh workflow run`)
**Briefed:** <written by scripts/cycle.sh briefed - stage 01+02 on the straight-through path (--go, Tier 1): "via grill, <owner>, <date>" (or "via grill (assumed)" / "via mini-brief"). Alternative to **Approved:** above.>
**Branch:** vulyk/post-045-tails
**Checked:** <written by scripts/human-check.sh after the owner has looked - stage 05, and the override for stage 04+05. /vulyk-ship refuses without either this or a GREEN **Council:** line.>
**Council:** <written by scripts/cycle.sh judge/escalate - stages 04+05: "<GREEN|RED|ESCALATE|STALE> round <N>, <date>, at <sha7>, pack <fp12>[ - red: 2,5]", appended once per round.>
**Shipped:** <written by scripts/ship-check.sh --record - stage 06: the published version, and where>
