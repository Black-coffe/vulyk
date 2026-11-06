# Brief: uncommitted-work-guard

**Date:** 2026-11-05
**Tier:** 2 - a feature inside the hooks (one new PreToolUse hook, its wiring and tests) plus three small items; the
owner picked one plan of three stories
**Source:** study `docs/specs/claude-code-mods-9/report.md` (commits 6010fc9, 0769a9f), candidates C1-C4. The owner's
pick was an `AskUserQuestion` option written by the Queen; it is recorded as a decision, not as a quote.

## Request (verbatim)

> Так что то внедряем?

Decision (option label picked by the owner, 2026-11-05):

> C1+C2+C3+C4 (Рекомендую)

The option's text, written by the Queen: one Tier 2 plan of three stories: 1) the C1 hook, 2) the diff before
ACCEPTED, 3) "a quote is not a correction" together with the pulse note.

Horizon step skipped: the study `claude-code-mods-9` (three source-reading researchers, a local probe, a two-round
Fable/Opus/Sonnet grill) covered this ground the same day.

## Answers

1. Главная: Команда не выполняется, в ответе список файлов, которые пропали бы, и совет закоммитить их или запустить команду самому. Проба показала, что запрет работает в вашем режиме bypass.
2. Удаление: Обе настоящие потери были от git, а в PowerShell и bash удаление пишется слишком многими способами, и разбор был бы ненадёжным. В отчёте прямо напишем, что удаление файлов не покрыто.
3. Обход: Одна строка в стартовой сводке, только когда такой мод найден, и та же строка в /vulyk-status. Обход молчаливый, поэтому его стоит увидеть сразу, а не только когда сами заглянете в статус.
4. Требования: Пять строк становятся требованиями, план после написания ждёт вашего утверждения. Сессия уже длинная, и сборке Tier 2 всё равно нужна свежая сессия.


**After escalation (round 2, 2026-11-06).**
> owner chose reopen (option «Переоткрыть и починить»): an unresolvable cd target checks the whole tree instead of passing; plus 100755, <<b inside quotes, cd -/popd
## Asks

1. Предохранитель: воркерам всегда запрещены git-команды, стирающие работу, главной сессии — если пропадут незакоммиченные файлы (со списком этих файлов), только git, без rm.
2. Строка о моде с tool.check — при старте сессии и в /vulyk-status.
3. Дифф текстом в ответе перед вашим ACCEPTED.
4. Слова-поправки внутри цитаты не считаются поправкой.
5. Заметка о конфликте pulse со Skins.
