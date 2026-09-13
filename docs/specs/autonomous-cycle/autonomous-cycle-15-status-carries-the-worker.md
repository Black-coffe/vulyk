---
story: autonomous-cycle-15
spec: autonomous-cycle
status: done
tier: 4
worker: worker-code
tracer: false
wave: 4
blocked_by: [autonomous-cycle-04, autonomous-cycle-06]
---

# `status --json` carries each story's worker, so the driver can route without reading files

## Goal
`cycle.sh status --json` tells the driver everything a build dispatch needs — which story file, which worker caste, how many verification repeats — as data, so `.claude/workflows/vulyk-cycle.js` routes `worker-code` vs `worker-test` from the JSON and never opens a story file. The fallback loop in `/vulyk-build` reads the same objects.

## Requirements
> C3's `status --json` lists `wave_stories` as file paths only, with no per-story `worker:`; the Workflow driver may not read story files, so it dispatches every build story to `worker-code`.

> `wave_stories` becomes a list of objects `{"file": "<path>", "story": "<id>", "worker": "worker-code|worker-test", "repeat": <n|1>}` read from story frontmatter and `## Verification`

## Files
- scripts/cycle.sh
- tests/council.test.sh
- .claude/workflows/vulyk-cycle.js

## Non-goals
- Do not change any other key of the C3 object or any `next` derivation rule; this is one field's shape.
- Do not make the driver read, grep or infer anything from a story file — the whole point is that it does not.
- Do not touch `/vulyk-build.md` (story 09 owns it); if its fallback loop text names `wave_stories` as strings, report that in CONCERNS for the Queen to route, do not edit it.
- Do not add a `worker:` default beyond `worker-code` when the frontmatter line is missing — and say so in the object (`"worker": "worker-code"`), never `null`.

## Map slice
`docs/specs/autonomous-cycle/plan.md` `## Contracts` C3 (the object), C11 (driver agentTypes), `## Plan deltas` entry 2 (this change) · `scripts/cycle.sh` — the `status` implementation from stories 01/04 (`wave_stories` builder; frontmatter parsing already exists for `wave:`/`blocked_by:`/`status:`) · `.claude/workflows/vulyk-cycle.js` — the `build:<wave>` branch · `tests/council.test.sh` — the `status --json` fixtures and `expect()` helper.

## Acceptance criteria
- [ ] `status --json` emits `wave_stories` as objects with exactly the keys `file`, `story`, `worker`, `repeat`; `worker` is the frontmatter `worker:` value or `worker-code` when absent; `repeat` is the integer from a `repeat: N` line under `## Verification` or `1`.
- [ ] `tests/council.test.sh` gains a fixture spec with one `worker: worker-code` story and one `worker: worker-test` story in the same wave and asserts both objects verbatim (order = file name order); the existing checks stay green.
- [ ] `.claude/workflows/vulyk-cycle.js` `build:<wave>` branch dispatches each object with `agentType: story.worker` and passes `repeat` in the `close-story` clerk command (`--repeat <n>` only if `cycle.sh close-story` accepts it — read story 04's implementation; otherwise omit and note it), still without any string literal from the forbidden list in its acceptance criteria.
- [ ] `node --check .claude/workflows/vulyk-cycle.js` passes when `node` is present; `grep -c '"worker"' .claude/workflows/vulyk-cycle.js` ≥ 1 and `grep -c 'worker-code' .claude/workflows/vulyk-cycle.js` = 0 (no hardcoded caste).

## Verification
`git ls-files '*.sh' | xargs -n1 bash -n && bash tests/council.test.sh`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->
- `scripts/cycle.sh`: added `repeat_of()` (reuses `verify_of()`, same parse as `cmd_close_story`'s inline REPS logic, not refactored to keep the passing close-story tests untouched) and `wave_story_json()`; `cmd_status` now builds `WAVE_STORIES_JSON` from these instead of `json_str_array`.
- `close-story` takes no `--repeat` flag today (`cmd_close_story` derives `REPS` itself from the story file's own `## Verification` block, cycle.sh:975-976) - the driver's `close-story ... --commit` call was left as-is; `repeat` in the object is informational only. Flagged in CONCERNS.
- `.claude/workflows/vulyk-cycle.js`: `build:<wave>` now maps `agentType: story.worker` per wave_stories object; removed the old comment naming the hardcoded caste literally (verbatim string is now banned by the story's own acceptance grep).
- `tests/council.test.sh`: new fixture spec `wstory`, two todo stories same wave, `worker: worker-code` (repeat absent -> default 1) and `worker: worker-test` (`repeat: 3` explicit), asserts `.wave_stories` verbatim via `jq -c`. 128 -> 129 checks, still green.

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
