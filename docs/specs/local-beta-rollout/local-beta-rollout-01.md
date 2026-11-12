---
story: local-beta-rollout-01
spec: local-beta-rollout
status: done
returned: DONE
tier: 1
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: hives-behind: a hive one dev build behind with no hold is red
red_verified_at: 2026-11-12T17:07:04Z 985681103b62c0f94ed115a30f7d66b0b159f9a9e59d1e5cf013bc89e770bb75
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
- scripts/hives-behind.sh: collector (registry + each hive's `.claude/vulyk-version`, CR-stripped) writes a state file; `judge` reads it. `--check` runs the judge alone, so fixtures need no real hive. Today from `VULYK_TODAY`, source from `VULYK_SRC` (tests only). Bash 3.2 safe: no date arithmetic, a hold carries its end date and is compared as a string.
- A hive on the local build passes even with a hold line (the hold is stale but harmless); a hold is judged only for a lagging hive.
- Card: `status: block`, check `bash scripts/hives-behind.sh --check <arg>`, fixtures original (hive one dev build behind, no hold) and neighbour (expired hold); Never line + second quote added this session; INDEX regenerated. Card `paths:` narrowed to `*.hives-state` plus `cmd:` lines for push, gh release and install.sh --upgrade: close-story runs a block check on every file its globs match, and ship.md/CHANGELOG/VERSION are not state files (first close refused: `defect card public-release-per-change fails on .claude/commands/vulyk-ship.md`). defects-check GREEN (8 blocking checks).
- vulyk-ship.md: step 2a between the merge and the publish print; skipped silently outside the VULYK source repo, named skip without a registry.
- tests/maintenance.test.sh: 16 checks; the whole file ran 108 s, 540 checks, 0 failed.

## Findings

## Red receipt
- command: bash tests/maintenance.test.sh
- exit: 1
- tests: 985681103b62c0f94ed115a30f7d66b0b159f9a9e59d1e5cf013bc89e770bb75 (tests/maintenance.test.sh)
- impl: a58dc5c3217db6814b8c778c16f7c8e15a2163a15305b189dfdb5d75b411cefa
- stamped: 2026-11-12T17:07:04Z

```
  ok    hives-behind: a hive one dev build behind with no hold is red
        exit=127
::error::hives-behind: the card's original fixture is red
::error::hives-behind: the card's neighbour fixture is red
::error::ship 2a: the local-beta step ends on hives-behind.sh - expected 'bash scripts/hives-behind.sh' in:
        
::error::ship 2a: the step skips by name without a registry - expected 'local beta: no hive registry' in:
        
::error::ship 2a: the dev bump is never tagged or pushed - expected 'no tag and no push' in:
        
maintenance.test.sh: 540 checks, 10 failed
```
