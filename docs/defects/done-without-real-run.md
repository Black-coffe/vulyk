---
id: done-without-real-run
title: Work reported done without running it where it will really run
status: text
check:
fixtures: []
keys: [тестируй то, что ты делаешь, только слияние кода, не ставится по readme]
paths: [".claude/commands/vulyk-ship.md", ".claude/commands/vulyk-build.md", "install.sh", "scripts/vulyk-update.sh", "CHANGELOG.md"]
---

# Work reported done without running it where it will really run
Tests are green and the work is handed over as done, but nobody ran it in the place it will live: the viewer that
frames the page, the running process that still serves the old code, a clean machine following the published README.
The owner is the first to run it for real, and it fails there.

## Owner quotes

## Seen in hives
Not counted as owner quotes: they corrected hive work, not VULYK's (README, *Promoted from hives*). Verbatim, with
people, clients and hives masked.
- 2026-10-07 · a consulting hive · an HTML page's popup checked only as a local file — «Возьми себе Google, браузер и проверь, что этот попап работает. Оно не работает у меня, и куча ошибок JS. Проверяй, тестируй то, что ты делаешь и отдаешь.»
- 2026-10-08 · a local-RAG hive · a release merged into `main`, the running app not restarted — «Выпуск <spec> — это только слияние кода в `main`. Работающий <hive> начнёт показывать подсказки и вести журнал звонков лишь после перезапуска. Просто не забывай обновлять версию на которой я работаю»
- 2026-10-08 · a video hive · a public repository promised in a video, its README never run on a clean machine — «Публичный <hive> на GitHub сейчас не ставится по README: инструкция ломается в четырёх местах. Обещание «работает через час» и домашка держатся только после правки репозитория. Перепиши и исправь раз и навсегда и зафиксирпуй наблюдение за соответсивем кода и файла»

## Cause
"Done" is measured where it is cheap to measure (the test suite, a file opened locally, a merge) and the step to the
real target (a restart, the real viewer, a fresh install) is left to whoever uses it next. For VULYK the real target
is a hive: a fix released here is not live in a hive until it runs there (`framework-fix-skips-live-hives`).

## Check
None, and code cannot add one generically: the real target differs per deliverable (a browser frame, a process, a
clean machine, a hive), and only running there shows it works.

## Never
- Report work done, released or shipped before it has run once in its real target, or without saying plainly that it
  has not and what that step is.
- Treat a merge, a version bump or a green suite as the user having the change.

## Allowed
- Stopping at a step only a person can take (an interactive login, a device in hand), stated once, with what was
  already verified short of it.
