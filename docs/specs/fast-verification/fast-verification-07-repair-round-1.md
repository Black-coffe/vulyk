---
story: fast-verification-07
status: todo
returned:
worker: worker-code
model: opus
wave: 4
blocked_by: []
---

# Repair round 1

## Goal
Make the asks and findings council round 1 left RED pass, and change nothing else. The owner chose on 2026-10-26
to fix the root, not the budget: `VULYK_SUITE_TIMEOUT` stays 540.

## Requirements
> 1. Каждая строка проверки истории укладывается в минуту-две; telemetry и council получают быстрые части по темам, история берёт часть под свои файлы.
> 2. Полный набор запускается одним скриптом, все наборы разом, и проходит целиком внутри 9 минут; ревьюер запускает его один раз на раунд.
> 3. Упавший тест полного набора блокирует раунд; неуложившийся набор останавливает раунд и спрашивает тебя с цифрой времени; зелёным ни то, ни другое не считается.

## Findings
1. CLAUDE.md:66 [regression] CLAUDE.md must stay within the cap tests/model-profile.test.sh:162 enforces (7162 B
   without CR at baa5219): the head is 7165 B - repro: `bash tests/model-profile.test.sh` ->
   `::error::CLAUDE.md grew: 7165 B > 7162 B at baa5219`. Trim wording, keep every row and its meaning.
2. tests/telemetry.test.sh, tests/council.test.sh [ask 1, ask 2] every part re-pays its suite's whole fixture
   setup (telemetry.test.sh:8 says so): parts run 155-184 s alone (opus seat: telemetry mods 155 s, library 184 s,
   council verbs 161 s), not one to two minutes, and 19 parts at once contend to 695 s wall. Build the shared setup
   once per suite run, cached and reused by every part (a part run alone builds it if missing), so a part pays only
   its own checks. Record each part's time alone after the change.
3. tests/full-suite.sh:93 [ask 2] the runner must end green inside 540 s on this box under round conditions: at
   the default `--jobs` (nproc = 28) round 1 hit 541 s with 16 of 31 jobs cut, and the 28-way load pushes the
   wall-clock latency suites `tests/inject.test.sh` and `tests/intake.test.sh` past their 200 ms medians (748, 934,
   687 ms) - repro: `bash tests/full-suite.sh`. Run whole suites, not every part, at a bounded default `--jobs`,
   and run the latency-asserting suites after the rest, outside the contended window. Do not edit
   inject.test.sh or intake.test.sh, and do not loosen their medians.
4. scripts/cycle.sh:1149 [ask 3] judge reads only `SUITE: TIMEOUT`: a `VERDICT: PASS` review carrying
   `SUITE: FAIL` is judged GREEN - repro (opus seat): `cycle.sh judge` on a hand-built PASS + `SUITE: FAIL 300s`
   review -> GREEN, exit 0. A `SUITE: FAIL` is never green whatever the VERDICT line says; a review with
   `SUITE: none` while CLAUDE.md has a round-only full-suite row is rejected at record-seat, not judged.
5. scripts/cycle.sh:2569 [ask 3] `reopen` after a `suite-timeout` escalation always routes to `open-round`, even
   when the same row carries RED asks or a review BLOCK - repro: round 1 here (red [1,2,3], review BLOCK,
   escalate suite-timeout) -> `reopen` printed `next: open-round`, a fresh round over unchanged code, and
   `cycle.sh repair` refused (`next is open-round, not repair`). Route to `repair` when the escalated row has a
   RED ask or a BLOCK; `open-round` only for a timeout with nothing else red.
6. [ask 2] MEASURED, not estimated: after 2-5, run `bash tests/full-suite.sh` on this box at the new default
   `--jobs` while another heavy suite runs beside it (round conditions: a council seat runs alongside the
   reviewer), and record wall time, slowest job and exit code in plan.md beside story 03's numbers, with the gap
   between the two conditions stated.

## Files
- CLAUDE.md
- tests/telemetry.test.sh
- tests/council.test.sh
- tests/full-suite.sh
- tests/full-suite.test.sh
- scripts/cycle.sh
- tests/cycle.test.sh
- docs/specs/fast-verification/plan.md

## Verification
`git ls-files '*.sh' | xargs -n1 bash -n && bash tests/model-profile.test.sh && bash tests/full-suite.test.sh && bash tests/council.test.sh --part escalate && bash tests/telemetry.test.sh --part telemetry`

## Implementation notes
