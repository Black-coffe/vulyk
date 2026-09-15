# Driver hardening (plan)

**Tier:** 3 · **Spec slug:** `driver-hardening` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-001 (D2 verb table and exit codes, the `record-seat` taint clause, `paperwork_only`/`is_paperwork_path` as the one whitelist, "the driver switches on `status.next` and holds no logic"), ADR-006 (`returned:` is the worker's key; `status:` is written by `close-story`, `blocked` by a driver), ADR-009 (neither driver parses a return's prose; a clerk answer is the only thing the driver reads), `memory/map/scripts.md` Gotchas (taint and whitelist are security-relevant string matches - stay anchored), CLAUDE.md token economy ("Queen never reads source", "verification runs once per close").
**Depends on:** v0.14.0 (`267e447`), ADR-010 accepted (`4c37b4b`); recon `recon/cycle-sites.md` and `recon/driver-and-clerk.md` (2026-09-15) - every `file:line` below is theirs.

## Goal
Five defects the anomaly-telemetry circle met in the Workflow driver and `cycle.sh`, each closed at the site the owner chose in `## Answers`: the driver re-asks the clerk once on a non-JSON last line before ending the run; `memory/stats/skills.json` and `memory/learnings/*.md` join the cycle's paperwork whitelist so an open round neither refuses nor stales on hook-written files; `close-story` closes a story whose worker wrote `status: done` itself when its named files still carry an uncommitted diff, journals that fact, and keeps refusing a clean already-done story; the taint detector stops treating a bare `<slug>-NN` as a leak and keeps treating the story *file* as one; and every mutating verb the driver calls returns the post-verb status inside its own JSON, so the driver polls `status` only at loop start and after parallel steps. Nothing else moves: no telemetry, no constitution trimming, no new verbs.

## Assumptions
- **A1 - ship-check stage 03 is unaffected by widening `is_paperwork_path`.** After anomaly-telemetry story 12, `ship-check.sh` passes through exactly `memory/stats/anomalies.jsonl` by name (tests/cycle.test.sh:245-258 assert `skills.json`-alone and `council.jsonl`-alone both refuse - and `council.jsonl` *is* on the whitelist, so the stage filters by name, not by the predicate). Whitelisting `skills.json` and `memory/learnings/*.md` therefore changes `open-round` and staleness only, as ask 2 says. If the worker finds the stage does read `is_paperwork_path`, it returns NEEDS_CONTEXT rather than loosening the ship gate; the owner decides. `scope-check.sh` does not source `lib.sh` and is untouched (the owner's "скоуп-гейт для skills.json не трогаем").
- **A2 - `memory/learnings/*.md` means files directly under `memory/learnings/`,** one level, `.md` only. Nothing stages or commits them: they stay uncommitted until the librarian's or the owner's own commit, exactly like `skills.json` today (A18 of anomaly-telemetry: not cycle-owned).
- **A3 - the verb JSON carries the whole status object nested under one key, `status`,** not a flat subset of fields. Reason: `judge` already emits `verdict` at top level (collision), and a subset drifts from `status --json` the day a driver reads one more field; the cost is one ~1 KB line the clerk already relays on every poll. The owner may prefer a flat subset - say so at approval and story 03's contract changes, story 04's does not.
- **A4 - the clerk retry covers every verb,** not only `status`: the ask says "нечитаемая строка от клерка", and `clerk()` is the one parsing path for all of them. One extra dispatch per bad line, never more.
- **A5 - the expected saving is three polls per round, not "a third of calls".** On the recon's 16-call Tier 3 iteration the polls before `build`, `dispatch` and `green` are dropped (carried by `branch`, `open-round`, `judge`); the polls after `build:<wave>` and `dispatch:<seats>` stay because those steps run several verbs in parallel and no single carried status is known to be the newest. 16 -> 13 calls (about 19 %), polls 6 -> 3. The brief's "около трети" was an estimate; this is the honest number.
- **A6 - a story file name is taint wherever it appears,** including inside a seat's own `run:` line: the round-6 evidence was a bare id, and a seat that types `demo-14.md` has seen a file the court does not hold. No line-type discrimination (`run:` vs `saw:`) is added.
- **A7 - the self-marked path journals through `journal.sh` with the stage word `close-story` already uses** (or the one `state.sh` names for stage 03 if the verb writes no journal line today) - the worker aligns with the existing call, not a new vocabulary.
- **A8 - the record is a new ADR-011 plus a dated amendment in ADR-001,** not an amendment alone: the verb-status contract and the taint change each had a rejected alternative in `## Answers`, which is what an ADR exists to hold; ADR-001's D2 rows and invariants get one-line pointers so they stop contradicting the code.

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

## Contracts

### C1 - `clerk()` retry (story 02; story 04 keeps it)
`clerk(cmd)` in `.claude/workflows/vulyk-cycle.js:72-81` becomes: dispatch `cycle-clerk` with the same prompt; if the last stdout line does not `JSON.parse`, call `log()` once with `clerk: non-JSON last line from "<cmd>", retrying once: <first 200 chars of the line>` and dispatch the identical prompt a second time; if that line parses, continue as if the first never happened; if not, `throw new BadLine(line)` with the *second* line - the outer catch at :281-285 still ends the run and returns the raw line. Exactly two dispatches at most per `clerk()` call. `cycle-clerk.md` is unchanged (the clerk itself still never retries). `Paused` (`parsed.exit === 3`) is checked after parsing, as today, on whichever attempt parsed.

### C2 - `is_paperwork_path` additions (story 01)
`scripts/lib.sh` `is_paperwork_path` accepts two more repo-relative shapes: exactly `memory/stats/skills.json`, and `memory/learnings/<name>.md` with `<name>` free of `/` (one level). The `docs/specs/*/` anchoring of the existing entries is untouched. Consequences that follow without further code: `open-round`'s dirty-tree guard (cycle.sh:1804-1820) skips those paths; `paperwork_only()` treats a commit touching only them as paperwork, so such a commit never stales an open round or a GREEN row. Nothing stages them; `ship-check` stage 03 and `scope-check` keep today's behaviour (A1).

### C3 - `close-story` on a self-marked `status: done` (story 01)
In `cmd_close_story` (cycle.sh:1480-1493), the `done` branch becomes: `DIRTY=$(git status --porcelain -- "$STORY" <every path from files_of "$STORY">)`; if `DIRTY` is empty, exit 2 `already done` exactly as today; if non-empty, append one journal line through the existing `journal.sh` mechanism - `close-story <id>: worker marked status: done itself, closing on the uncommitted diff` - then fall through to the normal path unchanged: `returned:` check (exit 4 unless `DONE`), `scope-check.sh`, `## Verification` x `repeat:`, staging of `files_of` + the story file, one `story(<id>): <title>` commit under `--commit`. The `status:` line is not rewritten on this path and not reverted on commit failure (it already says `done`; a second attempt takes the same path). `todo|in-progress` and the "anything else" branch are unchanged.

### C4 - taint rule, story-file form (story 01)
`taint_reason()` (cycle.sh:1145-1157) pattern 1, with `S` the regex-escaped slug, becomes two alternatives: `\bS-[0-9]{2}\.md\b` and `(docs/specs/)?\bS/S-[0-9]{2}\b` (with or without `.md`). A bare `S-NN` with neither `.md` nor the `S/` directory prefix is not taint. Patterns 2-4 (`plan.md`, `journal.md`, `council/`) are unchanged. Order and first-hit-wins are unchanged; the returned reason text for pattern 1 says `story file`.

### C5 - mutating verbs carry `status` (story 03; consumed by 04 and 05)
On **exit 0**, the last-line JSON of `branch`, `close-story`, `open-round`, `record-seat` and `judge` gains one key, `status`, whose value is byte-for-byte the object `cmd_status <spec>` prints (`status --json`: `spec, slug, stage, next, briefed, approved, branch, head, pack, stories, wave, wave_stories, round, ceiling, tier, open, court, missing, stale, verdict, review, red, round_dir, paused, shipped`), computed after every write the verb made *and after its `--commit`* (so `head` is the new commit). The top-level `next` of that JSON equals `status.next`. On any non-zero exit `status` is absent and `next`/`error` keep today's meaning (exit 4 `next: repair`, exit 3 `next: paused`, exit 6 escalate). Key order: `ok, verb, exit, next, error, status`. `status` itself, `briefed`, `escalate`, `reopen`, `claim`, `release`, `pause`, `resume` are unchanged. Implementation hint, not contract: lift the body of `cmd_status` (:278-451) into a `status_json <spec>` builder that both `cmd_status` and the five verbs call; still exactly one stdout JSON line per verb (tests/council.test.sh:178 `lines -eq 1` stays true for `status`).

### C6 - the driver's poll rule (story 04)
The loop keeps one status object `st`. It is obtained by `clerk("status <spec> --json")` (1) once before the first iteration, and (2) after any iteration whose action ran zero verbs, ran more than one verb (a `parallel()` fan-out: `build:<wave>` workers each closing through `close-story`; `dispatch:<seats>` each recorded through `record-seat`), or ran one verb whose result lacked `status` (any non-ok result, any verb from an older `cycle.sh`). After an iteration whose action was exactly one sequential verb whose result has `ok:true` and `status`, `st = res.status` and no poll is made. Everything the loop reads (`next`, `wave_stories`, `missing`, `round_dir`, `verdict`, `red`, `stage`) is read from `st` only. `Paused`, `BadLine`, the two-miss stop and every stop shape of ADR-001 D2 are unchanged. Steady Tier 3 round, one story, four seats, no re-asks: 13 clerk calls (A5), polls after `claim`, after `build:<wave>` and after `dispatch:<seats>`.

### C7 - worker agent lines (story 01)
`.claude/agents/worker-code.md` and `worker-test.md` each gain one sentence in the return step: `Never edit the story's status: line - close-story writes it (and a driver writes blocked); you write returned: only.` And `worker-code.md:18` reads `close-story reads this key; the driver never opens the story file` instead of `close-story and the driver read this key`.

## Tradeoffs
- **Ask 1, chosen:** retry once inside `clerk()` - the same shape the driver already uses for a MALFORMED seat report; no new file, no clerk change. **Rejected:** status-to-file - the Workflow runtime has no filesystem, so a file still reaches the driver only through a clerk relay of the same bytes; it moves the copy, it does not remove it.
- **Ask 2, chosen:** whitelist the two hook-written shapes in the one predicate (`is_paperwork_path`), the patch the mmorpg hive re-applies on every upgrade. **Rejected:** making a cycle verb stage them (anomaly-telemetry story 09's route) - the owner ruled `skills.json` not cycle-owned, and learnings are the librarian's; **rejected:** gitignoring - both files are meant to be committed.
- **Ask 3, chosen:** `close-story` tolerates the self-mark when the tree proves work is pending, and the journal records it; workers are told once not to write `status:`. **Rejected:** the driver treating exit 2 `already done` as success - the run would continue with the worker's edits uncommitted and unscoped, the exact state the defect left behind.
- **Ask 4, chosen:** one regex change - the leak is a path to a hidden file, and a bare id is synthesisable from the slug the seat is given. **Rejected:** exempting `run:` lines from the scan - round 6 also echoed the id in a `saw:` line, and line-type parsing widens the detector's code for no extra safety.
- **Ask 5, chosen:** each mutating verb embeds the full post-verb status object (A3); the driver polls only where it cannot know which of several parallel results is newest. **Rejected:** a flat subset of fields (drift and a `verdict` collision); **rejected:** dropping the post-parallel polls too by picking the last-returned result - clerk latency reorders promise resolution relative to command completion, so "last returned" is not "last written".

## Integration gate
`bash tests/council.test.sh && bash tests/driver.test.sh && bash tests/cycle.test.sh && git ls-files '*.sh' | xargs -n1 bash -n`; `bash scripts/wave-check.sh docs/specs/driver-hardening` before each dispatch.

## Open questions for the owner (approval stop)
1. A3 - nested `status` object (recommended) or a flat subset of the seven fields the driver reads?
2. A5 - three polls dropped per round, not a third of all calls. Acceptable as the delivered scope of ask 5?
3. A8 - ADR-011 plus ADR-001 pointers (recommended) or an ADR-001 amendment alone?

## Descoped

*(empty)*

## Plan deltas

<!--
The six lines below are the cycle's confirmation artifacts (docs/cycle.md).
-->
**Approved:** Andrei, 2026-09-15
**Briefed:** <written by scripts/cycle.sh briefed - stage 01+02 on the straight-through path. Alternative to **Approved:** above.>
**Branch:** vulyk/driver-hardening
**Checked:** <written by scripts/human-check.sh after the owner has looked - stage 05, and the override for stage 04+05.>
**Council:** GREEN round 1, 2026-09-15, at 8521d20, pack 92f41ba75c4c
**Shipped:** <written by scripts/ship-check.sh --record - stage 06: the published version, and where>
