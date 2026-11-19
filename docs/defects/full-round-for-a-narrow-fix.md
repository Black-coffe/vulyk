---
id: full-round-for-a-narrow-fix
title: A repair re-runs a full council round and every inherited suite
status: block
check: bash -c 'f="$1"; [ -f "$f" ] || exit 0; t="$(tr -d "\r" < "$f")"; v() { printf "%s\n" "$t" | sed -n "s/^$1=//p" | head -n 1; }; if [ "$(v narrow)" = 1 ]; then if printf "%s\n" "$t" | grep -qE "^seats=.*(haiku|sonnet|opus)"; then [ -n "$(v asks)" ] || exit 1; fi; [ "$(v second)" != risk ] || exit 1; r="$(v rerun)"; [ "$r" = all ] && exit 0; for k in $(printf "%s\n" "$t" | sed -n "s|^STEP \([0-9][0-9]*\)/.*|\1|p"); do case ",$r," in *",$k,"*) ;; *) exit 1 ;; esac; done; exit 0; fi; printf "%s\n" "$t" | grep -q "^repair=" || exit 0; case "$(v full)" in design|asked|norecord) exit 0 ;; esac; exit 1' _ <arg>
fixtures: [docs/defects/full-round-for-a-narrow-fix.original.fixture, docs/defects/full-round-for-a-narrow-fix.neighbour.fixture, docs/defects/full-round-for-a-narrow-fix.repair.fixture, docs/defects/full-round-for-a-narrow-fix.solo.fixture]
keys: [одну строку поправили, зачем эти циклы гонять, дурной подход, ремонтировали маленький кусочек, все 100%, по кругу гонять одно и то же]
paths: ["scripts/cycle.sh", ".claude/workflows/vulyk-cycle.js", ".claude/commands/vulyk-build.md"]
---

# A repair re-runs a full council round and every inherited suite
A round ends RED on a few asks or findings while the rest is green. The loop cuts a repair story that inherits the
`## Verification` of every story before it (including suites that take minutes and do not touch the fixed files),
relaunches the hive, closes the story through those suites and then opens a whole new round: every seat dispatched
again, the full integration gate again. The owner pays a full round, and on audit-fixes-1113 about two hours, for what
a re-run of the findings' own tests, the red gate steps and a review of the repair's diff would settle.

## Owner quotes
- 2026-10-16 · spec `vulyk-watcher` · round 3 (opus GREEN, review BLOCK with one finding in `scripts/lib.sh`) — «Зачем перезапускать цикл, если всего лишь одну строку поправил и всё? Если всё остальное нормально было, green, и не было никаких проблем, то мы одну строку поправили, перепроверили эту строку и всё. Зачем эти циклы гонять? Что за дурной подход?»
- 2026-11-14 · spec `audit-fixes-1113` · the repair after round 1 (a full round 2 followed it, every seat and all ten gate steps) — «Ты можешь мне объяснить, что мы ремонтируем два часа? Почему два часа? Куда уходит это время — два часа? Смотри, вот моя логика, и ты скажи, в чём она неправа. Например, мы шо-то сделали, проводим тесты, проводим проверки, получаем грин по 95% проекта. В 5% мы видим какую-то проблему. Мы эту проблему устраняем и, как идиоты, начинаем снова весь проект, все 100%, прогонять часовыми проверками, грилями, тестами. Зачем? Мы ремонтировали маленький кусочек и проверяем. Глобально тесты мы гоняем только, например, раз в месяц или когда явно какие-то баги начинают вылазить, или фидбэк какой-то идёт. И глобально тесты мы гоняем, когда мажорная версия подымается, например, 0.5, 0.6 — это считаем мажор, 0.7 — мажор. А когда 0.51 было, стало 0.52 — это минорные версии. То есть мы тратим впустую тысячи, миллионы, десятки миллионов токенов , чтобы просто по кругу гонять одно и то же. Я, честно, логику не понимаю. Мне кажется, нужно запускать совет моделей — Fable, Opus, Sonnet — и разбираться, почему у нас такая дичь происходит в этом проекте. Почему у нас добавление простого правила в улик или простой логики, потом мы два дня не можем выкатить этот улик. Это вообще мне в голове не помещается.»

## Cause
`cycle.sh repair` cut a repair story with the union of earlier stories' verification and `advance` always followed a
repair with `open-round`; nothing sized the re-check to the finding. ab-run-fixes (C5) added a narrow path, but only
for one RED item in one non-test file, so a repair of four red asks or of one slow test part still paid for the full
round.

Since narrow-repair-1115 (ADR-040) the number of files and items decides nothing. A repair story carries its
findings' paths, their exact tests, `docs/defects/*` and only the rows of the stories that named those paths.
`open-round` computes the next round's scope from committed records and freezes `repair=<story>` with either
`narrow=1`, `asks=` (the asks to re-judge), `rerun=` (the gate steps that were red) and `second=none`, or
`full=design|asked|norecord`. A narrow round dispatches the blind seat only when `asks=` lists an ask and runs only
the `rerun=` steps. The full suite runs once, with no agent, before a local merge (`ship-check.sh` `suite:`). The
`check:` reads a round's `ROUND` and `suite.log` text: red on a narrow round that names a blind seat with an empty or
missing `asks=`, has `second=risk`, or ran a `STEP` not in `rerun=`, and on a round with `repair=` and neither
`narrow=1` nor a `full=` reason.

Round 1 of narrow-repair-1115 found three gaps, closed in its repair: a second repair in a row read the `steps=0` of a
narrow round that ran no step (`SUITE: none - narrow repair round`) as a changed step count and re-ran every step
(`rerun=all`), so the count is now compared with the last round that ran steps; `--fill-tests` saw no test of a script
the suites copy and run (`bash scripts/x.sh`), so a run by `bash`/`sh`/`exec` is now an `exact` hit; and an odd fence
line in a red receipt's captured output reopened the story's sections, so every section reader shares one fence rule
and the receipt's fence is longer than any backtick run in the output.

## Never
- Open a full round after a repair, whatever the number of files or red items: the next round re-checks the repair
  (a review of its diff, the blind seat over the asks it lists, the gate steps that were red), unless its `ROUND` says
  `full=design`, `full=asked` or `full=norecord`; a reopened `no-progress` is no exception without the owner's
  `--full`, and `--full` is never added without his word.
- Give a repair story verification it does not touch: keep the rows of the stories that named its files, drop the rest.
- Dispatch a council seat with no ask to judge, or re-run a gate step in a narrow round that was not red; a narrow
  round that ran no step is not a changed step count.
- Run the full check of the whole project on every repair or on a minor release, public or not: it is the owner's call.

## Allowed
- A full round after a repair only when the repaired round escalated as `half` and the owner reopened it, or the owner
  said at reopen that it is a design fault (`cycle.sh reopen ... --full`, any reason; both `full=design`), when the
  owner asked for it (`open-round --full`, `full=asked`), or when the records the scope is read from are missing
  (`full=norecord`). A reopened `no-progress` without `--full` is narrow: its `asks=` holds every repeated red ask.
- 2026-11-14 · «Глобально тесты мы гоняем только, например, раз в месяц или когда явно какие-то баги начинают вылазить, или фидбэк какой-то идёт. И глобально тесты мы гоняем, когда мажорная версия подымается, например, 0.5, 0.6 — это считаем мажор, 0.7 — мажор. А когда 0.51 было, стало 0.52 — это минорные версии.»
- 2026-11-14 · «Полные тесты без агентов (Рекомендую)»
- 2026-11-15 · «Весь набор ещё раз (Рекомендую)»
