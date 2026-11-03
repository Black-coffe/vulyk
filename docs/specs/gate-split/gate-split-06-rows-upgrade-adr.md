---
story: gate-split-06
spec: gate-split
status: done
returned: DONE
tier: 3
worker: worker-code
wave: 3
blocked_by: [gate-split-03, gate-split-04]
---

# The rule written down: VULYK's row, the hive upgrade text, the plan template, ADR-029

## Goal
The new gate is described where people and hives read it. VULYK's `CLAUDE.md` row becomes
`| Full suite steps (round-only) | bash tests/full-suite.sh |` (the word `steps` opts into the stepped protocol; no
bytes added under the ADR-016 cap). `install.sh` upgrade text (407-422 area) tells a hive that the round gate runs each
`Full suite ... (round-only)` row as one part under a 300 s cap, that it may list several such rows, and that a part
over 210 s is red; `install.sh` copies the whole `scripts/` tree (line 1311), so `scripts/suite-parts-check.sh`
ships with no list change. `/vulyk-update` step 6 (lines 40-44), which today tells a hive to rename its row to
`Full suite / build (round-only)`, also says it may split that row into several capped rows.
`templates/plan.md` `## Integration gate` (line 37) describes the stepped gate. ADR-029 records the decision
(crossgrill 3/3 + owner answers), amending ADR-001's suite-timeout contract, ADR-023's one-suite-in-`lead-review`
and ADR-024's suite clause.

## Requirements
> 9. В проектах на VULYK свой «полный прогон» можно разбить на несколько строк-частей с лимитом 300 с на каждую, и при обновлении об этом сказано.
> Давай запомни, построй запрет, разрешение, правила раз и навсегда.

## Files
- CLAUDE.md
- install.sh
- .claude/commands/vulyk-update.md
- docs/adr/029-gate-split.md
- docs/adr/001-cycle-state-contract.md
- docs/adr/023-fast-story-checks-full-suite-per-round.md
- docs/adr/024-no-reliance-on-background-commands-in-subagents.md
- tests/telemetry.test.sh

## Non-goals
- Do not rewrite a hive's constitution on upgrade: the text tells, the owner splits (cards `upgrade-overwrites-host-edits`,
  owner rule: upgrade keeps the host constitution).
- Do not touch `memory/` (drone-docs maps it at ship) or the defect card (`gate-split-01`).
- `tests/telemetry.test.sh` only for asserts on the row text or the upgrade text (recon question 2); no new parts.

## Map slice
memory/map/scripts.md `## install.sh - the upgrade contract`; memory/map/cycle.md `## Verbs` (Full-suite line);
plan.md `## Contracts` and `## Assumptions`; docs/adr/001-cycle-state-contract.md (63, 131-134, 140, 160-170),
docs/adr/023 (13), docs/adr/024 (9-29).

## Acceptance criteria
- [ ] `CLAUDE.md` row renamed as above; `CLAUDE.md` stays within the ADR-016 cap (the budget test is green).
- [ ] `install.sh --upgrade` prints the hive note once per upgrade, in the existing notice style; a hive
      constitution is not edited by it. A fresh install's hive template row (`install.sh` 264) stays
      `Full suite / build (round-only)`: one part until the owner splits it.
- [ ] `/vulyk-update` step 6 names the split: several `Full suite ... (round-only)` rows, each one part under 300 s.
- [ ] The hive note also says: every story `## Verification` line runs under a 300 s cap (`VULYK_VERIFY_TIMEOUT` above
      300 acts as 300); a row over ~210 s must be cut into `--part` rows before the hive takes this release.
- [ ] ADR-029 (`Status: accepted`, date, spec) states the decision, the six crossgrill points and the owner's three
      answers, and the rejected alternative from plan.md; ADR-001, 023 and 024 each get a dated `Amended by ADR-029`
      note at the clauses it changes, their old text kept.

## Verification
`bash tests/telemetry.test.sh --part install`
`bash tests/telemetry.test.sh --part constitution`
`bash tests/telemetry.test.sh --part constitution2`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes
- CLAUDE.md row renamed; install.sh prints the gate-split note once per --upgrade (after the constitution chain); vulyk-update step 6 names the split; ADR-029 added, ADR-001 (D3, D2/D6), 023, 024 amended. templates/plan.md was already done by story 04 (plan delta 3); no telemetry test edit needed.

## Findings
