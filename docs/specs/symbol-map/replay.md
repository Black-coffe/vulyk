# symbol-map replay

Run 2026-10-26, local cases file (git-ignored), `python docs/specs/symbol-map/replay.py <cases.json>`:

`replay: hits 3/13 noise 662 over 23 stories`

23 stories; 11 of them carry the 13 missed paths, the other 12 count only for noise.

| case | missed paths | hits | lines printed |
|---|---|---|---|
| case 1 | 1 | 0 | 28 |
| case 2 | 2 | 0 | 36 |
| case 3 | 0 | 0 | 26 |
| case 4 | 1 | 0 | 26 |
| case 5 | 0 | 0 | 34 |
| case 6 | 1 | 0 | 29 |
| case 7 | 0 | 0 | 33 |
| case 8 | 0 | 0 | 31 |
| case 9 | 1 | 0 | 32 |
| case 10 | 1 | 0 | 37 |
| case 11 | 0 | 0 | 33 |
| case 12 | 0 | 0 | 33 |
| case 13 | 0 | 0 | 37 |
| case 14 | 0 | 0 | 33 |
| case 15 | 0 | 0 | 31 |
| case 16 | 1 | 0 | 37 |
| case 17 | 0 | 0 | 26 |
| case 18 | 1 | 0 | 26 |
| case 19 | 1 | 1 | 32 |
| case 20 | 2 | 2 | 10 |
| case 21 | 1 | 0 | 21 |
| case 22 | 0 | 0 | 25 |
| case 23 | 0 | 0 | 6 |

## Unfound, by class (10 paths)
- docs/ADR: 1
- `.env.example`: 0 (the one case found it)
- runbook: 0 (the one case found it)
- sibling script: 1
- re-export (`__init__.py`): 1
- test file (a meta or coverage test): 3
- application module (a caller or sibling module): 3
- a symbol name, not a path: 1

## Cut by the cap
In 8 of the 9 stories with an unfound path the 1536-byte cap cut the output after 1-3 of their 8-73 inputs; the ninth was not cut and missed a re-export.

## Per-file run (the mode `/vulyk-plan` step 3 uses)
After round 1 the recon line runs the script once per file, so the figure above (one call on all of a story's files,
cut by the cap) understates it. Rerun 2026-10-26 by the Queen, one call per `## Files` entry with every other entry
as `--scope`, same cases, a local runner in the session scratchpad (not committed):

`per-file: hits 6/13 lines 8636 over 23 stories, 519 calls` - about 17 lines per call, about 375 per story (the cases
hold 8-73 files each).

## In-sample
The rules behind the guard-test and path-mention sections were derived from these same 13 missed paths, and 19 of the
23 stories come from one Python host. The figure shows the script works on the cases it was built from; it is not
evidence for a close-time gate or for more languages. Those wait for misses from stories planned after this release.

## Gap
The replay ran on the hosts' current trees, not the trees at plan time, so a path that moved or was deleted since counts as a miss.
