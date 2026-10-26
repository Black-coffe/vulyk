---
story: symbol-map-03
spec: symbol-map
status: done
returned: DONE
tier: 3
worker: worker-code
wave: 2
blocked_by: [symbol-map-01]
---

# Replay acceptance: hit share and noise on the stories that missed a path

## Goal
After this story `docs/specs/symbol-map/replay.py` replays the script on the local cases in `.vulyk/symbol-map-replay/cases.json` (git-ignored: it names hosts) and `docs/specs/symbol-map/replay.md` records, as numbers only, how many of the 13 missed paths the script finds and how many lines it prints per story. `tests/symbol-map.test.sh` gains one case that pins the runner on a fixture.

## Requirements
> 6. (horizon) До выпуска прогнать скрипт на историях с путём вне ## Files и записать долю найденных промахов и шум как критерий приёмки.

## Files
- docs/specs/symbol-map/replay.py
- docs/specs/symbol-map/replay.md
- tests/symbol-map.test.sh

## Non-goals
- Do not put the runner under `scripts/` (it would ship to hives through `OWNED`) and do not make it a `tests/*.test.sh` of its own: it reads trees outside this repo, so the suite never runs it on real cases.
- Do not change `scripts/symbol-map.py` or `scripts/symbol-map.sh`; if the replay shows a defect in them, write the number down and report it under `## Findings`, do not fix it here.
- Do not commit `cases.json`, any absolute path, host name, client name, story title or file path from a host repo: `replay.md` holds `case 1..n`, counts and the `replay:` line only (public-repo rule).
- Do not tune thresholds, add co-change or widen the script to make the number better; the number is the deliverable.
- Append the replay case to `tests/symbol-map.test.sh`; do not restructure or rename story 01's assertions or fixtures.

## Map slice
`memory/map/scripts.md`: `## Purpose` (python helpers stdlib only), `## Tests (0.36.0)` (suite budget; keep the test case under a second). Contracts `CLI` and `Replay` in `docs/specs/symbol-map/plan.md`. Write `.py` with the Write tool, never a Bash heredoc (CR-byte hazard).

## Acceptance criteria
- [ ] `python docs/specs/symbol-map/replay.py <cases.json>` reads `cases[]` = `{story_file, files, missed}`, finds each case's repo root as the nearest ancestor of `story_file` holding `.git`, runs `bash scripts/symbol-map.sh` of this repo on `files` with `files` as `--scope`, counts a hit per `missed` path that appears on any output line, counts noise as the number of path lines printed, and ends with `replay: hits <h>/<m> noise <lines> over <n> stories`; exit 2 on a missing cases file or an absent repo root, 0 otherwise.
- [ ] `tests/symbol-map.test.sh` gains a case: a `cases.json` written in the temp dir pointing at a fixture story file inside the git-inited Python fixture tree with `files: [pkg/core.py]`, `missed: [tests/test_core.py, docs/other.md]`; the runner's last line is `replay: hits 1/2 noise <N> over 1 stories` with the exact `N` the fixture yields; a cases file naming a story outside any git repo exits 2.
- [ ] `docs/specs/symbol-map/replay.md` holds: the date and the `replay:` line from the real local run; a table `case | missed paths | hits | lines printed` keyed `case 1..n`; one line per missed path class that stayed unfound (docs/ADR, `.env.example`, runbook, sibling script, re-export) as counts, no paths; a `## Gap` line saying the replay ran on the hosts' current trees, not the trees at plan time, so a path that moved since counts as a miss.
- [ ] `replay.md` contains no absolute path, no host or client name and no story slug from a host repo (check with a grep for `:/`, `/Users`, `/home`, `E:` and the host folder names before closing).
- [ ] `bash tests/symbol-map.test.sh` is green with the new case and `bash tests/full-suite.sh --list` still shows one `symbol-map` job (no new suite).

## Verification
`bash tests/symbol-map.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes
- docs/specs/symbol-map/replay.py: new runner; finds `bash` via `shutil.which` (avoids the System32 WSL bash on Windows), checks every repo root before running anything, prints `case i: missed m hits h lines l` plus local-only `unfound` lines, then the `replay:` line.
- tests/symbol-map.test.sh: appended a replay case on its own copy of the Python fixture (noise 9 = the nine path lines `pkg/core.py` yields) and a no-repo case (exit 2); paths go through `cygpath -m` when present.
- docs/specs/symbol-map/replay.md: real run 2026-10-26, `replay: hits 3/13 noise 662 over 23 stories`; leak-checked for `:/`, `/Users`, `/home`, `E:` and every host path segment from cases.json.
- `over <n> stories` counts all 23 cases in cases.json (11 carry the 13 missed paths), as the contract says.

## Findings
- Replay number for the release decision: 3 of 13 missed paths found. In 8 of the 9 stories with an unfound path, the 1536-byte per-run cap cut stdout after 1-3 of 8-73 inputs, so the cap (not the edge finder) decides most of the misses. Not fixed here (Non-goals).
- One cut line reported more hidden inputs (84) than the case had positional files (56, 2 of them globs); likely globs expanded into inputs. Not investigated.
