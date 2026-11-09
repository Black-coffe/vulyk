# Brief: mass-audit-fixes

**Date:** 2026-11-09
**Tier:** 4 - cross-cutting over every module (cycle.sh gates, hooks, install/upgrade, update, redact, handoff,
tests), with a migration of hive `settings.json` wiring and a change to what close-story trusts (the story file).
**Base:** `main` at 6cbcb46 (0.49.0 plus an external contributor's 45 audit-fix commits, merged 2026-11-09 with
commit subjects and files scrubbed of the client's name).
**Source:** the request below is the session's own summary of the owner's decisions, pasted back by the owner as the
`/vulyk-plan` argument; it is the owner's instruction, not the owner's own wording. Two client names and a person's name in it are
replaced by `[client]` / `[client product]`, and the contributor's name by `[автор]` (owner rule: no client data in the public repo).

## Request (verbatim)

> Записал: берём всю ветку [автора], а сверху делаем один общий план. «Снова» и «again» оставляем убранными из слов,
> по которым ловятся исправления.
>
> Дальше по порядку:
> 1. Чистка коммитов. Его 45 коммитов слить в наш main, но в их заголовках не должно быть «[client product]» и
>    «[client]», иначе данные клиента попадут в публичный репо.
> 2. Общий план через /vulyk-plan: переписать P10-11, семь доработок к его исправлениям, [client product]-08, защита
>    дополненного handoff и наши ~41 находка, которые его ветка не закрывает. Скорее всего это Tier 3–4, поэтому план
>    остановится на твоё утверждение.
> 3. Ответ [автору] после утверждения плана. Отклонённых исправлений нет, P10-11 переписываем, и я объясню почему.
>
> План большой, а контекст этой сессии почти заполнен. Предлагаю сделать /vulyk-handoff и /clear. Решения и разборы
> уже лежат на диске, и в новой сессии я начну сразу с шага 1.

Owner decisions recorded by the previous session (option labels the owner picked, 2026-11-09):

> Вся ветка + общий план (Рекомендую)

> Да, убрать (Рекомендую)

(the second: keep «снова» / "again" out of the correction lexicon.)

Step 1 is done (6cbcb46, fast-forward; the contributor's client-prefixed IDs are renamed `X-07` and `X-08`).
Step 3 is outside this spec.

## Where the detail lives (private, outside git)

This spec fixes security holes that are open in every installed hive. Per the owner rule on audit reports, the
`file:line` evidence and the failure scenarios stay out of the public repo until the release:

- `~/.vulyk/audits/mass-audit-2026-11-08.md` - our 47 findings (IDs `S*`, `I*`, `G*`, `O*`, `P*` with the finder
  prefix), each with Where / Evidence / Failure / Fix / Verifier.
- the private reconcile notes of 2026-11-09 (`cycle`, `hooks`, beside the audit) - the contributor's 35 IDs (P9-*, P10-*, X-07, X-08)
  checked against main: TAKE / extend / rewrite, and which of ours each closes.

Stories, reviews and commit messages describe the target behaviour ("hook commands quote the project dir"), never a
step-by-step way to exploit the old one.

## Scope (from the request and the two private files)

A. Rewrite P10-11: `defects-inject.sh` must skip Python when no card can match; its current skip never fires
   because `docs/defects/README.md` contains `tool:`. Search card files only; no cards -> exit (our O3).
B. Seven extensions of the contributor's fixes: P9-04 (redact the remaining secret names, the rest of our S2), P9-06
   (strip YAML quotes in `fm_field` and `blockers_of` together; unescaped `spec`/`round_dir`/`next` in
   `status --json`), P9-10 (the SessionStart update check still uses `sort -V`), P9-18/P10-10 (git-guard tries `py`
   and reads stdin as UTF-8; the rest of our P2), P10-03 (upgrade adds the SessionEnd `timeout` to existing hives,
   inside our I2 fix), P10-08 (a bare clock time in typed text still files as a correction), X-07 (the macOS branch
   of `load_sample` is only stub-tested).
C. X-08: the suite's `LOAD: start` sample overlaps the step's own first seconds.
D. Handoff: a `/clear` dump must not repoint `index.json` away from an enriched handoff; `tests/handoff.test.sh` has
   no `## Commands` row; `handoff.sh` lacks `$VULYK_PY`.
E. Our findings the merged branch does not close (G7 refuted; S7-hooks, S3-shell and G4 closed by the merge):
   fable-sec-hooks S1-S6, fable-sec-shell S1, S2, S4-S7, opus-consistency I1-I9, opus-gates G1-G3, G5, G6, G8,
   sonnet-tokens-perf O1-O8, sonnet-portability P1-P8 (duplicates fold: S1 = P1, S5 = I8, P2 with B).

## Answers

1. Имя клиента - «Файлы сейчас, история потом (Рекомендую)»: В этом плане убираем имя из файлов. Историю переписываем
   после выпуска, когда исправленное обновление дойдёт до ульев и переживёт сдвиг тегов. До тех пор имя видно в старых
   коммитах.
2. Файл истории - «Сверять с версией в git (Рекомендую)»: close-story берёт эти три блока из утверждённой версии в git,
   а не из рабочей копии. Если копия расходится с git, close-story отказывает. Done без коммита от close-story не
   считается закрытым. Истории и так коммитятся до работы исполнителя (коммит плана, коммит repair), поэтому новый
   файл состояния не нужен.
3. Карты block - «Гейт + строки (Рекомендую)»: close-story запускает проверку карты на файлах истории и при провале
   отказывает. Строки «никогда» снова показываются агентам. Так карта block действительно строже текстовой.
4. Утверждение - «Отказ в коде (Рекомендую)»: Для средних и крупных планов cycle.sh отказывается открыть сборку без
   твоего утверждения или явного --go и записывает, что был --go. Проверка перед выпуском требует того же. В памяти уже
   записаны случаи, когда остановку пропускали.

5. Драйвер (2026-11-09, посреди сборки, после двух остановок на искажённой строке `--claim`):
> Почини драйвер сразу, не жди конца сборки

6. Хуки старых ульев (2026-11-09, посреди сборки): «Сказать + раскатка (Рекомендую)»: --upgrade печатает строку о каждом
   отсутствующем хуке с командой, которая его подключит; на раскатке Queen сверяет каждый улей и подключает
   хуки, потерянные из-за старого бага; удалённый владельцем намеренно хук не возвращается.

## Asks

1. P10-11 rewritten: `defects-inject.sh` starts no Python when no card can match the tool call, searching card files only (not `docs/defects/README.md`), and exits at once when the hive has no cards (our O3).
2. P9-04 extended: `redact.sh` (and the handoff built-in pass kept in parity) masks the secret names still unmasked after the merge (the rest of our S2).
3. P9-06 extended: a quoted front-matter value is unquoted in `fm_field` and `blockers_of` together, and `status --json` escapes `spec`, `round_dir` and `next` too.
4. P9-10 extended: the SessionStart update check picks the newest tag without `sort -V`.
5. P9-18 / P10-10 extended: `git-guard.sh` tries `$VULYK_PY`, python3, python, py like `lib.sh`, and reads hook stdin as UTF-8 (the rest of our P2).
6. P10-03 extended: `install.sh --upgrade` gives existing hives' SessionEnd hooks their `timeout`, as part of the I2 fix (install into an existing `settings.json` wires every hook and says so).
7. P10-08 extended: a bare clock time in typed text is no longer filed as a correction; «снова» / "again" stay out of the correction words.
8. X-07: the macOS branch of `load_sample` runs for real on macOS (CI), not only against a stub.
9. X-08: the suite's `LOAD: start` sample is taken before the step starts and does not overlap it.
10. Handoff: a `/clear` dump never repoints `index.json` away from an enriched handoff; `tests/handoff.test.sh` gets a `## Commands` row; `handoff.sh` honours `$VULYK_PY`.
11. Every finding of our private audit that the merged branch does not close (Scope E) is fixed, with a regression test wherever code can check it.
12. close-story reads `## Verification`, `## Files` and `red:` from the story's approved version in git and refuses when the working copy differs in them; a story marked done without close-story's own commit is not closed.
13. A `block` defect card's check runs in close-story on the story's matching files and a failure refuses the close; the card's never-lines are shown to agents again.
14. `cycle.sh` refuses to open the build of a Tier 2-4 plan without the owner's `**Approved:**` or an explicit `--go`, records the `--go`, and the pre-release check requires the same.
15. The client's folder name is removed from the current public files (four places); rewriting history is left for after this release reaches the hives.
16. (Added by the Queen at planning on 2026-11-09, from a side agent's note the owner passed on; confirm at approval.) `brief_asks` keeps a wrapped `## Asks` item whole: an indented continuation line joins the numbered item above it, so `trace-check.sh` and `cycle.sh` read the full ask, not its first line.
17. (Added by the owner mid-build on 2026-11-09: «Почини драйвер сразу, не жди конца сборки».) The Workflow driver survives a cycle-clerk that garbles the long `advance --claim` line: it proves the claim with a short re-claim by the same stamp instead of stopping the run.
18. (Added by the owner mid-build on 2026-11-09, choice «Сказать + раскатка (Рекомендую)».) `install.sh --upgrade` names every hook this release ships that the hive's `settings.json` does not wire, one line each with the command that wires it, and never wires it unasked; at rollout the Queen wires, per hive, the hooks the old installer bug dropped.
