---
story: v0-12-0-remainders-15
spec: v0-12-0-remainders
status: todo
returned:
tier: 4
worker: worker-test
tracer: false
wave: 4
blocked_by: [v0-12-0-remainders-05]
---

# The council suite proves the six `open-round` fixes of story 05

## Goal
`tests/council.test.sh` gains one scenario per story 05 criterion - the no-op branch commits, a blocked story is refused by name, a round directory without `ROUND` is not open, the ceiling block carries its RED rows on both the plain and the STALE-fold path, the court reduction commit is real and fails loudly, every `ok:false` carries `error` and exit 6 is uniform - each shown to fail against the `cycle.sh` of `b9f36e8` and to pass against the one story 05 committed. The code is already on the branch; this story is the evidence.

## Requirements
> no-op ветка open-round коммитит незакоммиченный ROUND (r2m3)

> каждый ok:false несёт error, exit 6 значит одно и то же везде (r2m4/N-m1)

> блок потолка несёт RED-строки и имеет тест (r2m5, r2m6)

> коммит редукции суда без || true, с --no-verify и без подписи (r2m7/N-m2)

> open-round отказывает blocked-истории (r2m16)

> каталог раунда без ROUND не читается как открытый (N-m3)

## Files
- tests/council.test.sh

## Non-goals
- Do not edit `scripts/cycle.sh`. A scenario red against the branch is a wall: record the failing assertion under `## Findings` and return `WALL`; do not patch the script or weaken the assertion.
- Do not add scenarios for `close-story`, `wave_stories` or the semaphore (stories 08, 11 own those); do not touch story 14's six scenarios or its probe block.
- Do not restructure the suite's helpers (`mk_spec`, `mk_open_spec`, `mk_round`, `mk_open_round`, `write_seat`, `seat_report`, `expect`, `run_wall_probes`); add scenarios in the existing shape and extend the probe runner with a second pinned version rather than writing a second runner.
- Do not use `git stash` or checkout to reach `b9f36e8`; the branch's working tree stays untouched by the proof.
- Run the suite once, at the end, as `bash tests/council.test.sh | tail -3`; its full output is resent every turn.
- Write `returned: DONE` as your last edit; never write `status:` (story 09's rule).

## Map slice
`memory/map/cycle.md` (`open-round`, staleness/ceiling, court D5, `status --json` `open`) · `recon/tests-ci-hooks-driver.md` §1 (suite shape, helpers, `oceil1`/`ceil1` fixtures, `mk_open_round`, `write_seat`, `lockfail1` for the `index.lock` pattern, "To add one scenario") · story 05 `## Acceptance criteria` (the six behaviours) and its `## Implementation notes` (which criteria the kept diff already held) · story 14 `## Implementation notes` (the `run_wall_probes` shape: one scratch repo per version, `git show <sha>:scripts/cycle.sh` copied in) · `plan.md` K1.

## Acceptance criteria
- [ ] r2m3 scenario: first `open-round --commit` fails on an `index.lock`; lock removed; second `open-round --commit` exits 0 and `git status --porcelain docs/specs/<slug>` is empty - `ROUND` and `journal.md` are committed, not reported as a no-op.
- [ ] r2m16 scenario: a spec with one `status: blocked` story; `open-round` exits 2, last line has `ok:false`, `next:"open-round"`, `error` containing `is blocked:` plus the story id and file; `council/` is absent.
- [ ] N-m3 scenario: `council/round-1/` created without `ROUND`; `status --json` reports `open:false`, `next:"open-round"`; `open-round` then writes `council/round-1/ROUND` (no `round-2/`, no no-op line).
- [ ] r2m5/r2m6 ceiling scenario: a RED round N-1 with `red:[2,5]`, a code commit, `open-round` at N = ceiling: the ESCALATE row carries `red:[2,5]`, the `## Needs a human` block has one `- ask 2:` and one `- ask 5:` line with the evidence clause, `seats:` names `council/round-<N-1>`. A second scenario reaches the STALE-fold ceiling path (stale round folded at the ceiling) and asserts the same three facts.
- [ ] r2m7/N-m2 scenario: a court whose hooks path holds a `pre-commit` exiting 1; `open-round` exits 2 with `error` naming the reduction commit and the court directory is gone; a second scenario asserts by structure that the reduction commit line contains `-c commit.gpgsign=false` and `--no-verify` and no `|| true`.
- [ ] r2m4/N-m1 scenario: every last line the suite captures satisfies `jq -e '.ok or (.error|length>0)'` (a single pass over the captured lines, added where `expect` collects them, or an explicit assertion per `ok:false` site named in story 05's map slice); the ceiling `open-round` last line equals `{"ok":true,"verb":"open-round","exit":6,"next":"escalated"}` on its four keys.
- [ ] Each scenario is proven to fail at `b9f36e8` without touching the working tree: `run_wall_probes` (or the same shape) runs these scenarios with `git show b9f36e8:scripts/cycle.sh` copied into a scratch repo in place of `scripts/cycle.sh`; `## Implementation notes` records the `FAIL` labels observed there and the `ok` labels on the branch - a scenario that is `ok` at `b9f36e8` is recorded as observed, with the reason, never forced.
- [ ] `bash tests/council.test.sh` passes whole on the branch; every pre-existing scenario unchanged.

## Verification
`bash tests/council.test.sh`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
