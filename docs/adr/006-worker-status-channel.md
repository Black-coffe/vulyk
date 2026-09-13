# ADR-006: A worker's outcome travels in its story file, and `close-story` reads it there

- Status: proposed
- Date: 2026-09-13
- Spec: docs/specs/v0-12-0-remainders (ask 1, round-3 major 3)

## Context

Council round 3, major 3 (`docs/specs/autonomous-cycle/council/round-3/review.md`): the
Workflow driver at `.claude/workflows/vulyk-cycle.js:121-124` runs `close-story` on every
non-empty worker report. A worker that returns `STATUS: NEEDS_CONTEXT` or `STATUS: WALL`
(`.claude/agents/worker-code.md:26`) on a story whose `## Verification` is the literal
`none — reviewed by lead-review` therefore gets its story stamped `done` at `cycle.sh:1409`:
the verification runs nothing, and nothing else in `cmd_close_story` (`:1332-1435`) knows the
worker did not finish.

ADR-001 C11 forbids the fix that first comes to mind: the driver must not parse prose, so it
cannot grep the report for `STATUS:`. The fallback driver, `/vulyk-build` step 2 (row
`build:<wave>` at `.claude/commands/vulyk-build.md:57`), does read `STATUS: DONE` by eye and
counts `NEEDS_CONTEXT`/`WALL` as a miss under the same two-attempt bound as a red verification.
The two drivers therefore disagree today, and the constitution says a stage is closed by a
file on disk, never by a chat turn.

## Options

1. **`schema` on the worker `agent()` call**, so the report arrives as
   `{status: "DONE|NEEDS_CONTEXT|WALL", summary}` and the driver branches on `status`.
   The Workflow authoring reference documents `schema` as an `agent()` option; that is one
   source, not verified in this repository or against the CLI floor 2.1.154, and ADR-001's
   Context lists the runtime surface as `agent()`, `parallel()`, `pipeline()`, `phase()`,
   `log()` with no mention of it. Tradeoffs: the fallback driver has no `schema`, so the two
   drivers keep two contracts; the check lives in JS, which CI cannot run today (the `tests/`
   suite is bash and `node` is absent from `ci.yml`); a `close-story` run by hand or on
   `close-story:<file>` after a resume is still unguarded; and it puts a decision in the driver
   that ADR-001 says holds none.
2. **The worker writes its outcome into the story file's frontmatter; `close-story` refuses
   anything but `DONE`.** The driver stays blind; the verb does the check; both drivers, a
   human, and a resume all pass through the same gate. Two variants:
   - 2a. The worker writes `status: blocked` on a wall. Rejected: `blocked` is the verdict the
     driver reaches after the *second* miss (`vulyk-build.md:57`, `vulyk-cycle.js:128-130`),
     and once LR31 (ask 2) is fixed `wave_stories` never re-dispatches a blocked story, so a
     first `WALL` would skip the second attempt the fallback rule grants it.
   - 2b. A worker-owned frontmatter key, `returned:`, mirroring the report's `STATUS:` line
     verbatim; `close-story` exits 4 unless it reads `DONE`. *Chosen.*
3. **`close-story` treats a non-empty `## Findings` as walled.** Rejected: `## Findings` is a
   record, not a flag. After a `WALL` the second worker's success would be refused until it
   erased the first worker's findings, which is exactly the text the architect needs on a
   second miss; and `NEEDS_CONTEXT` writes no findings today.

## Decision

Option 2b. The deciding factor is the cheapest undo: one frontmatter key, one `case` in
`cmd_close_story`, no driver change in either driver, and a rollback is deleting the case
and the key.

### The contract

| Where | Change |
|---|---|
| `templates/story.md` frontmatter | New line after `status:`: `returned:              # written by the worker as its last edit: DONE \| NEEDS_CONTEXT \| WALL`. Empty in a fresh story. |
| `.claude/agents/worker-code.md`, `.claude/agents/worker-test.md` | Protocol gains one step before the return: set the story's `returned:` to the same word the `STATUS:` line will carry. On `NEEDS_CONTEXT` the exact question goes under `## Findings`, as `WALL` already does at step 5, so the next worker and the architect read it from the file. The `STATUS:` report line stays: it is for the Queen's and the human's eyes. |
| `scripts/cycle.sh` `cmd_close_story` | After the `status:` case (`:1343-1355`) and before `scope-check.sh` (`:1357`): read `returned`; `DONE` proceeds; `NEEDS_CONTEXT` / `WALL` / empty / anything else exits **4** with `next: repair` and `error: "returned <value>"` (`"returned: missing"` when empty). The story's `status:` is not changed; no commit is made. |
| ADR-001 D2 exit-code line | Amended to read: `4` = `record-seat` MALFORMED / `close-story` miss - red verification, or `returned:` not `DONE`. The driver semantics of 4 are unchanged: a miss under the two-attempt bound. This amendment rides on ask 1's X-M3 edit of D2. |
| `.claude/workflows/vulyk-cycle.js:121-131` | **No change.** Exit 4 already increments `attempts` and leaves the story open for the next poll; the second miss already stops with `{verb:'build', file, error}`. Only the stop's error text is touched, and that is M2/X-M1's business, not this ADR's. |
| `.claude/commands/vulyk-build.md:57` | The `build:<wave>` row stops saying "as each non-empty return says `STATUS: DONE` -> `close-story`" and says: run `close-story` on every non-empty return; exit 4 is a miss whatever its `error` says. Reading `STATUS:` by eye is allowed for the one-line log, never for the decision. |

Why exit 4 and not a new code: the driver's reaction to "this story cannot close on this
attempt" is the same for a red verification, an empty report and a non-`DONE` return - the
fallback row already lists the three together - so a new code would be a distinction without a
branch. The `error` field carries the reason for the human; the ledger of reasons is
`journal.md`, written by the driver on the second miss as today.

Why the worker writes the key rather than `close-story` inferring it: the worker is the only
party that knows whether it finished, and its story file is the one artefact both drivers, a
resume and a human all pass to the verb. A worker that forgets the key produces a visible miss
(`returned: missing`), a re-dispatch, and at worst a blocked story with the reason on record -
a recoverable, loud failure, where today's is silent.

### The fallback driver under this decision

`/vulyk-build` in session runs `close-story` on every non-empty return, exactly as the Workflow
driver does, and treats exit 4 as the first or second miss by its existing rule. It may still
read `STATUS:` to print its one visible line per action (step 2.3), but nothing it decides
depends on that line. On the second miss it edits `status:` to `blocked` itself, as today; the
worker never writes `blocked`.

### How the tests prove it

`tests/council.test.sh`, new `close-story` scenarios (their verification commands must be cells
of the fixture `## Commands` table, per the suite's R11 rule):

- `cstoryr1`: `returned: DONE`, verification `true` -> exit 0, `status: done`, one commit.
- `cstoryr2`: `returned: WALL`, verification `none — reviewed by lead-review` -> exit 4, last
  line `"ok":false … "error":"returned WALL"`, `status:` still `in-progress`, no new commit.
- `cstoryr3`: `returned:` absent -> exit 4, `error` is `returned: missing`.
- `cstoryr4`: `returned: NEEDS_CONTEXT` on a story with a real command -> exit 4 **before** the
  command runs (the fixture command writes a flag file; assert it is absent).

`tests/driver.test.sh` (new, planned in ask 1 M1), with `agent`/`parallel`/`clerk` stubbed:

- The `agent` stub returns a report whose first line is `STATUS: DONE`; the `clerk` stub
  answers `close-story` with `{ok:false, exit:4, error:"returned WALL"}` on the first call and
  `{ok:true}` on the second: the driver calls `close-story` both times, never fails on the
  first, and the run continues. This is the assertion that the driver did not read the prose.
- Same stub answering exit 4 twice: the run stops with `stop.verb === 'build'` and `stop.file`
  naming the story, and `close-story` was called exactly twice.
- The `agent` stub returns `STATUS: WALL` while the `clerk` stub answers `{ok:true}`: the
  story closes. This documents, not endorses, that the driver trusts the verb alone; the verb's
  own refusal is `cstoryr2`'s job.

## Consequences

- **Easier:** one gate for every path a story closes through; the driver keeps zero decision
  logic; the test lives in bash where CI already runs; a `NEEDS_CONTEXT` question is on disk
  where the next worker reads it, not only in a transcript.
- **Harder / accepted debt:** every worker prompt gains one edit before returning, and a
  worker on an older `worker-code.md` in a hive that upgraded `cycle.sh` alone would miss every
  story - both files are `OWNED` and ship together, so this needs a partial upgrade to happen. A
  human closing a story by hand must set `returned: DONE` first; `close-story`'s `error` says
  so. Stories written before this change have no key and read as `returned: missing` - correct
  for an unfinished one, and one line to add for a finished one.
- **Not decided here:** the wording of the second-miss stop error (M2/X-M1), and whether
  `open-round` at `cycle.sh:1587` should keep accepting `blocked` stories while `/vulyk-build`
  says never to open a round over one; both belong to ask 1 and ask 2 as already planned.

## Invariants created

- A story closes only when its own frontmatter says `returned: DONE`; no driver, human or
  resume path decides that from a worker's report text.
- `returned:` is written only by the worker that last ran the story, as its final edit; the
  driver never writes it and `close-story` never clears it.
- `blocked` is written by a driver after the second miss, never by a worker.
- `close-story` exit 4 means "this story cannot close on this attempt, count a miss"; its
  `error` field names why (`<verification line>`, `returned <value>`, `returned: missing`).
- Neither driver reads a worker report to make a decision; the report's `STATUS:` line is
  for the log and the Queen's context only.

## Revisit when

- Claude Code's Workflow runtime ships `schema` on `agent()` in a version this repo can pin
  and test in CI: the driver could then refuse to call `close-story` on a non-`DONE` report and
  save one clerk call per miss, keeping the verb's check as the gate.
- `memory/stats/scope.jsonl` or `journal.md` show `returned: missing` misses outnumbering
  real walls: the worker protocol step is being skipped and the key should be set by the
  worker's tooling rather than its prose instructions.
- A third outcome appears in the worker contract (a `BLOCKERS`-only return, say): the key's
  vocabulary and `close-story`'s case grow together, in one commit.
