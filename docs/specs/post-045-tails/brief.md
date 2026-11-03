# Tails after 0.45.0 (brief)

**Date:** 2026-11-03 · **Owner:** Andrei · **Escaped from:** gate-split

## Request (verbatim)

> - Замечания судьи Opus из раунда 4, которые не входили в задание (цитата):
> ▎ (1) lead-review.md says "No log ...: SUITE: none", but record-seat rejects SUITE: none as MALFORMED when a round-only row exists, so a reviewer dispatched without the gate loops into re-asks instead of a clear refusal. (2) judge still turns a legacy "SUITE: TIMEOUT" review line into ESCALATE suite-timeout when no round log exists, and cycle.sh:1167 still reads VULYK_SUITE_TIMEOUT for that note, though ADR-029 says it is no longer read. (3) suite-parts-check.sh exits 0 on a missing or unreadable file (documented, so defects-check can run it on any argument), so the card's check passes vacuously when the log is absent. (4) PART names built from a Purpose keep a trailing hyphen ("full-suite-round-only-"). (5) A stepped step killed at 590 s reports "step K failed" without naming the part that hung. (6) Handled well: a bogus --part name exits 1 (no vacuous pass), --step beyond S is refused (rc 2), SKIP needs both exit 77 and a SKIP: line.
> - Мелкие замечания ревьюера из раунда 4: все про то, что починено к раунду 4. Открытых нет.
> - Строка Cycle в CLAUDE.md: этот прогон сам дольше лимита 300 с. Чтобы разбить его на части, нужно около 20 байт, а в лимите ADR-016 свободно только 12.
> - Секция ## Needs a human в plan.md: запись от раунда 2 (ask 9 в раундах 1 и 2 без прогресса). Её закрыли раунд 4 GREEN и ваша приёмка.
> - Добавлю от себя: подтверждение CI на ветке в ship-check; rebase weekly-budget и раунд починки 3; потом исследование того, как установщик подстраивает скрипты под ОС и стек хоста.

## Answers
1. SUITE: TIMEOUT - Считать как FAIL (Рекомендую): Старая строка TIMEOUT = красный прогон: ревьюер BLOCK, раунд идёт в починку, не к вам. VULYK_SUITE_TIMEOUT больше нигде не читается. Так и написано в ADR-029: «упёрся в лимит = FAIL этой части». Старые записи suite-timeout (их две в weekly-budget) читаются как раньше.
2. CI в ульях - Пропуск с причиной (Рекомендую): Нет workflow или нет GitHub-ремоута: строка «ci: не проверяется - <причина>», выпуск не блокируется, CI там запускать негде. Есть workflow и ремоут: требуется зелёный прогон на HEAD (или на коммите, после которого только бумаги). Если gh нет или он не отвечает, это NOT READY, а не тихий пропуск. VULYK публичный, путь по умолчанию не должен запирать ульев без CI.
3. Требования - Верно, покажи план (Рекомендую): Список как есть. Я пишу план и истории и останавливаюсь, пока вы его не одобрите. На Tier 2 это обычный путь.

## Asks
1. Ревьюер, запущенный без гейта, получает понятный отказ, а не петлю переспросов.
2. Старая строка SUITE: TIMEOUT считается FAIL (починка, не остановка), VULYK_SUITE_TIMEOUT нигде не читается.
3. suite-parts-check.sh на отсутствующем или нечитаемом файле отказывает, а не пропускает.
4. Имена PART из Purpose без дефиса на конце.
5. Шаг, убитый на 590 с, называет зависшую часть.
6. Строка Cycle в CLAUDE.md идёт частями под 300 с, CLAUDE.md остаётся в лимите ADR-016.
7. ship-check подтверждает зелёный CI на последнем коммите ветки; без workflow или без GitHub-ремоута пропускает с причиной.
