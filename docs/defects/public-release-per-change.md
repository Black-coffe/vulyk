---
id: public-release-per-change
title: VULYK is published to GitHub after every small change instead of on the owner's call
status: block
check: bash scripts/hives-behind.sh --check <arg>
fixtures: [docs/defects/public-release-per-change.original.fixture, docs/defects/public-release-per-change.neighbour.fixture]
keys: [выкатываем в паблик, выкатывать теперь будем очень редко, постоянное обновление]
paths: ["*.hives-state", "cmd:git +(-C +[^ ]+ +)?push", "cmd:gh +release", "cmd:install[.]sh .*--upgrade"]
---

# VULYK is published to GitHub after every small change instead of on the owner's call
Each finished spec became a public release: a version bump, a tag, a push of main, a GitHub release, often several in
a day. People who use VULYK cannot follow what changed, get nervous, and miss the versions they were used to. Changes
also reached the public before practice had shown whether they were worth making.

## Owner quotes
- 2026-11-10 · VULYK, release practice after 0.50.0-0.50.3 shipped within two days — «Смотри, ещё такую штуку внедряем в этот проект, где мы адаптируем, развиваем, улучшаем «Вулик». Внедряем следующую штуку: «Вулик» теперь не выкатываем в паблик в GitHub каждый раз, когда сделали любую мелочь. Выкатывать теперь будем очень редко и когда я посчитаю нужным. Всё остальное время все доработки «Вулика» полностью тестируем на всех локальных проектах, там, где «Вулик» развёрнут. Собираем максимальную информацию, обратную связь, анализируем, валид ируем, прощупываем. Не каждое обновление, которое мы делаем, оно логично, уместно, и только на практике оно может показывать, стоило его делать или нет. И только когда мы наигрались, накатались, натестировали, собрали фидбэк, только потом выкатываем это на GitHub. Это теперь станет постоянным правилом нашей разработки, потому что мне уже много людей говорят, что постоянное обновление «Вулика» сбивает, не понимают, что там обновляется, нервничают, потому что привыкли к старым версиям. То есть вот эту историю мы с тобой будем фиксить.»
- 2026-11-12 · VULYK, after prompt-leaks-rules merged to local main and was reported as reaching hives "only after the next publish" — «Смотри, внедряем новое правило здесь, в этот проект, что все доработки в улька, которые улья, которые мы делаем, автоматически распространяются на все ульи, которые локально у меня на компьютере. Тем самым собираем фидбэк, тестируем, видим на практике, как повлияло то или иное изменение, улучшение, рефакторинг, доработка и инновация, и потом принимаем решение, остаётся оно в системе или мы его вырезаем. Тем самым публичный вулк не страдает, а мы локально полностью проводим самые последние бета-версии, тестируем их, и когда мы принимаем решение, что всё окей, только потом делаем это в публичный репозиторий.»

## Cause
"Shipped" was read as "published": `/vulyk-ship` ends at a local merge, but the next step, push, tag and GitHub
release, was taken at once after every spec, because the owner had asked for push and release to be run rather than
handed back (card work-handed-back-to-owner). Nothing separated "ready for the local hives" from "ready for the public".
The other half: after that rule, local rollouts were skipped or left for "later" (2026-11-12: a merged change was said
to reach the hives only after the next publish), so the local hives stopped being the beta channel. Nothing makes the
rollout happen by itself.

## Check
When to publish is the owner's call, not a property of the code. Whether the local hives carry the local build is:
`bash scripts/hives-behind.sh` reads the private registry (`~/.vulyk/hives`) and each hive's `.claude/vulyk-version`,
and is red on a hive that lags with no live hold. `--check <state>` judges a state file; the fixtures are the original
case (a hive left on the previous dev build) and a neighbour (a hold that ran out). `/vulyk-ship` step 2a runs it.

## Never
- Push VULYK's main, push a tag, or create a GitHub release without the owner's explicit word for that publish, in
  this session.
- Treat a merged, version-bumped or CI-green spec as a reason to publish.
- Leave a change merged on the local main without rolling it out to the local hives, or tell the owner it reaches
  them only with a publish.
- Push tags in bulk (`git push --tags`, `--follow-tags`), push a `-dev.N` tag, or push more than one version tag in
  one publish.

## How to
- After a ship, merge on the local main and roll the change out to the local hives from the local clone
  (`./install.sh <hive> --upgrade`, never `vulyk-update.sh`, which takes the published tags). Watch how it behaves
  there, collect the owner's and the hives' feedback, and keep a running list of what is unpublished and how it fared.
- Every change merged on the local main goes to every local hive, in the same session, without waiting to be asked:
  the local hives run the newest beta. A hive that cannot take it now (busy, red suite, held) is named with the reason
  and caught up next session.
- Each unpublished change is then kept or cut on its local results, by the owner; what is cut is removed from the
  local main and the hives before any publish (the wording is the agent's).
- When the owner says to publish, bundle what has proved itself into one release with a CHANGELOG a user can follow:
  one public version (`0.51.0`), one CHANGELOG section, exactly one tag pushed by name.
- Between publishes, number local builds `X.Y.Z-dev.N` (the owner picked this option on 2026-11-10; the wording is the agent's).

## Allowed
- A local `-dev.N` version and its local tag, so a hive's upgrade can name what it came from; neither leaves this
  machine.
- A narrow release of fixes for holes that are already public (issue #5, redact gaps), after a short trial in the local
  hives and on the owner's word for that publish (the owner picked this option on 2026-11-10; the wording is the agent's).

## Revoked
