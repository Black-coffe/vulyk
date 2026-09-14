---
story: v0-12-0-remainders-15
spec: v0-12-0-remainders
status: done
returned: DONE
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
- 2026-09-14 · The working tree already carried the six story-15 scenarios plus the `run_wall_probes` extension (`tests/council.test.sh:1855-2119`, +236/-4 uncommitted) from a prior interrupted attempt at this story (same "30-call cut" pattern recorded in `## Findings` below). Verified each scenario against story 05's six criteria and the suite's existing helper conventions, found them correct and non-duplicative of story 14's scenarios, and closed the story rather than rewriting - only frontmatter/notes are this pass's own edit.
- r2m3: scenario builds a locked `.git/index.lock`, asserts the first `--commit` fails (exit 2, `ROUND` on disk, tree dirty), then a clean second `--commit` exits 0, tree clean, and `ROUND`/`journal.md` are reachable via `git show HEAD:...` (committed, not silently reported as a no-op).
- r2m16: a fabricated `status: blocked` story asserts exit 2, `next:"open-round"`, `error` containing `"story r2m16a-02 is blocked: docs/specs/r2m16a/r2m16a-02-second.md"`, and no `council/` directory created.
- N-m3: an empty `council/round-1/` (no `ROUND` file) asserts `status --json` reports `open:false`/`next:"open-round"`; `open-round --commit` then writes `ROUND` into that same round-1 (asserted via `"next":"dispatch:sonnet"`, not a no-op line) with no `round-2/` created.
- r2m5/r2m6: two scenarios (`ceilred1` plain ceiling path via `mk_round`, `ceilstale1` STALE-fold path via `mk_open_round` + a real commit while the round is open) each fabricate a judged-RED round-1 row with `red:[2,5]` at `CEILING=1`, then assert the ESCALATE row carries `"red":[2,5]`, `plan.md` has one `- ask 2: RED - see` and one `- ask 5: RED - see` line, and `seats: <round-dir>/` names the round directory - both paths route through the same `write_escalate_row_for_round`, proven by identical assertions on both.
- r2m7/N-m2: one scenario taints the git identity env vars so the court reduction commit itself fails, asserting exit 2 with `error` `"court reduction commit failed"` and `council/round-1/` gone (never handed to a seat); a second scenario asserts by structure (grepping the 4 lines around `reduce the court to brief.md`) that the reduction commit carries `--no-verify` and `-c commit.gpgsign=false` and no `|| true`.
- r2m4/N-m1: chose the structural option named in the acceptance bullet over the single-pass-over-captured-lines option - one assertion counts every `emit false` call site in `scripts/cycle.sh` and confirms none is missing a non-empty `error` argument (superset of the specific sites named in story 05's map slice, since it scans all sites at once), and a second confirms all 3 literal `exit 6` sites pair with `emit true ... 6 escalated` (never `emit false`), plus the `ceilred1`/`ceilstale1` scenarios above each assert the ceiling's last line equals exactly `{"ok":true,"verb":"open-round","exit":6,"next":"escalated"}` on its four keys via `jq -e '{ok,verb,exit,next} == {...}'`.
- Regression proof: `run_wall_probes` was extended (kept as-is) with a variadic extra-probe-fn list rather than a second runner; `probe_r2m3`/`probe_r2m16`/`probe_nm3`/`probe_ceiling`/`probe_courtcommit`/`probe_exit6uniform` are each a compact re-run of the corresponding scenario's core assertion, invoked once against `git show b9f36e8:scripts/cycle.sh` copied into its own scratch repo and once against the branch's `scripts/cycle.sh` - branch's own `$T` fixture and working tree untouched throughout (own `mktemp -d`, own `git init`, per the non-goal).
- Observed labels (`bash tests/council.test.sh` full run, `tail`/`grep` of the captured log): `[b9f36e8]` all six of `probe_r2m3`/`probe_r2m16`/`probe_nm3`/`probe_ceiling`/`probe_courtcommit`/`probe_exit6uniform` → `FAIL`; `[branch]` all six → `ok`. No criterion was `ok` at `b9f36e8` (all six of story 05's fixes were genuinely absent there), so nothing needed the "observed, not forced" carve-out.
- Verification: `bash tests/council.test.sh` run once in full - exit 0, zero `::error::` lines; the only `FAIL` tokens in the captured output are the deliberate baseline-regression labels (5 `[3e200bb]` story-14 probes + 6 `[b9f36e8]` story-15 probes, all expected); every `[branch]` probe line (18 total across both `run_wall_probes` extensions) is `ok`.

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
- 2026-09-13 · two misses in run wf_ae57019b-aa9 (stamp 52574b7c6d9fc1a4), both "worker returned no report": each `worker-test` subagent made exactly 30 tool calls (transcripts agent-aa0421577cf3ce514, agent-a9315e1dcc77d089e - 159/151 events, both cut mid-read, nothing written to `tests/council.test.sh`). Not the suite runtime: neither attempt reached a suite run. Same 30-call cut is the likely cause of every earlier death (01 x2, 05 x2, 02, 07, 14 first attempts).
