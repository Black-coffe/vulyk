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

## Files
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
