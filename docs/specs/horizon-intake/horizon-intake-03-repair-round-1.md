---
story: horizon-intake-03
status: done
returned: DONE
worker: worker-code
model: opus
wave: 3
blocked_by: []
---

# Repair round 1

## Goal
Make the asks and findings council round 1 left RED pass, and change nothing else.

## Requirements
> 7. Живой прогон: Здесь, на образце - три drone-horizon и отбор по-настоящему, токены через token-report, разрешение WebFetch в обычном режиме.

## Findings
1. docs/specs/horizon-intake/live-run.md:71-72 [ask 7] the live run must record the WebFetch permission result in default mode against a control, not infer it from WebSearch: both web rows show `0 × WebFetch` and no WebFetch prompt or refusal is observed anywhere in the file, while ask 7 names WebFetch by word and `## Descoped` is empty - repro: `grep -n "WebFetch" docs/specs/horizon-intake/live-run.md` (one `--allowedTools` line, one `no WebFetch`, one `0 × WebFetch`, no result line); a headless `drone-horizon` dispatch told to fetch one named URL under `--setting-sources project --permission-mode default`, with the granted control, closes it.

## Files
- .claude/agents/drone-horizon.md
- scripts/telemetry.sh
- README.md
- .claude/commands/vulyk-plan.md
- templates/grill.md
- docs/adr/022-horizon-step.md
- docs/command-reference.md
- docs/architecture.md
- CHANGELOG.md
- docs/specs/horizon-intake/live-run.md

## Verification
`bash tests/solo.test.sh`

## Implementation notes
- Finding 1: four headless `drone-horizon` dispatches told to WebFetch one named page, default mode against a granted
  control, on two pages. `docs.stripe.com` was fetched without a grant; `dev.ua` was refused ("Claude requested
  permissions to use WebFetch, but you haven't granted it yet."), and fetched once granted. Recorded in `live-run.md`
  (Sample B, the tokens table, "Not run") and in ADR-022's consequence line. The reason one domain passes was not
  checked; the file says so.
- Verification trimmed to `solo.test.sh` (card `full-round-for-a-narrow-fix`): this repair changes only
  `live-run.md` and ADR-022, which no suite reads. `telemetry.test.sh` covers `scripts/telemetry.sh`, untouched since
  `horizon-intake-01` closed green (592 checks).
- Round 1 minor "Descoped empty": one `## Descoped` line in plan.md names ask 4's two-family shrink. The README
  "Drones" bullet and `docs/model-cascade.md` minors are left for the ship's next-brief draft: outside this repair.
