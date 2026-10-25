<!-- seat: review · model: claude-fable-5-1 · round: 1 · head: 66f09da · pack: 451665e3db2e · attempt: 1 · recorded: 2026-10-25T13:34:15Z · verdict: BLOCK -->
VERDICT: BLOCK
MODEL: claude-fable-5-1

## Critical
None.
## Major
1. docs/specs/horizon-intake/live-run.md:71-72 [ask 7] the live run must record the WebFetch permission result in default mode against a control, not infer it from WebSearch: both web rows show `0 × WebFetch` and no WebFetch prompt or refusal is observed anywhere in the file, while ask 7 names WebFetch by word and `## Descoped` is empty - repro: `grep -n "WebFetch" docs/specs/horizon-intake/live-run.md` (one `--allowedTools` line, one `no WebFetch`, one `0 × WebFetch`, no result line); a headless `drone-horizon` dispatch told to fetch one named URL under `--setting-sources project --permission-mode default`, with the granted control, closes it.
## Minor
- docs/model-cascade.md:132,324 and README.md's top "Drones" bullet still list the Sonnet drones as scout and docs only; `drone-horizon` is in the README table and ladder line but not there (outside the story's `## Files`).
- plan.md `## Descoped` is empty while ask 4's "три модели" ships as two families (Sonnet lenses, Opus judge) per the approved build request and the plan's Assumptions; one `## Descoped` line naming report option B would make the shrink explicit.
- `bash tests/telemetry.test.sh` timed out at 540 s on this machine (exit 124); its drift guard (case 20) re-run by hand against `scripts/telemetry.sh agents` and `.claude/agents/*.md` shows no drift, and `bash tests/solo.test.sh` passes.
- live-run.md:74-76 states the parallel-prompt stall only for headless (refused at once) and says the interactive three-prompt case was not seen; the claim is narrowed to match, so no finding, but the first real new-ground plan in default mode should be watched for it.
