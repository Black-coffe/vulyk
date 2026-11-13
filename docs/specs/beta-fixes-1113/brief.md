# Fix the eight defects the live hives showed, before the public release (brief)

**Date:** 2026-11-13 · **Owner:** Andrei · **From study:** beta-feedback-1113 (report.md)

## Request (verbatim)

> Проверь как отработал вулик обновленные локальный в проектах которые запущены, если есть моменты нюансы подправь, подтюнь а потом займись выкладыванием его на гитхаю публично с обновлением версии. Очень хорошо себя вулик показал в проекте D:\YouTube_AI всю нотчь и вечь вечер вчера раьботал

## Answers

**Grill (2026-11-13), after the study report.** Option text is the agent's, cross-checked with Sonnet (agreed; a fix that
grows is cut, not a reason to delay the release; each fix gets a failing check on the original case).
> «Все 8 одной задачей (Рекомендую)»: findings 1-8 of beta-feedback-1113/report.md in one spec before the public release.
> «Ветка-кандидат + CI (Рекомендую)»: publish after a leak scan of every commit to be published and a Fable re-review of the
> 0.51 security fix: push a release-candidate branch, CI on ubuntu and macOS, then main and the tag.
> «Сначала одна живая сборка (Рекомендую)» (after a side agent's note that the overnight run was on 0.51.0-dev.1): the public
> release waits until one real spec of the owner's reaches GREEN in a live hive on the fixed local build; if none has by
> 2026-11-19, run one real small task in an idle hive. This gates the publish, not this spec.

## Asks
1. Repair parser: `finding_paths` drops a leading `N. ` item number, so a reviewer's numbered finding never yields `1.` as a path; a repair whose findings name no real path is not a narrow round and keeps the round's suite.
2. Driver: a worker that returns `NEEDS_CONTEXT` stops the build with that story and its `## Findings` for the Queen, instead of being dispatched again as a miss.
3. A wave's stories are checked before dispatch: a `## Verification` segment that is not a `## Commands` cell stops `advance` with the story named, before any worker runs.
4. `agent_prefix_high` counts only agents VULYK dispatches (its own agent types), not built-in ones such as `general-purpose`.
5. `lead-review` no longer reports a `suite.log` head that differs from the reviewed head only by paperwork commits.
6. `/vulyk-plan`: `--go` comes only from the owner's own words, never added by the Queen.
7. A quoted `red_reason:` (YAML single or double quotes) matches the same as an unquoted one.
8. `/vulyk-resume` (and the build it starts) switches to the spec branch when the tree is on another branch and clean, instead of failing the first launch.
9. The `handoff-offered-too-early` card check judges the tree's `.claude/hooks/handoff.py` when the card fires on `scripts/telemetry.sh`, so a story that edits `telemetry.sh` can close (added by the Queen mid-build, card `framework-defect-deferred-mid-build`: it stopped story 03).

## Privacy
Public repo: hives by root name only; fixtures use stand-ins (Acme). Evidence stays in `~/.vulyk/audits/beta-feedback-1113/`.
