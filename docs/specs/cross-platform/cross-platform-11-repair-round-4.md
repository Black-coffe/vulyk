---
story: cross-platform-11
status: done
returned: DONE
worker: worker-code
model: opus
wave: 7
blocked_by: []
red: required
red_reason: run_capped with no timeout and no run-capped.py beside lib.sh
red_verified_at: 2026-10-29T16:12:42Z 1720375b32be42e9408e205cfb50d0816f68587ebd9e5b471df7543f36899c10
---

# Repair round 4

## Goal
Make the asks and findings council round 4 left RED pass, and change nothing else.

## Requirements
No brief ask is RED in round 4 - the findings below are the whole task.

## Findings
1. tests/inject.test.sh (`--part latency`) [regression] the full suite must end green: `bash tests/full-suite.sh` on 3697dd3 gave `full suite: 49 ok, 1 failed, 0 timed out, wall 565s, budget 590s, jobs 12`, the one failure `FAIL 18s bash tests/inject.test.sh --part latency` with `::error::median latency, Bash, 248 ms > 200 ms` (the job ran alone, 540 s to 558 s, after the last telemetry part); base-side: round-3 review.md's suite run on the base (505 s idle, `49 ok, 1 failed`) had only full-suite.test.sh red, so this part was green there; the diff touches neither `.claude/hooks/defects-inject.sh` nor this test, and the same part alone right afterwards passed twice at 162 ms and 161 ms, so this is a wall-clock threshold under the suite's tail load, not a code fault of the range - the cheap path is one re-run or the owner's ACCEPTED - repro: `bash tests/full-suite.sh; grep -n 'median latency' <logs dir>/48.log`

**Owner's ruling at reopen (2026-10-29), «Переоткрыть: только 3 падения Mac (Рекомендую)»:** finding 1 is machine-load
noise, not a regression - alone the part measures 163-168 ms against the 200 ms threshold and `.claude/hooks/defects-inject.sh`
is not in the diff. Do not change the hook, the test or the threshold for it. The task is the three macOS-only failures of
CI probe run 40871539881 (full output in `docs/specs/cross-platform/mac-probe-round4.txt`):
2. tests/maintenance.test.sh:119 - BSD sed rejects `1{/^---$/!q;d}` («extra characters at the end of d command»): a command
   before `}` needs a `;` (`...;d;}`), as in every other brace group. The «always-loaded rules cap» check is the one that fails.
3. scripts/cycle.sh `briefed` - on macOS an empty `## Asks` section (present, zero items) exits 0 and writes Briefed
   (`council --part judge`, «empty Asks: exit=0»); on Linux/Windows it exits 2. Find which BSD tool difference lets it pass
   (`brief_asks` in lib.sh, `asks_count`, or the section check) and make it exit 2 everywhere.
4. tests/council.test.sh `part walks` - the close-story probe r2m9 (a `## Commands` cell that is itself an `&&`-joined
   command, `sh -c 'true && true'`) FAILs on the branch under macOS only; the CI tail does not show why. Reproduce the
   cause from the code (`verification_segments`, `command_cell_exists` in lib.sh) against BSD sed/awk behaviour.
BSD sed/awk differences are not reproduced by Docker `bash:3.2` (busybox); use a stub as `tests/cycle.test.sh` `part bsd`
does, and say which ones you could only reason about. The Queen re-runs macOS CI on the branch before the next round.

## Files
- scripts/lib.sh
- scripts/py.sh
- scripts/run-capped.py
- scripts/cycle.sh
- CLAUDE.md
- tests/cycle.test.sh
- install.sh
- scripts/state.sh
- scripts/telemetry.sh
- scripts/redact.sh
- scripts/injection-check.sh
- scripts/leak-check.sh
- scripts/top-model.sh
- scripts/defects-check.sh
- scripts/defects-index.sh
- scripts/prompt-check.sh
- scripts/symbol-map.sh
- scripts/trace-autopsy.sh
- .claude/hooks/handoff.sh
- .claude/hooks/anomaly-scan.sh
- .claude/hooks/vulyk-update-check.sh
- .claude/commands/vulyk-build.md
- .claude/commands/vulyk-evolve.md
- .claude/commands/vulyk-review.md
- .claude/commands/vulyk-status.md
- .claude/agents/lead-review.md
- tests/telemetry.test.sh
- tests/council.test.sh
- tests/defects.test.sh
- tests/inject.test.sh
- tests/intake.test.sh
- tests/solo.test.sh
- tests/symbol-map.test.sh
- tests/mods.test.sh
- tests/token-report.test.sh
- tests/full-suite.sh
- tests/full-suite.test.sh
- scripts/portability-check.sh
- docs/defects/shell-needs-gnu-or-bash4.md
- docs/defects/shell-needs-gnu-or-bash4.sed-i.fixture
- docs/defects/shell-needs-gnu-or-bash4.sed-bre.fixture
- docs/defects/shell-needs-gnu-or-bash4.array.fixture
- docs/defects/shell-needs-gnu-or-bash4.python.fixture
- docs/defects/INDEX.md
- tests/maintenance.test.sh
- .github/workflows/ci.yml
- scripts/trace-check.sh
- scripts/wave-check.sh
- scripts/ship-check.sh
- scripts/human-check.sh
- scripts/journal.sh
- tests/model-profile.test.sh
- docs/defects/shell-needs-gnu-or-bash4.paste-s.fixture
- docs/defects/shell-needs-gnu-or-bash4.case-in-subst.fixture
- docs/defects/shell-needs-gnu-or-bash4.heredoc-in-subst.fixture

## Verification
`bash tests/cycle.test.sh`
`bash tests/telemetry.test.sh --part telemetry && bash tests/telemetry.test.sh --part scan && bash tests/telemetry.test.sh --part install && bash scripts/defects-check.sh && bash tests/maintenance.test.sh`
`bash tests/council.test.sh --part judge && bash tests/council.test.sh --part advance && bash tests/council.test.sh --part close`
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh`
`bash tests/symbol-map.test.sh`
`bash tests/full-suite.test.sh`
`bash tests/solo.test.sh`
`bash tests/maintenance.test.sh && bash scripts/defects-check.sh`
`bash tests/model-profile.test.sh`
`bash tests/telemetry.test.sh --part scan`
`bash tests/maintenance.test.sh`
`bash scripts/defects-check.sh`

## Red receipt
- command: bash tests/cycle.test.sh
- exit: 1
- tests: 1720375b32be42e9408e205cfb50d0816f68587ebd9e5b471df7543f36899c10 (scripts/defects-check.sh, tests/council.test.sh, tests/cycle.test.sh, tests/defects.test.sh, tests/full-suite.test.sh, tests/inject.test.sh, tests/intake.test.sh, tests/maintenance.test.sh, tests/model-profile.test.sh, tests/solo.test.sh, tests/symbol-map.test.sh, tests/telemetry.test.sh)
- impl: 23c9af191be3edd70db061fdfd011be46bd6a183d41ebad3be28abe6f8b0e09d
- stamped: 2026-10-29T16:12:42Z

```
red-receipt: an unmarked story built from templates/story.md closes as before
  ok    the template story closes and commits, no receipt asked
red-receipt: close-story on a marked story - the sealed test edited, no implementation change, then a real change closes
  ok    red-12 stamped
  ok    a sealed test edited after the stamp: exit 4
  ok    the implementation unchanged since the stamp: exit 4
  ok    receipt + changed implementation + green: closed, the receipt in the commit
red-receipt: close-story on a marked story that was never stamped
  ok    the unstamped story: exit 4, nothing committed
  ok    the refusal names stamp-red and the story
```

## Implementation notes
- tests/maintenance.test.sh:119 - finding 2: `1{/^---$/!q;d;}` and `/^paths:/{p;q;}`; BSD sed needs `;` before `}` after d (CI error) and, by the same parser rule, after q (reasoned, not reproduced).
- tests/council.test.sh mk_spec - finding 3: cycle.sh was right; the fixture was not. BSD `seq 1 0` counts down (prints 1 and 0), so the "empty" brief got two asks on macOS. A counted while loop replaces seq (reasoned from BSD seq's documented countdown, not run on a Mac).
- scripts/lib.sh capped_by - finding 4: macOS has no timeout, so capped_by picked the Python cap, but run_wall_probes copies lib.sh without run-capped.py, so close-story's verification died on python's "can't open file" (reproduced here with dead timeout/gtimeout stubs). The Python cap now counts only with run-capped.py beside lib.sh; otherwise the run goes uncapped with the existing warning. verification_segments/command_cell_exists were not the cause.
- tests/cycle.test.sh part bsd - the red test: lib.sh alone in a dir, dead timeout/gtimeout, `run_capped 5 true` must exit 0.
- Finding 1 untouched per the owner's ruling (hook, test, threshold unchanged).
- Fixes 2 and 3 live in sealed test files, so they went in with the red test before the receipt; only lib.sh is the post-receipt implementation.
