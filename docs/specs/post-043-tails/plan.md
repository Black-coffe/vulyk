# Tails after 0.43.0 (plan)

**Tier:** 2 · **Spec slug:** `post-043-tails` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-025 (red receipt), ADR-023 (fast story checks), ADR-005 (installer contract, untouched here), docs/cycle.md (stage markers)
**Depends on:** 0.43.0 at `54276a5`; study `docs/specs/post-043-audit/report.md` (`15575a1`)

## Goal
Close the review tails of 0.42.0 and 0.43.0 and the paperwork that makes `/vulyk-status` show finished work as open.
Code: prompt-check's three code minors, a real-Python probe in the handoff hook, the frame order of trace-autopsy and a
load-proof speed check, and `state.sh` reading story fields from the frontmatter only. Paper: one sentence in
`docs/architecture.md`, `upgrade-keeps-host-edits` recorded as superseded by 0.29.0 through `ship-check.sh --record`,
`self-learning` given its 0.19.0 line. At ship, `drone-docs` brings the memory index and the three map slices back to
budget. Code and paper are separate stories, so only the code stories carry `red: required`.

## Assumptions
- prompt-check minor 1: each whitespace token of a backticked span, stripped of surrounding punctuation, is checked
  against `AGENT_SHAPE`; today's prompts must still pass (`prompt-check: ok`).
- prompt-check minor 2: a `cycle.sh` that exists with no `case "$VERB" in` block prints `prompt-check: warn` and the
  verb check is skipped; a warn never fails a run, as for an absent `telemetry.sh`/`architecture.md`.
- prompt-check minor 3 (owner: «Отказ со своей причиной»): in `close-story`, rc 1 with no `^prompt-check: error ` line
  is a crash; the story is refused (exit 4) with the reason `prompt-check crashed: <last output line>`, never an empty one.
- handoff.sh: each candidate is probed with `"$PY" -c ''` before `exec`; a failing probe (the Windows Store stub,
  exit 49) moves to the next name; no working Python keeps today's `exit 0`.
- trace-autopsy: only the frames of the Python traceback are reversed (innermost first); `path:N`, bash and Node
  frames keep their written order after them.
- speed check: the best of three runs stays under the same 1000 ms; the threshold is not raised.
- state.sh: `story:`, `status:`, `wave:`, `tier:` are read from the leading `---` frontmatter block only; a file
  whose frontmatter has no `story:` is not a story. Shipped specs keep their stages (`tests/cycle.test.sh` 06-shipped case).
- upgrade-keeps-host-edits: `**Approved:**` stays the placeholder (it was never approved; filling it would write the
  owner's word). Story 01 gets `status: done` with an implementation note naming `5239eb0`;
  `bash scripts/ship-check.sh --record docs/specs/upgrade-keeps-host-edits 0.29.0 "superseded: built in 0.29.0 by 5239eb0 (hive-feedback-2026-10) outside this spec; never approved"`.
  `--record` stamps today's date and HEAD; the note carries the real commit.
- self-learning: `bash scripts/ship-check.sh --record docs/specs/self-learning 0.19.0 "recorded late: merged b6d61e9 on 2026-09-27"`.
- Both `--record` rows land in `memory/stats/ship.jsonl`, a ledger nothing aggregates (only `ship-check.sh` writes it).
- `memory/memory.md` is 62 lines today, over the asked 60: the `drone-docs` pass trims as well as adds.
- Story 01 carries five fixes and one receipt (ADR-025: one test per marked story). A side-agent note (model text,
  not an owner quote) pointed out four would go unproven; owner, 2026-10-28, chose «Штамп на state.sh + запись»:
  the receipt is on `state.sh`, all five tests are written before code, and the other four failure lines from the
  same `stamp-red` run go into the story's `## Implementation notes` for the reviewer. Rejected: five stories with
  a stamp each (over the Tier 2 cap of three); keeping the receipt on the drone-ghost case (no live prompt hits it).
- Story 02's receipt is on the frame order; the speed-check change is test-only and has nothing to turn red.
- Known wave-check noise, accepted: `verify-gap` on 03. No suite reads spec paperwork; `tests/maintenance.test.sh`
  runs prompt-check over the repo, which parses `docs/architecture.md`'s keeper sentence, so it can fail for the one
  code-adjacent edit. The other acceptance lines are checked by reading `state.json` and the two plan files.
- trace-check: 5 owner lines uncovered are the slicing instructions (items 1-3 of the request), carried by the
  story split, the closure method and the `## At ship` section, not by a story quote.

## Stories

**Wave 1**
- `post-043-tails-01-prompt-check-state-handoff` — prompt-check minors 1-3, `state.sh` frontmatter-only, handoff.sh Python probe (`red: required`)
- `post-043-tails-02-trace-order` — trace-autopsy frame order and the best-of-three speed check (`red: required`)

**Wave 2**
- `post-043-tails-03-paperwork` — «Those four» in architecture.md; upgrade-keeps-host-edits superseded; self-learning 0.19.0 (no red)

## Contracts
none

## Integration gate
`bash tests/full-suite.sh`

## At ship: the drone-docs pass (ask 6)
`/vulyk-ship` dispatches `drone-docs` with this task, verbatim:
- `memory/memory.md`: `## Learnings` lines for ADR-022 (horizon step), ADR-023 (fast story checks, one full suite per
  round), ADR-024 (no reliance on background commands in subagents); `drone-horizon`, `scripts/trace-autopsy.sh` and
  `scripts/prompt-check.sh` named where a reader would look (a `## Verification` line for `bash scripts/prompt-check.sh`);
  the file stays at or under 60 lines (62 today: merge or drop the oldest pointers to keep the budget).
- ADR-024 referenced in `memory/map/agents-and-commands.md` at `lead-review`'s suite step.
- `memory/map/scripts.md` (116), `memory/map/cycle.md` (153), `memory/map/agents-and-commands.md` (141) trimmed back
  to about 80 lines each, keeping contracts and gotchas, dropping what the code or ADRs already say; `last-verified`
  updated. `scripts.md` may also add `acceptance-log.sh` and `leak-check.sh` if the budget allows.

## Descoped

*(empty)*

## Plan deltas

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
**Approved:** Andrei, 2026-10-28 («да»)
**Briefed:** <written by scripts/cycle.sh briefed - stage 01+02 on the straight-through path (--go, Tier 1): "via grill, <owner>, <date>" (or "via grill (assumed)" / "via mini-brief"). Alternative to **Approved:** above.>
**Branch:** vulyk/post-043-tails
**Council:** RED round 1, 2026-10-28, at efaf1af, pack b83a52b31a38
**Shipped:** <written by scripts/ship-check.sh --record - stage 06: the published version, and where>
**Checked:** ACCEPTED by Andrei, 2026-10-28, at b188b8a - narrow repair of round-1 major 1 (handoff.sh single python start, b188b8a): reviewer repro telemetry --part scan 164/0, maintenance/cycle/symbol-map green; owner chose ACCEPTED without round 2
