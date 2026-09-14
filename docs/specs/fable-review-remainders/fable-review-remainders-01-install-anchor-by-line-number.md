---
story: fable-review-remainders-01
spec: fable-review-remainders
status: done
returned: DONE
tier: 3
worker: worker-code
tracer: false
wave: 1
blocked_by: []
model: sonnet
---

# The installer's anchor insert writes the same bytes as its EOF insert

## Goal
`ensure_marked_block` in `install.sh` no longer feeds the once-processed block through a second `awk -v block=` on the anchor path. The anchor line is found by number (`grep -n -F -x`), and the file is reassembled as `head -n` + `printf '%s\n' "$block"` + `tail -n +`, so the anchor path and the EOF path print the block through the same `printf` and are byte-identical; gawk prints no warning. CI's D4.7 scenario asserts the Browser MCP row's content, and the council job clones full history.

## Requirements
> Вставка блока Profile/Commands при `--upgrade` байт в байт равна источнику на обоих путях (по якорю и в конец файла); тест D4.7 в ci.yml сверяет содержимое строки Browser MCP, а не только число строк.
> Номер строки + head/tail (Рекомендую): найти якорь через `grep -n -F -x`, собрать файл как head + printf блока + tail. Второго awk нет вообще, блок пишется тем же `printf '%s\n'`, что и на EOF-пути, значит оба пути байт в байт одинаковы.
> CI-джоб council клонирует полную историю (fetch-depth 0).

## Files
- install.sh
- .github/workflows/ci.yml

## Non-goals
- Do not touch `reset_marked_block` (`install.sh:108-129`, the single-pass model that is already correct) or `print_profile_placeholder` (`:150-164`): the `\|` pre-escape at `:161` is right for exactly one `awk -v` pass and the EOF path depends on it.
- Do not replace the first `awk -v repl=` pass that builds `block` (`:209-215`); only the second awk at `:220-224` goes.
- In `ci.yml` touch only the D4.7 steps (`:321-339`) and the `council` job's `actions/checkout@v4` step (`:109-116`). No other job, no reorder, no rename.
- Do not fix majors 6, 11, 12 of the Fable review (re-install branch, `..` manifest lines, `unlisted (kept)` noise) - not in this brief.

## Map slice
`recon/install-and-suite.md` §"install.sh block insertion" (file:line for all three consumers) · `docs/adr/005-installer-upgrade-contract.md` D3 and D4 assertion 7 · `docs/specs/v0-12-0-remainders/plan.md` K7 (the insert-before-the-next-heading rule this story keeps) · `recon/install-and-suite.md` last line (`ci.yml:109-116`, the council job).

## Acceptance criteria
- [ ] `ensure_marked_block`'s anchor path locates the first later `## ` heading by line number (`grep -n -F -x`, first match) and writes `head -n $((n-1))` + `printf '%s\n' "$block"` + `tail -n "+$n"` to a temp file, then moves it over the target; the EOF path is unchanged. There is exactly one `awk` invocation left in the function.
- [ ] Hand smoke in `mktemp -d`, recorded in `## Implementation notes`: two targets, one with `## Commands` present (anchor) and one without (EOF), each upgraded; the inserted `## Profile` block extracted from both (`sed -n '/VULYK:PROFILE:START/,/VULYK:PROFILE:END/p'`) is byte-identical (`cmp`) and equal to the same extraction from the shipped `CLAUDE.md`; the Browser MCP row in both contains `\|` and has the same cell count as the source row; the `--upgrade` run's stderr contains no `warning:`.
- [ ] `ci.yml` D4.7: a new assertion greps the upgraded file for the Browser MCP row's literal content as it appears in the shipped `CLAUDE.md` (the row's leading text through the escaped pipes), failing with `::error::` when the row's cells differ; the existing count and order assertions stay.
- [ ] `ci.yml` council job: `actions/checkout@v4` step carries `with: fetch-depth: 0`; no other job changes.
- [ ] `bash -n install.sh` clean; the D4.7 assertion is shown passing locally by running its command lines by hand against the smoke target (record the command and its exit in the notes; CI is the record).

## Verification
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes
- `install.sh:220-227` `ensure_marked_block`: replaced the second `awk -v block=` splice with `grep -n -F -x` line lookup + `head -n $((n-1))` + `printf '%s\n' "$block"` + `tail -n "+$n"`, mirroring the EOF path's own `printf`. Only the splice awk was removed; heading-finder/block-builder/anchor-finder awks (unrelated to reprocessing `$block`) are untouched, per Non-goals.
- Surprise: under `set -euo pipefail`, `n="$(grep ... | head -1 | cut -d: -f1)"` aborts the whole script when `grep` finds no anchor (pipefail propagates grep's exit 1) even though `n` empty is a legitimate, expected case (EOF path). Fixed by gating the grep behind `[ -n "$anchor" ]` and appending `|| true` to the assignment.
- `.github/workflows/ci.yml:109-116` council job: added `with: fetch-depth: 0` to its `actions/checkout@v4` step.
- `.github/workflows/ci.yml:321-344` D4.7 step: appended a new assertion that greps the shipped `CLAUDE.md`'s literal Browser MCP row (`grep '| Browser MCP |' CLAUDE.md`) and requires it verbatim (`grep -qF`) in the upgraded target's `CLAUDE.md`, failing with `::error::` on mismatch. Existing count/order assertions untouched.
- Hand smoke (`mktemp -d` targets, recorded exit codes):
  - Two targets from a fresh install: one with `## Profile` block stripped only (`## Commands` intact -> anchor path), one with both `## Profile` and `## Commands` blocks stripped (anchor heading absent -> EOF path). Both upgraded with `./install.sh "$target" --upgrade`; both printed `insert CLAUDE.md '## Profile block' (placeholders)`; stderr empty on both (no `warning:`).
  - `sed -n '/VULYK:PROFILE:START/,/VULYK:PROFILE:END/p'` extracted from both targets and from the shipped `CLAUDE.md`: `cmp` on all three pairs exits 0 (byte-identical).
  - Browser MCP row in both targets: 5 pipes (6 cells), same as source; contains literal `\|` in both.
  - Ran the real D4.7 scenario (fresh install, strip only `## Profile`, upgrade) with every assertion line from the updated `ci.yml` step pasted verbatim, including the new Browser MCP content check: all passed, printed `ALL D4.7 ASSERTIONS PASSED (exit 0)`.
- `bash -n install.sh` clean; `git ls-files '*.sh' | xargs -n1 bash -n` clean across the repo.

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->

