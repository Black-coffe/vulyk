---
story: rules-tree-01
spec: rules-tree
status: done
returned: DONE
tier: 4
worker: worker-code
model: opus
wave: 1
blocked_by: []
---

# Card contract: area folders, three branches, tool scope, one shared parser

## Goal
After this story one parser, `.claude/hooks/defects_lib.py`, reads the whole library: cards at the root (area
`general`) and in one level of area folders, the three branch sections in en/ru/uk, `paths:` entries of kind glob /
`cmd:` / `tool:`, the `exception:` key and the `passes:` key. `scripts/defects-check.sh` discovers and
parses cards through it (git paths relative to the library root, `DUPLICATE` on an id used twice) and otherwise behaves
exactly as today: every existing `tests/defects.test.sh` case stays green with the same output. `docs/defects/README.md`
states the format contract. The inject and intake hooks switch to the parser in stories 04 and 05.
`model: opus`: this is the data contract every other story builds against; a wrong shape here costs the whole wave 2.

## Requirements
> чтобы он ввёл древовидную структуру, в которой будет одно направление — это разрешения markdown-файлов, другое направление — это запреты markdown-файлов, и третье направление — это правила.
> 1. Три ветки (Нельзя / Можно / Как надо) — секции карточки в `docs/defects/`; карточки лежат в папках по областям.
> 2. Разрешение — самостоятельная запись с областью и словами владельца; перебивает запрет только явной ссылкой на него (с фикстурой «проверка запрета на разрешённую форму не срабатывает»); пересечение без ссылки — действует запрет, гейт красный.
> 4. Область карточки = файлы + команды + инструменты (действия: отправка, публикация, браузер); правила, ни к чему не привязанные, — один всегда загружаемый файл в `.claude/rules/`, не длиннее ~40 строк.

## Files
- .claude/hooks/defects_lib.py
- scripts/defects-check.sh
- tests/defects.test.sh
- docs/defects/README.md

## Non-goals
- Do not change the gate's findings (debt rule, overlap, escape, undeliverable) beyond what sub-folder paths force; the
  new findings `CONFLICT`, `EXCEPTION`, `INDEX`, the Allowed counter and the index are story 03.
- Do not touch `defects-inject.sh` or `defect-intake.sh`: stories 04 and 05 switch them to the parser.
- Do not move VULYK's own cards into area folders; do not rewrite the README `## Cards` table (story 03 replaces it).
- Do not rename `paths:`; do not add a `kind:`/`branch:` field: a branch is a section.

## Map slice
- memory/map/scripts.md: `defects-check.sh` entry (exit codes, findings, `DEFECTS_DIR`); `## Tests`.
- docs/specs/rules-tree/scout-machinery.md: Gotchas 1-3 (flat discovery `inject:92 intake:89 check:158-160`, bare
  filename in blame/log `:93 :232 :81`, duplicated parser blocks, section regexes) and Tests (`mkrepo`, `card`, `run`).
- docs/specs/rules-tree/plan.md `## Contracts`: Library layout, Sections, Scope, `defects_lib.py`.

## Acceptance criteria
- [ ] `python3 .claude/hooks/defects_lib.py <lib-dir>` prints one JSON object per card with the fields of the contract;
      a card in `docs/defects/<area>/<id>.md` has `area` = folder and `ref` = `<area>/<id>`; a root card has `area:
      general` and `ref` = `<id>`; `fixtures/` at either level, `README.md` and `INDEX.md` (any case) are not cards.
- [ ] Sections parse under all three language headings; an Allowed line yields its date; `exception:` parses as a ref (or
      none); `passes:` parses like `fixtures:`; `tool:<regex>` parses as kind `tool`; `specificity()` ranks
      `src/pay/stripe.py` above `src/**` and `tool:WebFetch` above `tool:.*`.
- [ ] `defects-check.sh` on a library with a foldered card: the card is audited, its blame/`git log` paths resolve
      (debt new/old computed, no git error), and the README add-commit is still read from the root README.
- [ ] Two cards with one id (root + folder, or two folders) → `DUPLICATE <id>` and exit 1.
- [ ] On a flat library the gate's output is byte-identical to today's (all pre-existing `tests/defects.test.sh` cases
      pass unchanged); the parser's `listval` naive comma split is replaced by the lib's list parsing.
- [ ] `tests/defects.test.sh` gains failing-first cases: foldered card discovered and blamed; duplicate id red;
      `fixtures/` inside an area ignored; section/scope JSON dump assertions (one case each for `exception:`,
      `passes:`, `tool:`).
- [ ] `docs/defects/README.md` documents areas, the ref form, the three sections with their aliases, the dated Allowed
      line plus the `exception:` key, `passes:`, the `tool:` scope, and says `## Cards`/the index is generated (pointer only; the
      table itself is story 03's).

## Verification
`python -m py_compile .claude/hooks/*.py`
`git ls-files '*.sh' | xargs -n1 bash -n`
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh`
`bash scripts/defects-check.sh`

## Implementation notes
- `.claude/hooks/defects_lib.py` (new): discovery (root + one area level, `fixtures/`/dot dirs skipped, README/INDEX any case), frontmatter by `
` split so line numbers match git blame, `fm_scalar`/`fm_list` lifted verbatim from the hooks' shared block, `glob_rx` lifted from inject.
- Card is a plain attribute object (`vars(card)` = the JSON dump); a dict subclass was dropped because `card.keys` collided with `dict.keys`.
- Card fields beyond the contract, needed by the gate and story 03: `exception` (frontmatter ref, `.md` stripped, null when absent), `scopes`, `allowed_dates`, `fm_lines` (key -> line), `lines` (line numbers per section incl. `quotes`).
- `id` = file stem (contract), not frontmatter `id:` as the old gate did; identical on every card whose `id:` equals its stem (all of VULYK's and all test cards).
- `allowed_except(line)` not built: ADR-021 reconciled the exception to the `exception:` frontmatter key, exposed as `card.exception`.
- `effective_status(card)` returns `(status, reason)`; the gate keeps its two message forms on top of the reason.
- `tool:` is `re.fullmatch` on tool_name per the plan contract; ADR-021's example `tool:^(WebFetch|mcp__)` would not match `mcp__x` under it (README shows `tool:mcp__.*`).
- `scripts/defects-check.sh`: imports the lib from `$(dirname "$0")/../.claude/hooks` (exit 2 if missing), git calls use `card.path`, findings print `card.ref`, new `X`/`DUPLICATE` record and `N duplicate ids` verdict part; `listval` and the hand-rolled loops removed; help range 2,35.
- Byte-identical check: old vs new gate output on VULYK's own library diffed equal; the new test file run against the old gate fails exactly the 4 folder/duplicate gate cases and passes every pre-existing case.
- `tests/defects.test.sh`: `mkrepo` copies the lib; new sections area folders, duplicate ids, parser dump (exception, passes, tool, three-language sections, dates, specificity).
- `docs/defects/README.md`: CRLF working copy kept; added Areas and refs, branch table with aliases, `exception`/`passes`/`tool:` rows, pointer to the generated INDEX.md above the untouched `## Cards` table.

## Findings
- close-story exit 4 on a foreign untracked file (`docs/grill/2026-10-19-software-factory.md`, written by a parallel session); the Queen hid it in `.git/info/exclude` and closed the story.
