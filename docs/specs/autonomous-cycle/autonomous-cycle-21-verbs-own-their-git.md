---
story: autonomous-cycle-21
spec: autonomous-cycle
status: todo
tier: 4
worker: worker-code
tracer: false
wave: 10
blocked_by: [autonomous-cycle-20]
---

# The verbs own their git: the ceiling leaves a record, `scope.jsonl` is paperwork, failures surface, verification comes from `## Commands`

## Goal
`open-round` at the ceiling writes the ESCALATE record itself and `escalate` can record a stop for a round nobody dispatched, so `status` says `escalated` instead of looping. `close-story --commit` commits the ledger it wrote, and the whitelist names every file the cycle writes — anchored to `docs/specs/*/` — so the first `open-round` after a real `close-story` opens. A verb that could not check out, commit or build its court says so with exit 2 and writes no marker claiming otherwise. `close-story` runs only commands the hive's `## Commands` table lists, one per line, and fails on any of them. The court's reduction is committed inside the worktree so an orientation `git status` is clean.

## Requirements
> Потолок 3 раунда → стоп и зов человека

> После 3 красных раундов — система пишет walls в plan.md, печатает «нужен человек: вот что не сходится» и останавливается.

> Стори коммитятся на ветке vulyk/<slug> как сейчас (проверка — тест стори + scope-check).

> `memory/stats/scope.jsonl`, which `close-story` writes through `scope-check.sh` and does not commit (its commit is scoped to the story's `## Files`), must be either committed by `close-story` or whitelisted by `paperwork_only` and `open-round`'s clean-tree check, with a test that runs `close-story --commit` then `open-round` without an intervening `git add -A`.

> A ceiling reached at `open-round` (the STALE-fold path at line 1318, and the fresh-round gate at 1328) must leave an ESCALATE row and `## Needs a human` on disk so `status` says `escalated`, and a driver must end the run on any `"ok":false` clerk result instead of looping.

> `escalate` must be able to record an escalation for a round that was never dispatched.

> The plan must name and constrain the fact that `close-story` runs a story's `## Verification` through `bash -c` under the clerk's allow rule - e.g. require the command to be one of the Profile's `## Commands` rows, as the seats already are

> a `## Verification` block with more than one command must fail the story if any of them fails.

> a `cycle.sh` verb must not report success, or write the marker that claims it, when the git operation it depends on failed.

> the paperwork whitelist must match only paths the cycle itself writes, not any path in a hive that happens to share those names.

> `open-round` commits the reduction inside the court (detached), so an orientation `git status` is clean and `HEAD:docs/specs/<slug>/plan.md` no longer resolves.

## Files
- scripts/cycle.sh
- scripts/lib.sh
- tests/council.test.sh
- tests/cycle.test.sh

## Non-goals
- Do not touch `cmd_status`'s derivations (story 19) or the parsing/verdict rules (story 20); call them.
- Do not build the `DRIVER` claim/lock (delta 6, R27 — next circle) and do not add `--stamp` to any verb.
- Do not change `scope-check.sh`, `journal.sh`, the gate scripts or the allow rules; do not add a new allow rule.
- Do not read `.gitignore` or parse `CLAUDE.md` beyond the `## Commands` table rows (the backticked command cell of each `| … | \`…\` |` row).
- Do not touch the driver, commands, agents or docs.

## Map slice
`scripts/cycle.sh` — `cmd_open_round` (`build_round`, `clean_court`, the two ceiling gates, the STALE fold), `cmd_judge`/`escalate` alias (`cmd_escalate`), `cmd_close_story` (`verify_of`, the `bash -c` call, the scoped `git add`), `cmd_branch`'s checkout, every `git commit … || true` site · `scripts/lib.sh` `paperwork_only` whitelist (C1) · `tests/council.test.sh` — `open-round`/`close-story`/ceiling/`reopen` scenarios, the synthetic `.gitignore` · `tests/cycle.test.sh` — the `*/council/*` paperwork assertion (story 02) · `plan.md` delta 6: R4, R5, R11, R15, R17, R18, R23 · ADR-001 D1 "Resume and atomicity", D2, D5.

## Acceptance criteria
- [ ] `close-story --commit` stages `memory/stats/scope.jsonl` with the story's `## Files` and the story file; test: `close-story --commit` on a todo story, then `open-round` with no `git add -A` in between, exits 0 and the tree is clean after both.
- [ ] `lib.sh` whitelist (C1 amended): `docs/specs/*/plan.md`, `docs/specs/*/journal.md`, `docs/specs/*/council/*`, `docs/specs/*/brief.md`, `memory/stats/{human,acceptance,ship,council,scope}.jsonl`; a fixture commit to `src/council/x` or `src/journal.md` is not paperwork (it stales a round; `human-check.sh --check` says STALE in `cycle.test.sh`), the story-02 council-commit assertion still says CURRENT.
- [ ] `open-round` at the ceiling (fresh gate and STALE fold): writes a `council.jsonl` row `verdict:"ESCALATE"`, `escalate:"ceiling"`, `round` = the last judged round, the `**Council:** ESCALATE round N…` line, `## Needs a human` per C7 and the journal line; `--commit` commits them; exit 6 `{"ok":false,…,"next":"escalated"}`; a second call adds nothing; `status` then says `escalated`. Test with `council/CEILING` = 1.
- [ ] `escalate <spec> [--commit] [--reason <ceiling|half|env>] ["<note>"]`: on an open round with seats missing → ESCALATE row for that round with the given reason (default `env`) and note, court removed, `## Needs a human`, journal, exit 6; with nothing missing → identical to `judge`; under PAUSE → exit 3.
- [ ] Git failures: `branch` exits 2 and writes no `**Branch:**` when the checkout fails (fixture: the branch is checked out in a second worktree); a `--commit` whose `git commit` fails (fixture: `.git/index.lock` present) exits 2 with `error` naming `git commit`, leaves the paperwork on disk, and the re-run after unlocking commits it; `open-round` leaves no `ROUND` behind when `git worktree add` fails (`ROUND` is written last).
- [ ] `close-story` verification (C2 amended): each `## Verification` line is one command; every `&&`-separated segment must equal a command cell of the `## Commands` table in the hive's `CLAUDE.md` (a `\|` in a cell is a `|`), else exit 2 `error: "verification not in ## Commands: <segment>"`; the literal `none — reviewed by lead-review` runs nothing (scope-check still runs); lines run one at a time and any failure exits 4 naming that line — fixture block `false` then `true` exits 4. Fixture repos write a `CLAUDE.md` with a `## Commands` table holding the commands the fixtures use.
- [ ] Court: after pruning, `open-round` commits the reduction inside the worktree (detached, with a local identity so a fixture without `user.name` works); `git -C <court> status --porcelain` is empty, `git -C <court> show HEAD:docs/specs/demo/plan.md` fails, the main repo's HEAD is unchanged, `judge` still removes the court.
- [ ] Both suites green, exit 0, no `::error::`.

## Verification
`git ls-files '*.sh' | xargs -n1 bash -n && bash tests/council.test.sh && bash tests/cycle.test.sh`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
