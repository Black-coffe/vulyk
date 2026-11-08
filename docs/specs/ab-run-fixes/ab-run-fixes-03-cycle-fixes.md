---
story: ab-run-fixes-03
spec: ab-run-fixes
status: todo
returned:
tier: 3
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: status: an unknown story status is an error
---

# cycle.sh: `verify_run` stdin, an unknown story status, a ready-line hint, one suite commit

## Goal
After this story:
- **stdin.** `verify_run` runs each verification line with stdin from `/dev/null`, at both call sites (capped and uncapped, `scripts/cycle.sh:2011,2018`). A line that reads stdin can no longer eat the next line. `stamp-red` shares the runner.
- **Unknown status.** A story whose `status:` is a value `cycle.sh` does not recognise (for example `open`) is now an error in `status` and every verb that derives it (plan C6). It used to be counted as todo and listed in no wave (`:591-596, 606`).
- **Ready-line hint.** `close-story`'s refusal of a segment that is not a `## Commands` cell suggests the ready line (C7).
- **One suite commit.** `suite --commit` commits `suite.log` once, on the call that finishes the suite (C8).

## Requirements
> 11. Прогон частей без отдельного коммита на каждую часть. Сами части остаются, по правилу «гейты дробить».
> 16. Строка проверки в `verify_run` не съедает ввод следующей строки.
> 17. Неизвестный статус истории (`open`) — ошибка в `status`, а не молчаливый пропуск.
> 19. Отказ `close-story` из-за строки проверки вне Commands подсказывает готовую строку.

## Files
- scripts/cycle.sh
- tests/cycle.test.sh
- tests/council.test.sh
- docs/adr/029-*.md

## Non-goals
- Do not merge suite steps or parts, raise a cap, or change the one-step-per-call clerk loop in `vulyk-cycle.js` (owner rule: split gates, never raise the limit; card `test-gate-one-long-limit`).
- Leave alone: the dirty-tree predicate of `claim` / `open-round` (story 05, then `mass-audit-fixes`), seats, carry and repair (story 04), and `wave-check.sh`.
- No new status value. No hint in `stamp-red` or `wave-check`.

## Map slice
memory/map/cycle.md (Verbs: `close-story` and the verify runner, `suite`; `status --json` `next`); memory/map/scripts.md (Key contracts, Gotchas: anchored matches, bash 3.2)

## Acceptance criteria
- [ ] `verify_run: a line that reads stdin leaves the next line its turn`: in a two-line block whose first line reads stdin, the second line also runs.
- [ ] `status: an unknown story status is an error`: a story with `status: open` makes `status` exit 2 naming the file and the value. It fails on HEAD and passes after. Known values behave as before.
- [ ] `close-story: a non-cell segment names a ready line`: given `bash tests/x.test.sh --part a --verbose` and a fixture cell `bash tests/x.test.sh --part <topic>`, the refusal keeps its exit code and prints `try: bash tests/x.test.sh --part <topic>`.
- [ ] `suite: a middle step makes no commit`: with `--commit`, step 1 of 2 leaves HEAD unchanged with `suite.log` written, and step 2 commits it.
- [ ] ADR-029 gets a dated amendment line about the commit. The parts touched stay under 70% of their cap.
- [ ] `## Implementation notes` ends with one `CHANGELOG:` line.

## Verification
`bash tests/cycle.test.sh --part close`
`bash tests/cycle.test.sh --part gates`
`bash tests/council.test.sh --part suite`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes

## Findings
