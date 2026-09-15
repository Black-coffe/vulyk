---
story: driver-hardening-06
spec: driver-hardening
status: todo
returned:
tier: 3
worker: worker-code
model: opus
tracer: false
wave: 5
blocked_by: [driver-hardening-01, driver-hardening-03]
---

# Repair: taint matches the real story-file shape, learnings dir form, self-mark journal, no error envelope in `status`

## Goal
Round 1 review Major 1, opus UNASKED (a), Minors 5, 6, 10, 12 - all in the cycle's shell and its suite. After this story: `taint_reason()` taints `demo-14-title.md` (the shape every story file in the repo actually has) while a bare `demo-14` and the round-6 `run:`/`saw:` shape stay clean; `open-round` in a hive whose `memory/learnings/` holds only untracked `.md` files is not refused on the collapsed `?? memory/learnings/` line; the self-mark journal line is written once, after verification is green, with the story's real wave as `next`; a verb's exit-0 line never embeds a `{"ok":false,"verb":"status",...}` envelope as `status`; and the C2 open-round case asserts the refusal message is absent.

## Requirements
> Голый номер истории <slug>-NN — не утечка; утечка — файл истории и прежние пути.
> skills.json и memory/learnings/*.md — бумаги цикла: не блокируют открытие раунда, не старят его.
> close-story принимает историю с самоотметкой status: done, если есть незакоммиченный дифф; воркеру сказано status: не трогать.
> Меняющие глаголы cycle.sh возвращают next в своём JSON, драйвер опрашивает статус только на старте.

## Files
- scripts/cycle.sh
- scripts/lib.sh
- tests/council.test.sh

## Non-goals
- Do not widen taint patterns 2-4, add line-type parsing, or change first-hit-wins order - one regex alternative changes (C4 revised).
- Do not make `is_paperwork_path` accept any other directory or a nested `memory/learnings/sub/x.md`; the one-level rule (A2) holds. The fix is `-uall` on the open-round `git status --porcelain` (C2 addendum) - do not touch `paperwork_only`, `ship-check.sh`, `human-check.sh`, `scope-check.sh`, `tests/cycle.test.sh`.
- Do not change what `close-story` journals, only where and with which `next`; do not add a second journal line for the commit.
- Do not change the `status --json` object or the exit-0 key order `ok, verb, exit, next, error, status`; do not touch the top-level `next` semantics story 03 delivered (verb-owned).
- Do not edit `vulyk-cycle.js`, `tests/driver.test.sh`, agent files, `docs/`.

## Map slice
`docs/specs/driver-hardening/recon/cycle-sites.md` §1-3; plan.md `## Contracts` C2 addendum, C3 revised, C4 revised, C5 addendum; `council/round-1/review.md` Major 1, Minors 5, 6, 10, 12; `council/round-1/opus.md` UNASKED (a); story 01 and story 03 `## Implementation notes` (where `emit_status`, the journal call and the regex now sit); `memory/map/scripts.md` "Gotchas".

## Acceptance criteria
- [ ] C4 revised, `report_taint()` cases: `demo-14-title.md`, `docs/specs/demo/demo-14-title.md`, `demo-14.md`, `demo/demo-14` -> tainted; bare `demo-14`, `demo-14-title` (no `.md`), and the round-6 `run: ... --story demo-14` + `saw: {"story":"demo-14"}` shape -> not tainted; every existing taint case unchanged. Reason text still says `story file`.
- [ ] C2 addendum: a scratch repo whose `memory/learnings/` contains only one untracked `x.md` (nothing tracked inside) -> `open-round --commit` is not refused; stderr/JSON carry no `working tree not clean` / `outside the cycle's own paperwork`. The same with an untracked `memory/learnings/sub/x.md` -> refused (one-level rule).
- [ ] Minor 12: the existing C2 open-round case (tests/council.test.sh ~1589-1596) asserts `! grep -qF 'working tree not clean'` (and the "outside the cycle's own paperwork" text) on the verb's output directly, beside its `tier` assertion.
- [ ] C3 revised: self-marked `status: done`, dirty, `returned: DONE`, wave 2 -> exit 0, exactly one journal line containing `worker marked status: done itself` whose `next` is `build:2`; self-marked, dirty, `returned:` absent -> exit 4 and `journal.md` byte-identical to before the call; a second call after a green close -> exit 2 `already done`, no new journal line.
- [ ] C5 addendum: `emit_status` emits the pre-C5 five-key line (no `status` key) when its `cmd_status` call exits non-zero or prints a line containing `"ok":false`; a suite case proves that no exit-0 line in the C5 walk has a `status` value with an `ok` key, and one direct case (source the function or call the verb with a spec whose `plan.md` was removed after the verb's write, whichever the suite already supports) proves the fallback shape.
- [ ] `git ls-files '*.sh' | xargs -n1 bash -n` silent; `bash tests/cycle.test.sh` still green.

## Verification
`bash tests/council.test.sh && bash tests/cycle.test.sh && git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes

## Findings
