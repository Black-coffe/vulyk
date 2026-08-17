# <Spec title> (plan)

**Tier:** <2|3|4> · **Spec slug:** `<slug>` · **Brief:** [brief.md](brief.md)
**Governed by:** <ADRs, DESIGN.md sections, wiki notes that constrain this work>
**Depends on:** <prior specs / merged work this plan builds on, with commits if known>

## Goal
<one paragraph - restate the goal in the planner's words. The verbatim words live in
brief.md; this is the interpretation, and divergence between the two is reviewable.>

## Assumptions
<!-- Law 1: every assumption the plan rests on, stated so the human can veto it at the
approval stop. An assumption nobody confirmed is a defect, not a default. -->
- <...>

## Stories
<!-- One line per story, grouped by wave. The story files are the truth; this list is
the human-readable index of it. -->

**Wave 1**
- `<slug>-01-...` — <one line>

## Contracts
<!--
Interfaces that cross a story boundary, agreed HERE at plan time: function signatures,
message shapes, route paths, event names. Two workers building against each other's
story must both read the same contract from this section - neither invents it mid-build.
A worker whose story forces a contract change reports it in its INTERFACES line; the
Queen updates this section and records the change under ## Plan deltas.
-->
- <...>

## Integration gate
<!-- The full quiet suite the Queen runs after the last wave, from ## Commands in
CLAUDE.md, plus `bash scripts/wave-check.sh docs/specs/<slug>` before each dispatch. -->
`<command>`

## Descoped
<!-- Mid-build narrowing, appended by the Queen as it happens - never silent. Each line:
what was dropped, why, and the single line quoted from the human authorizing it. Only
the human removes a requirement. -->

*(empty)*

## Plan deltas
<!--
Queen-written, from a worker's RETURN REPORT (never from a diff), one entry per change
to the plan after approval: new story cut, story files expanded, contract changed.
Each entry: date, trigger, decision, what was rejected. One-line notice to the human
when it happens. trace-check.sh accepts these entries as a quote source for stories
born after approval - a delta is requirement change on the record.
-->

**Approved:** <owner, date - the unconditional gate. /vulyk-build refuses without this line.>
