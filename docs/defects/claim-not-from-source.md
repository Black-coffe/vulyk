---
id: claim-not-from-source
title: A claim made from memory, a docstring or a guess instead of the source that settles it
status: text
check:
fixtures: []
keys: [по памяти, без фактчекинга, из докстринга, по часам машины]
paths: ["docs/specs/*/brief.md", "docs/specs/*/plan.md", "docs/specs/*/report.md", "docs/wiki/**", "CHANGELOG.md"]
---

# A claim made from memory, a docstring or a guess instead of the source that settles it
An agent states a fact to the owner, or builds a decision on it, from what it remembers, what a docstring or a name
suggests, or what it infers from a proxy (the machine clock, a service timestamp), while the source that settles the
question is one read away: the transcript, the installed code path, the person who knows. The claim sounds checked,
the owner acts on it, and it is wrong.

## Owner quotes

## Seen in hives
Not counted as owner quotes: they corrected hive work, not VULYK's (README, *Promoted from hives*). Verbatim, with
people, clients and hives masked.
- 2026-10-05 · a video hive · video 5 release, links to earlier videos — «Ссылки на другие ролики вы отменили, потому что главный агент сказал, что ролик 5 ни на один прошлый не опирается. Но в самом ролике прямо звучит «это ролик 2». Добавить в описании и в самом ютюбе на єтой секунде вівести подсказку второго ролика по MCP»
- 2026-10-08 · a local-RAG hive · a grill question about a speech library's `multilingual` parameter, read from its docstring — «Режим multilingual определяет язык не на каждую фразу, а примерно на 30 секунд аудио, поэтому в быстром диалоге на украинском и русском он может почти не помочь.»
- 2026-10-07 · a web-app hive · release day, the time derived from GitHub timestamps and the machine clock — «Мой Claude жил на два часа в прошлом: часы в терминале врали»
- 2026-10-15 · a consulting hive · screen descriptions moved into the wiki marked "meaning not confirmed" — «[…] удалить все что было притяно без аргументов, фактчекинга, перекрестной провекри, и ууже в самом конце валидации <name>. Лучше ее создатьь с нуля и по тем истояниам которые уже на 100% прийняты и работают»

## Cause
Remembering is cheaper than a lookup and reads as fluent as a checked fact. A docstring's word ("segment", "every"), a
remembered outline of a video, the shell's clock and a model's own extraction are each taken as the source, and a
caveat ("not confirmed") written next to the claim does not stop the next reader leaning on it.

## Check
None, and code cannot add one generically: what counts as the settling source differs per claim (a transcript, a
library's code path, a person's word), and no text pattern tells a checked statement from a remembered one.

## Never
- State to the owner, or plan around, what a library, a file, a past video or a past decision says without opening
  it this session: read the installed code path, the transcript, the file, and name where the fact came from.
- Present a value derived from a proxy (the machine clock, a service timestamp, a docstring) as fact: mark it as
  derived, or ask the person who has it.
- Put an unchecked claim into a lasting place (wiki, memory, a card, a release note) with a "not confirmed" caveat
  instead of checking it or leaving it out.

## Allowed
- Quoting a docstring or a memory note, marked as such, next to what the source actually says.
