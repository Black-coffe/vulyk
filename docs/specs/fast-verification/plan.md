# Fast story checks, one full suite per round (plan)

**Tier:** 3 · **Spec slug:** `fast-verification` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-001 (cycle state contract: verbs, exit codes, ESCALATE reasons, review layout), ADR-011 (close-story exit 2 = not fixable here), ADR-013 (Light VULYK), ADR-015 (Sonnet executes, Opus judges), Law 2 and Law 6 of the constitution
**Depends on:** main at 6803f8d (0.35.0); the maintenance hotfix named under `## Assumptions`; scout reports [scout-suites.md](scout-suites.md), [scout-plumbing.md](scout-plumbing.md)

## Goal
A story's `## Verification` runs in a minute or two: `tests/telemetry.test.sh` and `tests/council.test.sh` get
`--part <topic>` switches, and a story names the part that covers its files. The whole suite becomes one script,
`tests/full-suite.sh`, that starts every `tests/*.test.sh` (the two slow suites as their parts) at once under one
budget, `VULYK_SUITE_TIMEOUT` (default 540 s), and prints one line per job. `lead-review` runs it once per round:
a failed test is an anchored BLOCK (`[regression]`), a run over budget is reported on a `SUITE: TIMEOUT` line that
`judge` turns into a new escalation reason, `suite-timeout`, with the seconds in `## Needs a human`. Neither is ever
GREEN. Slow rows of `## Commands` carry `round-only` in their Purpose cell; `wave-check` reports a story that names
one and `close-story` refuses it with exit 2. Bootstrap, the story and plan templates, the planner and the workers
teach a hive the same split. Nothing else from the next-circle draft (claim cleanliness, reopen -> repair,
trace-check) is in scope.

## Assumptions
- **Precondition, not a story:** `tests/maintenance.test.sh` is red on main (`agent + command descriptions 5308 B >
  4983 B`, drone-horizon in 0.35.0). The Queen ships that as a separate hotfix before wave 1; story 01 names
  `bash tests/maintenance.test.sh` in its verification and the runner includes the suite, so the build cannot start
  on a red main. No story here touches a `description:` line of an agent or command.
- The 6-7 minute full-suite figure in the brief is an estimate from one measurement (13 suites at once = 1070 s =
  telemetry alone, 28 cores, Windows Git Bash). It is not yet measured after the split. Story 03 is not done until the
  runner's real wall time, all jobs at once, is measured on this box and written under `## Integration gate` below
  with the core count; the number must be under 540 s. The split stories aim at <= 180 s per part alone so the
  parallel wall has margin; where fixture state forbids a cut, the part's time is recorded instead.
- Weak-machine check: the runner takes `--jobs N` (default = core count). Story 03 also measures `--jobs 4`, a
  four-core laptop stand-in, and records it beside the first number with the gap. The plan does not claim the suite
  fits on a small machine unless that run fits.
- **What happens on a machine that cannot fit the suite in the budget:** per the owner's answer the round ESCALATEs
  every time, `suite-timeout`, with the measured seconds. That is the expected outcome on a slow machine, not a bug.
  The owner's levers are two: a longer budget through the one variable both the runner and `lead-review` honour
  (`VULYK_SUITE_TIMEOUT=900` in the environment of the session that runs the round; a budget above ~570 s also needs
  the Bash tool's own cap in `lead-review.md`, `timeout: 600000`, raised - which setting allows that is recon Q6),
  or cutting the suite further (another part, a suite moved out of the runner). No new mechanics: one variable,
  one script.
- The runner lives in `tests/`, which `install.sh` is assumed not to ship to hives (recon Q1; if `tests/` does ship,
  story 03 adds the two files to the installer's exclusion). A hive gets no runner: its `Full suite / build` row is
  its own command, run by `lead-review` under the same budget rule.
- A hive's `## Commands` table is never overwritten by `--upgrade`: the `round-only` mark reaches existing hives only
  through `/vulyk-bootstrap` on a fresh hive or by hand. The limit is accepted; the CHANGELOG entry at ship tells
  hive owners to mark their slow rows.
- CI: `.github/workflows/ci.yml` gains one job that runs `VULYK_SUITE_TIMEOUT=0 bash tests/full-suite.sh` (uncapped:
  a hosted runner has fewer cores than the review box the budget is tuned to - count in recon Q2) and drops the
  per-suite steps the runner now covers; the non-suite steps (bash -n, top-model, handoff-window, install smoke)
  stay. That finally gives CI the five suites it never ran (defects, intake, inject, mods, model-profile). Rejected:
  leaving CI alone (cheap but keeps the gap). The Queen confirms the job layout with recon Q2 at the approval stop.
- `wave-check.sh` at plan time reports `verify-cell` for every `--part <topic>`, `bash tests/full-suite.test.sh` and
  runner cell: those rows exist only after story 01 lands in wave 1. The reports are expected, not a stop; the
  before-wave-2 run must be clean.
- The two full rows (`bash tests/telemetry.test.sh`, `bash tests/council.test.sh`) stay in `## Commands`, marked
  `round-only`, for a human's hand run; `bash tests/council.test.sh --quick` stays as it is (a cross-part subset,
  ~249 s) because wave-1 story 02 verifies with it and nothing else exists yet. During wave 1 the `Full suite /
  build` row names a script that exists only after wave 2; nothing runs it before the round.
- `suite-timeout` ranks right after the owner's `REJECTED` and before `env` in the verdict rule: a timeout stops the
  round whatever the other seats say, because a repair story cannot fix the machine and the owner asked to be asked
  with the time. `reopen` after it goes to `open-round` (as after `env`). Rejected alternative: ranking it last, so
  REDs are repaired first and the timeout escalates only once everything else is green - cheaper in rounds when the
  timeout is a hung test, but it pays a full-budget reviewer run every round for a question only the owner can
  answer, and the owner's words were "останавливается и спрашивает тебя".
- A test that is red on the base branch too is still a BLOCK: the branch ships only green. Today's "a suite that
  times out is a minor" sentence is removed from `lead-review.md`.
- Rejected design for the runner's list: a hardcoded suite list. The runner globs `tests/*.test.sh` and asks the two
  split suites for `--list-parts`, so a later re-cut of a suite needs no runner edit.
- Open recon questions for `drone-scout` (none blocks approval; each names the story it feeds):
  - Q1 (story 03): does `install.sh` ship `tests/`? Which manifest/OWNED list decides, file:line.
  - Q2 (story 03): `ci.yml` job layout - how many jobs, which suite runs in which, runner label and core count,
    whether `maintenance` runs on push.
  - Q3 (story 01): the `CLAUDE.md` size cap `tests/maintenance.test.sh` enforces - the number, which bytes count,
    today's size - so the row budget is known before wave 1.
  - Q4 (story 02): what `tests/council.test.sh` 1656-2166 holds beyond the escalate verb, and whether any block in
    it or in 2167-3588 reuses a spec a block in 1-1655 created.
  - Q5 (story 06): do `fold_reviews` (`cycle.sh:2884`) and `vulyk-cycle.js:151` keep a line-3 `SUITE:` line of either
    report in the folded body (Tier 4 only).
  - Q6 (story 06): the setting that raises the Bash tool's maximum `timeout`, from Claude Code's own documentation.

- Coverage (drone-coverage, 2026-10-25), carried forward, not silent:
  - Ask 1 is partial: no check enforces "минуту-две" on a story's `## Verification`. The bound is a target (<= 180 s
    per part); `bash tests/council.test.sh --quick` (~249 s) stays an unmarked row a story may name; a part that
    fixture state keeps above the bound has its time recorded instead. Owner has not agreed to that exception.
  - Ask 2 is narrowed to the measured box: "внутри 9 минут" is proven on this 28-core machine only; a slower round
    machine escalates `suite-timeout` every time. Owner has not said whether 9 min must hold on any machine.
  - Ask 5 and existing hives: `--upgrade` never rewrites a hive's `## Commands`, so the mark reaches a live hive only
    by hand. Owner rule (card framework-fix-skips-live-hives): at ship, the Queen marks the slow rows in every live
    hive herself, or names why a hive is left. Owner said «да» to this at approval, 2026-10-25.
  - Work with no ask behind it: the maintenance hotfix (precondition), the CI job calling the runner, `--jobs N` and
    the `--jobs 4` measurement (added by the Queen after a side-agent note on weak machines), the CHANGELOG hive line.

## Stories

**Wave 1** (parallel, disjoint files)
- `fast-verification-01` — telemetry.test.sh gets `--part telemetry|install|library|upgrade` and `--list-parts`;
  `CLAUDE.md` `## Commands` gains the part rows, the runner rows and the `round-only` marks, and the blockquote names
  the rule. worker-test.
- `fast-verification-02` — council.test.sh gets `--part verbs|escalate|replays|advance` and `--list-parts`, `--quick`
  kept orthogonal, per-part exit codes proven. worker-test.

**Wave 2** (parallel, disjoint files)
- `fast-verification-03` — `tests/full-suite.sh` (every suite at once, one budget, `--jobs`, one line per job), its
  contract test `tests/full-suite.test.sh`, the CI job, the two measurements written below. worker-test.
- `fast-verification-04` — `lib.sh` `command_cell_round_only`, `wave-check` `verify-round-only`, `close-story` exit 2
  `verification is round-only`, their tests. worker-code.
- `fast-verification-05` — bootstrap interview, story and plan templates, planner and worker rules, the installer's
  placeholder Commands block, one install-part test. worker-code, `model: haiku`.

**Wave 3**
- `fast-verification-06` — `lead-review` runs the full-suite row under the budget and reports `SUITE:`; `judge`
  escalates `suite-timeout` with the seconds; `escalate`/`reopen`/`status` know the reason; ADR-001 amendment;
  council cases. worker-code.

## Contracts
- **Part switch (stories 01, 02; read by 03, 04, 05, 06).** `bash tests/<suite>.test.sh [--part <name>] [--quick]
  [--list-parts]`. No `--part` = every part, today's behaviour. `--list-parts` prints one name per line, exit 0, runs
  nothing. Unknown name = exit 1 with the list on stderr. Every part pays the shared setup and the `bash -n` guard and
  exits non-zero when any of its checks fails (council's `expect` in a pipe is a known leak - fix it for the parts).
  Minimum names, which later stories rely on (a worker may cut further, keeping these names and the cases listed):
  - telemetry: `telemetry` (cases 1-16, litopys offer, cases 17-20; zero installs), `install` (install and consent
    wiring, `--constitution replace`; story 05's placeholder case goes here), `library` (defect library, ysk-offer,
    rg, mods; the `$TGT`/`$OWNSET` setup moves to a helper both install parts call), `upgrade` (retired files, host
    hook wrapper, CRLF host files, cases 21-22).
  - council: `verbs` (today's 1-1655: verb preconditions, close-story incl. the 1488-1505 refusal site, record-seat,
    judge basics; story 04's refusal case goes here), `escalate` (today's 1656-2166: the escalate verb 2072-2118,
    review-ABSENT; story 06's `suite-timeout` cases go here), `replays` (2167-3588), `advance` (3589-4002).
  - Target: <= 180 s per part alone on this box; each part's wall goes into the story's implementation notes.
- **`## Commands` rows (story 01 writes; 03-06 name them).** Purpose column holds the mark as the literal token
  `round-only`, e.g. `| Council tests (round-only) | \`bash tests/council.test.sh\` |`. New rows: `bash
  tests/telemetry.test.sh --part <topic>`, `bash tests/council.test.sh --part <topic>`, `bash
  tests/full-suite.test.sh`; `Full suite / build (round-only)` becomes `bash tests/full-suite.sh`. `command_cells`
  and `command_cell_exists` in `lib.sh` stay as they are.
- **`lib.sh` (story 04; read by wave-check, close-story).** `command_cell_round_only <constitution> <cmd>`: exit 0
  when the command matches (exact or `<placeholder>`, same rule as `command_cell_exists`) the Command cell of any
  row whose Purpose cell contains `round-only`; a command found in a marked row and an unmarked one is round-only
  (conservative). wave-check report line: `verify-round-only: <story> <segment>`. close-story: `emit false
  close-story 2 error "verification is round-only: <segment>"`, exit 2 (worker returns NEEDS_CONTEXT).
- **Runner (story 03; read by 06, CI).** `bash tests/full-suite.sh [--jobs N] [--list]`. Jobs = every
  `tests/*.test.sh` as `bash tests/<x>.test.sh`, except telemetry and council, which contribute one job per
  `--list-parts` name. Env: `VULYK_SUITE_TIMEOUT` = the whole run's budget in seconds, default 540, `0` = uncapped;
  `VULYK_SUITES` = newline-separated job commands overriding the list (tests only). `--jobs` default = core count
  (`nproc`, else 4). Output: one line per job `ok|FAIL|TIMEOUT <seconds>s <command>`; the last 20 lines of each
  failed job's log; a last line `full suite: <ok> ok, <fail> failed, <timeout> timed out, wall <W>s, budget <B>s,
  jobs <N>`. At the budget the runner kills what runs, marks it and every unstarted job `TIMEOUT`, and still prints
  the summary. Exit 0 all ok · 1 any FAIL · 124 any TIMEOUT (outranks FAIL). Logs in a `mktemp -d`, kept and named
  on a non-zero exit. No working `timeout` binary: jobs run uncapped and a job over budget is still reported
  `TIMEOUT` by its measured time.
- **Review report (story 06; `lead-review` writes, `record-seat`/`judge` read).** Line 3 of the report, after
  `MODEL:`: `SUITE: ok <N>s` · `SUITE: FAIL <N>s` · `SUITE: TIMEOUT <N>s budget <B>s` · `SUITE: none` (row is
  `none`). `VERDICT:` judges the code; `SUITE:` reports the run: a timeout with nothing else is `VERDICT: PASS` plus
  the TIMEOUT line (a BLOCK still needs its anchored finding, unchanged). `judge` reads the first body line matching
  `^SUITE: TIMEOUT ([0-9]+)s` anywhere in the stored review (fold-proof at Tier 4), before any other rule but the
  owner's `REJECTED`: ESCALATE, `escalate:"suite-timeout"`, `note:"full suite timed out: <N>s, budget <B>s"`, exit 6;
  `## Needs a human` gets `- reason: suite-timeout · round N · <date>`, `- suite: <N> s, budget <B> s - raise
  VULYK_SUITE_TIMEOUT or cut the suite`, `- seats: <dir>`. `escalate --reason` admits `suite-timeout`; `reopen` after
  it emits `next: open-round`; `status`'s `repair` branch excludes it like `env`. `lead-review` runs the row once as
  `timeout $((${VULYK_SUITE_TIMEOUT:-540} + 30)) <row>` under Bash `timeout: 600000`, measures the seconds, maps exit
  124 (either timeout) to TIMEOUT, other non-zero to FAIL + a `## Critical` `[regression]` line naming the suite and
  the failing check.

## Integration gate
`bash tests/full-suite.sh`
Measured basis (filled by `fast-verification-03`, paperwork edit): all jobs at once, default `--jobs`: `425 s` on
`28` cores, `2026-10-26` (31 jobs, Windows Git Bash; fits the 540 s budget). `--jobs 4`, same box, same day: does not
fit - the run hit the 540 s budget at 541 s wall with 23 of 31 jobs ended, 4 killed and 4 never started, so its full
wall was not measured; gap > 116 s. This says nothing about a real four-core machine beyond that run. Before the split: 13 suites at once 1070 s = telemetry
alone (28 cores, Windows Git Bash, 2026-10-25). Untested on fewer cores before story 03's second run; on a machine that
cannot fit the budget the round escalates `suite-timeout` with the time, see `## Assumptions`.
Repair round 1 (story 07, 2026-10-26, 40 jobs, install cache, inject/intake last, same box): round conditions (whole
`bash tests/council.test.sh` beside it) - default `--jobs` 12: wall 421 s, exit 0, slowest job `tests/cycle.test.sh`
196 s; `--jobs 8`: exit 124 at 540 s (intake cut). Alone, default `--jobs` 12: wall 444 s, exit 0, slowest
`tests/cycle.test.sh` 198 s. Gap between the two conditions: -23 s, inside run-to-run noise; against story 03's 425 s
alone at 28 jobs: +19 s alone, -4 s beside.

## Descoped

*(empty)*

## Plan deltas

- 2026-10-26, story 07 NEEDS_CONTEXT, Queen ruling (a): the repair premise "shared setup is the cost" came from a seat's reading, not a measurement; the worker measured it at 0.5-0.7 s. The cost is repeated `install.sh` runs (16-21 s each, 5-12 per telemetry part). Within the owner's "fix the root, not the budget": keep parts in the runner, cache one pristine `install.sh` output per run (fixtures copy it, checked by `diff -r`), split the parts still over two minutes, run parts at a bounded default `--jobs`, latency suites after the rest. Finding 3's "whole suites" clause is dropped: whole suites cannot fit 540 s. Rejected: (b) a faster `install.sh` (product code, outside this spec), (c) accepting parts over two minutes (contradicts ask 1 and the owner's choice).

<!--
The lines below are the cycle's confirmation markers (docs/cycle.md); each placeholder is replaced by
the command or script that owns it, and scripts/ship-check.sh reads them all.
-->
**Approved:** Andrei, 2026-10-25 («да» to the plan as shown, with both recommended items: the maintenance hotfix ships as 0.35.1 before wave 1; at ship the Queen marks the slow `## Commands` rows in every live hive herself)
**Briefed:** <written by scripts/cycle.sh briefed>
**Branch:** vulyk/fast-verification
**Checked:** <written by scripts/human-check.sh>
**Council:** ESCALATE round 1, 2026-10-26, at 9788d68, pack bec80b2bffbb - red: 1,2,3
**Shipped:** <written by scripts/ship-check.sh --record>

## Needs a human
- reason: suite-timeout · round 1 · 2026-10-26
- ask 1: RED - see docs/specs/fast-verification/council/round-1/*.md for evidence
- ask 2: RED - see docs/specs/fast-verification/council/round-1/*.md for evidence
- ask 3: RED - see docs/specs/fast-verification/council/round-1/*.md for evidence
- suite: 541 s, budget 540 s - raise VULYK_SUITE_TIMEOUT or cut the suite
- seats: docs/specs/fast-verification/council/round-1/
