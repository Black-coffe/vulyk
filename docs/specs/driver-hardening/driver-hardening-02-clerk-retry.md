---
story: driver-hardening-02
spec: driver-hardening
status: done
returned: DONE
tier: 3
worker: worker-code
model: sonnet
tracer: false
wave: 1
blocked_by: []
---

# The driver re-asks the clerk once on a non-JSON last line (ask 1)

## Goal
`clerk()` in the Workflow driver, today the only parsing path for every verb, throws `BadLine` on the first unparsable last line and the whole run ends (the anomaly-telemetry launch died at `vulyk-cycle.js:78` on a dropped `]`). After this story a bad line is logged and the identical clerk prompt is dispatched a second time; a second bad line ends the run exactly as today. Two scenarios in the driver suite prove both branches and the dispatch count.

## Requirements
> Нечитаемая строка от клерка — драйвер повторяет вызов один раз, потом останавливается.

## Files
- .claude/workflows/vulyk-cycle.js
- tests/driver.test.sh

## Non-goals
- Do not change `.claude/agents/cycle-clerk.md` - the clerk still runs its one command once and never retries; the retry is a second dispatch by the driver.
- Do not add a retry for `ok:false`, exit 2, exit 4 or `Paused` - those parse fine and keep their handling.
- Do not restructure the loop, the `status` polls, or read any new field from a verb result - story 04 (wave 3) does that on top of this file.
- Do not touch `record-seat`'s MALFORMED re-ask or the two-miss `close-story` bound.
- Do not call `telemetry.sh`; no anomaly is recorded for a retry.
- Keep the file LF-only (`.gitattributes` pins it; the Workflow tool refuses CRLF).

## Map slice
`docs/specs/driver-hardening/recon/driver-and-clerk.md` §1 (the `clerk()` wrapper verbatim, `BadLine` at :54-56, the outer catch at :281-285) and "Test coverage"; plan.md `## Contracts` C1 and A4; `memory/map/cycle.md` "Drivers"; ADR-009 (the driver inspects nothing beyond emptiness - a parse failure is not a prose check).

## Acceptance criteria
- [ ] C1: with the `agent` stub answering a `cycle-clerk` prompt with `{"ok":true,...` (truncated) first and a valid JSON line second, the run proceeds past that step, the stub was called exactly twice for that prompt, and `log` received one line containing `retrying once` and the command text.
- [ ] Same stub answering two truncated lines: the run ends with the raw *second* line returned (today's `BadLine` shape), the stub was called exactly twice for that prompt, and no further clerk prompt was dispatched.
- [ ] A `Paused` result (`exit: 3`) on the second attempt is still thrown as `Paused`, not swallowed.
- [ ] Every existing `tests/driver.test.sh` scenario passes unchanged; the header comment at :12-13 / :70-71 says "re-asked once, then ends the run".

## Verification
`bash tests/driver.test.sh`

## Implementation notes
- `clerk()` now wraps the single-attempt logic in an inner `ask()`; on `BadLine` it logs `cycle-clerk: non-JSON last line, retrying once: ${cmd}` and calls `ask()` once more. A second `BadLine` (or any other error, including `Paused`) propagates unchanged - only one retry, never caught twice.
- Updated the two header comments (:16-18, :71-73 post-edit) to say the non-JSON case is "re-asked once, then ends the run".
- Added three `tests/driver.test.sh` scenarios (ad/ae/af) exercising C1: retry-then-succeed (via `claim`), two-bad-lines-stop (raw second line, exactly 2 calls, no further dispatch), and Paused-on-retry-not-swallowed (via `status`). Added matching `expect` lines.
- `scope-check.sh` flags `scripts/cycle.sh`, `scripts/lib.sh`, `tests/council.test.sh` as changed-but-undeclared - these were already dirty in the working tree before this story started (other stories' output), not touched here.

## Findings
