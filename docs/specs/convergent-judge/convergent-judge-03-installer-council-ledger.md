---
story: convergent-judge-03
spec: convergent-judge
status: todo
returned:
tier: 2
worker: worker-code
model: opus
tracer: false
wave: 1
blocked_by: []
---

# Installer stops shipping council.jsonl, upgrade removes seeded rows (ask 5)

## Goal
A fresh install gets no `memory/stats/council.jsonl`; `install.sh --upgrade` removes the seeded `"spec":"autonomous-cycle"` rows from a hive's ledger when that hive has no `docs/specs/autonomous-cycle/`, and says how many it removed.

## Requirements
> `council.jsonl` исключается из установки, так же как уже исключён `anomalies.jsonl`.

> Заметил такую штуку, что в абсолютно любом проекте, где есть сидбулик, всегда он три цикла делает.

## Files
- install.sh
- tests/telemetry.test.sh

## Non-goals
- Do not exclude the other ledgers (`human`, `ship`, `scope`, `acceptance`) - out of scope (plan A7).
- Do not touch any other line of a hive's `council.jsonl`, and do nothing when `docs/specs/autonomous-cycle/` exists in the target (VULYK's own repo).
- Do not edit install.sh with a text-mode rewrite: it carries literal CR bytes (personal memory `vulyk-install-sh-literal-cr-bytes`) - use `Edit` or binary-safe tools and diff the byte count of untouched lines.
- Do not add a new test file or CI job; the install harness already lives in tests/telemetry.test.sh (:739+).

## Map slice
memory/map/scripts.md - install.sh entries; install.sh `shippable` (:59-77), `copy_tree` (:636), upgrade skip (:92-96).

## Acceptance criteria
- [ ] `shippable` returns 2 for `memory/stats/council.jsonl` (same class as `anomalies.jsonl`, :74); `--check` prints it as a runtime skip.
- [ ] `--upgrade` on a target whose `council.jsonl` holds `autonomous-cycle` rows and no `docs/specs/autonomous-cycle/` removes exactly those rows, keeps every other row byte-for-byte, prints `council.jsonl: removed <n> seeded autonomous-cycle row(s)`; `--check` reports it without writing.
- [ ] A target with `docs/specs/autonomous-cycle/`, or with no such rows, is left untouched and prints nothing about it.
- [ ] Tests cover fresh install (no file), upgrade cleaning, and the two untouched cases.

## Verification
`bash tests/telemetry.test.sh`

## Implementation notes

## Findings
