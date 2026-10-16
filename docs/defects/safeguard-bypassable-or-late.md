---
id: safeguard-bypassable-or-late
title: A safeguard that can be bypassed, passes silently on a missing input, or ships after what it guards
status: text
check:
fixtures: []
keys: [--no-verify, молча пропускает, пока не маскируются]
paths: ["scripts/*-check.sh", "scripts/git-hooks/**", ".claude/hooks/**", ".claude/settings.json", "install.sh"]
---

# A safeguard that can be bypassed, passes silently on a missing input, or ships after what it guards
A guard is reported as protection, but one flag switches it off, an equivalent path walks around it, it exits green
when the thing it reads is absent, or the release that makes the guarded path live goes out before the guard does.
The owner believes the risk is closed while it is open.

## Owner quotes

## Seen in hives
Not counted as owner quotes: they corrected hive work, not VULYK's (README, *Promoted from hives*). Verbatim, with
people, clients and hives masked.
- 2026-10-08 · a consulting hive · a local secrets hook offered as the barrier before a push — «Местный охранник от паролей можно отключить одним флагом `--no-verify`, причём не только у коммита, но и у отправки на GitHub. Тогда утечку заметит только проверка на GitHub, уже после отправки.»
- 2026-10-13 · a local-RAG hive · a restart that revived photo OCR while its password masking was still on a branch — «С момента перезапуска <hive> распознаёт текст на новых фото и сканах из Telegram, но пароли там пока не маскируются.»
- 2026-10-12 · a game hive · a new defect check, after release — «Новая проверка дефекта «вход не там, где аудитория» срабатывает, только если в плане есть таблица аудитории. Без таблицы она молча пропускает план.»

## Cause
A guard is designed against the one path it was written for and tested on inputs that contain what it looks for.
The bypass flag, the equivalent channel (the same consulting hive saw a blocked copy redone through another command),
the absent input and the release order are not asked about. A fix that turns a dead path on is not asked what else
it turns on.

## Check
None, and code cannot add one generically: whether a guard can be walked around depends on the guard. Each VULYK gate
carries its own tests; the rule here is what those tests must cover.

## Never
- Call a guard protection without naming how it is switched off or walked around (a flag, another command, a missing
  input), and what catches that case.
- Let a check exit 0 when the thing it reads is missing or empty: missing input is a refusal or a red, never a pass.
- Ship or restart a change that makes a guarded path live before its guard is live.

## Allowed
- A guard that is bypassable on purpose (an owner override), when the bypass is named, logged and the owner chose it.
