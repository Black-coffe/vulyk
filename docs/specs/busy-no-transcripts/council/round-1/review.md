<!-- seat: review · model: claude-fable-5-2 · round: 1 · head: a6552c6a · pack: 16fba058c6bd · attempt: 1 · recorded: 2026-11-12T22:16:59Z · verdict: BLOCK -->
VERDICT: BLOCK
SUITE: ok 1135s
MODEL: claude-fable-5-2

## Critical
None.
## Major
1. scripts/hives-behind.sh:151 [ask 1] `naming_proven` must count only a registry line that names a hive path as proof: a line whose path is empty (spaces or a tab only, or ` | hold 2026-11-19 x`) gives an empty slug, `[ -d "$r/projects/" ]` is true for every root, and a folderless hive reads `idle` (exit 0) although no registered hive resolves to a transcript folder, where the ask says it stays `unknown` (exit 1) - repro: `R=$(mktemp -d); mkdir -p $R/r/projects $R/h; printf '%s\n   \n' $R/h > $R/reg; VULYK_HIVES_FILE=$R/reg VULYK_SESSION_ROOTS=$R/r bash scripts/hives-behind.sh --busy $R/h; echo $?` prints `idle no session transcript folder for ... (no Claude Code session has run there)` and `0` (the same registry without the blank-looking line prints `unknown ...` and `1`; the base 40d1f374 prints `unknown` for both); the tests need a case of this shape next to the two they have.
## Minor
- scripts/hives-behind.sh:16 the header still says "No transcript folder under any root is `unknown`, never idle", which the diff makes untrue for the proven case.
- scripts/hives-behind.sh:151 a transcript folder left on disk from before a naming change still proves the rule; this is the proof the ask itself names, and the base has the same blind spot for hives that own a folder.
- docs/specs/busy-no-transcripts/council/round-1/suite.log:1 the log is keyed to the ROUND head e4701761; the head under review a6552c6a adds only the round's own paperwork (ROUND, suite.log, journal.md), so its `SUITE:` line is copied above.
