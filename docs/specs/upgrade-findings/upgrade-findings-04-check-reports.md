---
story: upgrade-findings-04
spec: upgrade-findings
status: todo
returned:
tier: 3
worker: worker-code
wave: 2
blocked_by: [upgrade-findings-01, upgrade-findings-02]
red: required
red_reason: full suite measured 378s in round
---

# The dry run reports this hive: odd command rows, a measured suite over the cap, backup-only constitution lines

## Goal
`install.sh --upgrade` and `--upgrade --check` (what `vulyk-update.sh --check` prints, through the release's
own installer) say three things about the hive in front of them, and change no hive file for any of them.
**Commands lint:** the report calls `commands_lint` (story 01, plan.md `## Contracts` B1) on the hive's
constitution and prints its lines. **Measured suite:** beside the fixed `gate split (ADR-029)` note, the
installer reads the 5 newest measured rounds from `docs/specs/*/council/round-*/suite.log` and, where a round
has no such log, the `SUITE:` line of its `review.md`; a round with `PART` lines is judged by part, one
without by its `SUITE:` seconds (`ok`, `FAIL` and `TIMEOUT` forms); every value over 210 s prints the C1 line,
followed once by the `suite-parts-check.sh` pointer; no measured round prints the C1 "no measured full suite"
line. **Backup-only lines:** `--upgrade --check --constitution replace` prints the E4 block: the hive
constitution's lines outside the `VULYK:PROFILE` and `VULYK:COMMANDS` blocks (blank lines and the carried
telemetry row aside) found neither in the new constitution nor, when the installed release's tag is in the
source, in that release's constitution; without the tag, every line absent from the new one, with a note.
`.claude/commands/vulyk-update.md`: step 2 names `would merge frontmatter` (story 02) and the lint lines,
step 4 uses the backup-only list for its recommendation, step 6 names the measured-suite line and gains the
cutting recipe.

## Requirements
> 7. B: `install.sh --upgrade` / `vulyk-update.sh --check` names each hive `## Commands` row with text outside its one backticked span or with several spans.
> 8. C: `vulyk-update.sh --check` reads the newest `SUITE:` (and any `PART`) lines of the hive's full-suite rows from its council logs; any over 210 s prints `full suite measured <N>s in round <ref>: cut before taking this release` and names `scripts/suite-parts-check.sh`.
> 9. C: the `/vulyk-update` doc's step 6 gets the cutting recipe: measure once with per-file timings, cut by a stable selector (file globs), check that the parts' test counts add up to the single run, measure each part's wall time instead of trusting per-file sums, and leave every part headroom under 210 s.
> 15. E4: `--check` with `--constitution replace` prints the non-block lines that would exist only in the backup.
> 16. Out of scope: no hive-side file changes, no change to the A/B measurement study or model profiles, and `install.sh --upgrade` widened no further than asks 7, 8, 12, 14 and 15 describe.

## Files
- install.sh
- tests/telemetry.test.sh
- .claude/commands/vulyk-update.md

## Non-goals
- The installer never edits a hive's `## Commands` rows, council logs or constitution for these reports, and
  never cuts a suite: it names, the owner acts.
- Do not re-implement the span rule in `install.sh`; call `lib.sh` beside it. Do not edit `scripts/lib.sh`.
- Do not change `scripts/vulyk-update.sh` or `scripts/suite-parts-check.sh`, the fixed ADR-029 note's text, or
  what `--constitution replace` writes.
- The recipe is generic: no hive name, test count or timing from the report; `pytest --junitxml` may stand as
  one example of per-file timing, beside "your runner's per-file report".
- Do not edit `tests/telemetry.test.sh` outside parts `upgrade` and `constitution`.
- CR-byte trap: edit `install.sh` with Edit, never through a Python text-mode rewrite.

## Map slice
`memory/map/scripts.md` → install.sh - the upgrade contract, Tests (`suite-parts-check.sh`), Gotchas;
`memory/map/cycle.md` → Verbs (`suite`: the `suite.log` line shapes; Full-suite line: the legacy `SUITE:` forms).

## Acceptance criteria
- [ ] `--part upgrade`: a synthetic hive with `docs/specs/demo/council/round-1/suite.log` ending
  `SUITE: ok 378s` (no `PART` line) prints `full suite measured 378s in round demo/round-1: cut before taking
  this release` and a line naming `scripts/suite-parts-check.sh`, under `--check` and on the real upgrade.
- [ ] `--part upgrade`: a log with parts of 120 s and 250 s and `SUITE: ok 370s` prints only the part line
  for 250 s; a `review.md` with `SUITE: TIMEOUT 596s budget 595s` in a round with no log is read as 596;
  `SUITE: ok 150s` and `SUITE: none` print nothing; a sixth-newest round over the cap is not reported; a hive
  with no measured round prints the "no measured full suite" line.
- [ ] `--part upgrade`: a hive constitution with one noted row and one two-span row gets exactly the two
  `commands: row '...'` lines; a clean table gets none; the hive's constitution is byte-identical afterwards.
- [ ] `--part constitution`: `--upgrade --check --constitution replace` on a hive with two hand-written lines
  outside the blocks prints `constitution: 2 lines only in the backup (...)` and both lines, and not the old
  release's own wording; from a source without the installed tag it prints every line absent from the new
  file plus the note; nothing is written.
- [ ] `vulyk-update.md` step 6 holds the recipe's five points (measure per file once; cut by file globs; part
  counts add up to the single run; measure each part's wall time, not the sums; headroom under 210 s) and
  `bash scripts/prompt-check.sh --touched .claude/commands/vulyk-update.md` reports no `error`.
- [ ] `bash scripts/portability-check.sh install.sh` is clean; fixtures use `demo` / `Acme` names only.
- [ ] The step 6 recipe names each part: measure once with per-file timings (`pytest --junitxml`, sum `testcase@time` per file), cut by a stable selector (file globs), check that the parts' test counts add up to the single run, measure each part's wall time rather than trusting the per-file sums (import and collection overhead), and leave every part headroom under 210 s. Synthetic numbers only. (Queen, coverage gap ask 9)

## Verification
`bash tests/telemetry.test.sh --part upgrade`
`bash tests/telemetry.test.sh --part constitution`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each -->

## Findings
