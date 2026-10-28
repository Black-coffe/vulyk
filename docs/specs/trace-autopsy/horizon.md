# Horizon: trace-autopsy

**Date:** 2026-10-28 · lenses: altitude, depth, range (all three returned)

## New-ground test
Terms: `stacktrace`, `traceback`, `git log -L`, `autopsy`, `bisect`. Searched in `memory/memory.md`, `memory/map/`,
`scripts/`, `.claude/`, `templates/`, `tests/`, `install.sh`: zero hits on the capability. `stack trace` hits only
the container (`.claude/commands/vulyk-plan.md` step 2); `bisect` only a `token-report.py` identifier.

## Candidates and verdicts
- altitude P1 + depth P2 (trace text is untrusted: paths only from `git ls-files`, after `--`, numeric lines,
  every git failure a `skipped:` line, exit 0): **merged into the plan, not a question**. Law 2 never drops
  trust-boundary validation, so it is built regardless.
- depth P1 + range P1 (path half) (Python/Node/bash/Go/Java frames, absolute and Windows paths mapped to repo
  paths by suffix, innermost repo frame first): **kept as H1**.
- range P1 (`--rev` half) + depth P3b (run `git log -L` at the build's revision, warn on shifted lines):
  **kept as H2**.
- altitude P3 + depth P3d + range P3 (print a ready `git bisect run` hint when the brief holds a reproduction,
  never run it): **kept as H3**.
- altitude P2 + depth P3a ("last touched", not "broke"; marks for lines past EOF and unresolved frames; say when a
  scout is still needed): **merged**: the wording becomes an ordinary grill question, the marks are core
  behaviour (a git exit 128 must not break `/vulyk-plan`).
- depth P1 (code lines ±2): **merged**: the code line itself is in the request («точную строчку кода»); ±2 lines
  dropped for the 15-line cap.
- depth P3c (function-level `git log -L :func:file`): **dropped**: extra cost, the cap leaves no room.
- range P2 (`git blame -w -M -C` + `.git-blame-ignore-revs`, SZZ): **dropped**: sources `не подтверждено`, a second
  git call per frame, and the label question covers the false-certainty risk.
- depth DROPPED (hook outside step 2), range/depth DROPPED (running bisect): agreed, not offered.

## Kept proposals

### H1
- what: parse the common trace forms (Python `File "x", line N`, Node `at f (x.js:L:C)`, bash `x.sh: line N:`,
  plain `path:N`), map absolute and Windows paths from another machine (`/app/src/a.py`, `C:\build\src\a.py`) to
  repo files by unique suffix of `git ls-files`, innermost repo frame first.
- why: production traces carry deployment paths; a literal match finds no repo file and the summary comes back empty.
- cost: about 40 lines of parser plus one fixture per form.
- check: `tests/trace-autopsy.test.sh` fixtures: each form, an absolute path, a Windows path, a non-repo frame.
- sources: none: repo only · status: confirmed
- kind: gap. Fragment it rests on: «вырезает из стектрейса все пути file:line, принадлежащие репозиторию». With a
  deployment path no path literally belongs to the repo.
- ask line: (horizon) Скрипт разбирает трейсы Python, Node, bash и вида `путь:строка` и находит файл репозитория
  по хвосту абсолютного или Windows-пути.

### H2
- what: optional `--rev <sha>`: `git log -L` runs at the build's commit, and the summary marks a line that changed
  between that commit and HEAD.
- why: line numbers are read at HEAD; a trace from an older deployed build can point at shifted lines.
- cost: one flag, one extra git call per frame, a fixture repo with a line-shifting commit.
- check: fixture repo: a commit shifts lines, the trace carries the old sha; assert the right commit and the mark.
- sources: https://docs.sentry.io/product/issues/suspect-commits/ (read 2026-10-28, single vendor) · status: не подтверждено
- kind: extension
- ask line: (horizon) `trace-autopsy.sh --rev <sha>` читает строки на коммите сборки и помечает строки, сдвинутые до HEAD.

### H3
- what: when the brief holds a reproduction command, the summary prints a ready `git bisect start` /
  `git bisect run <cmd>` line; the script never runs it.
- why: the idea's title says «Git Bisect», but only a reproduction run finds the commit that broke the behaviour.
- cost: a few lines of output inside the cap; detecting a reproduction command in free text is a heuristic.
- check: fixture brief with and without a reproduction; assert the line and that HEAD and `git status` are unchanged.
- sources: none: repo only · status: confirmed
- kind: extension
- ask line: (horizon) Если в брифе есть команда воспроизведения, сводка печатает готовую команду `git bisect run`, не запуская её.
