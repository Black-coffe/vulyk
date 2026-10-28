# Red-to-Green receipt for critical stories (plan)

**Tier:** 3 · **Spec slug:** `red-receipt` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-001 (cycle verbs, exit codes, one JSON line), ADR-011 (close-story exit 2 = not fixable by the worker), ADR-013 D4 (`cycle.sh repair` writes the repair story, no planner), ADR-015 (Sonnet executes, Opus judges), Law 2 (smallest change), Law 6 (a branch names the test that fails), defect card `safeguard-bypassable-or-late` (a missing input is a refusal, never a pass; every bypass named), [horizon.md](horizon.md) H1 adopted / H2 declined
**Depends on:** main at c341a75 (0.39.1): `cmd_close_story` (cycle.sh:1932-2190, `verify_of` :1884), `cmd_repair` (:2848), `wave-check.sh` verify-gap tokeniser (:188-217), `lib.sh` `command_cell_exists` / `command_cell_round_only`, `tests/cycle.test.sh --part` (7 parts)

## Goal
A story the planner marks `red: required` (branch, loop, parser, money, security, data write - the list `/vulyk-plan`
step 6 already carries) cannot close until the hive has a receipt that its test was red for the declared reason
before the code existed. The builder writes the test, writes the expected failure text into `red_reason:`, runs
`cycle.sh stamp-red <story>`: the verb runs the story's `## Verification` exactly as close-story does, accepts the
red only when a line fails with that text in its output and the failure is not a launch error, and writes
`red_verified_at:` (timestamp + sha256 of the sealed test files) plus a `## Red receipt` section (command, exit, the
redacted output tail, a hash of the implementation files). `close-story` on a marked story refuses without the
receipt, when the sealed tests changed after it, or when no implementation file changed since it. A repair story
inherits the mark from any RED story it unions. `wave-check` reports a marked story whose verification names no test
under its `## Files`. Worker, planner, solo-build prompts and the story template teach the order
test -> `red_reason` -> `stamp-red` -> code -> `close-story`, and forbid mocks of unwritten logic and breaking the
code to get a red. No new agent, no driver change, no CLAUDE.md change. Unmarked stories - every story in every hive
today - close exactly as before.

## Assumptions
- **Marker absent = today's behaviour**, in VULYK and in every hive. `red: required` is the only recognised value;
  the planner's omission is the designed bypass and is visible in plan.md's story index. A `red:` key with any other
  value is reported by wave-check (`red-value`) rather than silently unmarked (card: a typo must not pass as a waiver).
- **«за секунду»** holds for tokens (zero), not for wall time: `stamp-red` runs the same `## Verification` lines under
  the same 540 s budget as close-story, so a stamp costs one verification run. For this spec's own story 01 that is
  the whole `bash tests/cycle.test.sh` (~200 s): CLAUDE.md is at its size cap and gets no `Cycle part` row.
- **The residual bypass is named, not closed by a script:** a worker can break the implementation, stamp, and restore
  it. The worker prompts forbid it, ADR-025 names it, and `lead-review` reads the receipt's output tail of every
  marked story in the diff (a staged break reads differently from a missing feature). The implementation-hash check
  closes the neighbouring hole (a green with no code change) but not this one.
- **A re-stamp needs a red.** A test edited after the stamp while the implementation is already green cannot be
  re-stamped by the worker (workers never stash/checkout). The worker returns `NEEDS_CONTEXT` naming the edit; the
  Queen, after `/vulyk-pause`, re-stamps against the baseline by hand (stash the implementation files only,
  `stamp-red`, pop) or sends the story back. No waiver field exists (horizon depth P3, rejected): the owner is asked
  to confirm this escape rather than a `red_waived:` key.
- **Bootstrap exception for story 01 (dogfood):** the verb must exist before any story can be stamped, so story 01's
  builder writes the whole `red` test part first, implements only the `stamp-red` verb, stamps its own story (the
  close-story gate assertions fail with `no red receipt` in the output), then builds the gate, the repair
  inheritance and the wave-check report. ADR-025 records the exception; it never recurs.
- **Sealed tests are literal path tokens** of `## Verification` lines that are listed in (or match a glob of)
  `## Files`; a quoted glob such as `'*.sh'` in the Shell row is never sealed. A marked story whose verification names
  no such path, or whose `## Files` holds nothing but sealed tests, is refused at stamp time (nothing to seal /
  nothing to turn green) - earlier than the close-story gate would catch it.
- **The solo path is the same gate, not a different one:** the Queen at Tier 1-2 follows the same order (vulyk-build
  solo step); nothing beyond `close-story`'s refusals enforces it on her.
- Decision 6's second check (a marked story whose worker is `worker-test` with a later code sibling) is not built:
  it needs cross-story reasoning in wave-check for a case ask 5 already forbids at plan time. `red-no-test` plus the
  planner rule cover it.
- Hash tool: `sha256sum`, else `shasum -a 256`; neither present = `stamp-red` exit 2 (precondition), never a stamp
  without a hash. `scripts/redact.sh` missing = exit 2, never an unredacted tail.
- Live hives receive `cycle.sh`, `wave-check.sh`, prompts and template through `/vulyk-update` at ship (framework-owned
  trees); the Queen upgrades the hives then (owner rule: a fix reaches live hives), not a story here.
- No telemetry code, no driver change (`vulyk-cycle.js` never parses close-story exit codes; the worker prompt does),
  no `cycle-clerk` verb change (workers run `stamp-red` themselves, as they run `close-story`).
- Known wave-check noise, accepted: `verify-gap` on stories 02 and 03 (prose files have no test of their own);
  `verify-cell` for nothing (all cells exist today).
- Recon questions for `drone-scout` (none blocks approval; each names the story it feeds):
  - Q1 (story 01): which tests exercise `scripts/wave-check.sh` (symbol-map: `tests textual 2`), and in which file a
    `red-no-test` case belongs; if it is not `tests/cycle.test.sh`, that file joins story 01's `## Files` before dispatch.
  - Q2 (story 02): which tests mention `templates/story.md` (`tests textual 8`) and whether any copies it as a fixture
    or parses its frontmatter keys - a commented `# red:` line must change no fixture.
  - Q3 (story 01): among `cycle.sh`'s 15 textual importers, does any script read story frontmatter with a closed key
    list (`state.sh`, `scope-check.sh`, `trace-check.sh`) that would reject `red`, `red_reason`, `red_verified_at`.
  - Q4 (story 01): whether `tests/solo.test.sh` or `tests/e2e.test.sh` closes a template-built story end to end
    (the regression check that an unmarked story still closes).
  - Q5 (story 02): whether `tests/maintenance.test.sh` caps anything beyond `description:` bytes in agent and command
    files (the prompt bodies grow by a paragraph each).
  - Answered by the Queen's grep, 2026-10-28, no scout dispatched: Q1 - only `tests/cycle.test.sh` and
    `tests/council.test.sh` run wave-check; the `red-no-test` case goes in cycle.test.sh, Files unchanged. Q2 -
    `tests/cycle.test.sh:551` builds a story from the template and reads `status --json`, `tests/telemetry.test.sh:871`
    copies it into a fixture hive; commented `# red:` lines change neither, so the template keeps them commented.
    Q3 - no script in `scripts/` or `.claude/hooks/` validates frontmatter against a closed key list. Q4 - neither
    solo nor e2e builds a story from the template. Q5 - maintenance caps only CLAUDE.md size and the summed
    `description:` bytes; prompt bodies are not capped.

## Stories

**Wave 1**
- `red-receipt-01-stamp-red-verb` — `cycle.sh stamp-red`, the close-story gate, `repair` inherits the mark,
  `wave-check` `red-no-test` / `red-value`, the `red` part of `tests/cycle.test.sh`. worker-code. `red: required`
  itself (dogfood, bootstrap exception above). Asks 1, 2, 6, 7.

**Wave 2** (parallel; `## Files` disjoint; both blocked by 01)
- `red-receipt-02-prompts-and-template` — worker-code / worker-test order of work and exit-4 handling; queen-planner
  and `/vulyk-plan` step 6 mark rule; `/vulyk-build` solo step; `lead-review` reads the receipt tail;
  `templates/story.md` fields and section. worker-code. Asks 2, 3, 5.
- `red-receipt-03-docs` — ADR-025, `docs/cycle.md`, `docs/command-reference.md`, CHANGELOG `## [Unreleased]`.
  worker-code, `model: haiku`. Asks 1, 4, 7.

## Contracts
- **Story frontmatter (story 01 reads/writes; 02 documents; `repair` writes).** `red: required` - the mark; absent or
  any other value = unmarked (wave-check reports a value other than `required` as `red-value: <story> <value>`).
  `red_reason: <text>` - the expected failure text, a fixed string (no regex), matched with `grep -F` against the
  combined stdout+stderr of one failing verification line; empty after trim = refusal. `red_verified_at: <UTC ISO
  8601> <sha256>` - written only by `stamp-red`; the hash is the sealed-tests hash. The template shows the three as
  commented lines (`# red: required ...`), so a story built from it is unmarked. A repair story inherits `red:
  required` and an empty `red_reason:` line when any story it unions carries the mark.
- **Sealed tests and implementation set (story 01; `stamp-red`, `close-story`, `wave-check` share one helper in
  `lib.sh`, lifted from wave-check.sh:188-217).** Sealed = every literal path token (quotes stripped, no glob
  characters) of a `## Verification` line that equals a `## Files` entry or matches a `## Files` glob, sorted,
  deduplicated. Implementation set = `## Files` expanded the way close-story's commit step expands it today, minus
  the sealed paths, minus the story file. Hash of a set = `sha256sum` (else `shasum -a 256`) of each file in order,
  the listing hashed once more, 64 hex chars; a missing file contributes the literal `missing <path>`.
- **`cycle.sh stamp-red <story-file> [--stamp <S>]` (story 01; workers, the Queen and story 02's prompts call it).**
  Guards as close-story: `pause_guard`, `driver_guard` with `--stamp`, `branch_guard`; no `returned:` requirement.
  Each `## Verification` segment must be a `## Commands` cell (close-story's existing check and messages, reused:
  exit 2, `verification is round-only: <segment>` unchanged). Runs the lines once under `timeout
  ${VULYK_VERIFY_TIMEOUT:-540}`, the same runner as close-story (factored into one function, not copied). Exit 4,
  nothing written, messages literal: `story is not red: required` · `red_reason is empty` · `no test to seal:
  ## Verification names no path under ## Files` · `nothing to turn green: ## Files holds only sealed tests` · `not
  red: every verification line exits 0` · `not red: <segment> exits <126|127> (launch failure)` · `not red: timed out
  after <N>s` · `red for another reason: red_reason not in the output of <segment>`. A 126/127 on any line refuses
  even when another line carries the text. Exit 2: `no sha256 tool`, `scripts/redact.sh missing`. Success (exit 0):
  rewrites `red_verified_at:` (added after `red_reason:` when absent), deletes an existing `## Red receipt` block
  (heading to the next `## ` heading or EOF) and appends at EOF:
  `## Red receipt` / `- command: <segment>` / `- exit: <n>` / `- tests: <sha256> (<path>, <path>)` / `- impl: <sha256>`
  / `- stamped: <ts>` / a fenced block of the last <= 10 output lines of that segment piped through
  `bash scripts/redact.sh`. Last stdout line `{"ok":true,"verb":"stamp-red","story":"<file>","exit":<n>,"tests":
  "<sha256>","impl":"<sha256>"}`; refusals `emit false stamp-red <code> error "<msg>"` like every verb. Re-stamping
  overwrites both. Commits nothing (the receipt rides close-story's commit of the story file).
- **`close-story` gate (story 01; prompts in 02 handle the messages).** For a marked story, after the scope check and
  before running verification, exit 4 with: `no red receipt: run cycle.sh stamp-red <story> after writing the failing
  test` when `red_verified_at` or the `## Red receipt` section is missing; `test changed after red receipt: re-run
  stamp-red` when the sealed-tests hash recomputed now differs from `red_verified_at`'s; `no implementation change
  since red receipt` when the implementation-set hash equals the receipt's `impl:`. Unmarked stories: no new code
  path runs; a stray `red_verified_at` on an unmarked story is ignored.
- **`wave-check.sh` (story 01).** New report lines, same shape as `verify-gap`: `red-no-test: <story>` for a marked
  story whose sealed set is empty; `red-value: <story> <value>` for `red:` not equal to `required`. Report-only, exit 0,
  as today.
- **`cmd_repair` (story 01).** The frontmatter printf gains `red: required` and `red_reason:` (empty) when any
  unioned story has `red: required`; otherwise the printf is byte-identical to today's.
- **Prompt order (story 02 writes; 03 cites).** For a `red: required` story: 1 write the test file named in `## Files`
  (and only that test; no mock of logic the story has not written yet); 2 write `red_reason:` (the assertion text the
  test prints on failure); 3 `bash scripts/cycle.sh stamp-red <story> [--stamp <S>]`; 4 implement; 5 `close-story`.
  No implementation edit before step 3; never edit the implementation to produce a red. Exit-4 handling: a
  `stamp-red` refusal = fix the test or the reason text and rerun (a 126/127 is a broken test launch, not a feature
  gap); `no red receipt` = go to step 3; `test changed after red receipt` with no implementation yet = re-stamp; with
  the implementation already green = `NEEDS_CONTEXT` naming the test edit (never stash); `no implementation change
  since red receipt` = the story's code is still missing. Planner rule (queen-planner, `/vulyk-plan` step 6): the
  critical list marks `red: required`; the test file is in that story's `## Files` and its path appears in
  `## Verification` (so it is sealed); `red_reason` prefilled when the assertion is known; no `worker-test` story in
  a later wave for a marked story. `lead-review`: for every marked story in the diff, read its `## Red receipt` tail
  and the `red_reason`; a tail that shows a staged break (an error inside the implementation rather than the missing
  behaviour) is a major finding `[ask N]` naming the story.

## Rejected
- **Reading red from git history inside `close-story`** (the request's own alternative «проверять это в close-story по
  истории git»): a worker commits nothing before `close-story`, so there is no commit at which the test exists without
  the code; the gate would be trusting the ordering it is meant to check. A stamp written at the moment the test is
  red, with the test sealed by hash, is the only artifact that proves the order.
- H2 (owner declined): `close-story` re-running the test on a base worktree - a fresh worktree lacks `node_modules`,
  `.venv`, and fails for the wrong reason, which stamp-red's reason check would then accept as red.
- A `red_waived:` field: a second bypass beside the planner's; the escape is `NEEDS_CONTEXT` to the Queen.

## Integration gate
`bash tests/full-suite.sh`

## Descoped

*(empty)*

## Plan deltas

- 2026-10-28, planner, before approval: decision 7's prompt list gains `.claude/agents/lead-review.md` (story 02).
  Reason: decision 4 names the reviewer as the reader of the receipt's output tail against the break-the-code bypass;
  without a line in its prompt no one reads it. Rejected: leaving it to the reviewer's general correctness pass (the
  receipt is a story-file section, outside the diff ranges the reviewer is told to read).
- 2026-10-28, planner, before approval: decision 6 gains `red-value` (a `red:` key with a value other than
  `required`), one grep in the same wave-check block, because a typo must not read as "unmarked" (card
  `safeguard-bypassable-or-late`). Decision 6's worker-test sibling check is not built (see `## Assumptions`).

<!--
The lines below are the cycle's confirmation markers (docs/cycle.md); each placeholder is replaced by
the command or script that owns it, and scripts/ship-check.sh reads them all. Approved is the owner's
word, the stop at Tier 2-4; Briefed is written by `cycle.sh briefed` instead, at Tier 1 ("via
mini-brief"), with `--go`, or in no-question mode ("assumed"). Either closes stage 02. Council and
Checked close stages 04+05 together: a GREEN council row is enough on its own, and Checked is the
owner's override in either direction, newest timestamp wins. No line of this comment may start with
a marker: the scripts read the first line that does.

There is no default tier: `cycle.sh open-round` refuses to open a round while the `**Tier:**` line above
is missing or unparsable.
-->
**Approved:** Andrei, 2026-10-28 («Одобряешь - ДА»)
**Briefed:** <written by scripts/cycle.sh briefed - stage 01+02 on the straight-through path (--go, Tier 1): "via grill, <owner>, <date>" (or "via grill (assumed)" / "via mini-brief"). Alternative to **Approved:** above.>
**Branch:** vulyk/red-receipt
**Checked:** <written by scripts/human-check.sh after the owner has looked - stage 05, and the override for stage 04+05. /vulyk-ship refuses without either this or a GREEN **Council:** line.>
**Council:** GREEN round 1, 2026-10-28, at 0353e48, pack d0e2cbf3d988
**Shipped:** 0.40.0, 2026-10-28, at e56b2d8 - merged to main, publish pending
