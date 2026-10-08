# Brief: constitution-merge

**Date:** 2026-10-08
**Tier:** 2 - one module (the upgrade path: `/vulyk-update`, `install.sh --upgrade`, its contract ADR-005), a feature
inside it: the upgrade merges the release into the hive's constitution instead of offering to replace it
**Escaped from:** v0.18.0 "Light VULYK" (ADR-013 D7, commit b8a1f07, 2026-09-26) - it added `--constitution replace`
and the `/vulyk-update` step 4 advice "little hand-written text outside the two blocks favours replacing"
**Source:** the owner's message, mid-session, 2026-10-08 (supergrill on the SDD course, `haiku-5-5-floor` in review)

## Request (verbatim)

> Еще есть такая система, что, например, когда Wulic мы обновляем, то другие проекты видят, что обновился Wulic, и предлагают его обновить. И во время обновления Wulic предлагает перезаписать своим .clout MarkDown-файлом тот файл, который в проекте. При этом Wulic не учитывает, что в том основном .clout MarkDown-файле заложено очень много ценной, важной и именно специфической информации, правил под тот проект. Сейчас нужно с этой версией Wulica внести изменение, что при обновлении Wulic обязательно изучает текущие правила, конструкцию, инструкцию и во время обновления адаптирует, чтобы была консистентность, единство, и чтобы не потерялся смысл, сенс, логика и правила того проекта, в который заходит Wulic, чтобы Wulic не косячил. Я думаю, ты понимаешь, о чём я говорю.

## Recon (2026-10-08)
- `/vulyk-update` step 4 offers `scripts/vulyk-update.sh . --constitution replace` and recommends it when there is
  "little hand-written text outside the two blocks"; replace writes the release's CLAUDE.md whole and carries over only
  `VULYK:PROFILE` and `VULYK:COMMANDS`; "Hand-written sections outside those blocks stay only in the backup"
  (`.claude/commands/vulyk-update.md:21-26`, `install.sh:311-351`). A plain upgrade never writes the constitution and
  leaves the owner to "merge by hand" (step 6).
- Host constitutions on this machine: YouTube_AI 14.6 KB, katan 16.3 KB (sidecar `CLAUDE.vulyk.md`), senseti-doker
  35.4 KB, mmorpg 12.1 KB (sidecar); VULYK's own is 7.2 KB. 24 hives carry `.claude/vulyk-version` (0.11.0-0.25.0).
- The original case: `E:/Projects/AI` was replaced at 0.19 - `CLAUDE.md` 16 360 B -> 8 151 B; `CLAUDE.pre-0.19.md`
  holds 129 non-blank lines the current file lacks, among them the project's own sections "Complexity routing",
  "Evolution", "Memory protocol".
- `scripts/vulyk-update.sh` keeps a clone of the origin with all `v*` tags (`~/.vulyk/src`, 44 tags here), so every
  released CLAUDE.md is readable as `git show v<x>:CLAUDE.md`; `git merge-file` is available.
- `tests/telemetry.test.sh` holds 15 `--constitution` cases.

## Answers

1. Кто сливает новую версию VULYK с CLAUDE.md проекта при обновлении? — Королева + проверка скриптом: при
   /vulyk-update Королева читает оба файла и пишет слитую версию: изменения VULYK приходят, все правила проекта
   остаются на месте. Вы видите короткую сводку и говорите «да», затем скрипт проверяет, что ни одна строка проекта не
   пропала молча.
2. Конфликт: проект переписал кусок правил VULYK под себя, а новая версия VULYK меняет тот же кусок. Чья версия
   остаётся? — Спрашивать, по умолчанию проект: каждый такой конфликт показывается вам двумя строками простыми
   словами: «ваше правило» и «что предлагает VULYK». Если вы молчите, остаётся правило проекта.
3. Что делаем со старой кнопкой «заменить конституцию целиком» (--constitution replace)? — Убрать совсем; удаление
   записываем поправкой в ADR-005.
4. В E:/Projects/AI уже сработал replace (0.19). Возвращаем потерянное? — Да, слияние читает бэкап: если рядом лежит
   CLAUDE.pre-*.md, слияние при ближайшем обновлении находит в нём правила проекта, которых нет в текущем файле, и
   предлагает вернуть их в той же сводке. Старый текст самого VULYK при этом не возвращается.
5. Требования подтверждены; план показать и дождаться слова владельца.

## Asks

1. при обновлении Wulic обязательно изучает текущие правила, конструкцию, инструкцию и во время обновления адаптирует, чтобы была консистентность, единство
2. чтобы не потерялся смысл, сенс, логика и правила того проекта, в который заходит Wulic
3. Сейчас нужно с этой версией Wulica внести изменение
