# ADR-039: The owner's check record is committed by human-check.sh, the guard keeps a strict text rule

- Status: accepted (2026-11-15, owner: Andrei, «Принять все 15 (Рекомендую)»)
- Date: 2026-11-15
- Spec: docs/specs/owner-guard-commit-fp

## Context
`owner-guard.sh` (PreToolUse) refused the legitimate commit of a check that `human-check.sh` had just recorded:
any shell command naming `memory/stats/human.jsonl` beside ACCEPTED or REJECTED counted as a forged row. The spec
first tried to tell a real write from a harmless mention by reading the command text. The plan's deltas, verbatim:

> 2026-11-14/15, after the round-1 BLOCK and four automated security scans: the detect-a-write rule missed write
> forms, so the rule is deny by default with a short safe-form list. Regex parsing of heredoc bodies kept opening
> parser gaps, so any heredoc or here-string in a command naming the record counts as a write: ask 1's "text that
> only names the path passes" holds for echo, printf and commit messages, not for heredocs (that text goes through
> the Write tool). The owner chose a review-only re-check of the diff, then his acceptance.

> 2026-11-15, review-only re-check at 56ec89b7: BLOCK (.vulyk/reports/owner-guard-commit-fp/recheck/review.md):
> the allowlist still refused real commits (multi-line messages with a trailer, `2>&1`, `|| true`, quoted `>`) and
> let some writes through; details (moved to a private file before publishing).
> Shell-text parsing does not converge. Owner decision (option label, the agent's wording; cross-checked with
> Fable): «Строгое правило + коммит внутри скрипта (Рекомендую)». Next, in a fresh session:
> 1. `owner-guard.sh`: restore the record rule of bc962e77 (a command naming the record and holding a verdict
>    word is a write); keep `writes_record`'s found bypasses as deny fixtures in `tests/defects.test.sh`.
> 2. `scripts/human-check.sh --commit`: the script commits its own `plan.md` line and record row with
>    `git commit -- <those paths>` only, so no agent command ever names the record with a verdict word.
> 3. Callers (`/vulyk-build`, `/vulyk-ship`, docs) use `--commit`; the brief's ask 1 is rewritten to this
>    design with the owner's words; integrity of a row is checked where it is read, in a later spec.

## Options
1. Deny by default with a short safe-form list, parsing heredocs and redirects to tell a write from a mention -
   rejected: across a BLOCK, four security scans and a re-check it kept refusing real commits and letting some
   writes through ("Shell-text parsing does not converge").
2. Strict text rule plus the commit inside the script - chosen (the owner's pick, option label in the agent's
   wording: «Строгое правило + коммит внутри скрипта (Рекомендую)»).

## Decision
The guard keeps the strict rule: a shell command naming the record beside a verdict word is a record write, a
`git add` / `git commit` of it included. Recording and committing a human check is one step,
`scripts/human-check.sh <spec> <verdict> "<note>" --commit`, which commits only its own `plan.md` line and record
row (`git commit -- <those paths>`) and refuses when either file already holds an uncommitted change. Deciding
factor: the text parser did not converge; moving the commit into the script removes the need for any agent
command to name the record beside a verdict.

## Consequences
- Callers (`/vulyk-build`, `/vulyk-ship`, docs) commit a check only through `--commit`.
- The bypasses found while the parser existed stay as deny fixtures in `tests/defects.test.sh`.
- Integrity of a row is to be checked where the row is read, in a later spec (not yet written).
- The PreToolUse guards read command text: they are a seatbelt against an agent's ordinary slips, not a complete
  barrier.
- Other consequences: not recorded.

## Invariants created
- No agent command names `memory/stats/human.jsonl` beside ACCEPTED or REJECTED; the record and its `plan.md`
  line are written and committed only by `human-check.sh --commit`.
- `human-check.sh --commit` stages and commits only its own two paths, never a spec folder or the whole tree, and
  refuses over an uncommitted change in either.
- Owner-guard does not grow a shell-text parser that tries to tell a record write from a mention.

## Revisit when
Not recorded.
