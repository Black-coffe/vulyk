# ADR-029: Gate split - per-part caps, one stepped suite per round, no suite-timeout escalation

- Status: accepted
- Date: 2026-11-02
- Spec: docs/specs/gate-split
- Amends: ADR-001 (D3/D4: the suite-timeout contract), ADR-023 (the whole suite runs once per round in `lead-review`),
  ADR-024 (the suite clause: the reviewer runs the suite in the foreground). Respects ADR-016 (constitution byte cap).

## Context
Spec `weekly-budget` round 2 ended ESCALATE with the suite at 904 s of a 905 s budget, after the budget had been raised
to 900. One long limit over the whole gate is a limit the run can always reach (card `test-gate-one-long-limit`).
The owner's order: split the tests into small gates with limits of 100, 200 or 300 s rather than run 20-30 minutes and hit a
limit again (verbatim in the spec's `brief.md`).

## Decision
Replace the one wall-clock budget by parts that each carry a hard cap of 300 s, grouped into steps that each fit one Bash
call; the suite runs once per council round through `cycle.sh suite`, before any seat is dispatched. The six points
settled by the triple cross-validation (crossgrill, three models, two rounds):
1. A cap per part (hard 300 s) and per step (one Bash call, under 600 s). 3/3.
2. The suite runs once per round before the seats, in steps; reviewers read the SHA-bound log and may rerun one part. 3/3.
3. A part at its cap is a FAIL of that part ("cut part X"), never a `suite-timeout` escalation. 3/3.
4. The growth check is red, not a warning: a part over 70% of its cap (210 s at 300) on contended time fails the gate. 3/3
   red; the threshold was 2/3.
5. The cap acts on contended time at the real `--jobs`; the cutting target is about 100 s alone. 3/3.
6. `close-story`/`stamp-red`: a cap per line, a repair story keeps only the lines covering its files, lines are
   deduplicated, and when the next line would not fit a call the verb stops with a resume mark (exit 7). 3/3.

Owner answers (2026-11-02, plan approval): CI uses the same 300 s caps on every OS; a missing tool reads SKIP (a failure in
CI); Windows part times come from the local round log, no Windows CI job. Hives may split their own full-suite row into
several `Full suite ... (round-only)` rows, each one part under 300 s; VULYK's own row is `Full suite steps (round-only)`,
and the word `steps` opts a row into the stepped protocol.

## Options
- Steps of at most `--jobs` parts (chosen): a step's wall is bounded by the part cap alone.
- Rejected: fill each step from a queue of up to `2 x jobs` parts to keep the 698 s wall. A step's wall is then bounded only
  by how the parts fall (two 300 s parts in one slot reach 600 s, the Bash call limit): the "one long limit the run can
  reach" the card forbids.
- Rejected: raise the budget again (the card forbids it; cut the work first).

## Consequences
`VULYK_SUITE_TIMEOUT` no longer bounds any run and exit 124 is never returned; nothing reads it (post-045-tails,
2026-11-03): `judge` reads an old reviewer's `SUITE: TIMEOUT <N>s` line as `SUITE: FAIL`, a repair, never a budget.
`suite-timeout` stays a readable reason for old rows and seat files. `VULYK_VERIFY_TIMEOUT` above 300 acts as 300, so a hive's story row over 300 s can no longer be
bypassed; a hive cuts any row over about 210 s into `--part` rows before taking this release. The round may take longer in
wall time than one 698 s run. `install.sh --upgrade` tells a hive; it never edits the hive's constitution.

## Revisit when
The first CI run measures macOS parts (a part red there is cut, never given a bigger cap), or a Windows CI job is planned.

## Amendment (2026-11-08) - spec `ab-run-fixes`, story 03
`suite --commit` commits `council/round-N/suite.log` once, on the call that returns `done:true`; earlier steps leave the
log written and uncommitted (paperwork, so the round stays fresh and the next call resumes from it). Steps, parts and
caps are unchanged.
