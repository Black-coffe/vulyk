# ADR-009: Dispatch failure reasons come from verb exit codes; seat reports travel by file path

- Status: proposed
- Date: 2026-09-14
- Spec: docs/specs/fable-review-remainders

## Context

`fable-review-remainders` closed two pieces of debt the Fable review's four majors and the
turn-cap conclusion left on `v0-12-0-remainders`' `## Next circle`: how a dead dispatch is
classified, and how a seat's or reviewer's report reaches `record-seat`. Both decisions were
reshaped mid-build by the round-1 council BLOCK and are recorded only in the spec's
`## Plan deltas`, which closes with the spec.

**Decision 1 - the third failure reason, from the verbs.** The plan's C3 contract, as amended
2026-09-14 (round-1 critical 1):

> `worker returned no report` - a non-empty return that the verb refuses as no report.
> **Round-1 amendment (2026-09-14, replaces the story-07 content check):** the driver never
> inspects the return's text beyond the empty test. For a worker, every non-empty return goes
> to `close-story` (ADR-006); exit 4 with `error` `returned: missing` is this reason, exit 4
> with any other `error` keeps today's handling (that `error` is the miss reason). For a seat
> or the reviewer, a `record-seat` exit 4 (on the `--file` try or the heredoc) after a
> non-empty return logs this reason once, before the existing single re-ask; an empty return
> already logged the empty reason and gets no second line. Both drivers apply this bound
> identically (R6).

The round-1 review's critical 1 is why: story 07's original approach greped the worker's chat
reply for a line-anchored `/^STATUS:/m` (`VERDICT:` for seats) to decide whether `close-story`
ran, which directly contradicted `docs/adr/006-worker-status-channel.md:135` ("Neither driver
reads a worker report to make a decision") and ADR-001 C11 ("never parses prose") - neither
amended, both still listed as governing the plan. The plan deltas record the fix as story 08
(driver + suite) and story 09 (the fallback loop's mirroring row), and record the rejected
alternative:

> **Rejected:** amending ADR-006 and C11 so the `STATUS:` grep is legal - it costs the owner an
> on-record amendment, three more files (both worker files and the fallback sentence), a
> line-format rule workers can miss, and it lets chat prose overrule `returned: DONE` on disk;
> the verb route is one clerk answer the driver already reads.

**Decision 2 - reports travel by file path.** The plan's C1/C2 contracts, and the brief's
answer that fixed the shape before the build:

> Сам сид пишет файл по пути от драйвера (Рекомендую): драйвер даёт сиду путь под
> `.vulyk/reports/<slug>/round-N/<seat>.attempt-K.md` (вне docs/specs, чтобы не задеть
> taint-правило), сид сохраняет туда отчёт последним действием, клерк вызывает `record-seat
> --file <путь>` одной короткой строкой. Если файла нет, драйвер откатывается на сегодняшний
> heredoc.

And the plan's own rejected alternative for the recording mechanism (C2's tradeoffs):

> **Rejected: a clerk `test -s` probe before recording** - one extra clerk turn on every seat
> in the good case, for a check the `--file` call already makes.

The plan also records a deliberate, named exception - the Tier 4 folded review keeps the old
heredoc path, because the fold is driver-composed and exists in no file:

> A Tier 4 folded review is recorded through the heredoc as today (C2). The fold is
> driver-composed and exists in no file; only a single reviewer dispatch (Tier 1-3) gets a
> report path... flagged, not fixed, because a two-file `--file` fold is a `cycle.sh` contract
> change the brief did not ask for.

Both decisions constrain code no future story has written yet: any new dispatch kind (a fourth
agent type, a new council seat) inherits the same three-reason classification and the same
file-first recording path, and any change to either must clear the same bar this ADR records.

## Options

**Decision 1 (third failure reason):**
1. Grep the return's chat prose for a status marker (`STATUS:` / `VERDICT:`) and let its
   absence decide whether `close-story` runs. Rejected by round-1 critical 1: contradicts
   ADR-006 and ADR-001 C11 without amending either, and lets chat prose overrule the
   `returned:` value already on disk.
2. Derive the third reason from the verbs' own exit codes - `close-story` exit 4
   `returned: missing` for a worker, `record-seat` exit 4 on a non-empty return for a seat or
   the reviewer - so the driver inspects nothing beyond emptiness. Chosen.
3. Amend ADR-006 and ADR-001 C11 on the record to legalize the prose grep. Rejected: needs the
   owner's word on the record, adds a formatting rule every worker can miss, and still lets
   chat prose outrank disk truth.

**Decision 2 (report delivery):**
1. The clerk probes the file with `test -s` before calling `record-seat`. Rejected: costs one
   extra clerk turn on every seat in the good case for a check `--file` already performs.
2. The seat writes its report to a driver-given path as its last action; the driver calls
   `record-seat --file <path>` first and falls back to the existing heredoc only on exit 2
   `file: <path>`. Chosen.
3. (Not recorded as considered for the Tier 4 fold - the plan states the fold keeps the heredoc
   because folding it into a file-backed record is a `cycle.sh` contract change outside the
   brief, not a rejected design option.)

## Decision

A failed or incomplete dispatch has exactly one of three reasons, and the third is decided by
verb exit codes, never by inspecting the return's prose:

- `<agent> threw: <message>` - the dispatch promise rejected.
- `<agent> returned empty - turn cap suspected (<agent>, maxTurns <N> in .claude/agents/<agent>.md)`
  - resolved to null, empty, or whitespace only; `<N>` from a static `CAPS` map mirroring
  agent frontmatter, with `maxTurns unknown` when an agent has no `CAPS` entry.
- `<agent> returned no report` - a non-empty return the verb itself refuses: for a worker,
  `close-story` exit 4 with `error` `returned: missing`; for a seat or the reviewer,
  `record-seat` exit 4 on a non-empty return (on the `--file` attempt or the heredoc fallback).

Both the Workflow driver and the `/vulyk-build` fallback loop apply this bound identically
(R6): the same string shape, the same verb-derived source for the third reason, for workers,
council seats and `lead-review` alike.

A seat's or the reviewer's report reaches `record-seat` by file path, not stdin, as the normal
case: the driver hands the agent a path under
`.vulyk/reports/<slug>/round-<N>/<seat>.attempt-<K>.md` (repo-relative, outside `docs/specs/`
so the taint rule is untouched), the agent writes its full report there as its last action,
and the clerk calls `record-seat --file <path>` - `--file` parsed before the report is read, a
missing/unreadable/empty file exits 2 with `error` `file: <path>` and writes nothing. On that
exit 2, the driver falls back to today's heredoc call with the chat reply and continues; any
other exit 2 is a failed verb as before. The Tier 4 folded review (two dispatches composited by
the driver, existing in no single file) is the one named exception and stays on the heredoc
path.

## Consequences

Easier: a driver crash or turn-cap death now says which of three things happened and, for a
cap death, which agent and what its configured ceiling is - the string a human reads at the
stop is diagnostic instead of a single undifferentiated "no report". A seat report of any size
can be recorded without truncation risk or a wasted clerk turn, since the file check and the
read happen in the same `--file` attempt.

Harder: `CAPS` is a second copy of every dispatched agent's `maxTurns`, hand-maintained in the
driver; whoever changes a `maxTurns:` line must remember to update `CAPS` too (the plan accepts
this as cheaper than teaching the Workflow script, which has no filesystem access, to read six
agent files on every launch). The Tier 4 fold remains on the older heredoc path, so the
`--file` invariant is not yet uniform across every reviewer dispatch shape.

## Invariants created

- Neither driver classifies a dispatch failure by reading the return's prose beyond an
  emptiness test; the third reason is always sourced from `close-story`'s or `record-seat`'s
  own exit code and `error` field.
- The two drivers (Workflow script, `/vulyk-build` fallback loop) apply the same three-reason
  bound to the same dispatch kind; a change to one's classification changes the other's in the
  same story.
- A seat's or the reviewer's report is written by the agent itself, as its last action, to a
  driver-given path under `.vulyk/reports/<slug>/round-<N>/<seat>.attempt-<K>.md`; writing
  there is not a court BREACH. `record-seat --file` is tried first; the heredoc is a fallback
  triggered only by that verb's exit 2 `file:` error, never a first choice, except for the
  Tier 4 folded review, which stays on the heredoc.

## Revisit when

A `CAPS` entry drifts from an agent's actual `maxTurns:` (caught by the plan's mirroring
comment requiring both to change together) - or a future story folds the Tier 4 review into a
single file-backed dispatch, at which point the named heredoc exception should be re-examined
rather than silently carried forward.
