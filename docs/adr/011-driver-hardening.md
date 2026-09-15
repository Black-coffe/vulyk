# ADR-011: Driver hardening - clerk retry, paperwork whitelist, self-marked close, story-file taint, verb-carried status

- Status: proposed
- Date: 2026-09-15
- Spec: docs/specs/driver-hardening

## Context

The anomaly-telemetry circle's round 6 surfaced five defects in the Workflow driver
(`.claude/workflows/vulyk-cycle.js`) and `scripts/cycle.sh` that ADR-001 and ADR-006 did not
anticipate: a clerk relay can return a non-JSON last line and end a run outright; two files
the cycle's own hooks write (`memory/stats/skills.json`, `memory/learnings/*.md`) are not on
`is_paperwork_path`'s whitelist, so they stall `open-round` and stale a GREEN row they never
touched; `close-story` refuses a story a worker marked `status: done` itself even when its
files still carry an uncommitted diff, leaving the tree in exactly the state the guard exists
to prevent; `record-seat`'s taint detector flags a bare `<slug>-NN` token, which any seat can
synthesise from the slug it is handed, while the actual leak in round 6 was a story *file*
path; and the driver spends one clerk call on `status` after nearly every action even though
five of `cycle.sh`'s mutating verbs already compute that object internally before returning.
Each defect had a named alternative in the brief's `## Answers`; this ADR records the five
decisions as built.

## Options

1. **Fix each defect at the call site named in `## Answers`** (chosen for all five - see
   Decision). Tradeoff: five small, independently testable changes, no new abstraction.
2. **A driver-side workaround for each defect** (e.g. the driver re-derives taint, caches its
   own status, retries every clerk call blindly). Rejected: duplicates logic `cycle.sh`
   already owns or should own, and the Workflow runtime cannot hold state across a crash
   (ADR-001), so a driver-side fix is not durable.

## Decision

Each of the five, as built - decision, rejected alternative, site, invariant:

**1. Clerk retry on a non-JSON last line.**
Built: `clerk()` in `.claude/workflows/vulyk-cycle.js` re-dispatches the identical prompt once
when the last stdout line fails `JSON.parse`, logs the retry, and only then lets a second
`BadLine` end the run - the same shape the driver already uses for a MALFORMED seat report.
Rejected: writing status to a file for the driver to read - the Workflow runtime has no
filesystem, so a file still reaches the driver only through a clerk relay of the same bytes;
it moves the copy, it does not remove it.
Site: `clerk()`, `.claude/workflows/vulyk-cycle.js`.
Invariant: at most two `cycle-clerk` dispatches per `clerk()` call; `cycle-clerk.md` itself
never retries.

**2. `skills.json` and `memory/learnings/*.md` are cycle paperwork.**
Built: `is_paperwork_path` in `scripts/lib.sh` accepts exactly `memory/stats/skills.json` and
`memory/learnings/<name>.md` (one level, no `/` in `<name>`), so `open-round`'s dirty-tree
guard and `paperwork_only()` treat a commit touching only them as paperwork.
Rejected: staging them through a cycle verb - the owner ruled `skills.json` not cycle-owned
and learnings are the librarian's; rejected: gitignoring them - both are meant to be
committed. `scope-check.sh`, which does not source `lib.sh`, is untouched.
Site: `is_paperwork_path`, `scripts/lib.sh`.
Invariant: `is_paperwork_path` is the one predicate both `open-round` and `paperwork_only()`
consult; nothing stages the two new paths.

**3. `close-story` tolerates a self-marked `status: done`.**
Built: `cmd_close_story`'s `done` branch runs `git status --porcelain` against the story file
and every path in `files_of`; a clean result still exits 2 `already done`; a dirty result
journals "worker marked status: done itself, closing on the uncommitted diff" and falls
through to the unchanged `returned:`/scope/verify/commit path. `worker-code.md` and
`worker-test.md` each gained one line telling workers not to write `status:` themselves.
Rejected: treating the driver's exit-2 `already done` as success - the run would continue
with the worker's edits uncommitted and unscoped, the exact state the defect left behind.
Site: `cmd_close_story`, `scripts/cycle.sh`.
Invariant: `status:` is never the worker's key to close a story with; a self-mark is
tolerated, not endorsed - it always goes through scope-check and verification before it
commits.

**4. Taint is the story file, not the bare id.**
Built: `taint_reason()`'s pattern 1 matches `\bS-NN\.md\b` or `(docs/specs/)?\bS/S-NN\b` (with
or without `.md`), `S` the escaped slug; a bare `<slug>-NN` token with neither `.md` nor the
`<slug>/` directory prefix is no longer taint. Patterns 2-4 (`plan.md`, `journal.md`,
`council/`) are unchanged.
Rejected: exempting `run:` lines from the scan - round 6 also echoed the id in a `saw:` line,
and line-type parsing widens the detector's code for no extra safety.
Site: `taint_reason()`, `scripts/cycle.sh`.
Invariant: a seat report is tainted only by a path to a hidden file (a story file, `plan.md`,
`journal.md`, `council/`), never by a token synthesisable from the slug it was handed.

**5. Mutating verbs carry post-verb status; the driver polls only at start and after a
parallel step.**
Built: on exit 0, `branch`, `close-story`, `open-round`, `record-seat` and `judge` embed one
more key, `status` - byte-for-byte `cmd_status <spec>` computed after every write the verb
made, including its own `--commit`:
```
`status, spec, slug, stage, next, briefed, approved, branch, head, pack, stories, wave,
wave_stories, round, ceiling, tier, open, court, missing, stale, verdict, review, red,
round_dir, paused, shipped`
```
The driver keeps one status object `st`, polled `clerk("status <spec> --json")`
`once before the first iteration, and after any iteration whose action ran zero verbs, ran
more than one verb ... or ran one verb whose result lacked status`; after a single sequential
verb with `ok:true` and `status`, `st = res.status` and no poll is made.
Rejected: a flat subset of the fields the driver reads - drifts from `status --json` the day
the driver reads one more field, and collides with `judge`'s own top-level `verdict` key;
rejected: dropping the post-parallel polls too by trusting the last-returned result - clerk
latency reorders promise resolution relative to command completion, so "last returned" is not
"last written".
Site: `emit_status`/`cmd_status`, `scripts/cycle.sh`; the loop's `carriedStatus()` and the
pre-loop poll, `.claude/workflows/vulyk-cycle.js`.
Invariant: the top-level `next` of a verb's JSON always equals `status.next` when `status` is
present; a driver that does not read `status` still works unchanged (the key is additive).

## Consequences

- **Easier:** a garbled clerk relay costs one retry instead of a dead run; the two hook-written
  files stop being a recurring manual patch (mmorpg re-applied ask 2's fix on every upgrade);
  a worker's stray `status: done` no longer strands its own commit; a seat cannot accidentally
  trip taint by typing the slug it was given; a steady Tier 3 round drops from 16 to 13 clerk
  calls (6 status polls to 3).
- **Harder / accepted debt:** `cmd_status`'s body now runs an extra time inside five verbs
  (one more `git`/`jq` pass per mutating call); `close-story`'s self-mark path adds one more
  branch a reader must trace before trusting `status: done` in a story file.

## Invariants created

- A `clerk()` call ends a run only after a *second* consecutive non-JSON last line, never the
  first.
- `is_paperwork_path` is the single predicate that decides whether a path staling an open
  round or a GREEN row is paperwork; a hook-written file is added there, not in a verb.
- `close-story` never closes a story on a clean tree whose worker wrote `status: done`
  without a commit backing it, and never *silently* closes one on a dirty tree either - the
  self-mark is always journalled.
- Taint is a path to a hidden file, never a bare `<slug>-NN` token.
- A mutating verb's `status` key, when present, is byte-for-byte `cmd_status`'s output after
  every write the verb made; a driver polls only when no single carried result is known to be
  the newest.

## Revisit when

- A sixth mutating verb is added to `cycle.sh` - it must decide whether it carries `status`
  too, per decision 5's pattern.
- `memory/learnings/` grows a second level of subdirectories - decision 2's one-level
  restriction would need revisiting.
- The Workflow runtime gains a filesystem or shell primitive - decision 1's retry-in-clerk
  shape may be replaced by a direct read.
