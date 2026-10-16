# close-story refuses an edit outside ## Files (plan)

**Tier:** 1 · **Spec slug:** `close-story-scope-refusal` · **Brief:** [brief.md](brief.md)
**Governed by:** Law 3 (no out-of-scope edits), ADR-013 D5 (`dirty_outside_paperwork`, the predicate open-round and claim share)
**Depends on:** `df38b8d` (scope-check no longer counts its own `memory/stats/scope.jsonl`)

## Goal
`close-story --commit` stops leaving a dirty tree behind. When the story's diff touches a path that `scope-check.sh`
counts out of scope and that `dirty_outside_paperwork` would also report, close-story exits 4 (`repair`) before
verification and before any commit, listing those paths and what to do: revert them, or return NEEDS_CONTEXT naming
them. The worker meets it in its own turn; open-round no longer meets it hours later.

## Assumptions
- Only with `--commit`. Without it nothing is committed and the tree is meant to stay dirty, so the refusal has no
  failure to prevent; scope-check still records the breach as today.
- The refused set is the intersection: an out-of-scope path that is paperwork (`is_paperwork_path`, e.g.
  `memory/stats/skills.json`) never stops a story, since open-round would not stop on it either. A wave sibling's
  declared files are already left out by scope-check.
- The check runs right after scope-check, before verification, so a refusal costs seconds, and the story's status
  and files stay as they were.
- scope-check itself keeps recording and never blocks (its header says "neither is decided here"); the decision lives
  in close-story.

## Stories

**Wave 1**
- `close-story-scope-refusal-01` — the refusal in `cmd_close_story`, cases in `tests/cycle.test.sh`, the exit-4 line
  of both worker agents

## Contracts
- stderr: `cycle: close-story - edited outside ## Files: <path>[, <path>...] - revert them, or return NEEDS_CONTEXT naming them`
- JSON: `emit false close-story 4 repair "edited outside ## Files: <paths>"`

## Integration gate
`bash tests/cycle.test.sh` · `git ls-files '*.sh' | xargs -n1 bash -n`

## Descoped

*(empty)*

## Plan deltas

**Approved:** <owner, date - the approval stop>
**Briefed:** via mini-brief, Andrei, 2026-10-16
**Branch:** vulyk/close-story-scope-refusal
**Checked:** <written by scripts/human-check.sh after the owner has looked>
**Council:** ESCALATE round 1, 2026-10-16, at e2d0ad6, pack a0812d9f8d03
**Shipped:** <written by scripts/ship-check.sh --record>

## Needs a human
- reason: ceiling · round 1 · 2026-10-16
- seats: docs/specs/close-story-scope-refusal/council/round-1/
