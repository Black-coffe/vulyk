# Report: post-043-audit

**Date:** 2026-10-28 · **HEAD:** `54276a5` (0.43.0) · study work, read only, no tests run.

## 1. prompt-check: four minors left for the next circle

There is no `next-circle.md` in `docs/specs/prompt-check/`. The four are the round-1 minors of
`council/round-1/review.md:11-14`, named as left for the next circle in `plan.md:77-78`. Verbatim:

> - scripts/prompt-check.py:163 an agent name is only recognised when it is the whole backticked span, so `` `Agent drone-ghost` `` passes (no such span exists in today's prompts; the plan said "a backticked token")
> - scripts/prompt-check.py:69 when `scripts/cycle.sh` has no `case "$VERB" in` block the verb check is skipped silently instead of a `warn` like the absent `telemetry.sh`/`architecture.md` cases
> - scripts/cycle.sh:2347 a python traceback exits 1 and is reported as a blocking finding with an empty `error` field in the JSON line; a `prompt-check: error` line missing from a rc=1 output deserves its own note
> - docs/architecture.md:23 "Those four keep it" now follows a sentence naming five agents (pre-existing wording, out of scope)

All four still hold at HEAD; line numbers moved after repair round 1:
- 1 -> `scripts/prompt-check.py:181` (`re.match(r"^[a-z][a-z0-9-]*$", word)` on the whole span).
- 2 -> `scripts/prompt-check.py:67-68` returns `None`, `:198` skips on `verbs is not None`, no warn.
- 3 -> `scripts/cycle.sh:2347-2351`: any rc 1 is a finding; the emitted reason is `grep -m1 '^prompt-check: error '`, empty on a traceback.
- 4 -> `docs/architecture.md:21-23`: five agents named, "Those four keep it".

Round 2's one minor (`## Descoped` empty) is closed: `plan.md` `## Descoped` now carries the hive narrowing.

Other open review tails found on the way:
- trace-autopsy round-1 minors 1 and 4 (`council/round-1/review.md`); 2 and 3 were fixed in `c73c3fa` (`plan.md:70`):
  - `scripts/trace-autopsy.py:268`: a `most recent call last` line reverses every frame, so `path:N` frames after the traceback take the three slots.
  - `tests/symbol-map.test.sh:442`: the `< 1000 ms` wall-clock check depends on host load and GNU `date +%s%N`.
- `docs/specs/upgrade-keeps-host-edits/plan.md:47-49` (next circle): `.claude/hooks/handoff.sh:9-11` still picks `python3` by
  `command -v` and `exec`s it; on Windows that can be the Store stub (exit 49), which breaks the hook's fail-open.
  The other item there (a new hook wired around a hive's launcher) is done: `install.sh:725-744` copies the sibling's head and tail.

## 2. Specs with a plan.md and no `**Shipped:**`

Specs with only `brief.md`/`report.md` (study work: architecture-passport, cache-economy, fable-budget, hindsight-memory,
hive-feedback-2026-10, opus-5-5-ladder, ponytail-adoption, rrsi-self-improvement, software-factory-study,
sonnet-5-5-ladder, token-audit) need no ship line. Every spec that has `**Shipped:**` has no story left open.

### A. Code not written: needs `/vulyk-build`
| Spec | Approved | Stories | Evidence the code is absent |
|---|---|---|---|
| `constitution-merge` | Andrei, 2026-10-08 (`journal.md`) | 01-03, all `status: todo`, Tier 2 | no `scripts/constitution-merge.sh`, no `tests/constitution.test.sh`; CHANGELOG 0.26.0 still says "carry the line over by hand until the constitution merge lands" (`CHANGELOG.md:614`) |
| `handoff-ownership` | Andrei, 2026-10-13 | 01 `status: todo`, Tier 2 | no `scripts/handoff-owner.sh`; no `skillOverrides` in `install.sh` or `scripts/` |

Both plans are 2-3 weeks old (0.26 era): `install.sh`, `/vulyk-update` and ADR-005 changed since (0.29 host-edit merge,
0.39.1 suite-row rename). Re-check the stories' `## Files` and line refs against HEAD before building.

### B. Code shipped, paperwork not closed
| Spec | Where the code is | What is missing |
|---|---|---|
| `upgrade-keeps-host-edits` | built outside the spec in 0.29.0: `5239eb0` "fix(install): an upgrade replaces release copies only...", `CHANGELOG.md:415-417`, `install.sh:111-201` (`merged edit`, `kept + new`, `kept deleted`) | `**Approved:**` is the template placeholder (`plan.md:57`), story 01 `status: todo`; never approved, so a `**Shipped:**` line would be invented: close it as superseded by 0.29.0 |
| `self-learning` | 0.19.0 (`CHANGELOG.md` [0.19.0], merge `b6d61e9`) | old-format plan (no cycle markers, no stories); `status: block` is a schema line in `contract.md:13`, not a story |

### Neither
- `autopilot-merge`: the 2026-08-16 integration roadmap, shipped in slices 0.5.0-0.9.1 (`CHANGELOG.md:1630-2050`); a design document with no stories, not a cycle spec.

## 3. memory/map against 0.35.0-0.43.0

Checked mechanically: every `cycle.sh` dispatcher verb appears in `memory/map/cycle.md` (`stamp-red` included); every
`.claude/agents/*.md` appears in `agents-and-commands.md` (`drone-horizon` included); `symbol-map`, `trace-autopsy`,
`prompt-check` (`.sh` and `.py`), `tests/full-suite.sh`, `verdict_stale`, `red-no-test`, `red-value`, `verify-round-only`,
`memory-triage.sh --mark/--dir`, `--exact`, `--part`, `fable_limit_fallback` are in `scripts.md`/`cycle.md`.

Missing:
- `memory/memory.md` (the index): no `## Learnings` line for ADR-022 (horizon), ADR-023 (fast checks) or ADR-024
  (no background commands in subagents); no `## Verification` line for `bash scripts/prompt-check.sh`; `drone-horizon`,
  `trace-autopsy`, `prompt-check` named nowhere in it.
- ADR-024 is referenced by no slice (it bounds `lead-review`'s suite step, `agents-and-commands.md`).
- `scripts.md` lacks `acceptance-log.sh` (0.8.0) and `leak-check.sh` (0.26.2): older than 0.35, listed for completeness.
- Size: `scripts.md` 116, `cycle.md` 153, `agents-and-commands.md` 141 lines against the ~80-line cap; the slices say so
  in their own `last-verified` lines.

`memory/` is written only by `drone-docs` and `librarian` (constitution), so these are a `drone-docs` dispatch, not a hand edit.

## Not read or run
No test, no script run beyond `grep`/`git`. Journals read only at their tail. Story bodies of `constitution-merge` and
`handoff-ownership` read for `## Files` only, not checked line by line against HEAD.

## Options

1. **(Recommended) One `post-043-tails` at Tier 2 plus two separate builds.** Tails are small, one or two files each,
   and share no design fork; the two approved specs are features with their own asks and stale plans.
   - `post-043-tails`: prompt-check minors 1-4; trace-autopsy minors 1 and 4; `handoff.sh` Store-stub check;
     close `upgrade-keeps-host-edits` as superseded and give `self-learning` its 0.19.0 line; a `drone-docs` pass for
     the index and ADR-024 at ship.
   - `/vulyk-build handoff-ownership` and `/vulyk-build constitution-merge`, each after a plan refresh against HEAD.
2. Fold everything into one spec: rejected, `constitution-merge` alone is three stories and a merge algorithm; a RED
   on it would hold the one-line tails hostage.
3. Build the two approved specs as they stand: rejected, their `## Files` and line refs predate 0.29-0.43 changes to
   `install.sh` and `/vulyk-update`.

## Candidate stories (not cut)
- post-043-tails-01: `scripts/prompt-check.py` + `scripts/cycle.sh` close-story branch + `docs/architecture.md` (minors 1-4).
- post-043-tails-02: `scripts/trace-autopsy.py` frame order; `tests/symbol-map.test.sh` timing check (minors 1, 4).
- post-043-tails-03: `.claude/hooks/handoff.sh` runs `"$PY" -c ''` before `exec`.
- post-043-tails-04 (paperwork): `upgrade-keeps-host-edits` superseded note, `self-learning` shipped note.
- Separate: refresh + build `handoff-ownership`; refresh + build `constitution-merge`.
