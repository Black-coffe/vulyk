# The horizon step: five fixes from its first real run (plan)

**Tier:** 2 · **Spec slug:** `horizon-audit` · **Brief:** [brief.md](brief.md) · **Study:** [report.md](report.md)
**Governed by:** ADR-022 (the horizon step, amended here), ADR-013 (Light VULYK: no new script, no new gate), Law 2, Law 6
**Depends on:** study commit 6849876 `study(horizon-audit)`; horizon shipped in 0.35.0, agent load fix in 0.37.0

## Goal
The horizon step stays what it is. Five text edits close what its one real run (spec `symbol-map`) showed. The docs
say the court sees the owner's decisions, not proposals, and that `--horizon` overrides the no-question skip. Every
horizon answer in the brief carries a countable label. A proposal stays a gap only when the Queen names the request
item that fails without it. The lenses get the Profile rows in their dispatch. The question order inside the cap is
fixed. ADR-022 records what has not run yet and two triggers. `/vulyk-evolve` counts picks once three `horizon.md`
files exist.

## Assumptions
- Prompt and doc text only: `templates/grill.md`, `.claude/commands/vulyk-plan.md`, `.claude/agents/drone-horizon.md`,
  `.claude/commands/vulyk-evolve.md`, `docs/adr/022-horizon-step.md`, `CHANGELOG.md`. No script changes, so no
  suite can fail on the new wording. The story's verification is a regression guard for the plan and build
  mechanics and the size caps. Its acceptance criteria are checked by reading the diff, as in `horizon-intake`.
- Trigger 2 (a declined idea returns in `UNASKED`) is an ADR line only. No edit to `vulyk-ship.md` or to a seat
  prompt until it happens (study report, panel 2/3 on timing for a written trigger).
- The evolve line is silent below three `docs/specs/*/horizon.md` files and reads `## Answers` lines labelled
  `(horizon H`. Specs before this change have no label; `symbol-map` happens to have it.
- `docs/command-reference.md` and `docs/architecture.md` already state the `--horizon` override and stay as they are.
- Release 0.39.0 (ask 8) is ship work after GREEN: version, CHANGELOG heading, tag, push, GitHub release, leak check.
  No hive is upgraded (owner's answer 1); they get it with their next upgrade.

## Stories

**Wave 1** (the Queen builds; one reviewer per round)
- `horizon-audit-01` — the five edits, the three ADR-022 lines, the evolve counter line, the CHANGELOG entry.

## Contracts
- Answers label: `<n>. <header> (horizon H<k>): <picked option> - <its description>`, with the pick being
  `Добавить`, `Не добавлять`, or `(offered, not adopted)` in no-question mode.

## Integration gate
`bash tests/full-suite.sh`

## Descoped

*(empty)*

## Plan deltas

<!--
The lines below are the cycle's confirmation markers (docs/cycle.md); each placeholder is replaced by
the command or script that owns it, and scripts/ship-check.sh reads them all.
-->
**Approved:** Andrei, 2026-10-27 («ОДОБРЯЮ»)
**Briefed:** <written by scripts/cycle.sh briefed>
**Branch:** vulyk/horizon-audit
**Checked:** <written by scripts/human-check.sh>
**Council:** GREEN round 1, 2026-10-27, at b4ce15d, pack a69cc8878fb6
**Shipped:** 0.39.0, 2026-10-27, at 1cb04c2 - merged to main, publish pending
