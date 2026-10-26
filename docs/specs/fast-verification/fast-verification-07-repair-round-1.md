---
story: fast-verification-07
status: done
returned: DONE
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
2. tests/telemetry.test.sh, tests/council.test.sh [ask 1, ask 2] (revised by the Queen's ruling (a), plan.md
   `## Plan deltas`, after item 7's measurement) a part's cost is its own `install.sh` runs (16-21 s each, 5-12 per
   telemetry part), not the shared setup. Build one pristine `install.sh` output per suite run, cached and reused:
   every plain fresh-install fixture is a copy of it, the cache is checked equal to a real install (`diff -r`) and a
   part run alone builds it if missing. Split every part still over two minutes alone (telemetry `telemetry`,
   `mods`, `upgrade`, `library`; council `verbs`, `advance`) into more `--part` names. Record each part's time
   alone after the change.
3. tests/full-suite.sh:93 [ask 2] the runner must end green inside 540 s on this box under round conditions: at
   the default `--jobs` (nproc = 28) round 1 hit 541 s with 16 of 31 jobs cut, and the 28-way load pushes the
   wall-clock latency suites `tests/inject.test.sh` and `tests/intake.test.sh` past their 200 ms medians (748, 934,
   687 ms) - repro: `bash tests/full-suite.sh`. Keep parts as jobs, bound the default `--jobs` (measure, e.g. 8),
   and run the latency-asserting suites after the rest, outside the contended window. Do not edit inject.test.sh
   or intake.test.sh, and do not loosen their medians. If after 2 and 3 the runner still cannot fit 540 s, return
   NEEDS_CONTEXT with the measured wall time and the slowest jobs, not a raised budget.
6. [ask 2] MEASURED, not estimated: after 2-5, run `bash tests/full-suite.sh` on this box at the new default
   `--jobs` while another heavy suite runs beside it (round conditions: a council seat runs alongside the
   reviewer), and record wall time, slowest job and exit code in plan.md beside story 03's numbers, with the gap
   between the two conditions stated.

7. NEEDS_CONTEXT (worker, 2026-10-26; answered: (a), see plan.md `## Plan deltas`) - findings 2, 3 and 6 rest on a premise this box measures false:
   - Shared setup is not the cost. Timed with an `exit 0` placed right after it: telemetry's shared setup
     0.7 s, council's 0.5 s. The only heavier shared piece is telemetry's `install_fixtures` (two
     `install.sh` runs, ~35 s), used by 4 of 11 parts. A part's time is its own checks: one `install.sh`
     run costs 16-21 s here (telemetry parts run 5-12 of them), and one `cycle.sh` call about 1 s (council).
     Caching the setup saves under 1 s per part, or ~35 s in the 4 install parts. That leaves
     `telemetry` (144 s, no installs), `mods`, `upgrade`, `library`, and council `verbs` (180 s) and `advance` (156 s)
     above two minutes. Times are parts alone, 5 at once, at HEAD 5f97b2e.
   - "Run whole suites, not every part" cannot fit 540 s. Telemetry's parts add up to ~1430 s at 5-way load,
     and council's to ~900 s. Run whole, each suite is one serial job far over the budget (the plan already
     records telemetry alone at 1070 s).
   Question: which way? (a) Recommended: keep parts in the runner, and make the parts themselves smaller.
   Cut the slow parts further (more `--part` names) and add a per-run cache of one pristine `install.sh`
   output (path-independent, checked by diff -r), so every plain fresh-install fixture is a copy and not
   a 16 s install. Then run parts at a bounded default `--jobs` (e.g. 8), with inject/intake after the rest.
   This drops finding 3's "whole suites" clause. (b) Make `install.sh` itself faster. That file is not
   in `## Files`. (c) Accept parts over two minutes, with their times recorded, and only change the
   runner's `--jobs` bound and the latency-suite ordering.
   Findings 1, 4 and 5 are done in the tree (not committed): see Implementation notes.

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
- CLAUDE.md: Commands sentence trimmed ("each turn", "flags it"), 7165 -> 7162 B, every row kept (finding 1).
- scripts/cycle.sh: judge turns any `SUITE: FAIL` review into BLOCK (note "review PASS with SUITE: FAIL"); record-seat rejects `SUITE: none` as MALFORMED when ## Commands has a round-only Full suite row (`full_suite_row_round_only`) (finding 4).
- scripts/cycle.sh: `escalate_reruns_round` shared by status and reopen: suite-timeout goes to open-round only with no RED ask and no review BLOCK in the row, otherwise to repair (finding 5).
- tests/council.test.sh (part escalate): PASS+SUITE: FAIL -> RED; SUITE: none vs SUITE: ok at record-seat; reopen of a suite-timeout+RED+BLOCK row -> repair. `--part escalate` green, 62 s alone.
- Findings 2, 3, 6 done after ruling (a).
- tests/telemetry.test.sh: `install_cache`/`fresh_install` (one `install.sh` output per run under `VULYK_INSTALL_CACHE` or the run's tmp, mkdir lock for parallel parts); plain fresh installs copy it; install part checks it with `diff -r` against a real install. Parts re-cut: + scan, terminal, ledger, ysk, watcher, crlf (16 parts). Installs into dirs with pre-seeded files (ysk, sidecar, rg, mods stubs) stay real: not plain.
- tests/council.test.sh: + judge, close, roster parts (11); `write_review_body` moved to shared setup; roster/advance share the 0.18 fixture; the last-seven-keys check reads r18ad (r18nc lives in roster).
- tests/full-suite.sh: default `--jobs` = cores capped at 12 (8 measured exit 124 at 540 s under round load); inject/intake last, each alone; exports `VULYK_INSTALL_CACHE`. full-suite.test.sh covers all three.
- Part times alone (one at a time, 2026-10-26): council verbs 47, judge 63, seats 87, close 31, escalate 66, ceilings 82, replays 112, walks 107, driver 78, roster 89, advance 58 s; telemetry telemetry 37, scan 81, install 80, terminal 55, wiring 61, ledger 63, constitution 111, library 63, ysk 110, rg 76, mods 102, watcher 65, upgrade 53, crlf 65, wrapper 106, launchers 70, edits 98 s (most measured with the other suite's loop beside; the three over 115 s re-timed truly alone).
- Full-suite measurements in plan.md `## Integration gate` (finding 6): 421 s beside a council run, 444 s alone, both exit 0.
