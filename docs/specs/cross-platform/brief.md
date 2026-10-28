# Brief: cross-platform

**Date:** 2026-10-28 · **Deliverable:** document (study, `/vulyk-plan` step 0) · no story, no council

## Request (verbatim)

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

## Asks

1. Bash 4+ syntax sites, `file:line`.
2. GNU-only utilities and flags, `file:line`.
3. Unguarded `python` / `python3` calls, `file:line`.
4. Hard-wired paths and separators, `file:line`.
5. Count of affected files; how to close it with shared helpers in `scripts/lib.sh` and a static compatibility gate.
