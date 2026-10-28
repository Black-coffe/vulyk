---
story: trace-autopsy-01
spec: trace-autopsy
status: done
returned: DONE
tier: 2
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: ::error::trace-autopsy: a Python traceback writes autopsy.md
red_verified_at: 2026-10-28T17:43:22Z 2c51264577d163518bc83ffd3d3563426fe28f9372d41427b3a8540011899c4a
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
- `scripts/trace-autopsy.{sh,py}`: wrapper as `symbol-map.sh`; per line the first frame form wins (Python, Node, bash), else every plain `p.ext:N`. A frame resolves only when a tracked path is its whole tail; a basename-only match is `ambiguous`, so a stdlib `decoder.py` never lands on a repo file of that name.
- The 15-line cap drops whole frame blocks (never a frame's commits) and ends with `... N more repo frames`.
- Known limit: a `most recent call last` trace reverses every frame of the brief, so a plain `path:N` written after the traceback comes first. Measured: 252 ms in the fixture repo, 0.32 s on this repo (3 frames).
- The test block sits in `tests/symbol-map.test.sh` (plan `## Assumptions`); the fixture repo is built in its temp dir.

## Findings

## Red receipt
- command: bash tests/symbol-map.test.sh
- exit: 1
- tests: 2c51264577d163518bc83ffd3d3563426fe28f9372d41427b3a8540011899c4a (tests/symbol-map.test.sh)
- impl: 5b5f19de1b8a2093023e106db3fb26f51c79271a0db8252ae6e5940f3dbc93f6
- stamped: 2026-10-28T17:43:22Z

```
  ok    trace-autopsy: ../../etc/passwd never becomes a frame
::error::trace-autopsy: no repo frame exits 0 - expected '0', got '127'
  ok    trace-autopsy: no repo frame writes no autopsy.md
::error::trace-autopsy: no repo frame says so - expected 'no repo frame' in:
        bash: /e/Projects/vulyk/scripts/trace-autopsy.sh: No such file or directory
::error::trace-autopsy: twelve frames give 0 lines (want 1-15)
::error::trace-autopsy: the last line is not '... N more': 
::error::trace-autopsy: no argument exits 2 - expected '2', got '127'
::error::trace-autopsy: a brief outside any git repo exits 2 - expected '2', got '127'
symbol-map.test.sh: 102 checks, 24 failed
```
