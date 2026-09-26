# <Spec title> (plan)

**Tier:** <1|2|3|4> · **Spec slug:** `<slug>` · **Brief:** [brief.md](brief.md)
**Governed by:** <ADRs, DESIGN.md sections, wiki notes that constrain this work>
**Depends on:** <prior specs / merged work this plan builds on, with commits if known>

## Goal
<one paragraph - the goal in the planner's words. The verbatim words live in brief.md; this is the
interpretation, and divergence between the two is reviewable.>

## Assumptions
<!-- Law 1: every assumption the plan rests on, stated so the owner can veto it at the approval
stop. -->
- <...>

## Stories
<!-- One line per story, grouped by wave; the story files are the truth, this is their index.
Tier 1-2 (solo): the Queen builds the stories herself, in order, and one reviewer judges each round.
Tier 3-4 (hive): one worker per story; a wave's workers run in parallel, so their ## Files are
disjoint. A story earns its own worker only when it can run in parallel; fewer, larger stories are
cheaper. -->

**Wave 1**
- `<slug>-01-...` — <one line>

## Contracts
<!--
Tier 3-4: interfaces that cross a story boundary, agreed here at plan time - function signatures,
message shapes, route paths, event names - so two workers building against each other read the same
contract. A worker whose story forces a change reports it in its INTERFACES line; the Queen updates
this section and records it under ## Plan deltas. Tier 1-2: usually "none".
-->
- <...>

## Integration gate
<!-- The full quiet suite from ## Commands in the constitution. lead-review runs it once per round;
wave-check.sh runs before each wave. -->
`<command>`

## Descoped
<!-- Mid-build narrowing, appended as it happens - never silent. Each line: what was dropped, why,
and the owner's line authorizing it, quoted. Only the owner removes a requirement. -->

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
**Briefed:** <written by scripts/cycle.sh briefed - stage 01+02 on the straight-through path (--go, Tier 1): "via grill, <owner>, <date>" (or "via grill (assumed)" / "via mini-brief"). Alternative to **Approved:** above.>
**Branch:** <written by /vulyk-build before wave 1 - stage 03: the branch every story commit lives on>
**Checked:** <written by scripts/human-check.sh after the owner has looked - stage 05, and the override for stage 04+05. /vulyk-ship refuses without either this or a GREEN **Council:** line.>
**Council:** <written by scripts/cycle.sh judge/escalate - stages 04+05: "<GREEN|RED|ESCALATE|STALE> round <N>, <date>, at <sha7>, pack <fp12>[ - red: 2,5]", appended once per round.>
**Shipped:** <written by scripts/ship-check.sh --record - stage 06: the published version, and where>
