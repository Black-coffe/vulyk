# Stack trace autopsy for bug-fix briefs (plan)

**Tier:** 2 · **Spec slug:** `trace-autopsy` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-008 (deliverable, approval stop), ADR-022 (horizon step); sibling contract `docs/specs/symbol-map/plan.md`
**Depends on:** 0.41.1 (`c4fec65`)

## Goal
When the owner's request carries a stack trace, `/vulyk-plan` step 2 runs a no-model script on the fresh brief. The
script finds the trace frames that belong to the repo, also when they are written as deployment or Windows paths. It
then writes `docs/specs/<slug>/autopsy.md`, at most 15 lines: each frame's code line read at HEAD and the last
commits that touched that line, labelled as a lead, not as the culprit. When the autopsy resolves a repo line, the
location counts as known and step 3 sends no scout.

## Assumptions
- The script reads only the brief's `> ` blockquote lines (the verbatim request). Recon facts written into the brief
  later carry `file:line` references of their own and must not become frames.
- Frames are found by their forms (Python `File "x", line N`, Node `at f (x:L:C)` / `at x:L:C`, bash `x.sh: line N:`,
  plain `path.ext:N`). This covers the owner's three trigger regexes (`Traceback`, `at .*\.(js|ts|py|sh):[0-9]+`,
  `line [0-9]+`), so no separate trigger gate runs: no resolved frame means no `autopsy.md`.
- Trust boundary (Law 2, merged from horizon altitude P1 and depth P2, not an owner ask): only paths in
  `git ls-files` ever reach git, a line number is digits only, git runs from an argv list with no shell, and every
  git failure (a line past EOF exits 128) becomes a mark in the summary, never a non-zero exit.
- Suffix match: a frame path matches the tracked file whose path is the longest unique suffix of it. Two equal
  candidates are reported as `ambiguous`, not guessed.
- Order: innermost frame first (a Python `Traceback (most recent call last)` block is reversed). At most 3 frames ×
  3 commits fit the 15 lines; the rest folds into one `... N more` line.
- `git log -L` without `-n` follows a line to its first commit; `-n 3` keeps the newest three.
- The script is Python stdlib behind a bash wrapper, like `symbol-map.sh` / `symbol-map.py` (picks python3|python,
  exit 2 without one).
- Its tests join `tests/symbol-map.test.sh` (the planning-helper suite) as their own block. Rejected: a new
  `tests/trace-autopsy.test.sh`, because a story's `## Verification` needs a `## Commands` row, and `CLAUDE.md` is
  at 7153 of 7168 bytes (`tests/maintenance.test.sh:31`), so a row would force a trim of constitution text.
- Not measured, not promised: the request's «Скорость планирования Tier 1–2 вырастает вдвое» and «расход токенов
  на разведку падает до нуля». Step 3 already sends no scout at Tier 1 with a known location, at most one at
  Tier 2, so the saving is mostly the Queen's own Grep/Read calls. CHANGELOG states no speed figure. Comparing a
  few real bug fixes before and after is a post-release check, outside this spec.

## Stories

**Wave 1**
- `trace-autopsy-01` — `scripts/trace-autopsy.{sh,py}` + its test block and fixtures (red: required)

**Wave 2**
- `trace-autopsy-02` — `/vulyk-plan` steps 2-3, command reference, CHANGELOG, a guard check that step 2 names the script

## Contracts
- `bash scripts/trace-autopsy.sh <brief.md>`: writes `<dir of brief>/autopsy.md` and prints it when at least one
  repo frame resolves; else prints one `trace-autopsy: no repo frame (<n> frames seen)` line and writes nothing.
  Exit 0 for any brief content; 2 for usage, no python, or not inside a git repo.

## Integration gate
`bash tests/full-suite.sh`

## Descoped

*(empty)*

## Plan deltas

- 2026-10-28, trigger: a side-agent note relayed by the owner during story 02 (model text, not an owner quote): a build
  that drops a folder (`/app/app/core.py` for `src/app/core.py`) left the frame `ambiguous`, and with no resolved frame
  the ambiguous hint was lost. Decision: a unique tail of two parts or more resolves; the `no repo frame` line names the
  first ambiguous candidates; story 02 also takes `scripts/trace-autopsy.py`. Rejected: mapping built `dist/` files
  back to sources (needs source maps; stays a known limit). Owner told in one line.


**Approved:** Andrei, 2026-10-28 («/vulyk-build trace-autopsy»)
**Branch:** vulyk/trace-autopsy
**Council:** GREEN round 1, 2026-10-28, at dba32f4, pack d12770efbfef
