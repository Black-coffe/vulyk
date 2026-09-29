# ADR-016: The constitution budget test caps both VULYK's own CLAUDE.md and the shipped render

- Status: proposed
- Date: 2026-09-29
- Spec: docs/specs/auto-maintenance

## Context
From plan.md `## Plan deltas`, verbatim:

> **2026-09-29, story 01 - the budget premise was half wrong.** The study (report §7) and the approval question said CLAUDE.md breaks ADR-013's cap. Measured while building: the constitution a host receives (both marked blocks swapped for install.sh placeholders) is 6 266 B / 93 lines, inside the cap; only VULYK's own copy was over, because of VULYK-only Commands rows. Decision: the test caps both the repo file (the owner's choice, "Подрезать до 7 KB") and the shipped render (ADR-013's real subject), and the trim came mostly from VULYK-only rows. Also removed two version mentions from `## Models and effort` (the owner's floor rule: versions live only in `model_floor`), crossing story 01's Non-goal on Models wording. Rejected: capping only the shipped render (the owner chose the trim); cutting Laws or Routing (owner-approved text that every host loads).

ADR-013 (D7) sets the cap (~7 KB, 120 lines) on the constitution hosts load. Its text did not say whether VULYK's own copy, with VULYK-only rows, is held to it too.

## Options
1. Cap both the repo CLAUDE.md and the shipped render - chosen; the owner asked for the trim.
2. Cap only the shipped render - rejected: the owner chose the trim of the repo file.
3. Meet the cap by cutting Laws or Routing - rejected: owner-approved text that every host loads.

## Decision
The budget test holds two files to ADR-013's cap (≤ 7 168 B, ≤ 120 lines, CR stripped): VULYK's own `CLAUDE.md` and the constitution rendered for a host. Deciding factor: the owner's explicit choice ("Подрезать до 7 KB"), with the shipped render as ADR-013's real subject.

## Consequences
Not recorded beyond the delta: the trim came mostly from VULYK-only Commands rows, so VULYK-only rows now compete for the same budget as host text.

## Invariants created
- Any change to CLAUDE.md must keep both the repo file and the host render within the caps in the test.
- Raising a cap is a visible diff to the test's numbers, paid by owner-signed evidence (plan A5).
- Laws and Routing are not the first place to cut when the budget is tight.

## Revisit when
Not recorded.
