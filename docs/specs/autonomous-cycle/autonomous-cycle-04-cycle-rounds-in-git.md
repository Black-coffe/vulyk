---
story: autonomous-cycle-04
spec: autonomous-cycle
status: todo
tier: 4
worker: worker-code
tracer: false
wave: 3
blocked_by: [autonomous-cycle-03]
---

# `cycle.sh` rounds in git: `open-round` and the court, STALE, `close-story`, `reopen`, `--commit`

## Goal
A round is opened as a directory in git and a reduced worktree on disk, goes stale when code lands on it, counts against a ceiling that `reopen` can raise, and is closed by `judge` removing its court; stories are closed by one verb that runs the scope gate and the story's verification and commits. All of it under the PAUSE guard and tested.

## Requirements
> Спека целиком, перед мержем. Стори коммитятся на ветке vulyk/<slug> как сейчас (проверка — тест стори + scope-check). Совет собирается один раз на весь пак перед мержем в default. Фиксы — новые стори на той же ветке, совет повторно.

> Стори, implementation notes, отчёты воркеров — скрыты.

> Потолок 3 раунда → стоп и зов человека.

> И так пока всё будет зеленое, пока все тест ы будут пройдены, все проверки наглядовой рады будут сделаны. И только после этого мы делаем коммит

## Files
- scripts/cycle.sh
- tests/council.test.sh

## Non-goals
- Do not change the verdict rule, the row schema or `record-seat` validation (stories 01/03); `judge` gains only the court removal.
- Do not implement the merge to the default branch - `/vulyk-ship` (story 10) does it, as today.
- Do not run any model, dispatch any agent, or read seat reports for content.
- Do not touch `scope-check.sh`, `lib.sh`, `journal.sh` or the gate scripts.
- `close-story` runs the story's `## Verification` command as written; do not "fix" a story whose verification is red - exit 4 and let the driver route it.

## Map slice
`docs/specs/autonomous-cycle/plan.md` `## Contracts` C2, C3 (`next` derivation, `stale`, `court`), C4 (`ROUND`, `CEILING`, court path), C13 · `docs/adr/001-cycle-state-contract.md` D1 "Resume and atomicity" (the four crash rules), D2 rows `close-story`, `open-round`, `judge`, `reopen` and the `--commit` sentence, D5 (court construction and removal), D6 (manual commit -> STALE, the three exits after ESCALATE) · `docs/specs/autonomous-cycle/recon/scout-scripts.md` §Answer 4 (`## Verification` and `repeat:` parsing in `wave-check.sh:89-97,162-163` - reuse the same parse) and §Key types (`pack_fingerprint` identifies which stories, not their content).

## Acceptance criteria
- [ ] `open-round` preconditions (exit 2 naming the first failing): Branch line present; every story `done` or `blocked`; clean tree; `## Asks` non-empty; then exit 6 `{"next":"escalated"}` when `round count >= ceiling` (ceiling = `council/CEILING` or 3). On success: `mkdir council/round-N`, `ROUND` per C4, `git worktree add --detach .vulyk/court/<slug>/round-N <head>`, delete everything under `<court>/docs/specs/<slug>/` except `brief.md`, journal, `next:"dispatch:haiku,sonnet,opus,review"`.
- [ ] Idempotent per D1: `round-N/` without `ROUND` -> rewritten in place; open round, HEAD unchanged -> no-op, `next` lists only missing seats; open round with no seat file and HEAD moved (code, not paperwork) -> `ROUND` re-stamped and court rebuilt in place; with any seat file -> a `STALE` row for N, journal, and `round-(N+1)` opened.
- [ ] An orphaned court directory (`ROUND.court` exists, no matching `git worktree list` entry, or the previous round's court still present) is removed by the next `open-round` before it creates its own.
- [ ] `judge` (after writing row/line/journal) runs `git worktree remove --force <court>` and `git worktree prune`; `.vulyk/court/<slug>/round-N` is gone afterwards; a missing court is not an error.
- [ ] `close-story <story-file>`: runs `scope-check.sh` on the story, then the `## Verification` command `repeat:` times; on all green sets `status: done` in the frontmatter and (with `--commit`) commits `story(<id>): <title>`; exit 4 `{"next":"repair"}` with the failing command in `error` otherwise; accepts `todo` or `in-progress`, exits 2 on `done`.
- [ ] `reopen <spec> "<decision>"`: exit 2 unless the newest row is `ESCALATE`; appends `**After escalation (round N, <date>).**` + `> <decision>` to `brief.md` `## Answers`, writes `council/CEILING` = previous ceiling + 3, journal, `next:"open-round"`.
- [ ] `--commit` commits exactly the paperwork each verb wrote as `vulyk(<slug>): open-round N` / `judge N <verdict>` / `escalate` / `reopen`; the tree is clean after each.
- [ ] All four verbs exit 3 under `PAUSE` before any effect.
- [ ] `tests/council.test.sh` gains: `reopen` -> ceiling 6 and a fourth round opens; manual code commit on an open round with a seat file -> STALE row and round N+1; the court holds `brief.md` and nothing else under `docs/specs/demo/`; `judge` removes the court; `close-story` exit 4 on a red verification and `done` on green; `open-round` exit 6 at the ceiling.

## Verification
`git ls-files '*.sh' | xargs -n1 bash -n && bash tests/council.test.sh`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
