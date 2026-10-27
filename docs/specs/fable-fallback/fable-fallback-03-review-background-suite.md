---
story: fable-fallback-03
spec: fable-fallback
status: todo
returned:
tier: 3
worker: worker-code
model: opus
wave: 2
blocked_by: [fable-fallback-02]
---

# lead-review starts the suite in the background and reads the diff while it runs (probe first)

## Goal
After this story `lead-review` no longer sits idle for 5-13 minutes while `tests/full-suite.sh` runs (the study's F3: 31% of its cache writes are full rewrites after that wait). It starts the suite first, in the background, reviews the diff while it runs, and writes the `SUITE:` line only once the result is in. But the change is made only if a probe, run as this story's first step, shows the mechanism holds in a subagent; otherwise the story stops and changes nothing. `model: opus`: designing and reading the probe, and rewriting a reviewer protocol whose failure mode is a missing `SUITE:` line, is judgment work, not a well-scoped edit.

## Requirements
> 2. Ревьюер запускает тесты в фоне и смотрит дифф, пока они идут; если проба покажет, что фон в субагенте не работает, — скажу и предложу другое.

## Files
- .claude/agents/lead-review.md
- tests/telemetry.test.sh

## Non-goals
- **Stop rule (binding):** if the probe fails (below), edit nothing: write the measurement under `## Findings` (elapsed seconds, whether the marker file existed at return, the exact text the parent received, Claude Code version), set `returned: NEEDS_CONTEXT`, do not run `close-story`. The owner decides the alternative.
- Do not change `maxTurns`, `model`, `effort` or the `experimental:` block (story 02 wrote it); do not touch `.claude/workflows/vulyk-cycle.js` `CAPS`.
- Do not change the `SUITE:` line's grammar or meaning, `VULYK_SUITE_TIMEOUT`, the `timeout` wrapper, `record-seat` or `judge`; do not move the suite into the driver or `cycle.sh`.
- No polling loop that burns turns: at most one short wait step after the diff is read, as the contract below allows.
- The probe runs on `sonnet` (`--model sonnet` or `model: sonnet`), never on Fable; it writes only under the scratchpad.

## Map slice
- memory/map/agents-and-commands.md `## Agents` the `lead-review` bullet (what it reads, the `SUITE:` line at lead-review.md:49-54, 82, 94)
- memory/map/cycle.md `## Verbs` the **Full-suite line (0.36)** paragraph (`record-seat` refuses a missing line; `judge` on FAIL/TIMEOUT)
- memory/map/scripts.md `## Tests (0.37.0)` (`full-suite.sh` output and exit codes)

## Acceptance criteria
- [ ] **Step 1, the probe.** A throwaway subagent, dispatched from a headless `claude -p --model sonnet` session in a scratchpad dir with a temp `.claude/agents/probe.md` (`worker-code` has no Agent tool: `.claude/agents/worker-code.md` `tools:`), runs `bash -c 'sleep 45; date -u > <scratch>/probe-done'` with `run_in_background: true`, then returns the single line `STARTED` and ends its turn. The parent records the wall time of the call and, right after the return, whether `<scratch>/probe-done` exists. **Pass:** the return arrives after the command ends (file present, elapsed >= 45 s), or the return carries the command's completion. **Fail:** the return arrives early with the file absent. Result (numbers, text seen, CC version) goes into `## Implementation notes` either way.
- [ ] On pass, `lead-review.md`'s suite step reads: start `timeout $((${VULYK_SUITE_TIMEOUT:-590}+5)) bash tests/full-suite.sh` in the background first, output to a file; read the diff and judge; then, if the result is not in yet, wait for the completion notification (one blocking wait at most); then write `SUITE: ok|FAIL|TIMEOUT <N>s budget <B>s|none` from the file and exit code (124 = TIMEOUT with the seconds it ran), exactly as the line is defined today, and never return before it.
- [ ] The step says what to do when the background command never reports (the budget plus a margin has passed): write `SUITE: TIMEOUT <N>s budget <B>s`, so `judge` escalates `suite-timeout` as today.
- [ ] If `tests/telemetry.test.sh` asserts on the suite-step lines of `lead-review.md` (recon), the assertion is updated to the new wording; the `SUITE:` contract case stays and passes.
- [ ] `bash scripts/cycle.sh record-seat` (the part that refuses a missing `SUITE:` line) is not touched and the existing tests for it pass.

## Verification
`bash tests/telemetry.test.sh --part telemetry && bash tests/maintenance.test.sh`

## Implementation notes

## Findings
