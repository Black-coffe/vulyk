---
story: fast-verification-06
spec: fast-verification
status: done
returned: DONE
tier: 3
worker: worker-code
wave: 3
blocked_by: [fast-verification-02, fast-verification-03, fast-verification-04]
---

# A failed suite is an anchored BLOCK, an over-budget suite escalates `suite-timeout`

## Goal
`lead-review` runs the `Full suite / build` row once per round under the one budget and reports the result on a
`SUITE:` line; a failed test is a BLOCK anchored `[regression]` and goes to repair; a run over budget makes `judge`
write an ESCALATE row with the new reason `suite-timeout` and the seconds in `## Needs a human`. `escalate`,
`reopen` and `status` know the reason; ADR-001 records it with a dated amendment. Neither outcome is ever GREEN.

## Requirements
> 3. Упавший тест полного набора блокирует раунд; неуложившийся набор останавливает раунд и спрашивает тебя с цифрой времени; зелёным ни то, ни другое не считается.
> 2. Полный набор запускается одним скриптом, все наборы разом, и проходит целиком внутри 9 минут; ревьюер запускает его один раз на раунд.

## Files
- .claude/agents/lead-review.md
- scripts/cycle.sh
- docs/adr/001-cycle-state-contract.md
- .claude/commands/vulyk-build.md
- tests/council.test.sh

## Non-goals
- Do not touch `lead-review.md`'s `description:` line, the card-hook paragraph or the four judged items; only the
  suite rule (`:49-52`) and the report layout (`:72-97`).
- Do not change `cmd_escalate`'s missing-seat precondition, the `env` row, the anchored-BLOCK rule or the drivers
  (`vulyk-cycle.js`, `vulyk-build.md` beyond the `:91` wording): both stop on `next: escalated` already.
- Do not validate the `[regression]` tag or add a base-branch re-run to the reviewer.
- Do not edit `tests/full-suite.sh`, `CLAUDE.md`, `docs/cycle.md` or the command reference.

## Map slice
memory/map/cycle.md `## Seats by tier and the verdict`, `## Staleness, PAUSE, seat reports`, `## Verbs`
(`reopen`, `escalate`); memory/map/agents-and-commands.md `## Agents` (lead-review); scout-plumbing.md
`## Contracts`, `## Gotchas` (the ESCALATE seam), `## Test sites`; plan.md `## Contracts` `Review report`.

## Acceptance criteria
- [ ] `lead-review.md`: runs the row once as `timeout $((${VULYK_SUITE_TIMEOUT:-540} + 30)) <row>` under Bash
      `timeout: 600000`, measures seconds, writes line 3 `SUITE: ok|FAIL|TIMEOUT <N>s [budget <B>s]|none` per the
      contract; FAIL = `VERDICT: BLOCK` with a `## Critical` `[regression]` line naming the suite line and the failing
      check (red on the base too is still BLOCK); TIMEOUT = the line plus the verdict the code earns. The sentence
      "A suite that times out is a minor, never a BLOCK" is gone.
- [ ] `cycle.sh judge`: a stored review with a body line `^SUITE: TIMEOUT ([0-9]+)s` -> ESCALATE, exit 6,
      `escalate:"suite-timeout"`, `note` "full suite timed out: <N>s, budget <B>s" (through `redact_note`),
      `**Council:** ESCALATE`, `## Needs a human` with the reason, suite and seats lines of the contract; ranked
      after `REJECTED`, before `env`; `record-seat` accepts the line on a PASS and still demands a tagged line on a
      BLOCK.
- [ ] `escalate --reason suite-timeout` is accepted by the usage check; `reopen` after a `suite-timeout` row emits
      `next: open-round`; `status` never answers `repair` for a reopened `suite-timeout` round.
- [ ] `vulyk-build.md` `:91`: the `## Needs a human` print names the new reason's suite line.
- [ ] ADR-001: D1 `## Needs a human` and ledger `escalate` values (`:141`, `:161`), D2 `escalate` usage (`:63`,
      `:204`) and `reopen` row (`:205`), D3 review contract (the `SUITE:` line), D4 table (new row after
      `REJECTED`), D6 (`reopen` exit for it) - each gains the reason, plus a dated amendment section in the file's
      existing style naming this spec, the decision and the rejected ranking.
- [ ] `tests/council.test.sh` part `escalate`: (1) review PASS + `SUITE: TIMEOUT 571s budget 540s` -> judge exit 6,
      row `escalate` = `suite-timeout`, note and `## Needs a human` carry `571` - the test that fails when the
      branch breaks; (2) review BLOCK anchored `[regression]` + `SUITE: FAIL 300s` -> RED, `next: repair` (a failure
      never escalates); (3) `reopen` after (1) -> `next: open-round`; (4) `escalate --reason suite-timeout` passes
      usage.

## Verification
`bash tests/council.test.sh --part escalate`

## Implementation notes
- scripts/cycle.sh: `judge` reads the first `^SUITE: TIMEOUT <N>s` body line of the stored review (budget from `budget <B>s`, else `${VULYK_SUITE_TIMEOUT:-540}`); new verdict row right after the REJECTED override -> ESCALATE `suite-timeout`, redacted note, `- suite:` line in `## Needs a human`.
- scripts/cycle.sh: `escalate --reason` admits `suite-timeout` (case + three usage strings); `reopen` and `status` treat it like `env` (open-round, never repair).
- record-seat needed no change: a PASS was already accepted regardless of body, a BLOCK still needs a tagged Critical/Major line.
- .claude/agents/lead-review.md: suite rule rewritten (runs the row once under `VULYK_SUITE_TIMEOUT + 30`, ok/FAIL/TIMEOUT/none mapping), `SUITE:` as report line 3; the "minor, never a BLOCK" sentence removed.
- .claude/commands/vulyk-build.md: the `escalated` print names the `suite-timeout` `- suite:` line.
- docs/adr/001-cycle-state-contract.md: D1 (:141, :161), D2 (:63, :204, :205), D3, D4 row, D6 amended inline; dated 2026-10-26 amendment section with the rejected "rank it last" option. The file was already mixed CRLF/LF in the working tree; written back CRLF (text=auto normalises).
- tests/council.test.sh part escalate: four cases (timeout ESCALATE, FAIL+[regression] RED, reopen/status open-round, escalate --reason). Disabling the new judge branch turned case (1) red (checked).

## Findings
