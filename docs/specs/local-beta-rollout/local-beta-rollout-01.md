---
story: local-beta-rollout-01
spec: local-beta-rollout
status: todo
returned:
tier: 1
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: hives-behind: a hive one dev build behind with no hold is red
---

# Every local-main change reaches every local hive

## Goal
A registry-driven check that names every local hive lagging the local `VERSION` without a live hold, wired as the card
`public-release-per-change` check, and a `/vulyk-ship` step that rolls each merge out to the local hives.

## Requirements
> Смотри, внедряем новое правило здесь, в этот проект, что все доработки в улька, которые улья, которые мы делаем, автоматически распространяются на все ульи, которые локально у меня на компьютере. Тем самым собираем фидбэк, тестируем, видим на практике, как повлияло то или иное изменение, улучшение, рефакторинг, доработка и инновация, и потом принимаем решение, остаётся оно в системе или мы его вырезаем. Тем самым публичный вулк не страдает, а мы локально полностью проводим самые последние бета-версии, тестируем их, и когда мы принимаем решение, что всё окей, только потом делаем это в публичный репозиторий.

> 1. Every change merged to the local main of VULYK rolls out to every local hive automatically: a private hive registry with holds (reason and date), a check that goes red when a registered hive lags the local version without a live hold (the card public-release-per-change's check, with fixtures), and a `/vulyk-ship` step that bumps the local dev build, upgrades every registered hive from the local clone, commits in each and lists the hives held and why.

## Files
- scripts/hives-behind.sh
- tests/maintenance.test.sh
- docs/defects/public-release-per-change.md
- docs/defects/public-release-per-change.original.fixture
- docs/defects/public-release-per-change.neighbour.fixture
- docs/defects/INDEX.md
- .claude/commands/vulyk-ship.md
- CHANGELOG.md

## Non-goals
- No hive path, hive name or registry content in the repo; tests build a temp registry via `VULYK_HIVES_FILE`.
- No push, no tag, no change to install.sh.

## Map slice
memory/map/agents-and-commands.md

## Acceptance criteria
- [ ] `hives-behind.sh` reads the registry (`VULYK_HIVES_FILE`, default `~/.vulyk/hives`) and each hive's
      `.claude/vulyk-version`. It writes a state (`local <ver>`, then `hive <installed|none|missing> <path>[ | hold <date> <reason>]`)
      and judges it. Exit 0 when every hive matches or holds a live hold; exit 1 on any lag, missing version file,
      missing hive dir, expired or malformed hold, or empty registry; exit 2 when the registry or VERSION is absent.
- [ ] `--check <state-file>` judges a state file alone. It is the card's `check:`, so the card is `block`, with an
      original fixture (a hive on the previous dev build, no hold) and a neighbour (an expired hold), and both fail.
- [ ] The test covers: match passes; behind is red; none is red; a live hold passes and is listed with its reason; an
      expired hold is red; a missing registry exits 2. Today comes from `VULYK_TODAY`.
- [ ] `/vulyk-ship` has a local-beta step after the merge. It runs only in the VULYK source repo with a registry and
      prints a named skip otherwise. It covers:
      - the dev bump rule and its own commit, with no tag and no push;
      - the per-hive upgrade conditions (ship branch, clean tree), `.vulyk-new` merged by hand, a commit in each hive;
      - holds written with a reason and an end date at most 7 days ahead;
      - a final green `hives-behind.sh`.
- [ ] `bash scripts/defects-check.sh` reports no debt for the card.

## Verification
`bash tests/maintenance.test.sh`

## Implementation notes

## Findings
