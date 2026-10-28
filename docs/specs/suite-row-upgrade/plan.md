# Upgrade names a missing canonical full-suite row (plan)

**Tier:** 1 · **Spec slug:** `suite-row-upgrade` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-023 (fast story checks, one full suite per round), ADR-005 D3 (the Commands block is the hive's)
**Depends on:** fast-verification (0.36.0)

## Goal
The fast/full split of 0.36.0 reaches hives bootstrapped before it. The upgrade reports a Commands block with no
canonical `Full suite / build (round-only)` row, `/vulyk-update` has the Queen rename the hive's own full-suite row to
that canon (its command kept), and the stale audit note and ADR status are brought up to date.

## Assumptions
- The installer only reports; it never rewrites a filled Commands block (ADR-005 D3). The rename is the Queen's edit inside the owner-approved upgrade.
- The report keys on the canonical spelling, not on guessing which row is the hive's full suite: a non-English row is reported too, and the Queen recognises it.

## Stories

**Wave 1**
- `suite-row-upgrade-01` — install.sh note + /vulyk-update step + test in the `constitution` part; report 7.3 and ADR-023.

## Contracts
- none

## Integration gate
`bash tests/full-suite.sh`

## Descoped

*(empty)*

## Plan deltas

**Approved:**
**Briefed:** via mini-brief, Andrei, 2026-10-28
**Branch:** vulyk/suite-row-upgrade
**Checked:**
**Council:**
**Shipped:**
