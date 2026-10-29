# Brief: cross-platform

**Date:** 2026-10-28 · **Deliverable:** study (`report.md`, commit `study(cross-platform)`), then code (`/vulyk-plan`, Tier 3: option 1 of the report) · Source: the owner's two `/vulyk-plan` arguments

## Request (study)

> Проведи исследование (`/vulyk-plan cross-platform --study`) на совместимость всех скриптов (`scripts/*.sh`, `.claude/hooks/*.sh`, `install.sh`, `tests/*.sh`) и `CLAUDE.md` с тремя платформами: Windows (Git Bash), Linux и macOS (где системный `/bin/bash` версии 3.2 и BSD-утилиты вместо GNU).
>
> Ничего не меняй в коде, только проверь и выпиши все места (`file:line`), где сейчас используются:
> 1. Синтаксис Bash 4+ (несовместимый с `/bin/bash` 3.2 на macOS): `declare -A`, `${var,,}`, `${var^^}`, `mapfile`, `readarray`, `|&`, `&>>`.
> 2. Утилиты и флаги GNU, которых нет на стоковой macOS (BSD): `timeout`, `sha256sum`, `sed -i`, `grep -P`, `stat -c`, `date -d` / `date -I`, `readlink -f`, `find -printf`, `xargs -r`.
> 3. Прямые вызовы `python` или `python3` без проверки (на Windows `python3` может быть заглушкой Store с кодом 49, на macOS нет алиаса `python` без цифры 3).
> 4. Жёсткие привязки к путям или разделителям (`/` vs `\`, `/tmp`, `/proc` и т.д.).
>
> В конце отчёта оцени, сколько файлов затронуто и как проще всего закрыть это через единые хелперы в `scripts/lib.sh` и статический гейт совместимости.

## Context

Preceded in the same session by an owner brainstorm (Windows-first VULYK, wish to run on macOS and Linux, Docker vs CI). The Queen's answer recommended a `macos-latest` CI job plus portable helpers; this study is the evidence pass behind that.

## Study asks (answered by report.md)

1. Bash 4+ syntax sites, `file:line`.
2. GNU-only utilities and flags, `file:line`.
3. Unguarded `python` / `python3` calls, `file:line`.
4. Hard-wired paths and separators, `file:line`.
5. Count of affected files; how to close it with shared helpers in `scripts/lib.sh` and a static compatibility gate.

## Request (build)

> Запускаем `/vulyk-plan cross-platform` (Tier 3) по варианту 1 из отчёта `docs/specs/cross-platform/report.md`: четыре хелпера в `scripts/lib.sh` (`vulyk_python`, `sed_inplace`, `date_epoch`/`date_shift`, `run_capped`), фикс `cycle.sh:853` на `sed -nE`, перевод всех продуктовых, командных (`.claude/commands/*.md`, `CLAUDE.md:76`) и тестовых файлов на переносимые вызовы, статический гейт `scripts/portability-check.sh` с карточкой дефекта и фикстурами, плюс джоба `macos-latest` в `.github/workflows/ci.yml`.
>
> При подготовке плана учти четыре момента:
> 1. По пустым массивам под `set -u`: не оставляй 19 неклассифицированных мест до падения в CI — сразу переведи все раскрытия массивов в файлах с `set -u` на безопасную форму `${a[@]+"${a[@]}"}` и добавь проверку на незащищённый `"${a[@]}"` в `portability-check.sh`.
> 2. Убедись, что `install.sh` корректно подгружает `scripts/lib.sh` (или имеет доступ к `vulyk_python` и `sed_inplace`) при любом способе запуска.
> 3. Для `run_capped`: оцени, не проще ли при отсутствии `timeout` и `gtimeout` использовать fallback на `"$VULYK_PY"` (`subprocess.run` с `timeout` и кодом 124), чтобы таймауты реально работали на стоковой macOS, а тесты таймаутов проходили без `skip`.
> 4. При замене голого `python` в ячейке `CLAUDE.md:76` (`## Commands`) проверь совместимость с `verify-cell` и апгрейдом существующих ульев.

## Recon on the four points (Queen, 2026-10-28)

- (2) `install.sh:18` sets `SRC` to its own directory; every documented run (`README.md:80,90`, `scripts/vulyk-update.sh:98`) starts it from a full checkout, so `"$SRC/scripts/lib.sh"` is always beside it. `lib.sh` only defines functions plus `set -u` (`scripts/lib.sh:14`); `install.sh:16` already runs `set -euo pipefail`.
- (3) `subprocess.run(timeout=)` kills only the direct child; `bash -c` grandchildren survive unless the child gets its own session (`start_new_session=True`) and the group is killed (`os.killpg`), with a grace period then SIGKILL like `timeout -k 10` (`tests/full-suite.sh:97`).
- (4) The `## Commands` table of VULYK's `CLAUDE.md` is VULYK's own: a hive gets a placeholder and its own block is carried over verbatim on upgrade (`install.sh:209,292,417`). No open story names the `python -m py_compile` cell.

## Answers

1. Python — bash scripts/py.sh (Рекомендую): Маленькая обёртка: берёт vulyk_python из lib.sh (проверка запуском) и передаёт ей аргументы. Одна строка работает на всех трёх платформах и с заглушками, а гейт может запретить голый python/python3 везде, кроме lib.sh.
2. CI на Mac — Все тесты + установщик (Рекомендую): Те же два задания, что на Ubuntu, запускаются ещё и на Mac (строчка матрицы). Пустые массивы и BSD-поведение всплывают в самых разных тестах, а установщик — то, что владелец Mac запускает первым. Цена: CI дольше зеленеет.
3. Windows CI — Не добавлять (Рекомендую): Windows и так проходит все тесты при каждой сборке на вашей машине; Git Bash на GitHub — самый медленный раннер (каждый вызов — дорогой запуск процесса), а пользы новой практически нет, пока код пишется только здесь.
4. Требования — Подтверждаю (Рекомендую): Список верный; покажи план на одобрение перед сборкой — в плане много файлов, стоит увидеть разбивку.

Side-agent notes relayed in this session (model text, not owner words): a stock Mac without Xcode Command Line Tools may carry a `/usr/bin/python3` stub; GitHub's macOS image may put a Homebrew bash 5 ahead of `/bin/bash` on PATH, so the macOS job must pin `/bin/bash` 3.2 and print its version. Both unverified.


**After escalation (round 4, 2026-10-29).**
> Owner's choice: «Переоткрыть: только 3 падения Mac (Рекомендую)». The round-4 inject latency finding is treated as machine-load noise (alone: 163-168 ms, threshold 200 ms kept; the hook is not in the diff) - no code change for it. The repair fixes the three macOS-only failures of probe run 40871539881: tests/maintenance.test.sh:119 BSD sed brace; cycle.sh briefed accepting an empty ## Asks on macOS; council walks probe r2m9 on the branch.
## Asks

1. Четыре хелпера в `scripts/lib.sh`: `vulyk_python`, `sed_inplace`, `date_epoch`/`date_shift`, `run_capped`.
2. Фикс `cycle.sh:853` на `sed -nE`.
3. Перевод всех продуктовых, командных (`.claude/commands/*.md`, `CLAUDE.md:76`) и тестовых файлов на переносимые вызовы.
4. Статический гейт `scripts/portability-check.sh` с карточкой дефекта и фикстурами.
5. Джоба `macos-latest` в `.github/workflows/ci.yml`.
6. Все раскрытия массивов в файлах с `set -u` — на `${a[@]+"${a[@]}"}`, и проверка на незащищённый `"${a[@]}"` в гейте.
7. `install.sh` подгружает `scripts/lib.sh` (`vulyk_python`, `sed_inplace`) при любом способе запуска.
8. `run_capped` без `timeout` и `gtimeout` падает на `"$VULYK_PY"` (subprocess, код 124), тесты таймаутов идут без `skip`.
9. Замена голого `python` в `CLAUDE.md:76` совместима с `verify-cell` и апгрейдом ульев.
