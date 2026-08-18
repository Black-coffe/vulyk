# The gates

Seven checks stand between a request and a merge. This page is not a description of the
pipeline — [architecture.md](architecture.md) draws that. It answers the two questions that
turn out to matter in practice and are documented nowhere else:

**What can this gate not see?** and **when does it stop being true?**

A gate is only ever evidence about the thing it was pointed at, at the moment it was
pointed. Both halves get forgotten, and forgetting either one produces the same artifact: a
green on the record that describes work nobody shipped.

## What each gate sees

| Gate | Sees | Structurally cannot see | Currency |
|---|---|---|---|
| `wave-check.sh` | every story's frontmatter, `## Files`, `## Verification`, and the tree | whether the code is right; whether a verification command is *meaningful* beyond touching the story's own files | deterministic, free |
| `trace-check.sh` | every story's `## Requirements` quotes, `brief.md`, `## Plan deltas` | whether a quoted requirement was actually implemented | deterministic, free |
| `scope-check.sh` | one story's declared files against its own commit's diff | whether the change inside those files is correct | deterministic, free |
| `drone-coverage` | `brief.md` + `plan.md` — **never a story file** | whether the plan was built; it runs before anything exists | sonnet, `maxTurns: 5` |
| `drone-acceptance` | `brief.md` + the repository + one run command + the milestone ledger — **never `docs/specs/` beyond those** | whether the proof is real. It observes that the asks work; it cannot tell a suite that would catch a regression from one that would not | sonnet |
| `lead-review` | everything: diff, stories, notes, plan, wiki, ADRs | the human's ask *independently* — it reads the plan, so it inherits the plan's framing of what was wanted | opus |
| `acceptance-log.sh` | the story statuses, the caller's verdict, the pack's identity | anything about quality; it is a ledger, not a judge | deterministic, free |

## The two blind spots that matter

**Acceptance and review are orthogonal, and neither subsumes the other.** Acceptance asks
*did the asks get built*; review asks *is the proof real*. Both can be right at once, and on
the first real run both were: the blind gate accepted a pack `lead-review` then blocked
twice, on coverage holes that were entirely genuine — an end-to-end test that no longer
exercised the route it was named for, and a handler whose guard nothing would have missed if
it were removed. A `drift: false` in `acceptance.jsonl` is therefore **evidence about
delivery, never about proof**. Reading it as the latter is the single easiest way to
misuse this framework's own numbers.

**Coverage runs before the work and acceptance runs after it, so neither sees a build.**
Everything that happens *during* a build — a worker narrowing a story, a plan delta,
a repair round — is visible only to `lead-review` and to the deterministic checks, and only
if those are re-run. Which brings us to the other half.

## When a gate stops being true

Every one of these is evidence about a specific pack at a specific commit. Change the pack
and the evidence does not transfer — it just stops being about anything.

| Event | What it invalidates | What to do |
|---|---|---|
| A repair story is cut after review | the acceptance verdict, `wave-check` | re-dispatch `drone-acceptance` when the repair round closes; re-run `bash scripts/wave-check.sh docs/specs/<slug>` before dispatching it |
| A story's `## Files` changes | `wave-check`, and any concurrency assumption resting on it | re-run `wave-check` before the next dispatch |
| A plan delta adds or rewords a requirement | `trace-check` backward | re-run `bash scripts/trace-check.sh docs/specs/<slug>` |
| The tree moved since planning | `wave-check`'s `missing` and `empty-glob` classes | `/vulyk-build` step 2 re-runs it for exactly this reason |
| Anything at all, before proposing a merge | possibly the acceptance verdict | `bash scripts/acceptance-log.sh --check docs/specs/<slug>` → `CURRENT`, `STALE`, or `NO VERDICT RECORDED` |

The rule underneath all five rows is one sentence: **when the pack moves, whatever judged it
is re-run.** It is written down here because relying on remembering it is what produced the
failure it exists to prevent — an acceptance verdict recorded against six stories for a pack
that shipped with nine, and a repair round sent against a collision check nobody re-ran.

## Only one gate at a time may run the suite

`lead-review` and `drone-acceptance` are dispatched in one message because they are
independent *in information* — one sees everything, the other almost nothing. They are not
independent in **machine resources**, and only one of them runs anything: acceptance does.

That pairing is therefore safe. What is not safe is dispatching several acceptance gates at
once — catching up on a backlog of specs, say. A project whose test suite binds fixed ports
will hand you `EADDRINUSE` in one gate because another gate's server is up, and the failure
looks exactly like a defect in the code under test. Observed: two of three concurrent gates
lost their first runs to it, and only the drone's own honesty about *what it ran* made the
cause visible at all.

Run acceptance gates one at a time, or give the suite ephemeral ports. And when a gate
reports an environmental failure, believe it before you believe the code is broken — a gate
that names its own interference is doing the job.

## Reading a decline

Two verdicts look like caution and are not:

- **A `CANNOT_RUN` that names no attempt.** The branch is for behaviour with no reachable
  entry point, or an environment missing what reaching it needs. A library is *not* that: its
  surface is a caller, and writing one is the gate's job. A decline must say what was tried,
  so one that tried nothing is visible as such.
- **A coverage claim that overstates.** "Remove either guard and it goes red" must be true of
  *each* guard, checked separately. A claim about how well something was checked is itself a
  claim, and it is the one nobody re-checks.

Both are the same defect wearing different clothes: a verdict the gate did not earn. A gate
that declines honestly costs nothing. A counterfeit costs the only signal there is.

## What no gate covers

Named so it is a known gap rather than an assumed guarantee:

- **Whether the request was the right request.** Every gate below the brief is answerable to
  the brief. If the brief asks for the wrong thing, the pipeline builds it correctly.
- **Cross-spec regressions.** Each gate is scoped to one spec. The integration gate (build,
  typecheck, lint, full suite) is what stands between specs, and it is the project's, not
  VULYK's.
- **Whether the cascade beats an all-opus baseline.** Never measured; see
  [model-cascade.md](model-cascade.md) and the "what is not measured" section of the README.
