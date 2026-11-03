---
story: gate-split-09
status: done
returned: DONE
worker: worker-code
model: opus
wave: 5
blocked_by: []
red: required
red_reason: gate split: /vulyk-update step 6 tells every hive, not only a renamed row
red_verified_at: 2026-11-02T23:43:46Z dcab456096a7f3bc0829984a3393ae30faca1aa3dfa1f8cd0beb0d93447fdea6
---

# Repair round 2

## Goal
Make the asks and findings council round 2 left RED pass, and change nothing else.

## Requirements
> 9. В проектах на VULYK свой «полный прогон» можно разбить на несколько строк-частей с лимитом 300 с на каждую, и при обновлении об этом сказано.

## Findings
ASK 9: RED - hives may split their full run into several 300 s part rows, and the upgrade says so - run: full_suite_row probe; council.test.sh --part suite; grep install.sh, vulyk-update.md, CHANGELOG.md saw: the code works (several rows become one capped step each; exactly cell 2 is read). The notice does not reach most hives. The only text is in .claude/commands/vulyk-update.md step 6, inside the paragraph that starts "If the upgrade printed `commands: no 'Full suite / build (round-only)' row`". A hive that already has the row never sees the split option or the new 300 s cap on each verification line. install.sh --upgrade prints nothing about either. CHANGELOG [Unreleased] has no gate-split entry. install.sh's template still says "the reviewer runs it once per round".

## Files
- tests/full-suite.sh
- tests/full-suite.test.sh
- scripts/suite-parts-check.sh
- docs/defects/test-gate-one-long-limit.md
- docs/defects/test-gate-one-long-limit.original.fixture
- docs/defects/test-gate-one-long-limit.neighbour.fixture
- docs/defects/INDEX.md
- .github/workflows/ci.yml
- scripts/cycle.sh
- tests/council.test.sh
- tests/cycle.test.sh
- .claude/agents/worker-code.md
- .claude/agents/worker-test.md
- .claude/commands/vulyk-build.md
- tests/solo.test.sh
- tests/e2e.test.sh
- tests/model-profile.test.sh
- tests/telemetry.test.sh
- templates/plan.md
- .claude/workflows/vulyk-cycle.js
- tests/driver.test.sh
- .claude/agents/cycle-clerk.md
- .claude/agents/lead-review.md
- .claude/commands/vulyk-review.md
- CLAUDE.md
- install.sh
- .claude/commands/vulyk-update.md
- docs/adr/029-gate-split.md
- docs/adr/001-cycle-state-contract.md
- docs/adr/023-fast-story-checks-full-suite-per-round.md
- docs/adr/024-no-reliance-on-background-commands-in-subagents.md

## Verification
`bash tests/full-suite.test.sh`
`bash tests/council.test.sh --part advance`
`bash tests/council.test.sh --part roster`
`bash tests/solo.test.sh`
`bash tests/model-profile.test.sh`
`bash tests/e2e.test.sh`
`bash tests/telemetry.test.sh --part install`
`bash tests/telemetry.test.sh --part install-xp`
`bash tests/telemetry.test.sh --part constitution`
`bash tests/telemetry.test.sh --part constitution2`
`bash tests/telemetry.test.sh --part ysk`
`bash tests/telemetry.test.sh --part ysk-hook`
`bash tests/council.test.sh --part suite`
`bash tests/council.test.sh --part seats`
`bash tests/council.test.sh --part escalate`
`bash tests/council.test.sh --part replays`
`bash tests/council.test.sh --part replays2`
`bash tests/driver.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`
`bash tests/council.test.sh --part walks`
`bash tests/council.test.sh --part walks2`
`bash tests/council.test.sh --part seats2`
`bash tests/council.test.sh --part roster2`
`bash tests/council.test.sh --part ceilings`
`bash tests/council.test.sh --part ceilings2`

## Red receipt
- command: bash tests/telemetry.test.sh --part constitution
- exit: 1
- tests: dcab456096a7f3bc0829984a3393ae30faca1aa3dfa1f8cd0beb0d93447fdea6 (tests/council.test.sh, tests/driver.test.sh, tests/e2e.test.sh, tests/full-suite.test.sh, tests/model-profile.test.sh, tests/solo.test.sh, tests/telemetry.test.sh)
- impl: 74af5813556bbc6cce307c286c04ef9a83d9804d1c5baaf66edcd7675256a2bd
- stamped: 2026-11-02T23:43:46Z

```
  ok    the Commands body is carried over verbatim
  ok    everything outside the blocks is the release's text
  ok    the Telemetry row keeps its answer
  ok    an owner line outside the blocks survives in the backup only
  ok    VULYK's own Commands rows never land in a hive
  ok    a Profile with every release row gets no missing-rows note
  ok    a second replace has nothing to do
  ok    and writes no second backup
  ok    a migrated hive gets no migrate hint
telemetry.test.sh: 34 checks, 3 failed
```

## Implementation notes
- tests/telemetry.test.sh (part constitution): four checks - canonical-row hive hears `gate split (ADR-029)` on --upgrade, /vulyk-update step 6 has an unconditional "Gate split (ADR-029), every hive:" line, the install Commands template names the 300 s part cap, CHANGELOG [Unreleased] has the entry.
- .claude/commands/vulyk-update.md: split/300 s text moved out of the missing-row paragraph into its own every-hive paragraph.
- install.sh: Commands placeholder no longer says "the reviewer runs it once per round"; names part rows and the 300 s cap.
- CHANGELOG.md [Unreleased]: gate-split entry (paperwork path per scripts/lib.sh, not in ## Files).
- Surprise: install.sh --upgrade already printed the gate-split notice on every hive (story 06, line ~1517); the finding's "prints nothing" did not hold, now guarded by the first check.
