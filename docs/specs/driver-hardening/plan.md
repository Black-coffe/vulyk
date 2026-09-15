# Driver hardening (plan)

**Tier:** 3 · **Spec slug:** `driver-hardening` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-001 (D2 verb table and exit codes, the `record-seat` taint clause, `paperwork_only`/`is_paperwork_path` as the one whitelist, "the driver switches on `status.next` and holds no logic"), ADR-006 (`returned:` is the worker's key; `status:` is written by `close-story`, `blocked` by a driver), ADR-009 (neither driver parses a return's prose; a clerk answer is the only thing the driver reads), `memory/map/scripts.md` Gotchas (taint and whitelist are security-relevant string matches - stay anchored), CLAUDE.md token economy ("Queen never reads source", "verification runs once per close").
**Depends on:** v0.14.0 (`267e447`), ADR-010 accepted (`4c37b4b`); recon `recon/cycle-sites.md` and `recon/driver-and-clerk.md` (2026-09-15) - every `file:line` below is theirs.

## Goal
Five defects the anomaly-telemetry circle met in the Workflow driver and `cycle.sh`, each closed at the site the owner chose in `## Answers`: the driver re-asks the clerk once on a non-JSON last line before ending the run; `memory/stats/skills.json` and `memory/learnings/*.md` join the cycle's paperwork whitelist so an open round neither refuses nor stales on hook-written files; `close-story` closes a story whose worker wrote `status: done` itself when its named files still carry an uncommitted diff, journals that fact, and keeps refusing a clean already-done story; the taint detector stops treating a bare `<slug>-NN` as a leak and keeps treating the story *file* as one; and every mutating verb the driver calls returns the post-verb status inside its own JSON, so the driver polls `status` only at loop start and after parallel steps. Nothing else moves: no telemetry, no constitution trimming, no new verbs.

## Assumptions
- **A1 - ship-check stage 03 is unaffected by widening `is_paperwork_path`.** After anomaly-telemetry story 12, `ship-check.sh` passes through exactly `memory/stats/anomalies.jsonl` by name (tests/cycle.test.sh:245-258 assert `skills.json`-alone and `council.jsonl`-alone both refuse - and `council.jsonl` *is* on the whitelist, so the stage filters by name, not by the predicate). Whitelisting `skills.json` and `memory/learnings/*.md` therefore changes `open-round` and staleness only, as ask 2 says. If the worker finds the stage does read `is_paperwork_path`, it returns NEEDS_CONTEXT rather than loosening the ship gate; the owner decides. `scope-check.sh` does not source `lib.sh` and is untouched (the owner's "скоуп-гейт для skills.json не трогаем"). *Round 1 (Minor 8): "staleness" includes the `paperwork_only` callers in `ship-check.sh` (council/human staleness at ship) and `human-check.sh` - accepted as intended, recorded by story 08.*
- **A2 - `memory/learnings/*.md` means files directly under `memory/learnings/`,** one level, `.md` only. Nothing stages or commits them: they stay uncommitted until the librarian's or the owner's own commit, exactly like `skills.json` today (A18 of anomaly-telemetry: not cycle-owned).
- **A3 - the verb JSON carries the whole status object nested under one key, `status`,** not a flat subset of fields. Reason: `judge` already emits `verdict` at top level (collision), and a subset drifts from `status --json` the day a driver reads one more field; the cost is one ~1 KB line the clerk already relays on every poll. The owner may prefer a flat subset - say so at approval and story 03's contract changes, story 04's does not.
- **A4 - the clerk retry covers every verb,** not only `status`: the ask says "нечитаемая строка от клерка", and `clerk()` is the one parsing path for all of them. One extra dispatch per bad line, never more. *Revised after round 1 (Major 2): the second dispatch is not the same prompt for a mutating verb - see C1 revised.*
- **A5 - the expected saving is three polls per round, not "a third of calls".** On the recon's 16-call Tier 3 iteration the polls before `build`, `dispatch` and `green` are dropped (carried by `branch`, `open-round`, `judge`); the polls after `build:<wave>` and `dispatch:<seats>` stay because those steps run several verbs in parallel and no single carried status is known to be the newest. 16 -> 13 calls (about 19 %), polls 6 -> 3. The brief's "около трети" was an estimate; this is the honest number.
- **A6 - a story file name is taint wherever it appears,** including inside a seat's own `run:` line: the round-6 evidence was a bare id, and a seat that types `demo-14.md` has seen a file the court does not hold. No line-type discrimination (`run:` vs `saw:`) is added.
- **A7 - the self-marked path journals through `journal.sh` with the stage word `close-story` already uses** (or the one `state.sh` names for stage 03 if the verb writes no journal line today) - the worker aligns with the existing call, not a new vocabulary.
- **A8 - the record is a new ADR-011 plus a dated amendment in ADR-001,** not an amendment alone: the verb-status contract and the taint change each had a rejected alternative in `## Answers`, which is what an ADR exists to hold; ADR-001's D2 rows and invariants get one-line pointers so they stop contradicting the code.
- **A9 (repair) - `claim <spec> <stamp>` and `release <spec> <stamp>` are idempotent for the same stamp,** so an identical re-dispatch after a garbled relay is safe for them, as it is for `status` (`release`: "exit 2 only if a different stamp holds it", memory/map/cycle.md). Not verified for `claim` - recon question below; if same-stamp re-claim exits 2, story 07 routes `claim` through the status track too and the (ad) scenario moves to `status`.
  Verified by the Queen 2026-09-15: `cmd_claim` with the stamp already held exits 0 `claimed` (cycle.sh:2077-2080) - `claim` stays on the identical-re-dispatch track.

## Stories

**Wave 1** (disjoint files, run concurrently)
- `driver-hardening-01-paperwork-selfmark-taint` (sonnet) - asks 2, 3, 4 in `scripts/lib.sh`, `scripts/cycle.sh`, `tests/council.test.sh`, plus the two worker agent lines (`status:` is not the worker's; `close-story` reads `returned:`, the driver never opens the story). One story because the three edits are each a dozen lines and all three add cases to the same suite file.
- `driver-hardening-02-clerk-retry` (sonnet) - ask 1: `clerk()` in `vulyk-cycle.js` re-dispatches once on a non-JSON last line, logs it, ends the run on the second; two scenarios in `tests/driver.test.sh`.

**Wave 2** (blocked by 01: same `cycle.sh` and suite)
- `driver-hardening-03-verb-status` (opus, contract) - ask 5, verb side: `branch`, `close-story`, `open-round`, `record-seat`, `judge` emit `status` (the exact `status --json` object, post-verb) and `next` = `status.next` on exit 0; suite cases per verb.

**Wave 3** (blocked by 02 and 03: same driver file and suite as 02; consumes 03's contract)
- `driver-hardening-04-driver-carries-status` (opus, contract) - ask 5, driver side: poll `status` at loop start and after a parallel step only; act on the carried object otherwise; scenarios counting clerk calls in `tests/driver.test.sh`.

**Wave 4** (blocked by 01-04: documents what landed)
- `driver-hardening-05-adr-and-docs` (sonnet) - ADR-011 (verb status, taint rule, self-marked close, clerk retry, whitelist), ADR-001 amendment lines, `docs/cycle.md` only where it now misstates, CHANGELOG `## Unreleased`.

**Wave 5 - repair after round 1** (GREEN with `lead-review` PASS; four Majors, eight Minors, one opus UNASKED. Disjoint files; each blocked by the earlier stories on its files.)
- `driver-hardening-06-taint-shape-learnings-dir-selfmark-journal` (opus) - Major 1 (taint matches `<slug>-NN-<title>.md`), opus UNASKED (a) (`?? memory/learnings/` collapsed directory), Minors 5, 6 (journal line once, after verification, with the real wave), 10 verb side (`emit_status` never embeds an error envelope), 12 (assert the open-round message directly). `scripts/cycle.sh`, `scripts/lib.sh`, `tests/council.test.sh`. Blocked by 01, 03.
- `driver-hardening-07-clerk-retry-via-status` (opus, contract) - Major 2 (garbled relay of a mutating verb recovered via `status <spec> --json`, never by re-running the verb) and Minor 10 driver side (`carriedStatus()` refuses an error envelope). `.claude/workflows/vulyk-cycle.js`, `tests/driver.test.sh`. Blocked by 02, 04.

**Wave 6** (blocked by 05, 06, 07: documents the repair)
- `driver-hardening-08-adr-docs-repair` (sonnet) - Majors 3, 4 (ADR-011 invariant as built; the C5 narrowing mirrored from `## Plan deltas`), Minors 7, 8, 9, 11, plus C1 revised and C4 revised on the record. `docs/adr/011-driver-hardening.md`, `docs/adr/001-cycle-state-contract.md`, `.claude/agents/worker-test.md`, `CHANGELOG.md`.

Merge pass: 06 and 07 fail the neighbour test against each other only if one worker held both suites - they do not (shell vs JS, disjoint files, both opus-sized). Minor 10 is split by file, not by idea: its verb half borders 06's `emit_status`, its driver half borders 07's `carriedStatus()`. 08 cannot fold into 06/07 (wave 6 sequencing: it documents what they build).

## Contracts

### C1 - `clerk()` recovery of a non-JSON last line (story 02; **revised** by story 07 after round 1 Major 2)
`clerk(cmd)` in `.claude/workflows/vulyk-cycle.js` makes at most **two** `cycle-clerk` dispatches per call. Attempt 1 dispatches the prompt for `cmd`. If its last stdout line does not `JSON.parse`, the second dispatch depends on the verb (first word of `cmd`):
- **`status`, `claim`, `release`** (read-only or idempotent by stamp, A9): `log()` once - `cycle-clerk: non-JSON last line, retrying once: <cmd>` - and dispatch the **identical** prompt; the parsed result is returned as if the first attempt never happened. (Story 02's behaviour, unchanged.)
- **`branch`, `close-story`, `open-round`, `record-seat`, `judge`** (mutating; a re-run of a verb that took effect exits 2 `already done` / `already recorded` and would end the run): `log()` once - `cycle-clerk: non-JSON last line from "<cmd>", asking status instead` - and dispatch `status <spec> --json` (spec from `args.spec`). If that line parses to a status object `st`, `clerk()` returns `{ ok: true, verb: <verb>, exit: 0, next: st.next, error: '', status: st, recovered: 'status' }`. The verb is **never** dispatched a second time. The loop continues from `status`/`next` exactly as it would from a carried status (C6): a verb that did not take effect shows up as the same `next` again (`judge`, `open-round`, `close-story:<file>`, the seat still in `missing`) and is re-run by the ordinary loop, not by `clerk()`; one that did take effect is not repeated.
- If the second line (either track) does not parse, `throw new BadLine(line)` with the **second** line - the outer catch ends the run and returns the raw line, as today. `parsed.exit === 3` on whichever attempt parsed throws `Paused`. `cycle-clerk.md` is unchanged.
**Rejected:** limiting the retry to idempotent verbs only (a garbled `judge` relay would end the run, the launch defect in a new coat); making `close-story`/`record-seat` re-runs return ok on an already-done story (widens `cycle.sh`'s preconditions for every caller to save one driver path). **Accepted cost:** a `close-story` that actually failed exit 4 behind a garbled relay does not count a miss on that attempt; the loop meets the real exit 4 on the next iteration.

### C2 - `is_paperwork_path` additions (story 01) · **addendum** (story 06, opus UNASKED (a))
`scripts/lib.sh` `is_paperwork_path` accepts two more repo-relative shapes: exactly `memory/stats/skills.json`, and `memory/learnings/<name>.md` with `<name>` free of `/` (one level). The `docs/specs/*/` anchoring of the existing entries is untouched. Consequences that follow without further code: `open-round`'s dirty-tree guard (cycle.sh:1804-1820) skips those paths; `paperwork_only()` treats a commit touching only them as paperwork, so such a commit never stales an open round or a GREEN row. Nothing stages them; `ship-check` stage 03 and `scope-check` keep today's behaviour (A1).
**Addendum.** In a hive with nothing tracked under `memory/learnings/`, `git status --porcelain` collapses the directory to one `?? memory/learnings/` line, which the predicate rejects. The open-round guard's `git status --porcelain` gains `-uall`, so every untracked file is listed by its own path and the one-level rule applies to each. The predicate itself is unchanged (no directory form, no `sub/x.md`). **Rejected:** accepting `memory/learnings/` (trailing slash) in the predicate - it would pass a collapsed directory that hides `memory/learnings/sub/junk.txt`.

### C3 - `close-story` on a self-marked `status: done` (story 01) · **revised** (story 06, Minors 5, 6)
In `cmd_close_story`, the `done` branch: `DIRTY=$(git status --porcelain -- "$STORY" <every path from files_of "$STORY">)`; if `DIRTY` is empty, exit 2 `already done` exactly as today; if non-empty, mark the closing as self-marked and fall through to the normal path unchanged: `returned:` check (exit 4 unless `DONE`), `scope-check.sh`, `## Verification` x `repeat:`, staging of `files_of` + the story file, one `story(<id>): <title>` commit under `--commit`. **Revised placement:** the one journal line - `close-story <id>: worker marked status: done itself, closing on the uncommitted diff` - is appended only once verification is green, immediately before the `status:` write / commit step, with `next` = `build:<wave>` taken from the story's `wave:` frontmatter (not a hardcoded `build:1`). Every exit-4 path leaves `journal.md` untouched, so a retried attempt never journals twice. The `status:` line is not rewritten on this path. `todo|in-progress` and the "anything else" branch are unchanged.

### C4 - taint rule, story-file form (story 01) · **revised** (story 06, Major 1)
`taint_reason()` pattern 1, with `S` the regex-escaped slug, is two alternatives: `\bS-[0-9]{2}(-[A-Za-z0-9_-]+)?\.md\b` and `(docs/specs/)?\bS/S-[0-9]{2}\b` (with or without a title and `.md`). So `demo-14-title.md`, `demo-14.md`, `docs/specs/demo/demo-14-title.md`, `demo/demo-14` are taint; a bare `S-NN`, `S-NN-title` without `.md`, and the round-6 `run:`/`saw:` shape are not. Patterns 2-4 (`plan.md`, `journal.md`, `council/`) are unchanged. Order and first-hit-wins are unchanged; the returned reason text for pattern 1 says `story file`.

### C5 - mutating verbs carry `status` (story 03; consumed by 04 and 05) · **addendum** (story 06, Minor 10)
On **exit 0**, the last-line JSON of `branch`, `close-story`, `open-round`, `record-seat` and `judge` gains one key, `status`, whose value is byte-for-byte the object `cmd_status <spec>` prints (`status --json`), computed after every write the verb made *and after its `--commit`* (so `head` is the new commit). The top-level `next` is the verb's own value and equals `status.next` on a well-formed spec (see `## Plan deltas`). On any non-zero exit `status` is absent and `next`/`error` keep today's meaning. Key order: `ok, verb, exit, next, error, status`. `status` itself, `briefed`, `escalate`, `reopen`, `claim`, `release`, `pause`, `resume` are unchanged. Still exactly one stdout JSON line per verb.
**Addendum.** `emit_status` embeds `status` only when its `cmd_status` call exits 0 and prints a status object; if `cmd_status` fails (usage branch, `{"ok":false,"verb":"status",...}`), the verb emits the pre-C5 five-key line with no `status` key, still exit 0. A carried `status` is a status object or absent, never an error envelope.

### C6 - the driver's poll rule (story 04) · **addendum** (story 07, Minor 10)
The loop keeps one status object `st`. It is obtained by `clerk("status <spec> --json")` (1) once before the first iteration, and (2) after any iteration whose action ran zero verbs, ran more than one verb (a `parallel()` fan-out), or ran one verb whose result lacked `status`. After an iteration whose action was exactly one sequential verb whose result has `ok:true` and `status`, `st = res.status` and no poll is made. Everything the loop reads is read from `st` only. Steady Tier 3 round: 13 clerk calls (A5).
**Addendum.** `carriedStatus(res)` returns `res.status` only when `res.ok === true`, `res.status` is a non-null object, `res.status.next` is a string and `res.status` has no `ok` key; otherwise `null` (poll). A `recovered: 'status'` result from C1 revised satisfies it.

### C7 - worker agent lines (story 01; Minor 9 mirrored by story 08)
`.claude/agents/worker-code.md` and `worker-test.md` each carry `Never edit the story's status: line - close-story writes it (and a driver writes blocked); you write returned: only.` and the same `close-story reads this key; the driver never opens the story file` sentence.

## Tradeoffs
- **Ask 1, chosen:** retry once inside `clerk()` - the same shape the driver already uses for a MALFORMED seat report; no new file, no clerk change. After round 1: the second dispatch is `status` for mutating verbs (C1 revised). **Rejected:** status-to-file - the Workflow runtime has no filesystem, so a file still reaches the driver only through a clerk relay of the same bytes.
- **Ask 2, chosen:** whitelist the two hook-written shapes in the one predicate, plus `-uall` on the open-round listing so an untracked-only directory is judged file by file. **Rejected:** a cycle verb staging them; gitignoring; a directory form in the predicate.
- **Ask 3, chosen:** `close-story` tolerates the self-mark when the tree proves work is pending, journals it once on success; workers are told once not to write `status:`. **Rejected:** the driver treating exit 2 `already done` as success.
- **Ask 4, chosen:** one regex change matching the repo's real story-file shape; a bare id is synthesisable from the slug. **Rejected:** exempting `run:` lines from the scan.
- **Ask 5, chosen:** each mutating verb embeds the full post-verb status object (A3); the driver polls only where it cannot know which of several parallel results is newest. **Rejected:** a flat subset; dropping the post-parallel polls; making the top-level `next` derive from `status.next` (broke pre-C5 fixtures - see `## Plan deltas`).

## Integration gate
`bash tests/council.test.sh && bash tests/driver.test.sh && bash tests/cycle.test.sh && git ls-files '*.sh' | xargs -n1 bash -n`; `bash scripts/wave-check.sh docs/specs/driver-hardening` before each dispatch.

## Open questions for the owner (approval stop)
1. A3 - nested `status` object (recommended) or a flat subset of the seven fields the driver reads? *(Answered by approval: nested.)*
2. A5 - three polls dropped per round, not a third of all calls. Acceptable as the delivered scope of ask 5? *(Answered by approval.)*
3. A8 - ADR-011 plus ADR-001 pointers (recommended) or an ADR-001 amendment alone? *(Answered by approval: ADR-011.)*

**Recon question for `drone-scout` (wave 5, before dispatching story 07):** in `scripts/cycle.sh` `cmd_claim`, does `claim <spec> <stamp>` exit 0 when the `DRIVER` semaphore already holds the *same* stamp (idempotent), or exit 2? Decides whether `claim` stays on the identical-re-dispatch track (A9) or joins the status track.

## Descoped
- **opus UNASKED (b)** - a clerk last line of literal `null` or a bare number parses as JSON and throws `TypeError` outside `BadLine`. Real, but outside the Queen's repair scope for this round and not in any ask's words; carry to the next circle (one `typeof parsed === 'object' && parsed !== null` guard inside `clerk()`'s try).
- **opus UNASKED (c)** - `record-seat` and `close-story` carry a ~700-byte `status` the driver discards (fan-out steps poll anyway). Harmless, consistent with C5's "every mutating verb" and A5's honest count; no change.
- **Minor 8** - not a defect: the widening reaching `ship-check.sh`/`human-check.sh` `paperwork_only` callers is what "не старят его" asks for. Recorded in ADR-011 by story 08, no code change.

## Plan deltas
- **2026-09-15, round 1 Major 4 - C5 `next` narrowed.** C5 said "the top-level `next` of that JSON equals `status.next`". Story 03 delivered: the top-level `next` stays the verb's own value; it coincides with `status.next` on a well-formed spec (Briefed/Approved present, round pack current) and the suite asserts equality only there. Reason (story 03 notes): deriving `next` from status changed several pre-C5 fixtures (a plan with no `**Briefed:**`, a round whose pack moved) and would have broken older callers the story promised to leave working. Accepted; C5 text above updated; ADR-011 aligned by story 08.
- **2026-09-15, round 1 Major 2 - C1 revised.** A4's "identical re-dispatch for every verb" is replaced by the two-track rule in C1 revised (status re-dispatch for the five mutating verbs). Story 07.
- **2026-09-15, round 1 Major 1 - C4 revised.** The prescribed `\bS-[0-9]{2}\.md\b` missed the repo's real `<slug>-NN-<title>.md` shape; the contract's defect, not the worker's. Story 06.
- **2026-09-15, opus UNASKED (a) - C2 addendum** (`-uall` on the open-round listing). Story 06.
- **2026-09-15, Minors 5, 6 - C3 revised** (journal once, after verification, real wave). Story 06.

<!--
The six lines below are the cycle's confirmation artifacts (docs/cycle.md).
-->
**Approved:** Andrei, 2026-09-15
**Briefed:** <written by scripts/cycle.sh briefed - stage 01+02 on the straight-through path. Alternative to **Approved:** above.>
**Branch:** vulyk/driver-hardening
**Checked:** <written by scripts/human-check.sh after the owner has looked - stage 05, and the override for stage 04+05.>
**Council:** GREEN round 1, 2026-09-15, at 8521d20, pack 92f41ba75c4c
**Shipped:** <written by scripts/ship-check.sh --record - stage 06: the published version, and where>
