---
story: driver-hardening-01
spec: driver-hardening
status: todo
returned:
tier: 3
worker: worker-code
model: sonnet
tracer: false
wave: 1
blocked_by: []
---

# Paperwork whitelist, self-marked close-story, story-file taint (asks 2, 3, 4)

## Goal
Three surgical fixes in the cycle's shell, each with suite cases. `is_paperwork_path` accepts `memory/stats/skills.json` and `memory/learnings/*.md`, so `open-round` no longer refuses `working tree not clean` on hook-written files and a commit of them never stales a round. `close-story` on a story whose worker wrote `status: done` itself proceeds down the normal path when the story's named files or the story file carry an uncommitted diff, journals that the worker self-marked, and still exits 2 `already done` on a clean tree. `taint_reason()` treats the story *file* (`<slug>-NN.md`, `<slug>/<slug>-NN`) as a leak and a bare `<slug>-NN` as none. Both worker agents are told `status:` is not theirs.

## Requirements
> skills.json и memory/learnings/*.md — бумаги цикла: не блокируют открытие раунда, не старят его.
> close-story принимает историю с самоотметкой status: done, если есть незакоммиченный дифф; воркеру сказано status: не трогать.
> Голый номер истории <slug>-NN — не утечка; утечка — файл истории и прежние пути.

## Files
- scripts/lib.sh
- scripts/cycle.sh
- tests/council.test.sh
- .claude/agents/worker-code.md
- .claude/agents/worker-test.md

## Non-goals
- Do not touch `scripts/ship-check.sh`, `scripts/scope-check.sh`, `tests/cycle.test.sh`: stage 03 and the scope gate keep today's behaviour (plan A1). If `bash tests/cycle.test.sh` goes red after the `lib.sh` edit, return NEEDS_CONTEXT - do not loosen or "fix" those tests.
- Do not stage or commit `skills.json` or learnings anywhere in `cycle.sh` (`commit_paperwork`, `close-story --commit`); they are whitelisted, not cycle-owned.
- Do not change the `docs/specs/*/` anchoring of the existing whitelist entries, and do not widen taint patterns 2-4.
- Do not add line-type parsing (`run:` vs `saw:`) to `taint_reason()`; one regex change.
- Do not touch `cmd_status`, `emit()`, or any verb's JSON shape - story 03 owns that in wave 2.
- Do not edit `cycle-clerk.md`, `vulyk-cycle.js`, `docs/`, `memory/`.

## Map slice
`docs/specs/driver-hardening/recon/cycle-sites.md` §1-3 (every line number); plan.md `## Contracts` C2, C3, C4, C7 and A1, A2, A6, A7; `memory/map/scripts.md` "Key types / contracts" (`is_paperwork_path`, `paperwork_only`) and "Gotchas"; `memory/map/cycle.md` "Seat report contract (D3)"; ADR-006 (`returned:` check order in `cmd_close_story`).

## Acceptance criteria
- [ ] C2: `is_paperwork_path memory/stats/skills.json` and `is_paperwork_path memory/learnings/2026-09-15-x.md` return true; `memory/learnings/sub/x.md`, `memory/stats/skills.jsonl`, `memory/learnings/x.txt` return false. Suite: `open-round` opens with only those two files dirty (beside tests/council.test.sh:1519-1525, which still refuses on a real dirty path); a commit touching only them between `ROUND.head` and HEAD leaves the round not stale (beside :676-698).
- [ ] C3: story `status: done`, `returned: DONE`, a named file modified but uncommitted -> exit 0, one new `story(<id>)` commit containing that file, `journal.md` gained one line containing `worker marked status: done itself`, `status:` still `done`. Same story, clean tree -> exit 2, `error` `already done`, no commit, no journal line (the existing case at :1105-1107 keeps passing; if its fixture tree is dirty for that story's files, fix the fixture, not the rule). `status: done`, dirty, `returned:` absent -> exit 4 `returned: missing`, no commit (the normal path runs).
- [ ] C4, `report_taint()` helper cases (:756-801): `demo-01` in a body -> **not** tainted (:764-766 updated); `demo-01.md` -> tainted; `demo/demo-14` and `docs/specs/demo/demo-14.md` -> tainted; the round-6 shape - a `run: bash scripts/telemetry.sh record x 1 0 --story demo-14` line plus a `saw: {"story":"demo-14"}` line - **not** tainted; every other existing taint case unchanged.
- [ ] C7: both agent files carry the one sentence; `worker-code.md:18` no longer says the driver reads the key.
- [ ] `git ls-files '*.sh' | xargs -n1 bash -n` silent.

## Verification
`bash tests/council.test.sh && bash tests/cycle.test.sh && git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes

## Findings
