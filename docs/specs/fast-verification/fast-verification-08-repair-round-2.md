---
story: fast-verification-08
status: todo
returned:
worker: worker-code
model: opus
wave: 5
blocked_by: []
---

# Repair round 2

## Goal
Make the asks and findings council round 2 left RED pass, and change nothing else.

## Requirements
> 1. Каждая строка проверки истории укладывается в минуту-две; telemetry и council получают быстрые части по темам, история берёт часть под свои файлы.
> 2. Полный набор запускается одним скриптом, все наборы разом, и проходит целиком внутри 9 минут; ревьюер запускает его один раз на раунд.
> 3. Упавший тест полного набора блокирует раунд; неуложившийся набор останавливает раунд и спрашивает тебя с цифрой времени; зелёным ни то, ни другое не считается.

## Findings
ASK 1: RED - story rows in 1-2 min; telemetry/council split by topic - run: `--list-parts` + timing saw: telemetry 17 parts, council 11 parts, `--part` rows in ## Commands; alone, `--part install` 97s and `--part walks` 107s fit; but the still-nameable, not round-only `Council, quick` row ran 303s alone (brief recon: 249s), and under 6-way contention parts reach 186-235s - a story naming `Council, quick` gets a 5-minute line
ASK 2: RED - one script, all suites, whole run inside 9 min, reviewer once per round - run: `bash tests/full-suite.sh --list`; `bash tests/maintenance.test.sh` in COURT saw: runner lists 40 jobs covering all 13 suites (inject/intake last), lead-review.md runs it once per round with SUITE: line; but maintenance.test.sh is RED in this court: its memory-triage cases build the slug with `sed 's#[:/\]#-#g'` (E--Projects-vulyk-.vulyk-court-...) while scripts/memory-triage.sh uses `[^0-9A-Za-z]` (E--Projects-vulyk--vulyk-court-...), so any checkout path with a dot - every council court under .vulyk/court/ - fails 3 checks and the full suite cannot pass whole under round conditions; the 9-min wall itself was not measured by this seat (whole suite is the reviewer's run)
ASK 3: RED - FAIL blocks, TIMEOUT stops and asks with seconds, neither green - run: scratch judge with review `VERDICT: PASS` + `SUITE: FAIL 300s` / `SUITE: TIMEOUT 571s budget 540s` / `SUITE: ok 400s` saw: RED note "review PASS with SUITE: FAIL" / ESCALATE suite-timeout, ## Needs a human "- suite: 571 s, budget 540 s" / GREEN - the named paths hold; but `SUITE: TIMEOUT` with no seconds, `SUITE: TIMEOUT 571 s` (space), and a review with NO SUITE line at all while ## Commands has a round-only Full suite row are all recorded (record-seat exit 0) and judged GREEN - only the literal `SUITE: none` is MALFORMED (exit 4); lead-review.md:94 says line 3 must be one of four SUITE forms but nothing enforces it, so a timeout or a skipped run reaches green
1. scripts/cycle.sh:1648 [regression] record-seat must accept `SUITE: none` when the round-only `Full suite / build` row carries no runnable command (`<fill in>` or `none`, the forms install.sh:255-262 ships to every hive and tells the owner to write), because `full_suite_row_round_only` matches the Purpose cell alone and every attempt then exits 4 MALFORMED, so the required review seat can never be recorded in such a hive - repro: `printf '## Commands\n| Full suite / build (round-only) | `<fill in>` |\n' > /tmp/c.md; bash -c 'source <(sed -n "/^full_suite_row_round_only()/,/^}/p" scripts/cycle.sh); full_suite_row_round_only /tmp/c.md; echo rc=$?'` -> `rc=0`, then cycle.sh:1648-1654 rejects the report; base: `git show 9788d68:scripts/cycle.sh | grep -c 'SUITE: none'` -> 0, record-seat recorded it.

2. (owner, round 2 reopen) [ask 3] record-seat enforces the review's SUITE line whenever ## Commands has a round-only
   full-suite row with a runnable command: a missing SUITE line, `SUITE: TIMEOUT` without seconds or with `571 s`
   (space), and `SUITE: none` are MALFORMED (exit 4), never recorded and never green. A row whose command is
   `<fill in>` or `none` accepts `SUITE: none` (finding 1). Fixtures: each refused form and its accepted neighbour.
3. tests/maintenance.test.sh [ask 2] its memory-triage cases build the slug with `sed 's#[:/\]#-#g'` while
   scripts/memory-triage.sh uses `[^0-9A-Za-z]`, so any checkout path with a dot (every court under .vulyk/court/)
   fails 3 checks. Make the test derive the slug by the script's rule; do not change memory-triage.sh.
4. (owner, round 2 reopen) [ask 1] CLAUDE.md: the `Council, quick` row ran 303 s alone; mark it `(round-only)`
   (or remove it if nothing reads it), staying within the model-profile.test.sh size cap.
5. (owner, round 2 reopen) [ask 2] tests/cycle.test.sh is the longest job of the runner (293 s under round load).
   Give it `--part <topic>` and `--list-parts` like telemetry and council (unknown part exits 1 listing the names);
   tests/full-suite.sh expands it into part jobs. Then measure `bash tests/full-suite.sh` under round conditions
   (another heavy suite beside it) and record wall time, slowest job and exit code in plan.md `## Integration gate`.
   Budget stays 540 s; if it still cannot fit, return NEEDS_CONTEXT with the numbers, not a raised budget.
6. tests/telemetry.test.sh:143 a builder that dies inside `install_cache` leaves `$ICACHE.lock` behind and every
   other part waits 300 s and fails "never built": reclaim a lock whose holder is gone.

NEEDS_CONTEXT (worker, finding 5): with `tests/cycle.test.sh` split (7 parts, 46 runner jobs) the full suite still
does not fit 540 s under round conditions (whole `bash tests/council.test.sh` beside it, default `--jobs` 12, box also
carrying other projects' sessions). Run 1: exit 124, wall 540 s, 44 ok / 0 failed, inject cut at 23 s, intake never
started, slowest `council.test.sh --part replays` 269 s. Run 2: exit 124, wall 540 s, 45 ok / 0 failed, intake cut at
29 s, slowest `council.test.sh --part replays` 227 s. Non-latency jobs end at ~490-517 s; inject + intake, run alone
last, need ~50 s more. No test failed in either run. Budget left at 540 s as the story says. The question: which lever
- start the latency suites earlier / together, cut the council `replays`/`walks` and telemetry `constitution`/`ysk`
parts further, or raise `VULYK_SUITE_TIMEOUT`? Findings 1, 2, 3, 4, 6 and the cycle split are built and checked
(the story's `## Verification` lines pass when run separately); nothing is committed.
Re-dispatch (stamp 7501ae8ca9d5dfc8): no answer to the question above is on disk (story, plan, journal), so the
lever is still open; the uncommitted work is left as it was. Note: the early jobs are throughput-bound (they end at
~490-517 s while the slowest single job is 227-269 s), so splitting parts further is unlikely to win ~50 s by itself.

NEEDS_CONTEXT (worker, owner answer «Срезать работу, лимит 540», stamp 87654065dedca511): the profile (table under
`## Implementation notes`) shows no repeated fixture worth 60 s. ~1500 of 3626 job-s are 83 real `install.sh` runs whose
inputs differ (the asserts' subject); the one identical repeat (`$OWNSET`, 4 parts) is now cached and saves ~35-40
job-s, about 6 s of wall at the round's parallelism. Per the answer: the owner chooses the 590 s budget (or names
another lever: a faster `install.sh`, outside this spec). No round-condition run was made after the cache, since
6 s cannot close the ~50 s gap.
Re-dispatch (same stamp): no owner choice between the 590 s budget and another lever is on disk yet; the answer's own
rule sends this back as NEEDS_CONTEXT. Only change: `seed_ownset` in tests/telemetry.test.sh writes `\n` again instead of
a literal newline inside the quotes (same bytes written). Uncommitted work left as is.

## Files
- tests/inject.test.sh
- tests/intake.test.sh
- tests/maintenance.test.sh
- tests/telemetry.test.sh
- CLAUDE.md
- tests/council.test.sh
- tests/full-suite.sh
- tests/full-suite.test.sh
- .github/workflows/ci.yml
- docs/specs/fast-verification/plan.md
- scripts/lib.sh
- scripts/wave-check.sh
- scripts/cycle.sh
- tests/cycle.test.sh
- .claude/commands/vulyk-bootstrap.md
- templates/story.md
- templates/plan.md
- .claude/agents/queen-planner.md
- .claude/agents/worker-code.md
- .claude/agents/worker-test.md
- install.sh
- .claude/agents/lead-review.md
- docs/adr/001-cycle-state-contract.md
- .claude/commands/vulyk-build.md

## Verification
`git ls-files '*.sh' | xargs -n1 bash -n && bash tests/maintenance.test.sh && bash tests/model-profile.test.sh && bash tests/full-suite.test.sh && bash tests/council.test.sh --part escalate`
`bash tests/cycle.test.sh`

Answer (owner, 2026-10-26, «Срезать работу, лимит 540»): the box is throughput-bound, so cut total work, not
wall per job. First measure where the CPU goes across the 46 jobs (per part: wall, and the count of spawned
git/bash/jq/python processes or the repeated fixture builds), and write the top costs as a short table under
`## Implementation notes`. Then remove the biggest repeated cost the way the install cache did: build a repeated
fixture (council/cycle fixture repos, repeated installs that are still real) once per run and copy it, checked
equal to a fresh build. Do not loosen any assertion or median. Goal: under round conditions the non-latency jobs
end by ~460 s so the ~50 s latency tail fits 540 s with margin; record two round-condition runs in plan.md.
If the profile shows no lever worth 60 s or more, return NEEDS_CONTEXT with that table: the owner then chooses a
590 s budget.

Answer 2 (owner, 2026-10-26, «Вынести в конец только замеры»): the serial tail is the lever. Split
tests/inject.test.sh and tests/intake.test.sh into a functional part and a latency part (`--part`/`--list-parts`
like the other suites): the functional parts run among the parallel jobs, only the latency parts (the median
assertions) run alone at the end. Cache intake's plain fresh install like telemetry's. The medians and every assert
stay as they are. Keep the `$OWNSET` cache. Then two round-condition runs recorded in plan.md. If they still exceed
540 s, the owner has already chosen the fallback: set the default `VULYK_SUITE_TIMEOUT` to 590 s everywhere it is
named, record it in plan.md, and close the story; no further question.

## Implementation notes
- scripts/cycle.sh: `full_suite_row_round_only` now also needs a runnable command cell (`<fill in...>`, `none`, empty do not count); record-seat review requires the first `SUITE:` line to be `ok|FAIL|TIMEOUT <N>s[ ...]` whenever that row exists, else MALFORMED exit 4.
- Decision: `TIMEOUT <N>s` without `budget <B>s` is accepted (judge already defaults the budget); `571 s`, bare `TIMEOUT`, `none` and a missing line are refused.
- tests/council.test.sh (part escalate): one fixture per refused form beside its accepted neighbour, plus `SUITE: none` recorded beside a `<fill in>` and a `none` row.
- tests/maintenance.test.sh: memory-triage slug built with the script's own `[^0-9A-Za-z]` rule.
- CLAUDE.md: `Council, quick` row removed (nothing reads it; marking it would have broken the 7162 B cap); now 7104 B.
- tests/telemetry.test.sh: `install_cache` writes the holder pid into the lock; a waiter reclaims a lock whose pid is dead (or has no pid after 10 s). Checked with a planted dead-pid lock: `--part install` built the cache and passed.
- tests/cycle.test.sh: `--part`/`--list-parts` (ship hooklog gates manual close bsd safety), unknown part exits 1 listing names; the 7 parts alone and the whole run each give 157 oks, exit 0. full-suite.sh expands it via its existing `--list-parts)` probe (comment updated); full-suite.test.sh real-list checks updated.
- docs/specs/fast-verification/plan.md: two round-condition measurements under `## Integration gate` - both exit 124 at 540 s.
- Profile (owner answer, 2026-10-26): `VULYK_SUITE_TIMEOUT=0 bash tests/full-suite.sh --jobs 6`, box otherwise idle-ish: 46 ok, wall 767 s, early jobs 3626 job-s; then every job re-run under bash xtrace (exported `SHELLOPTS`, `BASH_XTRACEFD`) to count spawns.
  | Cost | job-s (of 3626) | spawns | repeated identical fixture? |
  |---|---|---|---|
  | telemetry: 83 `install.sh` runs in 14 parts (constitution 11, ysk/mods/rg 8, install/wrapper 7, crlf 6, ...), ~17 s fresh / ~23 s upgrade each alone | ~1500 of telemetry's 1732 | grep 600-1250, cmp 160-560, python3 70-160 per part (inside install.sh) | no: all but 2 are `--upgrade`/`--check` runs or installs over distinct inputs (seeded settings, PATH rg stubs, claude stub, 9.8.0/defects release copies) - the subject of the asserts |
  | the same, repeated: `$OWNSET` (fresh install over one seeded settings.json) in install, library, ysk, mods | ~70 (4 x ~17) | - | yes: now cached (below), saves ~2 installs net (~35-40 job-s) |
  | council: 11 parts, `cycle.sh` verbs on per-scenario specs (mk_spec + 2-3 commits each), wall probes on 8 scratch hives | 1324 | git 170-735, grep 140-610, sed 130-470 per part | no: the per-part setup costs 0.6 s, each spec/hive is its own scenario; a cycle.sh call's own startup is 1 git + 1 dirname |
  | cycle: 7 parts | 206 | git 30-350 per part | no: setup 0.85 s per part |
  | others (defects, solo, e2e, maintenance, model-profile, full-suite, token-report, mods, driver) | 364 | - | no |
  | late, alone: inject 25 s, intake 63 s (1 fresh install + 2 upgrades ~50 s of it) | 88 wall | - | intake's fresh install is cacheable, but tests/intake.test.sh is not in `## Files` |
  Setup per part measured alone (a no-op part): telemetry 0.86 s, council 0.61 s, cycle 0.85 s.
- tests/telemetry.test.sh: `install_cache [<dir> [ownset]]` now also builds `$ICACHE-ownset` (settings.json seeded, then install.sh), once per run under the same pid lock; library/ysk/mods copy it; the install part keeps the real `$OWNSET` install and asserts `diff -r` equal to the cache. Checked: `--part install|ysk|mods|library` in parallel on one cache, all 0 failed, the new diff check ok. Not committed (story returns NEEDS_CONTEXT).
- Lever estimate: at the round's effective parallelism (~7: ~3600 job-s end at ~490-517 s) 60 s of wall needs ~400 job-s cut; the only repeated identical fixture left is worth ~35-40 job-s (~6 s wall). No lever worth 60 s exists without making `install.sh` itself faster (product code, plan delta (b) rejected) or cutting asserts.
