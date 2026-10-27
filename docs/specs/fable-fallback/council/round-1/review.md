<!-- seat: review · model: claude-fable-5-1 · round: 1 · head: d775f91 · pack: a378f5d8d650 · attempt: 1 · recorded: 2026-10-27T21:23:51Z · verdict: BLOCK -->
VERDICT: BLOCK
MODEL: claude-fable-5-1
SUITE: ok 571s

## Critical
None.
## Major
1. docs/model-cascade.md:112 [ask 3] the one-hour cache must be the reviewer's alone, or the brief, plan and this doc line must record that `worker-code` and `worker-test` already carry it and the owner accepted that - the diff writes "`lead-review` alone carries `experimental:` / `cacheTtl: 1h`" and plan.md:15 and story 02 say "the only agent that does", yet `.claude/agents/worker-code.md:9` and `.claude/agents/worker-test.md:9` carry `cacheTtl: 1h` on the base (commit ab4f8aa), so the 2026-11-03 "spread or not" decision the owner chose rests on a false baseline - repro: `grep -rn cacheTtl .claude/agents/`
## Minor
- .claude/workflows/vulyk-cycle.js:245 a BadLine return drops `fallbacks` (console line only), so a fallback before a bad clerk line never reaches the journal or telemetry on the Workflow path; story 01 notes it, the owner has not
- docs/specs/fable-fallback/fable-fallback-03-review-background-suite.md Findings say "nothing reports the command's completion to it"; this very round's reviewer, a subagent, received a completion notification for its background suite once it finished (task bnznjxk3e, exit 0) - the probe's subagent returned before the command ended, which is not the reviewer's shape; ask 2 is the owner's descope, so no finding, but the alternative offered to the owner should carry this
- asks 5-7 are post-build steps by the plan (settings outside the repo, another hive, the release); at review time both accounts' `modelSettings.claude-fable-5-1.effortLevel` still read `xhigh`, so the build's final report must tick them explicitly
