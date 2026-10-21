# Brief: court-setup

Date: 2026-10-22 · Source: the queue from docs/specs/software-factory-study/report.md (item H, Recommended work 3)

## Request

> Предлагаю делать court-setup: это следующий пункт в очереди, которую ты сам утвердил 19.10 (ship-safety → court-setup → owner-at-ship → исследование spec-worktree). ship-safety уже вышел в 0.31.0, а court-setup ещё не начат: папки docs/specs/court-setup нет. Делаем

(The owner quoted the Queen's proposal and added «Делаем».)

## Context (from the study, verbatim)

> | H | Fresh-checkout setup runs in every worktree, stop on failure (`SF:SKILL.md:114-117`) | `build_court` does `worktree add --detach` and nothing else (`cycle.sh:2099`, checked); a probe that needs `node_modules`/a venv fails, the seat may write `N/A`, and `N/A` counts toward unanimity (`docs/cycle.md:50`) | ADAPT: `.claude/vulyk-setup` run by `build_court`; failure = `open-round` exit 2 |

> Seat files with `N/A ... environment:` exist in most local Node and Python hives. In one Python hive a blind seat judged all seven asks `N/A` "purely on COURT's own missing venv/.env/DB". A setup step fixes the venv and `node_modules` part; a live database or a GPU stack stays a legitimate `N/A`.

## Answers

1. Где шаг: Файл .claude/vulyk-setup — Свой скрипт улья, установщик его никогда не ставит и не трогает. Так уже устроен .claude/vulyk-paperwork (install.sh:78). Скрипт может не ставить всё заново, а сослаться на node_modules или venv основной папки.
2. Ошибка: Раунд не открывается — Копия удаляется, цикл останавливается с ошибкой и хвостом лога. На сломанной копии ревьюер пишет N/A, а N/A считается согласием (docs/cycle.md:50), то есть пустая проверка стала бы «зелёной».
3. Лимит: 5 минут, превышение = ошибка — Вызов advance ограничен 600 секундами. Зависший npm install иначе оборвёт его без понятной ошибки. Улей может поменять лимит переменной VULYK_SETUP_TIMEOUT.
4. Как узнают: Bootstrap + строка при обновлении — Новый улей получает вопрос при /vulyk-bootstrap. Старый видит одну строку при /vulyk-update, если у него есть package.json, pyproject.toml или requirements.txt, а файла нет. Иначе в 20+ живых ульях ничего не изменится.
5. Требования: Верно, покажи план — Требования как есть. План станет на утверждение перед сборкой.

## Asks

1. Если в улье есть .claude/vulyk-setup, он запускается в копии для совета перед раундом.
2. Ошибка или превышение 5 минут: раунд не открывается, копия удаляется, виден хвост лога.
3. Установщик файл не ставит и не трогает.
4. /vulyk-bootstrap спрашивает про него, а обновление пишет одну строку-предложение ульям с зависимостями.
