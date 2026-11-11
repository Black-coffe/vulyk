---
story: upgrade-findings-07
status: todo
returned:
worker: worker-code
model: opus
wave: 4
blocked_by: []
red: required
red_reason:
---

# Repair round 1

## Goal
Make the asks and findings council round 1 left RED pass, and change nothing else.

## Requirements
> 2. A2: stamp-red's results directory is made with `mktemp -d` (0700), its path is recorded in that cycle-owned state, it is reused only when `[ -d ] && [ ! -L ] && [ -O ]` hold, and results this call chain did not produce are never trusted: a regression test that fails on 0.50.2.
> 5. A1-A4 each get a CHANGELOG line, and issue #5 is closed with the release that ships them.

## Findings
ASK 2: RED - A2 results this chain did not produce are never trusted - run: own probe on the red fixture: real pause, then overwrite <outd>/1.out with the declared reason text, resume saw: exit 0, red receipt written, PLANTED text twice in the receipt, line 1 ran once; the untampered control of the same story -> exit 4 "red for another reason". Only N.code and N.line are checked against the record, the stored output is not. Rest holds: mktemp -d /tmp/vulyk-sr.XXXXXX, outd= in the record, old predictable dir ignored, symlink swap refused (55 ok); 0700 check skipped on NTFS
ASK 5: RED - CHANGELOG lines for A1-A4, issue #5 closed - run: grep -n -i for verify_resume, mktemp, no-renames, round_second, "#5" in CHANGELOG.md; sed -n 1,8p; cat VERSION saw: no match; the top entry is still [0.50.3] (the gitignore fix), VERSION 0.50.3. Issue closure has no surface here before a release
1. tests/council.test.sh:4772 [regression] the council `suite` part must end under the 210 s part line (split it, never raise the line: card `test-gate-one-long-limit`): suite.log ends `SUITE: FAIL 1210s - cut part council:suite` (236 s), a rerun of that part alone took 221 s with exit 0 and all 43 checks ok, so the red is growth from the six scenarios the diff adds at tests/council.test.sh:4772-4815 and :4898-4925, not load or a failing check; on the base the part ran 155 s (`grep 'PART council:suite' docs/specs/redact-gaps-2/council/round-1/suite.log`) - repro: `bash scripts/suite-parts-check.sh docs/specs/upgrade-findings/council/round-1/suite.log` prints `cut part council:suite: 236s of cap 300s (grew)`
1. install.sh:535 [regression] `install.sh --upgrade` must finish (version stamp and manifest written, or a named error) when a hive holds a `docs/specs/*/council/round-*` directory with no `ROUND` file: under `set -euo pipefail` the failing `sed ... "$d/ROUND"` pipeline in `report_measured_suite` (called at install.sh:1919) ends the installer with exit 2 and no message right after the gate-split note, framework files already replaced and `.claude/vulyk-version` still the old one; the base has no such call (`git show 616a3c2e:install.sh | grep -c report_measured_suite` prints 0) and upgrades the same hive with exit 0 - repro: fresh `bash install.sh <hive>`, `mkdir -p <hive>/docs/specs/demo/council/round-1 && printf 'SUITE: ok 378s\n' > <hive>/docs/specs/demo/council/round-1/review.md`, `bash install.sh <hive> --upgrade; echo $?` prints 2 and the stamp is unchanged (with a ROUND file beside it: exit 0 and the `full suite measured 378s` line); the eval'd-function test at tests/telemetry.test.sh (`hive-unmeasured`) cannot see it because it runs outside the installer's `set -e`
2. CHANGELOG.md:5 [ask 5] A1, A2, A3 and A4 must each have a line in `CHANGELOG.md`: the branch does not touch the file (`git diff 616a3c2e..085286d4 --stat -- CHANGELOG.md` is empty, no `[Unreleased]` section), the four `CHANGELOG:` lines sit only in the `## Implementation notes` of stories 03 and 05, and plan.md `## Descoped` is empty
- [regression] PART council:suite ok 236s cap 300s

## Files
- scripts/lib.sh
- scripts/cycle.sh
- scripts/wave-check.sh
- tests/cycle.test.sh
- tests/council.test.sh
- templates/story.md
- install.sh
- tests/telemetry.test.sh
- docs/cycle.md
- .claude/commands/vulyk-update.md
- .claude/hooks/vulyk-update-check.sh
- .claude/hooks/session-start-brief.sh
- scripts/vulyk-update.sh
- tests/maintenance.test.sh
- docs/hooks-reference.md
- README.md

## Verification
`bash tests/council.test.sh --part suite`
`bash tests/cycle.test.sh --part close`
`bash tests/cycle.test.sh --part gates`
`bash tests/telemetry.test.sh --part edits`
`bash tests/telemetry.test.sh --part crlf`
`bash tests/telemetry.test.sh --part wiring`
`bash tests/cycle.test.sh --part red`
`bash tests/council.test.sh --part advance`
`bash tests/telemetry.test.sh --part upgrade`
`bash tests/telemetry.test.sh --part constitution`
`bash tests/council.test.sh --part verbs`
`bash tests/council.test.sh --part roster`
`bash tests/telemetry.test.sh --part install-xp`
`bash tests/maintenance.test.sh`
