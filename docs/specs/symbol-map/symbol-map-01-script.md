---
story: symbol-map-01
spec: symbol-map
status: done
returned: DONE
tier: 3
worker: worker-code
wave: 1
blocked_by: []
---

# `scripts/symbol-map.sh`: the link finder, its test and its `## Commands` row

## Goal
After this story `bash scripts/symbol-map.sh <file>...` prints, for each input, the repo paths linked to it that lie outside the scope set (tests, importers, imported, guard tests, path mentions), each line labelled `exact` or `textual`, each block capped at 1.5 KB, a missing input reported. `tests/symbol-map.test.sh` proves it on committed fixture trees and the constitution's `## Commands` table names that test, so later stories can verify with it. Python stdlib only, no cache, no tree-sitter/ctags.

## Requirements
> 2. scripts/symbol-map.sh <файл> без модели выдаёт связи файла: кто его импортирует, кого импортирует он сам, тесты-стражи, файлы с его путём. Языки Python и bash, только пути вне ## Files, не больше 1,5 КБ, метка «точно / по имени».
> 1. memory/map/*.md остаётся для смыслов и подводных камней.
> Оставить memory/map/*.md для смыслов и подводных камней (то, что скрипт не поймёт).
> Добавить детерминированный скрипт scripts/symbol-map.sh <file_or_module>, который без участия LLM мгновенно выдаёт

## Files
- scripts/symbol-map.sh
- scripts/symbol-map.py
- tests/symbol-map.test.sh
- tests/fixtures/symbol-map/**
- CLAUDE.md

## Non-goals
- Do not touch `memory/map/*.md`, `.claude/agents/*`, `.claude/commands/*` or `install.sh`: `OWNED` already ships `scripts/`; the protocol lines are story 02.
- No block, no gate, no exit code that fails on a found caller: the script reports, nothing more (crossgrill 3/3).
- No cache file, no `git log` co-change, no JS/TS/PHP import resolution, no function-level callers: file level only.
- No repo-wide name search without an input file; textual importers and path mentions stay capped.
- Change nothing in `CLAUDE.md` but one new row in `## Commands` (the file is 7104 B against a 7168 B cap and 108/120 lines; `tests/maintenance.test.sh` enforces both). Do not edit any `description:` frontmatter anywhere.
- Write `.py` files and fixtures with the Write tool, never through a Bash heredoc with backslashes (writes stray CR bytes on this machine). `.gitattributes` keeps `*.sh`/`*.py` LF.

## Map slice
`memory/map/scripts.md`: `## Purpose` (conventions: `set -u`, python helpers `scripts/<name>.py` stdlib only), `## Tests (0.36.0)` (`tests/full-suite.sh` picks up every `tests/*.test.sh`; budget 590 s, so this test must stay under a few seconds), `## Gotchas` (anchored string matches). `CLAUDE.md` `## Commands` for the row format.

## Acceptance criteria
- [ ] `bash scripts/symbol-map.sh pkg/core.py` inside the Python fixture (a package with `pkg/core.py`, `pkg/util.py` imported by core, `pkg/api.py` with `from . import core`, `pkg/__init__.py` re-exporting `core`, `app.py` importing `pkg`, `tests/test_core.py` importing core, `tests/test_tree.py` walking the repo with `os.walk`, `docs/notes.md` naming `pkg/core.py`, `misc/core_v2.py` and a file mentioning the word `core` without importing it) prints the block of the Contracts section: `tests:` first with `exact tests/test_core.py`; `importers:` with `exact pkg/api.py` and `exact app.py (via pkg/__init__.py)`; `imported:` with `exact pkg/util.py`; `guard tests:` with `textual tests/test_tree.py`; `path mentions:` with `textual docs/notes.md`; the false friends appear only as `textual`, never `exact`.
- [ ] An input whose language the script does not parse for imports (anything but `.py` and bash: `.sh`, `.bash`, or a bash shebang), e.g. a `src/app.ts` fixture, gets the language-independent sections and the line `  ! imports not parsed for .ts: search callers yourself` in its block, so an empty result never reads as "no callers"; the test pins the line.
- [ ] `--scope pkg/api.py` (and the same path listed under `## Files` of a story file passed with `--story`) removes `pkg/api.py` from the output; `--story` with no positional file uses the story's `## Files` as inputs; a glob line in `## Files` scopes by `fnmatch`.
- [ ] In the bash fixture (`scripts/run.sh` sourcing `lib.sh` via `$(dirname "$0")/lib.sh`, `tests/run.test.sh` sourcing it by literal path) `bash scripts/symbol-map.sh lib.sh` lists `exact scripts/run.sh` under `importers:` and `exact tests/run.test.sh` under `tests:`.
- [ ] A fixture that produces more than 1536 bytes in one call (several inputs, or one busy input) ends the whole output with exactly one `... N more` line and the whole stdout stays at or under 1536 bytes; `path mentions:` never exceeds 5 lines plus the count line.
- [ ] A missing input prints `## <path>` + `  ! missing`, the other inputs are still printed, exit status 1; no arguments or an unknown flag prints usage, exit 2; a `.py` input with a syntax error prints `  ! unparsed` and still gets its textual sections, exit 0; a `.md` input gets only tests/guard tests/path mentions.
- [ ] `tests/symbol-map.test.sh` copies `tests/fixtures/symbol-map/<tree>` into a temp dir, runs `git init -q && git add -A` there, asserts every line above, cleans up, and runs in under 10 s; `CLAUDE.md` `## Commands` gains the row `| Symbol map | \`bash tests/symbol-map.test.sh\` |` and nothing else; `bash tests/maintenance.test.sh` stays green (caps).
- [ ] `memory/map/*.md` is not touched by this story (ask 1).

## Verification
`bash tests/symbol-map.test.sh && bash tests/maintenance.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes
- `scripts/symbol-map.py` (stdlib: ast, fnmatch, subprocess git ls-files) + `scripts/symbol-map.sh` wrapper (python3 then python, like defects-index.sh).
- Fixtures: `tests/fixtures/symbol-map/python` and `.../bash`; the test generates the cap cases (8 extra docs, 70 importers) inside its own temp copies instead of committing them.
- `tests/symbol-map.test.sh`: 51 checks, about 4 s; `git -c core.autocrlf=false add -A` keeps the CRLF warnings out of the copies.
- `CLAUDE.md`: one `## Commands` row after Model profile tests (7154 B LF, 109 lines).
- Decisions: a path is listed once per block, in the first section that claims it; guard tests are capped at 5 like path mentions and textual importers; the `--story` file itself is in scope; a `## Files` glob is scope only, never an input.
- The `! imports not parsed for <ext>` line is printed for every non-Python, non-bash input, `.md` included (criterion 2 reads 'anything but .py and bash').
- An unparsed `.py` input still gets exact importers from other files' ASTs; only `imported:` is lost.
- Bash `source` words are read with quote/paren balancing so `"$(dirname "$0")/lib.sh"` resolves; a `$...)/` or `$VAR/` prefix resolves against the sourcing dir, then root, then a unique basename.

## Findings
