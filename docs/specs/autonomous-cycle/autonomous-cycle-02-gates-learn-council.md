---
story: autonomous-cycle-02
spec: autonomous-cycle
status: todo
tier: 4
worker: worker-code
tracer: false
wave: 2
blocked_by: [autonomous-cycle-01]
---

# The existing gates learn the council: `ship-check.sh`, `human-check.sh`, `state.sh`, `lib.sh` consumers, `templates/plan.md`

## Goal
`ship-check.sh` closes stage 02 on `**Briefed:**` or `**Approved:**` and stages 04+05 on the newest `council.jsonl` row (or the acceptance row for pre-0.12 specs), with `**Checked:**` as the owner's override in both directions; `human-check.sh` keeps working as that override and no longer stales on council paperwork; `state.sh` reports `04-council:<verdict>` and `paused`; the four scripts that carried private copies of `pack_fingerprint`/`paperwork_only` source `scripts/lib.sh`; `templates/plan.md` carries the two new placeholders; `tests/cycle.test.sh` still passes and now walks the council path too.

## Requirements
> Совет = приёмка + стадия 05; lead-review остаётся. Совет заменяет drone-acceptance и человека (слепой взгляд «делает ли оно то, что просили»).

> Человек может включиться на любом этапе, если у него есть желание, но пока он сам желания не проявляет, система должна максимально быть автономной.

> Все «Принять» из таблицы входят в бриф: скрипт судит раунды, worktree-слепота, ## Asks, PAUSE, Briefed:, N/A, пороги.

> Система сама мержит vulyk/<slug> в default-ветку, обновляет CHANGELOG/версию/карту, печатает команду publish в лог и НЕ ждёт.

## Files
- scripts/ship-check.sh
- scripts/human-check.sh
- scripts/acceptance-log.sh
- scripts/release-check.sh
- scripts/state.sh
- templates/plan.md
- tests/cycle.test.sh

## Non-goals
- Do not edit `scripts/lib.sh` or `scripts/cycle.sh` (story 01 / 03 own them). If `lib.sh` lacks something you need, report it in `INTERFACES` - do not add a local copy.
- Do not change what `acceptance-log.sh` or `release-check.sh` do; the only diff there is `source "$(dirname "$0")/lib.sh"` replacing the private function bodies (keep the "must match exactly" comments pointing at `lib.sh` instead).
- Do not remove `human-check.sh` or its `--check`; do not make `**Checked:**` mandatory anywhere.
- Do not touch `tests/council.test.sh`, `.claude/`, docs or `CLAUDE.md`.
- Keep the gates report-only (always exit 0) - only `cycle.sh` has meaningful exit codes.

## Map slice
`docs/specs/autonomous-cycle/plan.md` `## Contracts` C1, C4, C7 · `docs/adr/001-cycle-state-contract.md` D1 (`paperwork_only` list, `**Checked:**` override), D4 last paragraph (ship-check stage 04+05 rule) · `docs/specs/autonomous-cycle/recon/scout-scripts.md` §Answer 1 (`marker()` at `ship-check.sh:59-64`, stage 05 read from `human.jsonl` at `:200-220`, how to add Briefed at `:124`), §Answer 2 (schemas, staleness), §Answer 3 (`state.sh` if-chain `:120-131`), §Answer 5 (which `cycle.test.sh` lines hardcode `**Checked:**`: 58-59, 62-64, 66-81, fixture copy at 27).

## Acceptance criteria
- [ ] `ship-check.sh`, `human-check.sh`, `acceptance-log.sh`, `release-check.sh` each `source "$(dirname "$0")/lib.sh"` (with `# shellcheck source=scripts/lib.sh`) and define no local `pack_fingerprint`/`paperwork_only`/`marker`.
- [ ] Stage 02: `ok` when `**Briefed:**` or `**Approved:**` has a non-placeholder value; `OPEN` when neither.
- [ ] Stages 04+05: `ok` when the newest `council.jsonl` row for the spec is `GREEN`, its `pack` equals the current fingerprint and its `head` is HEAD or only paperwork landed since; `OPEN` with a one-line reason on `RED`/`ESCALATE`/`STALE`, stale pack, or code commits since. With no council row, fall back to today's `acceptance.jsonl` + `human.jsonl` logic unchanged.
- [ ] `**Checked:** ACCEPTED` (newest `human.jsonl` row, `ts` newer than the council row) makes 04+05 `ok` over a RED row; `REJECTED` newer than a GREEN row makes it `OPEN`; the report prints both verdicts.
- [ ] `paperwork_only` (via `lib.sh`) treats `*/council/*`, `*/journal.md`, `memory/stats/council.jsonl` as paperwork: `human-check.sh --check` says `CURRENT` after a commit touching only those.
- [ ] `state.sh` emits `04-council:<verdict>` from the newest council row (between `03-built` and `05-*` in the chain) and `paused` when `<spec>/PAUSE` exists (below `06-shipped` only); existing stages unchanged.
- [ ] `templates/plan.md` has `**Briefed:**` after `**Approved:**` and `**Council:**` after `**Checked:**`, both `<placeholder>` values, comment above updated to say six lines.
- [ ] `tests/cycle.test.sh` copies `lib.sh` into its fixture, keeps every existing assertion green, and adds: READY on `Briefed` + GREEN row (no `Approved`, no `Checked`); NOT READY on a RED row; READY on RED + `Checked: ACCEPTED`; NOT READY on GREEN + `Checked: REJECTED`; `human-check.sh --check` CURRENT after a council-paperwork commit.

## Verification
`git ls-files '*.sh' | xargs -n1 bash -n && bash tests/cycle.test.sh`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
