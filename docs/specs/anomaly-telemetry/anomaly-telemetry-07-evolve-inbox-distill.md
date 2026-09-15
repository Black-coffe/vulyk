---
story: anomaly-telemetry-07
spec: anomaly-telemetry
status: done
returned: DONE
tier: 3
worker: worker-code
model: opus
tracer: false
wave: 5
blocked_by: [anomaly-telemetry-03, anomaly-telemetry-04, anomaly-telemetry-06]
---

# Fix (council round 2, ask 5): the weekly inbox distil-and-clear the public docs promise must exist

## Goal
The public repo says (`README.md:257`, `docs/telemetry.md:141-143`, `telemetry/inbox/README.md:6`) that `/vulyk-evolve` distils and clears `telemetry/inbox/` weekly - and no command reads the inbox at all (`grep -c inbox .claude/commands/vulyk-evolve.md` = 0; opus seat, round 2; review finding 4). After this story `scripts/telemetry.sh inbox [--clear]` distils every inbox bundle into per-week, per-code counts and stages the emptied week directories, `/vulyk-evolve` runs it in the VULYK repo as part of its weekly changeset, and the three docs lines describe exactly that mechanism. The promise a contributor's PR is accepted on is backed by a command that exists.

## Requirements
> В публичном репозитории на GitHub написано, что логи собираются для улучшения VULYK, их можно запушить как pull request, раз в неделю логи чистятся и выходит апдейт.
> раз в неделю будет проводиться очищение тех логов и апдейт самого Vulik для улучшения.

## Files
- scripts/telemetry.sh
- tests/telemetry.test.sh
- .claude/commands/vulyk-evolve.md
- docs/telemetry.md
- README.md
- telemetry/inbox/README.md

## Non-goals
- The script still never runs `git commit`, `git push`, `git clone`, `gh repo fork` or `gh pr create`; `--clear` stages deletions with `git rm` and stops. The suite's PATH-shim assertion must still pass.
- No new stats file, ledger or "last distilled" marker: the distilled table lives in the evolve changeset's CHANGELOG entry and the cleared directory is a staged deletion in the same changeset. Nothing self-applies (evolve's rule).
- Do not touch `record`, `scan`, the detectors, `bundle`, `check` rules, `publish`, `recipe_pr` or the enum - review findings 1, 5, 6, 7, 8, 9, 10, 11 and opus UNASKED (1)-(2) live there and are the Queen's to route, even when one line away.
- Do not edit `install.sh`, `CLAUDE.md`, `.claude/hooks/*`, `ci.yml`, `CHANGELOG.md` or `vulyk-build.md`/`vulyk-resume.md`.
- Do not renumber evolve's steps; extend step 2's telemetry block the way story 03 did.

## Map slice
memory/map/scripts.md (`lib.sh` exports, root resolution, exit-code conventions); plan.md `## Contracts` (`inbox` verb, `bundle`/`check` rows) and A1, A11, A16; `docs/specs/anomaly-telemetry/council/round-2/opus.md` ASK 5; `council/round-2/review.md` findings 2, 3, 4; story 03 `## Implementation notes` (where the evolve telemetry block sits).

## Acceptance criteria
- [ ] `bash scripts/telemetry.sh inbox` in a root that has `telemetry/inbox/`: runs `check` over every `telemetry/inbox/*/*.jsonl` first - any failure prints `check`'s `<file>:<line>: <reason>` lines, exit 1, nothing else printed, nothing deleted; otherwise prints one TSV line per (week, code) present, `<week>\t<code>\t<rows>\t<hives>` sorted by week then code (`hives` = distinct `hive` values), and nothing when the inbox holds no rows; exit 0. In a root without `telemetry/inbox/` prints `telemetry: no inbox at <root> - nothing to distil` and exits 0.
- [ ] `inbox --clear`: after the table, `git rm -r -q -- telemetry/inbox/<week>` for every week directory that held files - staged, not committed (HEAD unchanged); `telemetry/inbox/README.md` survives; a no-row inbox makes `--clear` a no-op; exit 0.
- [ ] `.claude/commands/vulyk-evolve.md` step 2's telemetry block gains the repo-side half: when `telemetry/inbox/` exists (the VULYK repo, never a hive), run `bash scripts/telemetry.sh inbox`, show the table beside the local 7-day counts as diagnosis input, and put the same table into the changeset's CHANGELOG entry; on the full path (not `--dry-run`) run `bash scripts/telemetry.sh inbox --clear` so the staged deletions travel in that same reviewable changeset; under `--dry-run` distil only. In a hive the block is skipped in one sentence. A non-zero `inbox` exit stops the step with the reason and clears nothing.
- [ ] Fold-in, review finding 2 (same lines): the local 7-day count in that block keys on the bare code (no leading quote), so the committed log yields `scope_breach <n>`, not `0` for every code - verify against the real `memory/stats/anomalies.jsonl` once.
- [ ] `README.md:257`, `docs/telemetry.md:141-143` and `telemetry/inbox/README.md:6` state the mechanism that now exists: `/vulyk-evolve` in the VULYK repo runs `telemetry.sh inbox`, the per-week/per-code counts land in the evolve changeset's CHANGELOG entry, the emptied week directories are staged in the same changeset, a maintainer reviews and commits it, and the improvements ship with the next release. No sentence names a step that does not run.
- [ ] Fold-in, review finding 3 (same file): every env var `docs/telemetry.md:17-21` names is one `scripts/telemetry.sh` reads (`VULYK_ANOMALY_CONTEXT_PCT`, `VULYK_ANOMALY_CONTEXT_TOKENS`, `VULYK_ANOMALY_AGENT_PREFIX_TOKENS`, `VULYK_ANOMALY_COUNCIL_ROUNDS`, `VULYK_ANOMALY_STAGE_HOURS`); no other section of that page changes.
- [ ] `tests/telemetry.test.sh` gains an `inbox` section: a scratch git repo with committed fixtures `telemetry/inbox/2026-W37/<hiveA>.jsonl` (2 rows, two codes), `2026-W37/<hiveB>.jsonl` (1 row, a code shared with hiveA) and `2026-W38/<hiveA>.jsonl` (1 row), plus `telemetry/inbox/README.md`; asserts (a) the exact sorted TSV lines with `hives` = 2 for the shared (week, code); (b) `--clear` leaves `git status --porcelain` with `D ` for the three files only, README present, `git rev-parse HEAD` unchanged; (c) a root without the directory prints the notice and exits 0; (d) an invalid row makes `inbox --clear` exit 1 with no deletion; (e) the shim list still proves `commit`, `push`, `clone`, `fork`, `pr` never execute.

## Verification
`bash tests/telemetry.test.sh`

## Implementation notes
- `scripts/telemetry.sh` `cmd_inbox` (+ dispatch, usage, header): `find -mindepth 2 -maxdepth 2 -name '*.jsonl'` is the bundle set - README.md and anything not one week deep is never checked, counted or deleted. `check` runs over every file first and the verb returns 1 before printing or deleting anything.
- The table keys on the rows' own `week`/`hive` fields (the schema carries both), not on the path; `--clear` derives the week directories from the file paths. A bundle whose `week` disagreed with its directory would be counted under its row value and cleared by its directory - `check` does not couple the two, and nothing in the spec asked it to.
- `--clear` is `git -C "$ROOT" rm -r -q -- telemetry/inbox/<week>` per week directory; a failure `die`s rather than continuing, so a partially staged clear is named instead of silent.
- Review finding 2: the evolve awk keyed `substr($0, RSTART+7, RLENGTH-8)` - `"code":"` is 8 chars, so the value is `RSTART+8, RLENGTH-9`. Verified against the real `memory/stats/anomalies.jsonl`: now `scope_breach 91`, `council_rounds_high 1` (before: every code `0`).
- Review finding 3: `docs/telemetry.md` table now names `VULYK_ANOMALY_*`; `context_high` has two vars (`_CONTEXT_PCT` of an observed window, `_CONTEXT_TOKENS` fallback) and the cell says which is which.
- Suite: case 17 runs the fixture repo through the same PATH shim as `publish`, so the `commit`/`push`/`clone`/`fork`/`pr create` absence assertions now cover `inbox` as well; they were re-asserted over the shared ledger after inbox ran, each needle separately.

## Findings
