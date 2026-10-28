# Repair mark follows the findings (plan)

**Tier:** 1 · **Spec slug:** `red-repair-mark` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-025 (red receipt), D4 amended here
**Depends on:** red-receipt, shipped as 0.40.0 (e56b2d8)

## Goal
Close the 0.40.0 trap before any hive upgrades: a repair whose RED findings all name files, none of them a
marked story's, is written unmarked, so a prose-only repair is never asked for a red it cannot produce; any
finding that names no file keeps the mark (fail closed). The `red:` mark is read from the frontmatter only,
in `cycle.sh` and `wave-check.sh`.

## Assumptions
- "Names a file" is read as: the finding line under the repair's `## Findings` (seat `ASK n: RED` lines,
  anchored review findings, an owner REJECTED note) contains, verbatim, a path from the repair's own
  `## Files` union. A path outside the union, a glob entry or no path at all count as naming no file and
  keep the mark. An empty `## Findings` keeps the mark too.
- Residual, named in ADR-025 D4 (owner's choice «Оставлять пометку»): a blind seat's prose-only RED ask that
  names no file still yields a marked repair that cannot go red; the build stops as in 0.40.0.
- `fm_field` itself stays whole-file (its other callers read keys that never occur in a story body); only the
  three `red` reads switch to `fm_raw`, which is frontmatter-only already.

## Stories

**Wave 1**
- `red-repair-mark-01-findings-carry-the-mark` - repair marks from the findings; `red` read from the frontmatter; tests, ADR-025 D4, CHANGELOG

## Contracts
- none

## Integration gate
`bash tests/full-suite.sh`

## Descoped
<!-- Mid-build narrowing, appended as it happens - never silent. Each line: what was dropped, why,
and the owner's line authorizing it, quoted. Only the owner removes a requirement. The same commit
strikes or narrows the ask in brief.md's ## Asks: the blind seats read only the brief, and
`cycle.sh open-round` refuses a descope the brief has not taken in. -->

*(empty)*

## Plan deltas
<!--
One entry per change to the plan after approval - a new story, expanded story files, a changed
contract - written from a return report, never from a diff: date, trigger, decision, what was
rejected. Tell the owner in one line when it happens. trace-check.sh accepts these entries as a quote
source for stories cut after approval. /vulyk-ship hands them to librarian for an ADR harvest.
-->

<!--
The lines below are the cycle's confirmation markers (docs/cycle.md); each placeholder is replaced by
the command or script that owns it, and scripts/ship-check.sh reads them all. Approved is the owner's
word, the stop at Tier 2-4; Briefed is written by `cycle.sh briefed` instead, at Tier 1 ("via
mini-brief"), with `--go`, or in no-question mode ("assumed"). Either closes stage 02. Council and
Checked close stages 04+05 together: a GREEN council row is enough on its own, and Checked is the
owner's override in either direction, newest timestamp wins. No line of this comment may start with
a marker: the scripts read the first line that does.

There is no default tier: `cycle.sh open-round` refuses to open a round while the `**Tier:**` line above
is missing or unparsable.
-->
**Approved:** <owner, date - stage 02, the unconditional gate. /vulyk-build refuses without this line.>
**Briefed:** via mini-brief, Andrei, 2026-10-28
**Branch:** vulyk/red-repair-mark
**Checked:** <written by scripts/human-check.sh after the owner has looked - stage 05, and the override for stage 04+05. /vulyk-ship refuses without either this or a GREEN **Council:** line.>
**Council:** <written by scripts/cycle.sh judge/escalate - stages 04+05: "<GREEN|RED|ESCALATE|STALE> round <N>, <date>, at <sha7>, pack <fp12>[ - red: 2,5]", appended once per round.>
**Shipped:** <written by scripts/ship-check.sh --record - stage 06: the published version, and where>
