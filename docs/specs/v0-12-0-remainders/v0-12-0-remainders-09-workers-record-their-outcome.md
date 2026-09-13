---
story: v0-12-0-remainders-09
spec: v0-12-0-remainders
status: done
returned: DONE
tier: 4
worker: worker-code
tracer: false
wave: 3
blocked_by: [v0-12-0-remainders-06]
---

# Workers record their outcome in the story; neither driver reads the prose

## Goal
ADR-006's protocol side: `templates/story.md` documents `returned:`; `worker-code.md` and `worker-test.md` set it as their last edit, mirroring the `STATUS:` line, with a `NEEDS_CONTEXT` question written under `## Findings`; `/vulyk-build`'s `build:<wave>` row runs `close-story` on every non-empty return and counts exit 4 as a miss whatever its `error` says; three `tests/driver.test.sh` scenarios prove the Workflow driver never read the report to decide.

## Requirements
> история с ответом NEEDS_CONTEXT/WALL не закрывается (M3)

## Files
- .claude/agents/worker-code.md
- .claude/agents/worker-test.md
- templates/story.md
- .claude/commands/vulyk-build.md
- tests/driver.test.sh

## Non-goals
- Do not edit `.claude/workflows/vulyk-cycle.js` - ADR-006 says no driver change; the scenarios document its existing behaviour.
- Do not edit `scripts/cycle.sh` (story 08 owns the gate) or any story of this spec other than your own.
- In `vulyk-build.md` touch only the `build:<wave>` row (`:57`) and, if step 4's blocked-story text names `STATUS:` as the decision, that clause; no `--stamp`, no `claim` (story 13).
- Do not remove the `STATUS:` report line from the worker protocol; it stays for the Queen's and the human's eyes.
- Do not add a `schema` to any `agent()` call.

## Map slice
`docs/adr/006-worker-status-channel.md` (contract table rows for `templates/story.md`, the two worker files, `vulyk-build.md:57`; `## How the tests prove it` - the three driver scenarios exactly; `## Invariants`) · `plan.md` K5, K4 (stub queues: the `agents` entry is the report string, the `clerk` entry is the `close-story` answer) · `memory/map/agents-and-commands.md` (`worker-*` final line `STATUS: DONE|NEEDS_CONTEXT|WALL`, walls write `## Findings` first; `/vulyk-build` loop) · `templates/story.md` frontmatter.

## Acceptance criteria
- [ ] `templates/story.md` frontmatter gains, after `status:`, the line `returned:              # written by the worker as its last edit: DONE | NEEDS_CONTEXT | WALL`; the size-budget and other comments are unchanged.
- [ ] Both worker files gain one protocol step before the return: set the story's `returned:` to the word the `STATUS:` line will carry; on `NEEDS_CONTEXT` the exact question goes under `## Findings` (as `WALL` already does); wording says the driver reads the key, not the report.
- [ ] `vulyk-build.md` `build:<wave>` row: `close-story` runs on every non-empty return; exit 4 is a miss whatever its `error`; reading `STATUS:` is allowed for the one-line log only.
- [ ] Driver scenarios: (1) agent stub returns a report opening `STATUS: DONE`, clerk answers `close-story` exit 4 `returned WALL` then `ok:true` -> `close-story` called twice, no stop, run continues; (2) same with exit 4 twice -> `stop.verb === 'build'`, `stop.file` names the story, `close-story` called exactly twice; (3) agent stub returns `STATUS: WALL`, clerk answers `ok:true` -> the story closes (documents that the verb, not the driver, is the gate).
- [ ] `bash tests/driver.test.sh` passes; set `returned: DONE` in this story's own frontmatter before returning.

## Verification
`bash tests/driver.test.sh`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->
- `templates/story.md`: added `returned:` frontmatter line after `status:`, per ADR-006's contract table.
- `.claude/agents/worker-code.md`, `.claude/agents/worker-test.md`: added a final protocol step setting `returned:` to the STATUS word; NEEDS_CONTEXT now also writes its question under `## Findings` (mirroring WALL).
- `.claude/commands/vulyk-build.md` `build:<wave>` row: rewrote the close-story sentence so it runs on every non-empty return and treats exit 4 as a miss regardless of `error`; folded the old "red/NEEDS_CONTEXT/WALL, three kinds" wording into two kinds since `returned:` now routes all worker outcomes through the same exit code.
- `tests/driver.test.sh`: added scenarios (q)(r)(s) per ADR-006's `## How the tests prove it`, each stubbing `close-story`'s answer independently of the agent stub's `STATUS:` line to prove the driver never reads report prose to decide.

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
