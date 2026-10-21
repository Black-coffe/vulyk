---
story: court-setup-02
spec: court-setup
status: todo
returned:
tier: 2
worker: worker-code
wave: 2
blocked_by: [court-setup-01]
---

# The installer leaves the setup file alone and offers it

## Goal
`install.sh` treats `.claude/vulyk-setup` like `.claude/vulyk-paperwork`: never shipped, owned or removed. On `--upgrade`, a hive with `package.json`, `pyproject.toml` or `requirements.txt` at its root and no `.claude/vulyk-setup` gets one offer line naming what the file does and where it is described. It is printed once per upgrade, and nothing is created. `bootstrap/interview.md` asks, in Batch 2, whether a fresh checkout needs an install step to run the tests, and `/vulyk-bootstrap` writes the answer to `.claude/vulyk-setup`. CHANGELOG `[Unreleased]` names the feature.

## Requirements
> 3. Установщик файл не ставит и не трогает.
> 4. /vulyk-bootstrap спрашивает про него, а обновление пишет одну строку-предложение ульям с зависимостями.

## Files
- install.sh
- bootstrap/interview.md
- .claude/commands/vulyk-bootstrap.md
- tests/telemetry.test.sh
- CHANGELOG.md

## Non-goals
- No auto-created setup file, no guessed install command (offer, never enable).
- No change to `vulyk-update.sh` beyond what `install.sh --upgrade` prints.

## Map slice
memory/map: the install.sh slice (`is_shipped`, upgrade summary).

## Acceptance criteria
- [ ] An upgrade of a fixture hive holding its own `.claude/vulyk-setup` leaves that file byte-identical, and `--check` does not list it.
- [ ] An upgrade of a fixture hive with `package.json` and no setup file prints the offer line once. A hive with the file, or with no manifest, prints none.
- [ ] The interview holds the question, and the bootstrap command names where the answer goes.

## Verification
`bash tests/telemetry.test.sh`

## Implementation notes

## Findings
