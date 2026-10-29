---
id: shell-needs-gnu-or-bash4
title: Shell that runs only on Linux - bash 4+, GNU-only flags, a bare python
status: block
check: bash scripts/portability-check.sh <arg>
fixtures: [docs/defects/shell-needs-gnu-or-bash4.sed-bre.fixture, docs/defects/shell-needs-gnu-or-bash4.sed-i.fixture, docs/defects/shell-needs-gnu-or-bash4.array.fixture, docs/defects/shell-needs-gnu-or-bash4.python.fixture, docs/defects/shell-needs-gnu-or-bash4.paste-s.fixture, docs/defects/shell-needs-gnu-or-bash4.case-in-subst.fixture, docs/defects/shell-needs-gnu-or-bash4.heredoc-in-subst.fixture]
keys: [macOS, bash 3.2, BSD sed, GNU-only]
paths: ["**/*.sh", "CLAUDE.md", ".claude/commands/*.md", ".claude/agents/*.md"]
---

# Shell that runs only on Linux - bash 4+, GNU-only flags, a bare python
A script, a test or a command's shell block works on Linux and Git Bash and breaks on a stock macOS, where
`/bin/bash` is 3.2 and sed, date, stat, grep, readlink, find and xargs are the BSD ones, there is no
`timeout`, and no bare `python`; or on Windows, where `python3` may be the Store stub.

## Owner quotes
- 2026-10-28 · /vulyk-plan cross-platform · brief.md — «Запускаем `/vulyk-plan cross-platform` (Tier 3) по варианту 1 из отчёта `docs/specs/cross-platform/report.md`: четыре хелпера в `scripts/lib.sh` (`vulyk_python`, `sed_inplace`, `date_epoch`/`date_shift`, `run_capped`), фикс `cycle.sh:853` на `sed -nE`, перевод всех продуктовых, командных (`.claude/commands/*.md`, `CLAUDE.md:76`) и тестовых файлов на переносимые вызовы, статический гейт `scripts/portability-check.sh` с карточкой дефекта и фикстурами, плюс джоба `macos-latest` в `.github/workflows/ci.yml`.»

## Cause
VULYK was written and tested on Windows (Git Bash) and an Ubuntu CI runner, both GNU with bash 5. Nothing ran
the code on a BSD userland, so `sed -i`, BRE `\|`, `date -d`, `timeout`, `python` and empty arrays under `set -u`
spread unseen (docs/specs/cross-platform/report.md).

## Never
- Write `sed -i` bare: use `sed_inplace` from `scripts/lib.sh`; a sed regex with `\|` `\+` `\?` needs `-E` and ERE.
- Call `date -d`, `stat -c`, `grep -P`, `readlink -f`, `find -printf`, `xargs -r` or `%N` without a same-line
  fallback: use `date_epoch` / `date_shift`, or a portable spelling.
- Run `timeout` or `python` / `python3` / `py` by name: use `run_capped`, `vulyk_python` or `bash scripts/py.sh`.
- Use bash 4+ syntax (`declare -A`, `${v,,}`, `mapfile`, `|&`, `&>>`), or expand `"${a[@]}"` under `set -u`
  unguarded: write `${a[@]+"${a[@]}"}`.
- Run `paste -s` with no file operand (BSD paste wants `-` for stdin), or close a `case` pattern with a bare `)`
  inside a `$( )` (bash 3.2 reads it as the end of the substitution): write `paste -sd, -` and `(pat)`.
- Open a `<<` heredoc inside a `$( )` when its body holds a quote or `(` (bash 3.2 parses the body as part of
  the substitution): put the heredoc in a function and call it, `plan="$(read_cards)"`.

## How-to
- Pass a value that can hold a newline to awk through the environment (`name="$val" awk '... ENVIRON["name"] ...'`),
  never `awk -v`: BSD awk refuses a newline there (`awk: newline in string`), and no grep can see what a variable holds.
