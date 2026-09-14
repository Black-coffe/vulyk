---
story: v0-12-0-remainders-06
spec: v0-12-0-remainders
status: done
returned:
tier: 4
worker: worker-code
tracer: false
wave: 2
blocked_by: [v0-12-0-remainders-02]
---

# The Workflow driver's stops say what happened

## Goal
Every terminal the driver returns names the real cause: a two-miss stop carries the failing verification's own `error`; a Tier 4 run without a distinct `second_model` refuses at launch; a launch with no `args` reaches the guard, not a `TypeError`; a whitespace-only worker report is a miss; a `record-seat` exit 3 ends the run as `paused`; `next:"briefed"` stops the run instead of stamping `**Briefed:**`; an exit-6 `ok:true` line is followed by a `status` poll that ends as `escalated`. Each is a scenario in `tests/driver.test.sh` that fails first.

## Requirements
> стоп после двух промахов несёт настоящую ошибку (M2/X-M1)

> Tier 4 без second_model отказывает на старте (X-M4)

> гоняет драйвер с подменёнными agent/parallel/clerk по сценариям мажоров (два красных промаха, нет second_model на Tier 4, нет args, пробельный отчёт)

> оба драйвера одинаково отвечают на next:briefed (r2m15)

> record-seat exit 3 — терминал paused (r2m17)

> каждый ok:false несёт error, exit 6 значит одно и то же везде (r2m4/N-m1)

## Files
- .claude/workflows/vulyk-cycle.js
- tests/driver.test.sh

## Non-goals
- Nothing about `returned:`/M3 here - ADR-006 changes no driver code; story 09 adds its scenarios.
- No `claim`/`release`/`--stamp` (story 13).
- Do not touch `/vulyk-build` or `/vulyk-review`; the fallback already refuses `briefed` and already appends the verb's `error` on a blocked story.
- Do not add verdict, ceiling or staleness logic; do not read `st.tier` before the first `status` (it is unknown until then).
- Do not change the fold, the seat prompts, the delimiter or the repair block.
- Do not remove the `stamp` narrator line (round-3 minor 8, next circle).

## Map slice
`recon/tests-ci-hooks-driver.md` §4 (arg guards `:25-31`, build loop `:108-132`, `recordSeat` `:142-146`, stop shapes, `asStop`) · `plan.md` K1 (exit 3/exit 6 lines), K2 (stop shapes - build exactly these), K4 (`run(args, script)`, stub queues) · `plan.md` `## Assumptions` (r2m15: the driver refuses) · round-3 `review.md` major 2, X-M1 (`:121-130`), X-M4 (`:27,85-89`), minor 5, minor 6 (`:25-31`), X-m5 (`:121`), `## Next circle` r2m4 (`vulyk-cycle.js:117`), r2m15 (`:88-90`), r2m17 (`:130-136`).

## Acceptance criteria
- [ ] Two-miss stop: a per-file `lastError` beside `attempts`; an exit-4 `close-story` stores its line's `error`, an empty/null/whitespace report stores `'worker returned no report'`; the second miss ends with `{verb:'build', file, error:<lastError>}`. Scenarios: red+red -> the verification line text; empty+red -> the verification text; red+empty -> `'worker returned no report'`.
- [ ] `typeof r !== 'string' || r.trim() === ''` is a miss; `close-story` is not called for `'   '`.
- [ ] `args` undefined -> `{stop:{verb:'launch', error}}` with zero clerk calls (read `args` through `args ?? {}` or equivalent before the stamp guard).
- [ ] After the first `status` and before any non-clerk `agent()`: `st.tier === 4 && (!SECOND || SECOND === TOP)` -> `{stop:{verb:'launch', error:'second_model missing or equal to top_model on a Tier 4 spec'}}`; scenarios for missing and for equal; a Tier 3 run with no `second_model` proceeds.
- [ ] Any clerk line with `exit === 3` (scenario: `record-seat` answering `{"ok":false,"exit":3,"next":"paused","error":"paused: ..."}`) ends the run with `next === 'paused'` and no `stop`.
- [ ] `next:"briefed"` -> `{stop:{verb:'briefed', error:'spec not briefed: run /vulyk-plan'}}`; no clerk call contains `briefed --commit`.
- [ ] `open-round` answering `{"ok":true,"exit":6,"next":"escalated"}` is followed by a `status` poll; with `status` scripted `next:"escalated"` the run ends `next === 'escalated'`, no `stop`.
- [ ] Each build thunk catches a thrown worker `agent()` and logs `worker threw: <message>` before returning null, so a dead subagent leaves its reason in the run journal; the stop text `worker returned no report` and K2 are unchanged. Scenario: an `agents` entry that throws -> a `logs` entry starting `worker threw:` and the miss counted as before.
- [ ] The second-attempt worker prompt carries one extra sentence: "a previous attempt may have left uncommitted edits in your files; `git diff` them first". Scenario: after one miss the second `agent()` call's `prompt` contains that sentence and the first call's does not.
- [ ] Each scenario is asserted to fail against the driver at `3e200bb` before the change (note which); `bash tests/driver.test.sh` passes; story 26's greps stay clean (`GREEN`/`RED`/`stale`/`paperwork` outside comments, `worker-code` count 0, no `EOF` delimiter, `stamp` absent from seat prompts).

## Verification
`bash tests/driver.test.sh`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->
- `.claude/workflows/vulyk-cycle.js`: `args ?? {}` guard before any `args.*` read; a `Paused` control-flow class thrown from `clerk()` on any `exit:3` line, caught at the top and returned as `{next: e.next}` (no `stop`) - centralizing this in `clerk()` covers open-round/close-story/record-seat/judge/briefed/branch alike, not just record-seat.
- Tier 4 guard (`st.tier===4 && (!SECOND||SECOND===TOP)`) placed right after the terminal check, before the `next` dispatch chain, so it runs every poll (tier is unknown before the first status) but before any non-clerk `agent()`.
- `next:'briefed'` now `fail()`s immediately instead of ever calling `clerk('briefed --commit')`; `branch` unchanged.
- Build loop: added a per-file `lastError` map (set to the close-story line's own `error` on an exit-4 miss, or `'worker returned no report'` on an empty/null/whitespace report) fed into the two-miss stop; the falsy-report check became `typeof report === 'string' && report.trim() !== ''` so `'   '` counts as a miss without calling `close-story`; each build thunk now does `agent(...).catch(e => {log('worker threw: '+msg); return null})` so a dead subagent's reason lands in the run journal; a per-file retry (`attempts.get(file)>=1`) appends one sentence about a possible uncommitted diff to the second dispatch's prompt only.
- `tests/driver.test.sh`: added an `agent` stub extension - a `{throw:'<msg>'}` queue entry rejects instead of resolving, to simulate a dead subagent without changing `parallel`'s own catch - plus 11 new `run()` scenarios (d-p) and their `expect` lines, covering every acceptance criterion above.
- Verified each new scenario against the pre-change driver (`git stash` the driver edit only, rerun the new test file): scenarios d/e/g/h/i/j/k/l/m/n/o/p all failed (explicit `FAIL` lines or an uncaught `TypeError: Cannot read properties of undefined (reading 'spec')` for the `args undefined` case, which also halted the promise chain for every scenario after it - confirmed by re-running each pair (d,e) and (g) individually as `FAIL` before the crash point).
- Working-copy line endings: the file was CRLF on disk before this session (git `core.autocrlf=true`); edits landed as LF, `git diff --stat` shows a normal 58-line diff (not a whole-file rewrite), consistent with the CRLF/LF normalization already called out in plan.md `## Next circle`.

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
