# ADR-025: A critical story closes only with a red receipt (`cycle.sh stamp-red`)

- Status: accepted (2026-10-28, owner: Andrei, approved with the plan, «Одобряешь - ДА»)
- Date: 2026-10-28
- Spec: docs/specs/red-receipt (story 03 records it; stories 01 and 02 built it)

## Context
A verify-gap is static: the planner names a test that would fail if the logic broke, but nothing records that the
test was ever red. A test and its code land in one wave, so a worker can write both before any run, and the
council saw green tests on broken code twice (anomaly-telemetry, round 1). The owner asked for a receipt that the
test was red, for the declared reason, before the code existed.

## Options
1. **Red mark by the planner's critical list, `stamp-red` writes a sealed receipt (chosen, D1-D3, D5-D6).**
2. H2 FAIL_TO_PASS worktree - declined. `close-story` would re-run the test on a temporary copy at HEAD. A fresh
   worktree has no `node_modules`, `.venv` or other untracked dependencies, so the test fails for the wrong reason
   and passes as red. It also doubles the time of critical stories inside the same 540 s budget.
3. A `red_waived:` field - rejected. It would be a second bypass beside the planner's not marking a story, and the
   owner needed one visible bypass, not two.
4. Git-history detection - rejected. A worker commits nothing before `close-story`, so there is no commit at which
   the test exists without the code. The gate would trust the very ordering it is meant to check.
5. Mutation testing (Stryker, mutmut) - rejected. It needs a tool per stack and is not "0 tokens in a second".
6. A script check banning mocks of unwritten logic - rejected. It is fragile and not checkable by a script; it stays
   a worker prompt rule (D6).

## Decision
- **D1 - the mark.** The planner marks a story `red: required` when it is on the critical list (branch, loop, parser,
  money, security, data write - the list `/vulyk-plan` step 6 carries). Absent, or any other value, means unmarked
  (today's behaviour). `wave-check` reports a `red:` value other than `required` as `red-value: <story> <value>`, so a
  typo does not pass as unmarked.
- **D2 - the reason and the verb.** The story carries `red_reason: <text>`, the expected failure text, a fixed string
  matched with `grep -F`. `cycle.sh stamp-red <story-file> [--stamp <S>]` runs the story's `## Verification` lines
  under the same runner and the same 540 s budget as close-story, with the same guards (`pause_guard`, `driver_guard`,
  `branch_guard`). It refuses, exit 4 with nothing written:
  - `story is not red: required`
  - `red_reason is empty`
  - `no test to seal: ## Verification names no path under ## Files`
  - `nothing to turn green: ## Files holds only sealed tests`
  - `not red: every verification line exits 0`
  - `not red: <segment> exits <126|127> (launch failure)`
  - `not red: timed out after <N>s`
  - `red for another reason: red_reason not in the output of <segment>`

  A 126 or 127 on any line refuses even when another line carries the text. Exit 2 (precondition): `no sha256 tool`,
  `scripts/redact.sh missing`; a `round-only` row keeps close-story's existing message, `verification is round-only:
  <segment>`. On success it writes `red_verified_at: <UTC ISO 8601> <sha256>` (the sealed-tests hash), replaces any
  earlier `## Red receipt` section with a new one (command, exit, tests hash with its paths, impl hash, stamped time,
  and the last 10 output lines of the segment piped through `scripts/redact.sh`), and prints one JSON line. It commits
  nothing: the receipt rides close-story's commit of the story file.
- **D3 - the close-story gate.** For a marked story, after the scope check and before verification, close-story
  refuses with exit 4:
  - `no red receipt: run cycle.sh stamp-red <story> after writing the failing test` - `red_verified_at` or the
    `## Red receipt` section is missing;
  - `test changed after red receipt: re-run stamp-red` - the sealed-tests hash now differs from the stamped one;
  - `no implementation change since red receipt` - the implementation-set hash equals the receipt's `impl:`.

  An unmarked story runs no new code path; a stray `red_verified_at` on it is ignored.
- **D4 - repair inherits the mark.** `cycle.sh repair` writes `red: required` and an empty `red_reason:` into the
  repair story when any story it unions is marked. With no marked story the frontmatter is unchanged.
- **D5 - wave-check.** `red-no-test: <story>` for a marked story whose sealed set is empty; `red-value: <story> <value>`
  for a `red:` value other than `required`. Report-only, exit 0, like `verify-gap`.
- **D6 - prompts and the two prohibitions.** Worker, planner and solo-build prompts, `lead-review` and the story
  template teach one order for a marked story: 1 write the test named in `## Files` (only that test, no mock of logic
  not yet written); 2 write `red_reason:`; 3 `bash scripts/cycle.sh stamp-red <story>`; 4 implement; 5 `close-story`.
  Two prohibitions: no implementation edit before the receipt, and never an edit made to produce a red. `lead-review`
  reads the receipt's output tail of every marked story in the diff.

## Named bypasses (card `safeguard-bypassable-or-late`)
- **The planner does not mark a story.** It is the designed bypass, and it is visible: `red: required` is absent from
  the story index in plan.md, which the owner reads at approval.
- **Break the code, stamp, restore it.** A worker can make the code fail for a minute, stamp the red, and restore the
  code. The worker prompts forbid it (D6), and `lead-review` reads the receipt's output tail: a staged break (an error
  inside the implementation) reads differently from the missing behaviour. No script closes it; the implementation-hash
  check closes only the neighbouring hole, a green with no code change.
- **The Queen's solo discipline.** At Tier 1-2 the Queen follows the same order, with no driver to enforce it. The gate
  is the same `close-story`; nothing beyond its refusals enforces the order on her.
- **The bootstrap exception for the verb's own story.** `stamp-red` had to exist before any story could be stamped, so
  story 01 built the `red` test part first, implemented only the verb, stamped its own story (its tail shows `no red
  receipt`), and only then built the gate, the repair inheritance and the wave-check report. The exception is recorded
  here and never recurs.

## Consequences
- A stamp costs one verification run: zero tokens, but not zero seconds ("за секунду" is tokens, not wall time).
- A test edited after green cannot be re-stamped by a worker, because workers never stash or check out. The worker
  returns `NEEDS_CONTEXT` naming the edit. The Queen, after `/vulyk-pause`, re-stamps against the baseline by hand
  (stash the implementation files only, `stamp-red`, pop) or sends the story back. This is the escape; there is no
  waiver field.
- Stories that already exist in every hive are unmarked and close exactly as before. Only stories the planner marks
  from now on carry the gate.

## Invariants created
- A story marked `red: required` closes only with a receipt whose sealed-tests hash still matches and whose
  implementation hash has changed since.
- A marker absent or unknown never runs the gate: the planner's omission is the single designed bypass and it is
  visible in plan.md.

## Revisit when
A second bypass is asked for (a waiver of any kind); the Queen's manual re-stamp turns out to be frequent enough to
need a script; or a hive shows a false red that the reason text cannot tell apart from the real failure.
