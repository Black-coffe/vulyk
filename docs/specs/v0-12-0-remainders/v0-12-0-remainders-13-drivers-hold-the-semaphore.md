---
story: v0-12-0-remainders-13
spec: v0-12-0-remainders
status: done
returned: DONE
tier: 4
worker: worker-code
tracer: false
wave: 9
blocked_by: [v0-12-0-remainders-11, v0-12-0-remainders-17, v0-12-0-remainders-09]
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
- `.claude/workflows/vulyk-cycle.js`: first clerk call is `claim <spec> <stamp>` (returns `{stop:{verb:'claim',...}}` on refusal, no further clerk call); `open-round`/`close-story`/`judge`/`record-seat` command templates now append `--stamp ${stamp}`; a `finally` around the try/catch calls `release <spec> <stamp>` whenever `claimed` is true, covering every exit (terminal `next`, `Stop`, `BadLine`, `Paused`).
- `tests/driver.test.sh`: added a `withClaim()` helper that brackets every scenario's clerk queue with claim/release stub entries (kept scenarios (a)/(h) - the pre-claim launch guards - unwrapped); added scenario (t) for a refused claim, a static regex check that all four gated verbs' templates carry `--stamp ${stamp}`, and inline assertions on individual scenarios that close-story/open-round/record-seat commands carry `--stamp` and that release still runs after a two-miss stop.
- `.claude/commands/vulyk-build.md` step 1: claims right after taking `$stamp`, stops on refusal without dispatching either driver; fallback loop's four gated verbs (`close-story`, `open-round`, `record-seat`, `judge`) now pass `--stamp $stamp`; every loop exit (an `ok:false` stop, `briefed`, `shipped`, the three step-3 terminals, the second-miss block-and-stop) releases the semaphore; step 4's wake-up names `stop.verb === 'claim'` and points at the release command the error names.
- `.claude/commands/vulyk-review.md`: step 1 now takes the stamp and claims before the precondition check (release on refusal or ceiling exit 6); `open-round`, `record-seat`, `judge` carry `--stamp $stamp`; step 5 releases unconditionally right after `judge`, before reading `next`.
- Verification: `bash tests/driver.test.sh` - 31 checks green, exit 0 (run twice, both green). `bash scripts/scope-check.sh` on this story confirms the 4 declared files are exactly what changed (the two extra files scope-check flags - `journal.md`, a learnings file - predate this story, per the session's initial git status).

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
