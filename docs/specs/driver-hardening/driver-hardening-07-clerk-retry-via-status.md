---
story: driver-hardening-07
spec: driver-hardening
status: done
returned: DONE
tier: 3
worker: worker-code
model: opus
tracer: false
wave: 5
blocked_by: [driver-hardening-02, driver-hardening-04]
---

# Repair: a garbled relay of a mutating verb is recovered through `status`, never by re-running the verb

## Goal
Round 1 review Major 2 and the driver half of Minor 10. Story 02's retry re-dispatches the identical prompt, so a `close-story --commit`, `record-seat` or `judge --commit` that ran and only lost its relay line is run again and hits `already done` / `already recorded` (exit 2), which ends the run - the opposite of ask 1's intent. After this story `clerk()` recovers a garbled line from any of the five mutating verbs by dispatching `status <spec> --json` once and continuing from that status (story 03 made every verb carry the same object, so no information is lost); `status`, `claim` and `release` keep the identical re-dispatch. `carriedStatus()` also refuses an error envelope, so a verb line whose `status` is `{"ok":false,"verb":"status",...}` triggers a poll instead of an unrecognised-next stop.

## Requirements
> Нечитаемая строка от клерка — драйвер повторяет вызов один раз, потом останавливается.
> Меняющие глаголы cycle.sh возвращают next в своём JSON, драйвер опрашивает статус только на старте.

## Files
- .claude/workflows/vulyk-cycle.js
- tests/driver.test.sh

## Non-goals
- Do not add a third dispatch anywhere: at most two clerk dispatches per `clerk()` call, the second unparsable line still ends the run with that raw line.
- Do not teach the driver which `next` "proves" a verb took effect and re-run the verb on that basis - the loop re-derives from `status.next` as it already does (ADR-001: the driver holds no logic).
- Do not touch `cycle-clerk.md`, `cycle.sh`, `vulyk-build.md`; do not change the poll rule (C6), the MALFORMED re-ask, the two-miss bound, `Paused`, or the `CAPS` map.
- Do not handle a last line that parses to `null` or a number (opus UNASKED (b)) - descoped in plan.md, not this story.
- Keep the file LF-only.

## Map slice
`docs/specs/driver-hardening/recon/driver-and-clerk.md` §1 (`clerk()`, `BadLine`, the outer catch, the `res.ok` branches at :159/:212/:260); plan.md `## Contracts` C1 revised, C6 addendum, A9; `council/round-1/review.md` Major 2 and Minor 10; story 02 and story 04 `## Implementation notes` (`ask()` inner helper, `carriedStatus()`, `nextSt`); `memory/map/cycle.md` "Drivers".

## Acceptance criteria
- [ ] C1 revised, scenario per verb - `close-story`, `record-seat`, `judge`: the `agent` stub answers the verb's `cycle-clerk` prompt with a truncated line, then answers one `status <spec> --json` prompt with a valid status; the stub was called exactly twice for that step, the second prompt is the status prompt (the verb prompt is never re-sent), `log` received one line containing `asking status instead` and the command text, and the loop continues from that status (e.g. the judge scenario ends at `green`, the record-seat scenario proceeds to the post-dispatch poll, the close-story scenario neither counts a miss nor stops).
- [ ] Truncated verb line, then a truncated status line -> the run ends with the raw *second* line, exactly two dispatches, nothing further; a status line with `exit: 3` on the recovery -> `Paused`.
- [ ] `status` and `claim` keep story 02's behaviour: scenarios (ad)(ae)(af) pass unchanged.
- [ ] C6 addendum: a `judge` result `{ok:true,...,"status":{"ok":false,"verb":"status","exit":1,"next":"error",...}}` makes the next iteration poll `status`; the run does not stop with an unrecognised `next`.
- [ ] Every existing driver scenario passes; the header comment states the two-track rule in one sentence.

## Verification
`bash tests/driver.test.sh`

## Implementation notes
- `.claude/workflows/vulyk-cycle.js`: `clerk()`'s inner `ask()` now takes the command as an argument; a `BadLine` routes on the first token of `cmd` - a new `MUTATING` list (`branch`, `close-story`, `open-round`, `record-seat`, `judge`) asks `status ${spec} --json` once and returns `{ok:true, verb, exit:0, next: st.next, error:'', status: st, recovered:'status'}`; every other verb keeps story 02's identical re-dispatch. Still at most two dispatches per `clerk()` call; a second unparsable line throws `BadLine` with that line, an `exit:3` recovery throws `Paused`.
- `carriedStatus()` additionally requires `typeof res.status.next === 'string'` and no `ok` key, so cycle.sh's `{"ok":false,"verb":"status",...}` envelope makes the loop poll instead of falling through to the unrecognised-`next` return (C6 addendum / Minor 10 driver half).
- Verified against `scripts/cycle.sh` `cmd_claim:2075-2085` rather than assumed: a re-claim with the *same* stamp exits 0 (`already claimed by`), so A9's recon question is answered and `claim` correctly stays on the identical-re-dispatch track with `status` and `release`.
- `tests/driver.test.sh`: six scenarios (ak)-(ap) - judge, record-seat and close-story recoveries (each asserting the verb prompt is sent exactly once, the second prompt is the status prompt, the `asking status instead` log names the command, and the loop continues), the double-garble raw-second-line stop, an exit-3 recovery pausing, and the C6 error-envelope poll.
- Checked, not assumed: with only `vulyk-cycle.js` reverted to HEAD, each of the six new scenarios prints its own FAIL line (all six seen individually in one run) while every pre-existing scenario stays green.
- Not mine, already dirty before this story: `scripts/cycle.sh` (story 06's diff) shows in `git diff`.

## Findings
