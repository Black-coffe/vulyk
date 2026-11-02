# Gate split: per-part caps, one stepped suite per round (plan)

**Tier:** 3 · **Spec slug:** `gate-split` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-001 (suite-timeout escalation, amended here), ADR-016 (constitution byte cap), ADR-023 (one full suite per round), ADR-024 (foreground runs in subagents), ADR-025/027 (red receipt), card `test-gate-one-long-limit`, card `full-round-for-a-narrow-fix`
**Depends on:** main at the fast-verification (0.36.0) runner and the red-receipt (0.40.x) verify path; `weekly-budget` waits on this spec

## Goal
Replace the one wall-clock budget over the whole test gate with parts that each carry their own hard cap of 300 s,
grouped into steps that each fit one Bash call. The suite runs once per council round, before any seat is dispatched,
step by step through a new `cycle.sh suite` verb that the Workflow driver and the Queen's commands call; reviewers read
the round's log instead of running the suite. A part that reaches its cap, or grows past 70% of it, is a FAIL of that
part routed to repair ("cut part X"), never an escalation. Story verification in `close-story`/`stamp-red` gets the
same shape: a cap per line, a resume mark when the next line would not fit the call, and a repair story that keeps only
the lines covering its files. The long suites are cut to about 100 s alone, a missing tool reads SKIP (a failure in
CI), CI uses the same caps on every OS, and hives may split their own full-suite row into several capped rows.

## Assumptions
- No macOS (or Windows) part timings exist yet: the first CI run after this spec measures them. A part red there is cut
  further, never answered with a bigger cap (brief Answer 1).
- Windows part times come from the round's `suite.log` on the owner's Windows box; CI stays Linux + macOS, and a
  Windows CI job is a later spec of its own (brief Answer 4).
- `weekly-budget` waits on this spec: its repair story 10 needs the per-line verification caps of `gate-split-02`.
- A step is at most `--jobs` parts started together, so a step's wall is bounded by the 300 s part cap and never by
  luck. The round may take longer in wall time than today's single 698 s run (about 5-6 steps of up to ~220 s
  contended); the speed lever is one run per round instead of one per seat (brief, side-agent note).
- The growth line is contended time at the real `--jobs` (crossgrill 2/3: red over 70% of the cap, 210 s at 300).
- Bootstrap order: `gate-split-02` is red-first, so its `stamp-red` runs under today's `verify_run` (one 540 s total);
  its `## Verification` is two council parts that fit it. Every later story closes under the per-line caps and the
  resume mark that `gate-split-02` lands, which is why the cuts and the round gate wait for it.
- The test-cutting work (`gate-split-03`) is not marked `red: required` although it adds `--part` parsing: every file
  it changes is itself a test, and `stamp-red` refuses a story whose `## Files` are only tests. Its proof is that every
  new part runs in its `## Verification`, and `gate-split-01` tests the runner's SKIP route.
- No new `## Commands` rows: CLAUDE.md is held to the ADR-016 byte cap. Stories verify through the existing whole-file
  rows (`bash tests/solo.test.sh` ~192 s alone, under the new 300 s per-line cap) and the existing `--part` rows.
  VULYK's own full-suite row is renamed `Full suite steps (round-only)` (no bytes added); the word `steps` opts a row
  into the stepped protocol, every other full-suite row (a hive's) is one part.
- A cut keeps the old part name for its first half (`install`, `constitution`, `ysk`, `replays`), so existing
  `--part` callers keep working; the second half gets a new name (Contracts).
- A repair story's `## Files` stays the union of the done stories (unchanged), so the worker may touch any of them;
  its `## Verification` keeps only the lines covering the paths its `## Findings` name (Ask 6: "только проверки
  своих файлов"). The round's stepped suite still runs everything, so the narrow close-story set loses no coverage.
- `suite-timeout` stays a readable reason (old `council.jsonl` rows, `escalate --reason`, an old seat file's
  `SUITE: TIMEOUT` line); nothing new produces it.
- The new ADR takes number 029 (028 is `weekly-budget-governor` on main).

### Recon questions for `drone-scout` (before wave 1 dispatch)
1. `tests/full-suite.sh` symbol map shows `tests textual 5` and `importers textual 2` not shown: which files source or
   call it besides `tests/full-suite.test.sh` and `.github/workflows/ci.yml`, and does any read `VULYK_SUITE_TIMEOUT`,
   exit 124 or its last `SUITE:` line?
2. Which test enforces the ADR-016 byte cap on VULYK's `CLAUDE.md`, and does any test assert the row text
   `Full suite / build (round-only)` in VULYK's own `CLAUDE.md` (as opposed to a hive render)?
3. `tests/e2e.test.sh` `run_driver`: does its clerk execute `cycle.sh` for real, and does its fixture constitution
   carry a round-only full-suite row (so a `suite` call needs no mock)?
4. Does `.github/workflows/ci.yml` run `tests/full-suite.sh` on Windows, or only Linux and macOS?
5. `tests/cycle.test.sh` (13 SUITE hits): which parts assert `record-seat`/`judge` SUITE handling, `close-story`
   verification timing or `stamp-red` output?
6. Does any script besides `cycle.sh` read `VULYK_VERIFY_TIMEOUT` or `VULYK_SUITE_TIMEOUT` (`ship-check.sh`,
   `human-check.sh`, `install.sh`, `.claude/hooks/*`)?
7. Does `/vulyk-update` step 6 (`.claude/commands/vulyk-update.md`) or `install.sh --upgrade` rewrite a hive's
   full-suite row in a way that would collapse several rows into one?
8. Does `install.sh` copy `scripts/` by an explicit list (so `scripts/suite-parts-check.sh` must be added to it)?

### Recon answers (Queen, grep in the worktree, 2026-11-02)
1. `VULYK_SUITE_TIMEOUT` is read by `tests/full-suite.sh` 52, `tests/full-suite.test.sh`, `ci.yml` 150 and
   `scripts/cycle.sh` 1167 (escalate fallback) and 1290 (the "raise" advice): `gate-split-01`, `-04`. Other tests name
   `full-suite.sh` only in comments or seat-file fixtures (`council.test.sh` 2392, 2458).
2. The byte cap: `tests/cycle.test.sh` 949 and `tests/maintenance.test.sh` 34 (7168). The row text
   `Full suite / build (round-only)` is asserted only in fixtures and the hive template (`council.test.sh` 2410-2440,
   `telemetry.test.sh` 1522-1542, `install.sh` 264), never on VULYK's own `CLAUDE.md`: the rename breaks no assert.
3. `tests/e2e.test.sh` clerk stub runs `bash scripts/cycle.sh` for real (line 124); its fixture has a `## Commands`
   table (39-42): `gate-split-05` checks whether it holds a round-only full-suite row (else `suite` reads `none`).
4. CI runs `tests/full-suite.sh` on `ubuntu-latest` and `macos-latest` only; no Windows job (brief Answer 4: none added).
5. `tests/cycle.test.sh` has no `SUITE` asserts; the SUITE handling lives in `council.test.sh`.
6. `VULYK_VERIFY_TIMEOUT` is read only by `scripts/cycle.sh` 1983 and named in `council.test.sh` 3822, 4199.
7. `/vulyk-update` step 6 (40-44) asks a hive to rename its row to one canonical name; it never merges rows. It now
   also names the split (`gate-split-06`).
8. `install.sh` copies the whole `scripts/` tree (1311): no list to update.

### Coverage (drone-coverage, 2026-11-02) and what changed
- Ask 5: council `walks`/`seats`/`roster`/`ceilings` (205-225 s contended) were uncut -> new `gate-split-07`.
- Ask 6: the repair filter keyed on `## Files` only deduped -> keyed on the paths `## Findings` name (`gate-split-02`).
- Ask 9: the update path did not name the split -> `/vulyk-update` step 6 joins `gate-split-06`.
- Ask 2: the reviewer rerun lived only in `gate-split-05` -> a Contracts line.
- Ask 4: the card's check is real: `defects-check.sh` runs it on both fixtures, which must fail.
- Ask 7: no Windows CI job -> owner: Windows times from the local round log (brief Answer 4).

## Stories

**Wave 1**
- `gate-split-01` - runner: per-part cap 300 s, steps, PART lines, growth check (the card's `check:`), SKIP, CI. red.
- `gate-split-02` - `close-story`/`stamp-red`: per-line cap, resume mark (exit 7), repair verification filter. red.

**Wave 2**
- `gate-split-03` - cut solo (3), e2e (2, plus SKIP), model-profile (3), telemetry install/constitution/ysk (2 each).
- `gate-split-04` - `cycle.sh suite`: the round's stepped gate, its log, SUITE from the log, cap = FAIL; council `replays` cut. red, opus.

**Wave 3**
- `gate-split-05` - consumers: Workflow driver, clerk, `lead-review`, `/vulyk-build`, `/vulyk-review`; driver SKIP. red.
- `gate-split-06` - VULYK row rename, `install.sh` + `/vulyk-update` hive text, `templates/plan.md`, ADR-029 + amendments to 001/023/024.
- `gate-split-07` - cut council `walks`, `seats`, `roster`, `ceilings` (205-225 s contended, on the 210 s line). worker-test.

## Contracts
- **PART line** (runner output, round log, check input): `PART <name> <ok|FAIL|SKIP|CAP> <N>s cap <C>s[ - <reason>]`.
  `<name>` = `<suite>` or `<suite>:<part>` (`council:replays2`, `solo:block`); a hive row's part name is its Purpose
  cell, lowercased, every run of other than `[a-z0-9]` turned into `-`.
- **`scripts/suite-parts-check.sh <file>`** (new; the card's `check: bash scripts/suite-parts-check.sh <arg>`): reads
  PART lines; for each `CAP`, each cap over 300, each `N*10 > C*7` prints
  `suite-parts-check: cut part <name>: <N>s of cap <C>s (<cap|over-cap|grew>)`. Exit 1 on any such line; 0 when none,
  including input with no PART line and a path that is not a readable file (`defects-check.sh <arg>` runs every block
  check on any argument); 2 only with no argument. One parser: `tests/full-suite.sh` and `cycle.sh suite` call it.
- **SKIP:** a suite missing a required tool prints `SKIP: <reason>` and exits 77. The runner prints a `SKIP` PART line,
  counts skips apart from ok and FAIL, and with `VULYK_STRICT_SKIP=1` (set in CI) counts a SKIP as FAIL.
- **Runner CLI** `tests/full-suite.sh`: `[--jobs N]` runs every step in sequence; `--list` the jobs; `--steps` prints the
  step count S; `--step K` runs step K. A step = the K-th chunk of at most `jobs` jobs in `--list` order (a pure
  function of the job list and `jobs`), all started together; latency jobs each alone, last. Part cap
  `VULYK_PART_CAP` (default 300; above 300 = exit 2 usage; lower allowed, for tests). After a step it runs
  `suite-parts-check.sh` on its PART lines. Last line `STEP K/S: ok|FAIL <N>s` for `--step`, else
  `SUITE: ok|FAIL <N>s parts=<n> skip=<n> fail=<csv>`. Exit 0 / 1 (any FAIL, CAP, growth, strict SKIP) / 2 usage.
  `VULYK_SUITE_TIMEOUT` is no longer read; 124 is never returned.
- **Suites with parts:** `--list-parts` and `--part <topic>` as `council.test.sh` does today; the runner turns each into
  one job. New topics: `solo` green/block/rejected; `e2e` green/red; `model-profile` defaults/set/edges; telemetry
  `install`+`install-xp`, `constitution`+`constitution2`, `ysk`+`ysk-hook`; council `replays`+`replays2`, `suite` (new
  tests of `gate-split-04`).
- **Stepped row:** a `## Commands` row whose Purpose names the full suite, carries `round-only` and the word `steps` is
  run as `<cmd> --steps`, then `<cmd> --step K`, each call under `run_capped 590`; any other such row is one step and
  one part, run under `run_capped ${VULYK_PART_CAP:-300}` with its PART line written by `cycle.sh` (`CAP` on 124).
- **`cycle.sh suite <spec-dir> [--commit] [--stamp S]`** (guards as `open-round`: pause, driver stamp, branch; an open,
  non-stale round, else exit 2 / 5): runs the next unfinished step of the open round into
  `council/round-N/suite.log` (paperwork). Header `head=<ROUND head> steps=<S>`; per step `STEP K/S ...` plus its
  PART lines; after the last step one `SUITE: ok <N>s|FAIL <N>s - <cut part X / part X failed, csv>|none` line
  (`none`: no round-only full-suite row). A log whose `head=` differs from ROUND's is discarded; re-stamp deletes it;
  a finished log makes the verb a no-op. A FAIL step is data, exit 0. Last line
  `{"ok":true,"verb":"suite","step":K,"steps":S,"done":<bool>,"suite":"ok|FAIL|none|pending",...,"status":{...}}`.
- **SUITE from the log:** `record-seat review` with a finished log writes the log's `SUITE:` line as the seat file's
  SUITE line (inserted, or replacing a different reported one); without a log the old rule stands. `judge` unchanged:
  `SUITE: FAIL` = BLOCK `[regression]`; a legacy `SUITE: TIMEOUT` still escalates `suite-timeout`. `repair` copies the
  log's red PART lines into `## Findings`. The escalate note no longer advises raising a budget.
- **Driver:** `council(st)` calls `suite <spec> --commit --stamp <S>` through the clerk until `done:true` (at most 32
  calls; `ok:false` stops the run like any refused verb), then dispatches the seats. The clerk accepts `suite`.
- **Verification (close-story, stamp-red):** `VULYK_VERIFY_TIMEOUT` = cap per line (default 300; above 300 acts as
  300); `VULYK_VERIFY_CALL` = budget per call (default 540). A line starts only if elapsed + cap fits the budget (the
  first line always runs); otherwise the verb writes frontmatter `verify_resume: <verb> <K> <set_hash of ## Files>`,
  prints `{"ok":false,...,"resume":K}` and exits 7. Re-running the same command resumes at K when the hash matches,
  else starts at line 1; the line is removed when the verb finishes. A timed-out line still reads
  `timed out after <N>s` with N = the per-line cap.
- **Repair `## Verification`:** the union of done stories' lines, deduped, keeping a line only when one of its path
  tokens hits a path the repair's `## Findings` name (the `wave-check` overlap rule); else the lines hitting
  `## Files`; else the deduped union.
- **Reviewer rerun:** a reviewer reads `council/round-N/suite.log`, never runs the whole suite, and may rerun one
  part to look at a FAIL (`bash tests/<suite>.test.sh --part <topic>`, or the hive row's command) (`gate-split-05`).

## Rejected alternative
Fill each step from a queue of up to `2 x jobs` parts to keep today's 698 s wall: rejected, because a step's wall is then
bounded only by how the parts happen to fall (two 300 s parts in one slot reach 600 s, the Bash call limit), which is
the "one long limit the run can reach" the card forbids. Steps of at most `jobs` parts are bounded by the part cap alone.

## Integration gate
`bash scripts/cycle.sh suite docs/specs/gate-split --commit` until `done:true` (it runs `bash tests/full-suite.sh --step K`
for each step; per-part cap 300 s); `wave-check.sh` runs before each wave.

## Descoped

*(empty)*

## Plan deltas

**Approved:** Andrei, 2026-11-02 (Windows part times from the local round log, no Windows CI job)
**Briefed:** <written by scripts/cycle.sh briefed>
**Branch:** <written by /vulyk-build before wave 1>
**Checked:** <written by scripts/human-check.sh>
**Council:** <written by scripts/cycle.sh judge/escalate>
**Shipped:** <written by scripts/ship-check.sh --record>
