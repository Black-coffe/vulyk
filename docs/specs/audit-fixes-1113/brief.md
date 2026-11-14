# Fix the framework-audit findings of 2026-11-13 (brief)

**Date:** 2026-11-13 · **Owner:** Andrei · **Tier:** 3 · **Source:** private audit summary (~/.vulyk/audits/framework-audit-2026-11-13/FINAL.md, never in the repo)

## Request (verbatim, except the marked block and the private path in the last line)

The four lines of the owner's "Защита и гейты" block name security gaps that are not fixed yet. On the owner's forwarded
note of 2026-11-13 they are given here in generic words (marked); the verbatim request is kept privately in
`~/.vulyk/audits/framework-audit-2026-11-13/request-verbatim.md` until the fixes are released.

> В файле сведены отчёты пяти аудиторов фреймворка VULYK. Аудиторы нашли 132 проблемы, после удаления дублей осталось 70. Критических нет, серьёзных 11, средних 37, мелких 22.
>
> Срочно:
> - Версии. Сравнение считает 0.52.0-dev.3 новее 0.52.0, поэтому после выпуска 0.52.0 ульи на dev-сборках не узнают о релизе.
> - Утечка. (moved to a private file before publishing)
> - Публичные пуши. /vulyk-ship сам пушит рабочие ветки в публичный GitHub, и туда уже ушли неопубликованные коммиты.
>
> Защита и гейты: *(generic wording, not the owner's words)* four gaps: in who may record the owner's acceptance, in the
> git safety hook's coverage and its behaviour without Python, in secret masking for non-English keywords and
> credentials in command arguments, and in the scope check of story files.
>
> Установка и обновление:
> - Новая установка кладёт в чужой проект служебные файлы самого VULYK.
> - Вариант через GitHub template отдаёт весь репозиторий целиком.
> - Обновление может затереть осознанную правку улья.
> - На Windows шаг установщика, который приводит переводы строк к LF, ничего не делает, но пишет, что сделал.
>
> Отставание от Claude Code:
> - Минимум для Fable стоит на 5.1, хотя по умолчанию уже 5.2. Ещё и расход Fable 5.2 считается примерно в 4 раза дороже реального.
> - В доках сказано, что субагенты не могут запускать своих субагентов. С версии Claude Code 2.1.219 это неверно.
> - Два служебных навыка Claude Code не видит вообще.
> - Хуки начала сессии и сжатия контекста срабатывают и у субагентов, поэтому воркер может забрать хендофф главной сессии.
>
> Противоречия в доках: около 18 мест, где документация говорит одно, а код делает другое. Главное: конституция обещает, что заполненный Client path добавляет место в совете, а код этим местом заменяет проверку намерений.
>
> Мёртвое: несколько механизмов работают впустую. Это хранилище уроков memory/learnings, в которое никто не пишет, снимки состояния перед сжатием контекста, которые никто не читает, вопросы интервью, ответы на которые ничто не использует, и счётчик готовности к 1.0, который всегда показывает 0.
>
> В конце файла есть порядок работ, внешние источники и список того, что не удалось подтвердить или прочитать. "<private audit folder>\FINAL.md"

## Privacy
Stories, council reports and commit subjects of this spec describe a security fix by what it now does, never by how the
old gap could be used. Evidence and finding IDs (V-NN) stay in the private audit folder. Fixtures use stand-ins (Acme).

## Answers

Grill 2026-11-13, two batches. Option labels and descriptions are the agent's; the owner picked each by option label
(no own words). Each batch was cross-checked with Fable before it was shown (it agreed; its additions are in the options).

1. Нарезка — «Сначала срочное и защита (Рекомендую)»: Сразу одной правкой: /vulyk-ship перестаёт пушить ветки в публичный GitHub и спрашивает вас. Первая задача включает версии, утечку skills.json, все дыры защиты и гейтов, хуки у субагентов, три пункта установщика того же класса (служебные файлы VULYK в чужом проекте, template, затирание правки улья) и два хвоста. Потом установщик, доки вместе с Fable 5.2, чистка мёртвого, а плагин и штатные средства станут исследованиями.
2. skills.json — «Убрать, историю не трогать (Рекомендую)»: Файл перестаёт отслеживаться: git rm --cached, .gitignore, и шаг ship больше не коммитит счётчики. Он считает только навыки VULYK и живёт локально, а из публичного main исчезнет при следующей публикации.
3. Client path — «Оставить «вместо», поправить доки (Рекомендую)»: решение ab-run-fixes (C1) остаётся; правятся только доки и конституция. This decision belongs to the later docs spec; it is recorded here so it is not lost.
4. «Принял» и `--go` — «Только с вашей цитатой (Рекомендую)»: Субагенту это запрещено всегда. Главной сессии разрешено, только если заметка дословно цитирует ваше сообщение или ваш выбор в вопросе из этой сессии, написанные после последнего вердикта. Голое «ок» не считается. Хук читает переписку сессии, а без Python отказывает с громким сообщением. Ручная правка файла записи и строки **Approved:** тоже закрывается.
5. Без Python — «Запасной сторож на bash (Рекомендую)»: Даже без Python сторож запрещает очевидно опасные команды git (и в Bash, и в PowerShell) по общему списку с Python-частью. Тест проверяет, что обе части совпадают. Остальные команды git проходят, а бриф в начале сессии пишет, что Python нет. Если настоящий Python упал на команде git, команда запрещается.
6. Template — «Убрать способ и флаг (Рекомендую)»: Способ удаляется из README и getting-started. Тем, кто уже им пользовался, добавляется строка о восстановлении, а бриф сессии узнаёт такую копию. Флаг template на GitHub выключается при следующей публикации, по вашему слову.

Side-agent notes the owner forwarded (2026-11-13), carried as plan constraints, not as owner quotes:
- The stories that change the gates judging this build (owner-acceptance guard, git-guard, scope gate, story approval,
  paperwork) land in the last wave, each with a test on the original case.
- A security item dropped from this spec or left half done moves to the private audit folder; no repo text describes it.


**After escalation (round 4, 2026-11-14).**
> Владелец 2026-11-14 выбрал «Узкий ремонт + раунд (Рекомендую)»: ремонт git-guard и шапок owner-guard и git-guard, CRLF-тест ship; подробности (moved to a private file before publishing).
## Asks
1. Version order: a release `X.Y.Z` is newer than any `X.Y.Z-dev.N`, and `dev.10` is newer than `dev.3`. The update-check hook and `vulyk-update.sh` use one shared comparison, and `vulyk-update.sh` refuses a target that is not newer than the installed version.
2. `memory/stats/skills.json` is no longer tracked (`git rm --cached`, gitignored) and public history is not rewritten. It counts only VULYK's own skills and `vulyk-*` commands and lives locally. `install.sh` does not ship it, no ship step commits it, and the clean-tree exceptions made for it are gone.
3. `/vulyk-ship` pushes a spec branch only to a private origin; with a public origin it asks the owner (landed as Tier 0 in 86e15292); a test pins it.
4. Only the owner's own words record his acceptance (`human-check.sh ACCEPTED|REJECTED`) or a plan's straight-through `--go`: a subagent is always refused; the main session passes only when the note quotes, verbatim and after the latest verdict, an owner prompt or AskUserQuestion answer from this session, with whitespace normalised and a bare «ок» not enough; direct edits of the record file and of the `**Approved:**` line are guarded the same way; without Python the guard refuses with a loud message.
5. git-guard covers every git form that discards uncommitted work or commits, including git run through a shell, an alias or a heredoc fed to a shell. Every form it leaves open on purpose is named in its header.
6. git-guard without Python: a pure-bash fallback with the same verb list (a test compares both lists) still denies the work-losing verbs in Bash and PowerShell; a real interpreter that crashes on a git command denies it; the SessionStart brief says when Python is missing.
7. `redact.sh` masks: Russian and Ukrainian secret keywords; credentials passed in command arguments; the service-token shapes in the private audit list, with the privately recorded open shapes. If `redact.sh` itself fails, it says so on stderr and records `redact_degraded`; it never passes the text through silently.
8. The scope check also catches edits outside `## Files` that were committed before `close-story`, counting from the head recorded at claim. A subagent cannot `git commit` or `git add` while a DRIVER holds the spec, and worker prompts say never to commit.
9. A story's approved version is bound to a commit that `cycle.sh` itself made, not to a commit subject.
10. Only files `cycle.sh` writes count as paperwork. A hand edit of `brief.md` or `plan.md` stales the round and is reported, and paperwork commits stage the named files, not the spec folder.
11. `install.sh` allows only the clerk's and workers' `cycle.sh` verbs. Owner-only verbs (`briefed --go`, `reopen`, `manual-done`, `escalate`, `human-check.sh`) are not in the allow list.
12. Defect cards reach PowerShell commands as they reach Bash ones.
13. A hook keeps a blind council seat inside its court: no reads outside the court, no git reads of the spec. Seat prompts no longer say `record-seat` enforces blindness.
14. `leak-check.sh` catches any absolute path outside the VULYK root, the hive roots in the private registry and Claude temp-folder paths, and today's hits in the repo are replaced with stand-ins.
15. CI pins third-party actions by full commit SHA.
16. SessionStart and PreCompact hooks exit silently for a subagent (the input carries `agent_id`).
17. A fresh install ships the memory skeleton from `templates/memory.md`, not VULYK's own memory index, and CI checks that the installed index names no `memory/map/` or `tests/` path.
18. The GitHub template quick start leaves README and getting-started, with a recovery line for people who used it. The SessionStart brief recognises such a copy (VULYK's own specs, no `.claude/vulyk-version`). The repo's template flag is switched off at the next publish, on the owner's word.
19. `install.sh --upgrade` takes as a release copy only the blob in the tag of the hive's installed version and merges anything else three-way. Card `upgrade-overwrites-host-edits` gets a `check:` and two fixtures and becomes `block`.
20. `stamp-red` re-hashes `<k>.out` against its record before the re-read, and the parked tests from `wip/a2-minor-tests` come in.
21. `/vulyk-ship` reviews outward text before every publish. A reviewer reads the CHANGELOG, the release notes and the UNASKED/Minor lines of the spec folders being published, by an explicit rule, and a line naming an unfixed gate bypass or hole moves to private notes.
