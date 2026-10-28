---
story: trace-autopsy-02
spec: trace-autopsy
status: todo
returned:
tier: 2
worker: worker-code
wave: 2
blocked_by: [trace-autopsy-01]
---

# /vulyk-plan runs the autopsy after the brief; a resolved line means no scout

## Goal
`/vulyk-plan` step 2 tells the Queen: when the request carries a stack trace, run
`bash scripts/trace-autopsy.sh docs/specs/<slug>/brief.md` right after writing the brief and read `autopsy.md`.
Step 3: an `autopsy.md` with a resolved repo line makes the location known, so Tier 1-2 send no `drone-scout`
for it. The command reference and CHANGELOG `[Unreleased]` say the same, with no speed figure (plan
`## Assumptions`). A guard check in the test suite fails when step 2 stops naming the script.

## Requirements
> 2. Шаг 2 /vulyk-plan: если в запросе есть стектрейс (Traceback, at …:N, line N), Queen сразу после брифа запускает скрипт. Сводка до 15 строк ложится рядом с брифом.
> 5. Если сводка нашла хотя бы одну строку репозитория, место считается известным, и drone-scout не посылается.
> Добавить скрипт scripts/trace-autopsy.sh, который автоматически вызывается при создании brief.md, если в запросе владельца обнаружен стектрейс (Traceback, at .*\.(js|ts|py|sh):[0-9]+, line [0-9]+).

## Files
- .claude/commands/vulyk-plan.md
- docs/command-reference.md
- CHANGELOG.md
- tests/symbol-map.test.sh

## Non-goals
- No hook: the owner chose step 2 (brief `## Answers` 1).
- No other step of `vulyk-plan.md` changes; keep the file's wording style and length (one or two sentences per step).
- CHANGELOG claims no planning speed-up or token figure.

## Map slice
`memory/map/agents-and-commands.md`: the `/vulyk-plan` entry.

## Acceptance criteria
- [ ] Step 2 names `scripts/trace-autopsy.sh` and `autopsy.md`; step 3 says a resolved autopsy line counts as a known location.
- [ ] `docs/command-reference.md` `/vulyk-plan` paragraph mentions the autopsy run.
- [ ] CHANGELOG `[Unreleased]` has one entry.
- [ ] `tests/symbol-map.test.sh` checks that step 2 of `vulyk-plan.md` names `trace-autopsy.sh`.

## Verification
`bash tests/symbol-map.test.sh`

## Implementation notes

## Findings
