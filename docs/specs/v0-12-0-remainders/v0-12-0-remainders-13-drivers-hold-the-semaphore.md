---
story: v0-12-0-remainders-13
spec: v0-12-0-remainders
status: todo
returned:
tier: 4
worker: worker-code
tracer: false
wave: 6
blocked_by: [v0-12-0-remainders-11, v0-12-0-remainders-09]
---

# Both drivers claim, stamp and release

## Goal
The Workflow driver, the `/vulyk-build` fallback and `/vulyk-review` each claim the spec once with their stamp, pass `--stamp` on `open-round`, `record-seat`, `judge` and `close-story`, and release on every exit including a `stop`; a `held by` refusal reaches the Queen as a named stop pointing at the `release` command.

## Requirements
> Второй драйвер на том же спеке получает отказ — семафор DRIVER через cycle.sh claim/release (M-7, решено в дельте 6).

## Files
- .claude/workflows/vulyk-cycle.js
- tests/driver.test.sh
- .claude/commands/vulyk-build.md
- .claude/commands/vulyk-review.md

## Non-goals
- Do not change the stamp's source (`/dev/urandom`, 16 hex, taken once) or show it to a seat; the same value is the semaphore key.
- Do not `release` on `paused` - `pause` already released; a `release` after `pause` is harmless (absent file, exit 0) but must not be described as the mechanism.
- Do not edit `/vulyk-pause`, `/vulyk-resume`, `/vulyk-plan`; do not touch `cycle.sh`; do not touch the `build:<wave>` row's `close-story`-on-every-return rule story 09 wrote.
- No retry loop on `held by`: a refused claim ends the run at once.
- Set `returned: DONE` in this story's own frontmatter before returning (story 08's gate is live).

## Map slice
`plan.md` K3 (verbs, `--stamp`, release points - build exactly this), K2 (`{verb:'claim', exit:2, error}` is the generic failed-verb stop), K4 · `recon/tests-ci-hooks-driver.md` §4 (`clerk()` call sites, the `Stop` catch at `:184-188` - release belongs in a `finally`) · `memory/map/agents-and-commands.md` (`/vulyk-build` step 1-2, `/vulyk-review` dispatches only `missing` and records with the stamp delimiter) · `docs/adr/004-driver-mutual-exclusion.md`.

## Acceptance criteria
- [ ] Workflow: the first clerk call is `claim <spec> <stamp>` (after the launch guards); every `open-round`, `record-seat`, `judge`, `close-story` command string contains `--stamp <stamp>`; `release <spec> <stamp>` is the last clerk call on every path (terminal `next`, any `stop`, a `BadLine`) - a `finally` around the loop.
- [ ] Driver scenarios: `claim` answering `{"ok":false,"exit":2,"error":"held by ..."}` ends the run with `{stop:{verb:'claim', exit:2, error}}` and no further clerk call; a green run's `calls` start with `claim` and end with `release`; a `stop` from a two-miss build is still followed by `release`; every gated verb's command carries `--stamp`.
- [ ] `/vulyk-build` step 1 runs `bash scripts/cycle.sh claim docs/specs/<slug> $stamp` after taking the stamp and stops, quoting the error, on refusal; every gated verb in the fallback loop's verb table carries `--stamp $stamp`; the loop's every exit runs `release`; step 4's wake-up text names `held by` as "another driver holds this spec; if it is dead, run the release command the error names".
- [ ] `/vulyk-review` claims with its own stamp at step 1, passes `--stamp` on `open-round`, `record-seat`, `judge`, releases at the end and on any refusal.
- [ ] `bash tests/driver.test.sh` passes; story 26 greps stay clean.

## Verification
`bash tests/driver.test.sh`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
