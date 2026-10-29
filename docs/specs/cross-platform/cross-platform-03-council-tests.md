---
story: cross-platform-03
spec: cross-platform
status: done
returned: DONE
tier: 3
worker: worker-test
model: haiku
wave: 2
blocked_by: [cross-platform-01]
---

# tests/council.test.sh on sed_inplace and run_capped, timeout cases without skip

## Goal
`tests/council.test.sh` sources `scripts/lib.sh`, edits fixtures only through `sed_inplace` (42 bare `sed -i` lines,
report §2) and its two timeout assertions - court setup under `VULYK_SETUP_TIMEOUT=2` (`part judge`, today
`:1026-1030`) and close-story under `VULYK_VERIFY_TIMEOUT=1` (`part advance`, today `:4178-4184`) - hold with no `skip`
branch, and once more with dead `timeout`/`gtimeout` stubs first on PATH, which proves `cycle.sh` reaches the Python
cap. `model: haiku`: a repeated mechanical pattern plus two copied assertions, the helper semantics are story 01's.

## Requirements
> 3. Перевод всех продуктовых, командных (`.claude/commands/*.md`, `CLAUDE.md:76`) и тестовых файлов на переносимые вызовы.
> 8. `run_capped` без `timeout` и `gtimeout` падает на `"$VULYK_PY"` (subprocess, код 124), тесты таймаутов идут без `skip`.

## Files
- tests/council.test.sh

## Non-goals
- Do not edit `scripts/cycle.sh` or `scripts/lib.sh`: a timeout case that fails under the stubs is a finding for
  `## Findings` and `NEEDS_CONTEXT`, not a patch to the product.
- Do not change what any assertion expects (exit codes, JSON error texts); only how fixtures are edited and the
  stub-PATH repeat of the two timeout cases.
- Sourcing `lib.sh` turns on `set -u`: guard an unbound variable the suite relied on, do not drop `set -u`.
- No `--quick` changes, no new part.

## Map slice
`memory/map/cycle.md` «Verbs» (close-story under `VULYK_VERIFY_TIMEOUT`, court setup under `VULYK_SETUP_TIMEOUT`),
«Tests»; `memory/map/scripts.md` «Tests» (`--part` flags).

## Acceptance criteria
- [ ] `grep -c 'sed -i ' tests/council.test.sh` is 0 and `grep -c sed_inplace tests/council.test.sh` is 42 or more.
- [ ] `part judge` and `part advance` each run their timeout case twice: on the real PATH and on a PATH whose first dir
      holds `timeout` and `gtimeout` scripts that `exit 1`; both runs report the same exit and error text.
- [ ] No `skip` word is printed by either part on this box, with or without the stubs.
- [ ] `bash tests/council.test.sh --list-parts` is unchanged.

## Verification
`bash tests/council.test.sh --part judge && bash tests/council.test.sh --part advance && bash tests/council.test.sh --part close`

## Implementation notes
- The 42 bare `sed -i` fixture edits are `sed_inplace` now, same arguments (the file is still the last one).
- `tests/council.test.sh` sources `scripts/lib.sh` at the top (the goal assumed it; it did not before). `set -u` kept.
- Fixture gap found by the stubbed run, not a product bug: the fixture repo did not copy `scripts/run-capped.py`,
  so lib.sh's Python cap failed with "can't open file". The fixture now copies it beside lib.sh.
- Part judge (court setup timeout) and part advance (close-story timeout) repeat their timeout case with a
  `$STUBS` dir first on PATH (`timeout` and `gtimeout` exit 1, kept outside the fixture repo). Each compares exit
  and error text (judge) or the exact timeout JSON line (advance) with the real-PATH run. Judge also checks
  `capped_by` falls through to `python` under the stubs.
- No expectation changed. Part judge, part advance and part close pass on this box; no `skip` printed.

## Findings
