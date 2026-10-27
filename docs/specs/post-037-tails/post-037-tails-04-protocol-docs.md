---
story: post-037-tails-04
spec: post-037-tails
status: todo
returned:
tier: 3
worker: worker-code
wave: 2
blocked_by: [post-037-tails-03]
---

# Protocol and docs: `--exact` hand-off, the publish step waits for green CI, the script's one-line doc

## Goal
After this story `/vulyk-plan` step 3 runs `bash scripts/symbol-map.sh --exact <file>` once per candidate file and hands that output to `queen-planner`, whose `## Files` bullet reads it as `exact` lines plus a count of the rest; `/vulyk-ship`'s printed publish step says that when the Release / deploy row pushes and tags and the repository has CI, the order is push the release commit, green CI on that commit, then the tag; `README.md` and `docs/command-reference.md` carry one line each naming `scripts/symbol-map.sh`; the 163-char line in `vulyk-plan.md` is rewrapped at the file's ~104 width. Prose only; no script change.

## Requirements
> 2. `/vulyk-ship`'s printed publish step says: tag only after CI on the release commit is green.
> 5. symbol-map gets a one-line doc where the docs list scripts; the 163-char line in `vulyk-plan.md` is rewrapped.
> 6. The planner hand-off from symbol-map is tighter: `exact` lines plus counts of the rest.

## Files
- .claude/commands/vulyk-plan.md
- .claude/commands/vulyk-ship.md
- .claude/agents/queen-planner.md
- README.md
- docs/command-reference.md

## Non-goals
- Do not edit any `description:` frontmatter (the agents' and commands' descriptions share a 4983-byte cap in `tests/maintenance.test.sh`); bodies only.
- Do not fill VULYK's own Profile `Release / deploy` row in `CLAUDE.md` (it ships to hives as the template) and do not touch `CLAUDE.md` at all.
- Do not make `/vulyk-ship` run, poll or check CI: it prints the step, a human presses it. One sentence or a short ordered list under the existing `to publish, run:` heading, conditional on "the step pushes and tags and the repo has CI (`.github/workflows/`)".
- Do not change `worker-code.md` or `vulyk-build.md` (the worker's run keeps the full output; `--exact` is the planner hand-off only).
- Do not add a wiki page or a new `docs/` file; the one-line doc goes beside the existing script mentions.
- Do not reword `vulyk-plan.md` step 3 beyond: `--exact`, once per file, the output handed to the planner dispatch, and the rewrap.

## Map slice
`memory/map/agents-and-commands.md`: `## Commands - what each runs` (`/vulyk-plan` recon step 3 at vulyk-plan.md:27-29, `/vulyk-ship` prints the publish command and never runs it), `## Agents` (`queen-planner`: `## Files` lists every reached path, symbol-map output as a source, queen-planner.md:31-33). Contract `--exact` in `docs/specs/post-037-tails/plan.md` `## Contracts`; `README.md` `## What is measured, and what is not` (the `scope-check.sh` / `wave-check.sh` / `trace-check.sh` paragraphs) and `docs/command-reference.md` `## /vulyk-plan`.

## Acceptance criteria
- [ ] `.claude/commands/vulyk-plan.md` step 3 names `bash scripts/symbol-map.sh --exact <file>`, once per file the plan is likely to name, and says the planner dispatch receives that output; no line in the file exceeds 110 characters (the 163-char line at ~28 included).
- [ ] `.claude/agents/queen-planner.md`'s `## Files` bullet says the symbol-map output in the brief is `exact` lines plus a `textual <N> not shown` count per section: `exact` lines go into `## Files` when the change reaches them; a non-zero count under `tests` or `importers` is a recon question for `drone-scout` when the story's change could reach an unnamed caller, never a guess.
- [ ] `.claude/commands/vulyk-ship.md`'s publish step (the `to publish, run:` printout) says: when the Release / deploy row pushes and tags and the repo has CI, push the release commit first, wait for CI on that commit to be green, then tag and push the tag; a red run means no tag.
- [ ] `README.md` `## What is measured, and what is not` has one bold-led line for `scripts/symbol-map.sh` (what it prints, zero tokens, model-free; reports only, never a gate); `docs/command-reference.md` `## /vulyk-plan` names `scripts/symbol-map.sh --exact` in its recon sentence.
- [ ] No `description:` line changed; `bash tests/maintenance.test.sh` stays green.
- [ ] `git diff --stat` touches only the five files under `## Files`.

## Verification
`bash tests/maintenance.test.sh`

## Implementation notes

## Findings
