---
story: cross-platform-05
spec: cross-platform
status: todo
returned:
tier: 3
worker: worker-code
wave: 3
blocked_by: [cross-platform-02, cross-platform-03, cross-platform-04]
red: required
red_reason:
# red_verified_at:      # written by `cycle.sh stamp-red`, never by hand
---

# The portability gate, its defect card and fixtures, and the macOS CI leg

## Goal
`scripts/portability-check.sh` exists as `plan.md ## Contracts` states it and exits 0 on the whole tree this spec leaves
behind; `docs/defects/shell-needs-gnu-or-bash4.md` is a `block` card whose `check:` is the gate and whose four fixtures
each make it exit 1 (`docs/defects/INDEX.md` regenerated); `tests/maintenance.test.sh` runs the gate on the tree and, per
rule, on a temp file holding the original form and a neighbour form (exit 1, the rule named), plus the `# portable:`
allow (exit 0, counted), a Python heredoc body (exit 0) and a missing argument (exit 2). `tests/maintenance.test.sh`'s own
four `sed -i`, five unguarded arrays and the `:15` resolver switch here (the gate would hit them). CI: the `shell` job runs
the gate; `full-suite` and `install-smoke` run on a matrix of `ubuntu-latest` and `macos-latest`, the macOS leg pinned to
the stock bash and asserting it. Test first (ADR-025): the maintenance assertions are written and stamped red before the
gate script exists (a `red_reason` such as `portability-check` - the «No such file» line and the assertion labels carry it).

## Requirements
> 4. Статический гейт `scripts/portability-check.sh` с карточкой дефекта и фикстурами.
> 5. Джоба `macos-latest` в `.github/workflows/ci.yml`.
> 6. Все раскрытия массивов в файлах с `set -u` — на `${a[@]+"${a[@]}"}`, и проверка на незащищённый `"${a[@]}"` в гейте.

## Files
- scripts/portability-check.sh
- docs/defects/shell-needs-gnu-or-bash4.md
- docs/defects/shell-needs-gnu-or-bash4.sed-i.fixture
- docs/defects/shell-needs-gnu-or-bash4.sed-bre.fixture
- docs/defects/shell-needs-gnu-or-bash4.array.fixture
- docs/defects/shell-needs-gnu-or-bash4.python.fixture
- docs/defects/INDEX.md
- tests/maintenance.test.sh
- .github/workflows/ci.yml

## Non-goals
- No new `## Commands` row and no `CLAUDE.md` edit: the gate is reached through the `Maintenance` row and CI.
- No warn-only mode, no `--fix`, no env var that disables a rule: the one bypass is the same-line `# portable: <reason>`,
  and the summary line prints how many were honoured.
- The gate does not rewrite sites. A hit it finds in the tree at this point is a leftover of stories 01-04: fix it only if
  the file is in this story's `## Files`; otherwise report `NEEDS_CONTEXT` naming the path.
- No `continue-on-error` on the macOS leg; no Windows runner; no third job. Assert the image, do not assume it: install
  through brew only what an assertion shows missing (`jq` if absent), never a bash or coreutils.
- Card format is `docs/defects/README.md`; the owner quote is the build request of `brief.md` (its `> Запускаем ...`
  line), dated `2026-10-28 · /vulyk-plan cross-platform · brief.md`, verbatim. No invented quote.

## Map slice
`memory/map/scripts.md` «Entry points» (`defects-check.sh`, `defects-index.sh`, `injection-check.sh` as the card-check
pattern), «Tests» (`tests/maintenance.test.sh` caps); `docs/wiki/rules-tree.md` (card, fixtures, gate);
`memory/map/agents-and-commands.md` «Commands» (`/vulyk-ship` publish order: push, green CI, then tag).

## Acceptance criteria
- [ ] `bash scripts/portability-check.sh` on the tree prints `portability-check: ok (...)` and exits 0; with no file to
      scan or a missing named file it exits 2.
- [ ] For each rule (`bash4`, `sed-i`, `sed-bre`, `grep-P`, `stat-c`, `date-d`, `pct-n`, `readlink-f`, `find-printf`,
      `xargs-r`, `timeout`, `python`, `array`) a temp file with the original form and one with a neighbour form exit 1
      naming that rule; `cycle.sh:853`'s old `\(PASS\|BLOCK\)` line is the `sed-bre` original; a bare `sed -i` from the
      old `tests/council.test.sh` is the `sed-i` original; `"${AUTH[@]}"` under `set -u` is the `array` original;
      `python -m py_compile` is the `python` original.
- [ ] `date -d ... || date -v...` on one line, `sed -i.bak`, `"${#a[@]}"`, `"$@"`, `${a[@]+"${a[@]}"}`, a `for p in
      python3 python py` list, the word `timeout` in an `.md` sentence outside backticks, and `|&` inside a Python heredoc
      are not hits; a line ending `# portable: <reason>` is not a hit and is counted.
- [ ] `bash scripts/defects-check.sh` is green: the card is `block` with four fixtures that fail, the index is current.
- [ ] `ci.yml`: `shell` has a `bash scripts/portability-check.sh` step; `full-suite` and `install-smoke` declare
      `strategy.matrix.os: [ubuntu-latest, macos-latest]`; the macOS-only step prepends a dir with `bash -> /bin/bash`
      to `GITHUB_PATH` and fails unless `bash --version` says `3.2`, `sed --version` fails and `command -v timeout` is
      empty; `install-smoke`'s own `sed -i` and `md5sum` lines are BSD-clean (no `.bak` left in `$target`).
- [ ] `tests/maintenance.test.sh` has no bare `sed -i`, no unguarded array, no `command -v python`; the CLAUDE.md byte cap
      test still passes.

## Verification
`bash tests/maintenance.test.sh && bash scripts/defects-check.sh`

## Implementation notes

## Findings
