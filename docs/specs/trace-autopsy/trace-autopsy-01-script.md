---
story: trace-autopsy-01
spec: trace-autopsy
status: todo
returned:
tier: 2
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: "scripts/trace-autopsy.sh: No such file or directory"
---

# trace-autopsy.sh: repo frames of a stack trace, with the last commits per line

## Goal
`bash scripts/trace-autopsy.sh docs/specs/<slug>/brief.md` reads the brief's `> ` lines, finds the stack frames
that belong to the repo and writes `docs/specs/<slug>/autopsy.md` (at most 15 lines): HEAD sha7 and date, then
per frame `path:line` with the code line at HEAD and up to three `git log -n 3 -L <line>,<line>:<path>` commits
(sha7, date, author, subject) under the label «last touched this line», then marks for unresolved, ambiguous and
past-EOF frames. Contract and every rule: plan.md `## Contracts` and `## Assumptions`.

## Requirements
> 1. Скрипт scripts/trace-autopsy.sh вырезает из стектрейса в brief.md пути file:line из репозитория и для каждого берёт git log -n 3 -L.
> 3. В сводке есть точная строка кода, коммиты с подписью «последний, кто менял строку» и HEAD, на котором читались строки.
> 4. Скрипт работает без модели, на доли секунды.
> 6. (horizon) Скрипт разбирает трейсы Python, Node, bash и вида путь:строка и находит файл репозитория по хвосту абсолютного или Windows-пути.
> Скрипт за 0 токенов и 0.1 секунды находит точные строки в коде и последний коммит, который их менял, и кладёт сводку на 15 строк рядом с брифом.

## Files
- scripts/trace-autopsy.sh
- scripts/trace-autopsy.py
- tests/symbol-map.test.sh

## Non-goals
- No committed fixture tree: the test builds its fixture repo and briefs in its temp dir.
- No `--rev`, no `git bisect` hint, no `git blame -w -M -C`, no function-level `-L :func:` (horizon H2/H3 declined, the rest dropped).
- Do not touch `symbol-map.py` or the existing symbol-map test cases; the new cases are their own block.
- Do not read anything but the brief's `> ` lines; no network, no model.

## Map slice
`memory/map/scripts.md`: the `symbol-map.sh` entry (wrapper shape, python pick, exit codes, capped output).

## Acceptance criteria
- [ ] Python traceback with a deployment path (`File "/app/<repo path>", line N`), a Node frame
      (`at f (C:\build\<repo path>:L:C)`), a bash frame (`<path>.sh: line N:`) and a plain `path:N` each resolve to
      the tracked file in a fixture repo; innermost frame first.
- [ ] A frame outside the repo, an ambiguous suffix and a line past EOF each give a mark line, exit 0.
- [ ] Hostile frames (`-L1,1:x`, `../../etc/passwd`, `$(touch pwned)`) reach no git argument: no file `pwned`
      appears, exit 0.
- [ ] A brief with no repo frame writes no `autopsy.md` and prints the `no repo frame` line, exit 0.
- [ ] Twelve repo frames: `autopsy.md` has at most 15 lines and ends with `... N more`.
- [ ] The output names HEAD's sha7 and «last touched»; it never says «broke» or «сломал».
- [ ] A run on the fixture repo takes under 1 s (measured in the test, printed).
- [ ] Usage errors and a brief outside a git repo exit 2.

## Verification
`bash tests/symbol-map.test.sh`

## Implementation notes

## Findings
