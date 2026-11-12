<!-- seat: review · model: claude-fable-5-2 · round: 1 · head: 65076920 · pack: 7d7a0c98b2b4 · attempt: 1 · recorded: 2026-11-12T20:35:09Z · verdict: BLOCK -->
VERDICT: BLOCK
SUITE: ok 1268s
MODEL: claude-fable-5-2

## Critical
None.
## Major
1. scripts/hives-behind.sh:116 [ask 7] `--busy` must count a transcript written in the last 60 minutes at any depth under the hive's transcript folder: Workflow agents write `<slug>/<session>/subagents/workflows/<wf>/agent-*.jsonl` (depth 5), `-maxdepth 3` never reads them, so a hive whose only fresh writes are a running Workflow's (main session quiet for an hour, no DRIVER file) is reported `idle` and upgraded - repro: `R=$(mktemp -d); mkdir -p $R/h; s=$(bash scripts/hives-behind.sh --slug $R/h); mkdir -p $R/r/projects/$s/sid/subagents/workflows/wf; : > $R/r/projects/$s/sid/subagents/workflows/wf/agent-a.jsonl; VULYK_SESSION_ROOTS=$R/r bash scripts/hives-behind.sh --busy $R/h` prints `idle`, exit 0 (the same file one level up at `sid/subagents/` prints `busy`); in this repo's own transcript folder 593 of 1181 transcripts sit at that depth and 4 past sessions had Workflow writes with no shallower write in the hour before (one stretch 135 minutes); a build that claimed a DRIVER is still caught by the first sign.
2. docs/specs/post-052-tails/post-052-tails-01.md:75 [unanchored] card `host-internals-in-public-repo` (Never: another project's transcript slug in this repository): the `--slug` test at tests/maintenance.test.sh:1147 and the red receipt that quotes it must use a synthetic stand-in path, not the path and transcript slug of a hive in the registry - evidence: `grep -n '<hive slug, masked>' tests/maintenance.test.sh docs/specs/post-052-tails/post-052-tails-01.md`; `leak-check.sh` passes on it, so nothing else stops it before a publish.
## Minor
- docs/specs/post-052-tails/council/round-1/suite.log:1 the log says `head=616d0023`, the round's ROUND head; the reviewed head 65076920 adds only the round's paperwork on top (ROUND, suite.log, journal.md), so the SUITE line is copied.
- tests/maintenance.test.sh:1149 the fixture folder is named `busy`, so every `expect ... "busy"` also passes on an `unknown ...` line that names the path; the checks tell busy from idle, not busy from unknown.
- scripts/hives-behind.sh:126 the subfolder `cwd` match is case-sensitive past the drive letter, so on Windows a registry path spelled in another case than the session's `cwd` leaves a subfolder session unseen.
- tests/maintenance.test.sh:1198 the split check accepts 2 slices where ask 5 names 4.
- memory/map/scripts.md:56 the `--busy` bullet does not carry the `<slug>-*` subfolder rule or the stale-DRIVER hint yet (story 03 leaves it to the ship's drone-docs pass).
