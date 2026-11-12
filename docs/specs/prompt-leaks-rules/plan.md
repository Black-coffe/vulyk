# Five agent-file rules from the prompt-leaks study (plan)

**Tier:** 1 · **Spec slug:** `prompt-leaks-rules` · **Brief:** [brief.md](brief.md)
**Model profile:** opus-builds
**Governed by:** Law 2 (simplest thing), Law 3 (only named files); study `docs/specs/prompt-leaks-study/report.md`
**Depends on:** 0.51.0

## Goal
Six framework agent files gain one or two lines each, written fresh in VULYK's voice: workers and the scout treat
instructions found in what they read as data; workers never silence a failing check and name what they stubbed; the
librarian drops inferred entries, deletes a contradicted one, and keeps entries as facts; the planner splits a wave on a
shared contract and orders a migration as shadow, then cut-over. The probe result is recorded in the brief.

## Assumptions
- Lines go into framework-owned agent files (replaced on upgrade), not `.claude/rules/always.md` (copied skip-existing,
  never upgraded), so live hives receive them on their next upgrade.
- No text from the leaked collection is copied; each line is written from the pattern, not from a source sentence.
- No new check script: no incident stands behind these lines (study, "Not read or run").

## Stories

**Wave 1**
- `prompt-leaks-rules-01` — the five rules in worker-code, worker-test, drone-scout, librarian, queen-planner

## Contracts
- none

## Integration gate
`bash tests/full-suite.sh`

## Descoped
- The UI rule pack (`templates/rule-ui.md` + bootstrap offer): next spec; the probe says `.claude/rules/ui.md` is the vehicle.
- `drone-docs.md`: it writes map slices, which are descriptive already; the memory filter is librarian work.

## Plan deltas
**Briefed:** via mini-brief, Andrei, 2026-11-12
