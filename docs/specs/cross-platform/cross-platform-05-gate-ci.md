---
story: cross-platform-05
spec: cross-platform
status: done
returned: DONE
tier: 3
worker: worker-code
wave: 3
blocked_by: [cross-platform-02, cross-platform-03, cross-platform-04]
red: required
red_reason: portability-check: the tree exits 0
red_verified_at: 2026-10-28T22:10:40Z 83a704f8f43911ef798f5062e3d2e81f64db07fb8505f21520e71dd57e7fdf71
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
- tests/cycle.test.sh
- tests/inject.test.sh
- tests/intake.test.sh
- .claude/commands/vulyk-evolve.md

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
- `tests/maintenance.test.sh`: written first and stamped red. It has the gate section (tree run, 28 hit and 9 clean cases read from a heredoc so the file passes its own tree scan, the `# portable:` count, the Python heredoc, an .md sentence, the `CLAUDE.md:76` cell, exit 2 for a missing file and for an empty repo). It now sources `lib.sh`: `vulyk_python` resolves `PYBIN` (full path, because the counting `python3` stub would otherwise exec itself), `date_shift` for `iso_ago`, `sed_inplace` at the four `pc_case` sites, an awk CRLF rewrite instead of `sed -i 's/$/\r/'`, and `${a[@]+...}` at the five array sites.
- `scripts/portability-check.sh`: a bash wrapper around one Python pass (`vulyk_python`). It tracks quotes across lines, so `timeout`/`python`/`mapfile`/`|&`/heredoc openers count only as code, never inside a quoted message. A Python crash exits 2, not 1.
- Decision: `stat-c` gets the same same-line `||` exemption as `date-d` (the contract names `||` only for `date-d`). Without it, `state.sh:130` and `session-start-brief.sh:11` count as hits, and both already try `date -r` first, which works on BSD.
- Decision: in .md files a one-word inline span (`` `timeout` ``, the Bash tool parameter in 4 agent files) names something and is not a command. Only spans of two or more words and shell fences are read.
- BRE rule: only an odd run of backslashes before `|+?` counts, so `lib.sh:161`'s `s/\\|/|/g` (a literal backslash, then a bar) is not a hit.
- Card, 4 fixtures (each exits 1), `INDEX.md` regenerated; `defects-check.sh` GREEN (3 blocking checks).
- `ci.yml`: `shell` runs the gate; `full-suite` and `install-smoke` use a matrix of `[ubuntu-latest, macos-latest]` with `fail-fast: false`. A macOS-only step pins `/bin/bash` through `GITHUB_PATH` and asserts 3.2, BSD sed and no `timeout`, and installs `jq` only if it is missing. install-smoke: `sed -i.bak ... && rm -f ...bak`, `md5sum` -> `cksum`.
- Per the Queen's ruling: `tests/cycle.test.sh:802` joined to one line and marked `# portable:` (the BSD-stub case); `tests/inject.test.sh:350`, `tests/intake.test.sh:259` probe with `( VULYK_PY=""; PATH="$T/stubbin:$PATH"; vulyk_python )`, i.e. "is there a Python 3 besides the stubbed python3"; `vulyk-evolve.md:20,37,58` got the same-line `|| date -u -v-7d ...` fallback. Gate on the tree: ok (80 files, 1 allowed).

## Findings
- Tree run is red on 6 leftovers of stories 01-04, all in files outside this story's `## Files` (Non-goals: report, do not fix):
  - `tests/cycle.test.sh:802` (sed-bre): the deliberate BRE alternation fed to the BSD sed stub. It needs a same-line
    `# portable: <reason>`, but the line ends in a `\` continuation, so it has to become one line first.
  - `tests/inject.test.sh:350` and `tests/intake.test.sh:259` (python): `if python -c 'import sys' ...` probes a bare
    `python`; probe through `vulyk_python`/`scripts/py.sh` or mark the line `# portable:`.
  - `.claude/commands/vulyk-evolve.md:20,37,58` (date-d): `date -u -d '-7 days'` with no fallback. Use `date_shift -7`
    or a same-line `|| date -u -v-7d ...`.
  Once these are fixed, `bash tests/maintenance.test.sh` passes (its other 283 checks are green) and `defects-check.sh` is GREEN.

## Red receipt
- command: bash tests/maintenance.test.sh && bash scripts/defects-check.sh
- exit: 1
- tests: 83a704f8f43911ef798f5062e3d2e81f64db07fb8505f21520e71dd57e7fdf71 (tests/maintenance.test.sh)
- impl: bc37e106e66af991a94b59fc139dcded4189aa789f70d60abd65da555bbdbbf3
- stamped: 2026-10-28T22:10:40Z

```
::error::portability-check: the bare python cell of CLAUDE.md:76 is a hit - expected ': python: ' in:
        bash: /e/Projects/vulyk/scripts/portability-check.sh: No such file or directory
        exit=127;
::error::portability-check: a missing named file exits 2 - expected 'exit=2;' in:
        bash: /e/Projects/vulyk/scripts/portability-check.sh: No such file or directory
        exit=127;
::error::portability-check: nothing to scan exits 2 - expected 'exit=2;' in:
        bash: /e/Projects/vulyk/scripts/portability-check.sh: No such file or directory
        exit=127;
maintenance.test.sh: 285 checks, 74 failed
```

**Queen's ruling, 2026-10-29 (after two NEEDS_CONTEXT returns):** `## Files` widened by the four files that hold the six
tree-scan hits stories 01, 02 and 04 left (`tests/cycle.test.sh:802` sed-bre - join the continuation and mark it
`# portable:` as the deliberate BSD-stub case; `tests/inject.test.sh:350`, `tests/intake.test.sh:259` - probe through
`vulyk_python`; `.claude/commands/vulyk-evolve.md:20,37,58` - same-line `|| date -u -v-7d ...` fallback, the idiom the
plan keeps for prose). Fix those six lines only, nothing else in those files; then close as written. The two contract
calls (`stat-c` same-line `||`, one-word inline span not a command) go to the reviewer as they are.
