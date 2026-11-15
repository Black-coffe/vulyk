# owner-guard must not block committing a record human-check already wrote (plan)

**Tier:** 1 · **Spec slug:** `owner-guard-commit-fp` · **Brief:** [brief.md](brief.md)
**Model profile:** opus-builds
**Governed by:** card `owner-words-by-builder`; spec audit-fixes-1113 contract O1
**Depends on:** 0.53.0-dev.1 (local main, e7dc1bce)

## Goal
The owner guard judges what a shell command does to `memory/stats/human.jsonl`, not whether the text of the
command mentions it: a write into the file is still guarded, a `git add` / `git commit` / read / text that only names
the path passes.

## Assumptions
<!-- Law 1: every assumption the plan rests on, stated so the owner can veto it at the approval
stop. -->
- The write forms are the ones the guard already lists for plan.md rewrites (redirect, tee, cp/mv, interpreter,
  sed/awk -i); the same reader serves both.

## Stories
<!-- One line per story, grouped by wave; the story files are the truth, this is their index.
Tier 1-2 (solo): the Queen builds the stories herself, in order, and one reviewer judges each round.
Tier 3-4 (hive): one worker per story; a wave's workers run in parallel, so their ## Files are
disjoint. A story earns its own worker only when it can run in parallel; fewer, larger stories are
cheaper. -->

**Wave 1**
- `owner-guard-commit-fp-01` — a human.jsonl row counts as written only by a command that writes the file

## Contracts
<!--
Tier 3-4: interfaces that cross a story boundary, agreed here at plan time - function signatures,
message shapes, route paths, event names - so two workers building against each other read the same
contract. A worker whose story forces a change reports it in its INTERFACES line; the Queen updates
this section and records it under ## Plan deltas. Tier 1-2: usually "none".
-->
- none

## Integration gate
<!-- The full quiet suite: the constitution's `round-only` row from ## Commands. It runs once per round
via `cycle.sh suite`, step by step, each part capped at 300 s; a red part (at its cap) is cut, not escalated.
wave-check.sh runs before each wave. -->
`bash tests/full-suite.sh`

## Descoped
<!-- Mid-build narrowing, appended as it happens - never silent. Each line: what was dropped, why,
and the owner's line authorizing it, quoted. Only the owner removes a requirement. The same commit
strikes or narrows the ask in brief.md's ## Asks: the blind seats read only the brief, and
`cycle.sh open-round` refuses a descope the brief has not taken in. -->

*(empty)*

## Plan deltas

- 2026-11-14/15, after the round-1 BLOCK and four automated security scans: the detect-a-write rule missed write
  forms, so the rule is deny by default with a short safe-form list. Regex parsing of heredoc bodies kept opening
  parser gaps, so any heredoc or here-string in a command naming the record counts as a write: ask 1's "text that
  only names the path passes" holds for echo, printf and commit messages, not for heredocs (that text goes through
  the Write tool). The owner chose a review-only re-check of the diff, then his acceptance.
- 2026-11-15, review-only re-check at 56ec89b7: BLOCK (.vulyk/reports/owner-guard-commit-fp/recheck/review.md):
  the allowlist still refused real commits (multi-line messages with a trailer, `2>&1`, `|| true`, quoted `>`) and
  let some writes through; details (moved to a private file before publishing).
  Shell-text parsing does not converge. Owner decision (option label, the agent's wording; cross-checked with
  Fable): «Строгое правило + коммит внутри скрипта (Рекомендую)». Next, in a fresh session:
  1. `owner-guard.sh`: restore the record rule of bc962e77 (a command naming the record and holding a verdict
     word is a write); keep `writes_record`'s found bypasses as deny fixtures in `tests/defects.test.sh`.
  2. `scripts/human-check.sh --commit`: the script commits its own `plan.md` line and record row with
     `git commit -- <those paths>` only, so no agent command ever names the record with a verdict word.
  3. Callers (`/vulyk-build`, `/vulyk-ship`, docs) use `--commit`; the brief's ask 1 is rewritten to this
     design with the owner's words; integrity of a row is checked where it is read, in a later spec.

<!--
One entry per change to the plan after approval - a new story, expanded story files, a changed
contract - written from a return report, never from a diff: date, trigger, decision, what was
rejected. Tell the owner in one line when it happens. trace-check.sh accepts these entries as a quote
source for stories cut after approval. /vulyk-ship hands them to librarian for an ADR harvest.
-->

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
**Approved:** <owner, date - stage 02, the unconditional gate. /vulyk-build refuses without this line.>
**Briefed:** via mini-brief, Andrei, 2026-11-14
**Branch:** vulyk/owner-guard-commit-fp
**Council:** ESCALATE round 1, 2026-11-14, at db39ef68, pack 3a8a9b920fb6
**Shipped:** <written by scripts/ship-check.sh --record - stage 06: the published version, and where>

## Needs a human
- reason: ceiling · round 1 · 2026-11-14
- ask 1: BLOCK by the reviewer - see docs/specs/owner-guard-commit-fp/council/round-1/review.md
- seats: docs/specs/owner-guard-commit-fp/council/round-1/
**Checked:** ACCEPTED by Andrei, 2026-11-15, at 03b3cbbe - owner picked «Принимаю owner-guard-commit-fp (Рекомендую)» after the diff in the reply
