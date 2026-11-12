# Brief: local-beta-rollout

Date: 2026-11-12 · Tier: 1

## Request

The owner, this session, verbatim:

> Смотри, внедряем новое правило здесь, в этот проект, что все доработки в улька, которые улья, которые мы делаем, автоматически распространяются на все ульи, которые локально у меня на компьютере. Тем самым собираем фидбэк, тестируем, видим на практике, как повлияло то или иное изменение, улучшение, рефакторинг, доработка и инновация, и потом принимаем решение, остаётся оно в системе или мы его вырезаем. Тем самым публичный вулк не страдает, а мы локально полностью проводим самые последние бета-версии, тестируем их, и когда мы принимаем решение, что всё окей, только потом делаем это в публичный репозиторий.

Then the owner chose an option in an AskUserQuestion window: «Скрипт + шаг в ship (Рекомендую)». The label and its
text are the agent's words, not the owner's. The text described: a private hive registry in `~/.vulyk/hives`
(outside the public repo) where a hive can carry a hold with a reason and a date; `hives-behind.sh` goes red when a
hive lags the local version without a recorded hold; `/vulyk-ship`, after the merge, bumps `-dev.N`, upgrades every
hive from the local clone, commits in each and lists the hives skipped and why; then the current main is rolled out
to every hive as a dev build. A second model (Sonnet) agreed and added the hold, so the check does not stay red for
good and stop being noticed.

## Recon (2026-11-12)

- Card `docs/defects/public-release-per-change.md` (2026-11-10) already says in How to: roll each change out to the
  local hives from the local clone. Its status is `text`, with no check. The quote above makes it two quotes, so the
  defect gate reports new debt: `DEBT public-release-per-change: 2 quotes, not block ... add a failing check: and 2
  fixtures`.
- `install.sh` stamps the source's `VERSION` (whitespace stripped, line 28) into the hive's `.claude/vulyk-version`.
  Local builds are numbered `X.Y.Z-dev.N` (card How to). `v0.51.0-dev.1` is a local tag. `VERSION` on local main is
  `0.51.0` (commit 287da19f "release: 0.51.0", unpublished), and the `[Unreleased]` prompt-leaks rules sit on top of it.
- Last rollout, 2026-11-11: 7 hives on 0.51.0-dev.1, 8 held (a feature branch, a dirty tree, a suite over its cap,
  an old version). No registry file exists: `~/.vulyk/hives` is absent.
- `/vulyk-ship` is shipped to every hive. A rollout step must run only in the VULYK source repo, and the default path
  must need no personal file (an owner without a registry gets a named skip, not a failure).
- The defect gate runs a card's `check:` with a fixture path as `<arg>`; every fixture must make it exit non-zero.

## Asks

1. Every change merged to the local main of VULYK rolls out to every local hive automatically: a private hive registry with holds (reason and date), a check that goes red when a registered hive lags the local version without a live hold (the card public-release-per-change's check, with fixtures), and a `/vulyk-ship` step that bumps the local dev build, upgrades every registered hive from the local clone, commits in each and lists the hives held and why.

## Answers

**After escalation (round 1, 2026-11-12).**
> owner chose «Починить всё + ревью (Рекомендую)» (option text is the agent's): repair both majors and all minors, one more review round
