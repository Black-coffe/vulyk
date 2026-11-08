---
story: ab-run-fixes-05
spec: ab-run-fixes
status: todo
returned:
tier: 3
worker: worker-code
wave: 3
blocked_by: [ab-run-fixes-01, ab-run-fixes-03, ab-run-fixes-04]
red: required
red_reason: claim: leftover edits of a wave story are accepted
---

# Driver: leftover edits re-dispatched, a checkpoint before the hour, the manual-wave repro

## Goal
After this story:
- **Leftover edits (ask 20).** When a worker returns without closing, the next `claim` no longer stops on its dirty `## Files` (plan C9). The driver re-dispatches the story with a note about the leftover edits; the retry model and the two-miss stop are unchanged.
- **Checkpoint (ask 9).** The driver returns `checkpoint` at a wave or gate-step boundary once 50 min have passed since launch, and `/vulyk-build` relaunches it with a fresh stamp (C10). The Queen's turn comes back before her 1 h cache lapses.
- **Manual-wave repro (ask 18).** It comes first: a test that a ready story in the same wave as a `manual:`-blocked one is built, in `tests/driver.test.sh` and in `tests/cycle.test.sh` part `manual`.
  - If it is red on HEAD, fix the cause, in `status` (`scripts/cycle.sh:629-640`) or in the driver.
  - If it is green, keep the test and write "not a bug: <why>" in `## Implementation notes`.
  - The red receipt comes from ask 20's test.

## Requirements
> 9. Главная сессия не простаивает дольше часа во время сборки, чтобы кэш не умирал.
> 18. Ручной шаг в волне: сначала repro. Если готовые истории правда ждут — чиним, если нет — закрываем как не баг.
> 20. Исполнитель вернулся без коммита: драйвер возвращает историю ему же, а не останавливает сборку.

## Files
- .claude/workflows/vulyk-cycle.js
- scripts/cycle.sh
- tests/driver.test.sh
- tests/cycle.test.sh
- .claude/commands/vulyk-build.md
- docs/cycle.md
- docs/token-economy.md

## Non-goals
- Leave `open-round`'s dirty-tree refusal alone, and accept no dirty path outside the current wave's `todo` stories. The wider dirty-tree rework belongs to `mass-audit-fixes`.
- Do not change the retry model, the miss count, `SUITE_CALLS` or any cap. No timer, sleep or background poll in the Queen (ADR-024).
- Do not make 50 min configurable beyond the `checkpoint_min` arg.

## Map slice
memory/map/cycle.md (The Workflow driver, `gate`; Verbs: `claim`, `release`; `status --json` `next`; `advance`); memory/map/agents-and-commands.md (`/vulyk-build` hive path; `worker-code` close)

## Acceptance criteria
- [ ] `claim: leftover edits of a wave story are accepted`:
  - A tree dirty only in a `todo` wave story's `## Files` lets `claim` exit 0 with `leftover` naming that story. It fails on HEAD and passes after.
  - A dirty path outside those `## Files` is still refused (the neighbour case).
- [ ] Driver test: a worker returns with its story still `todo` and its files dirty. The story is re-dispatched with the leftover note, and a second miss stops the run as today.
- [ ] Checkpoint:
  - With `checkpoint_min: 0`, the driver returns `{"status":"checkpoint",...}` at the first boundary after work, and the claim is released.
  - At the default, the existing driver tests pass unchanged.
- [ ] Manual-wave repro tests in both suites: green, or red with a fix.
- [ ] Docs:
  - `vulyk-build.md`: relaunch on `checkpoint` with a journal line, plus a note that one wave longer than ~55 min still idles the cache; the leftover retry.
  - `docs/cycle.md`: the driver and manual paragraphs.
  - `docs/token-economy.md`: the Queen-idle line.
- [ ] `## Implementation notes` ends with one `CHANGELOG:` line.

## Verification
`bash tests/driver.test.sh`
`bash tests/cycle.test.sh --part manual`
`bash tests/cycle.test.sh --part safety`
`bash tests/council.test.sh --part driver`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes

## Findings
