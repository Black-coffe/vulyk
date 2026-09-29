# ADR-018: Every red defect finding splits new from old by git blame

- Status: accepted (owner, 2026-09-30)
- Date: 2026-09-29
- Spec: docs/specs/hindsight-harvest (v0.23.0)

## Context
ADR-014 D3 split old from new by git blame for one finding only: debt. v0.23.0 added three more red
findings (C4 overlap, C5 undeliverable, C11 escape). The plan extended the same split to all of them.

`docs/specs/hindsight-harvest/plan.md`, `## Assumptions`:

> **"New" follows the debt rule.** It means committed after the commit that added `docs/defects/README.md` (git blame
> committer time); uncommitted counts as new. Anything older is reported on an `I` line and never fails. Without
> this rule, `lead-review`, which runs the audit, would fail an upgraded host for cards it already had.

`docs/specs/hindsight-memory/report.md`, `## Accepted package`:

> Every new red (C4, C5, C11) needs the new/old split by blame, because `lead-review` runs the audit. Without it, the next upgrade turns a host red in review over pre-existing cards.

## Options
none recorded - the delta states the chosen shape only. (For C4 alone the board's votes show that some
members wanted red for every exact overlap and others wanted info only. The 2:1 result kept the blame split.)

## Decision
Any finding in `scripts/defects-check.sh` that can fail the gate is red only for material that is new by
blame. That means material committed after the commit that added `docs/defects/README.md`, using git blame
committer time and never a date written in the text. Uncommitted material counts as new. Older material
goes on an `I` line and never fails. The deciding factor: `lead-review` runs the audit, so an upgrade must
not turn a host red over cards it already had.

Exception already on record: C11 `ESCAPE` compares blame times within one card (quote vs `check:`/`fixtures:`),
and it is red from day one with no report-only stage (ADR-014 D4).

## Consequences
not recorded

## Invariants created
- A new red check in the defect gate must take its new/old cut from blame time against the README's commit.
  It may not use a date in the text, and it may not skip the cut.
- Old material yields an `I` line, never a failure.
- Uncommitted counts as new.

## Revisit when
not recorded
