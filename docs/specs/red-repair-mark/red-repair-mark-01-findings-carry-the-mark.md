---
story: red-repair-mark-01-findings-carry-the-mark
spec: red-repair-mark
status: done
returned: DONE
tier: 1
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: a prose-only repair carries red: required
red_verified_at: 2026-10-28T12:46:26Z c15b5bcf77811218cbed0fef7f54480325cd8a1742c39d1adeea4c4b355c6a66
---

# Repair mark follows the findings; `red` read from the frontmatter

## Goal
`cycle.sh repair`, on a spec with a done marked story, writes the repair unmarked (byte for byte as before
0.40.0) only when every `## Findings` line names a path of the repair's `## Files` union and none names a
marked story's path; a finding with no such path, or no findings at all, keeps the mark. `stamp-red`,
`close-story` and `wave-check` read `red:` from the frontmatter only, so a body line `red: ...` marks nothing.

## Requirements
> 1. A repair of a spec with a marked story is written unmarked, as before 0.40.0, only when every one of its RED findings names a file and none names a file from a marked story's `## Files`; a finding that names no file keeps the mark.
> 2. A `red:` line in a story's body, outside its frontmatter, neither marks the story for `stamp-red`/`close-story` nor raises a `wave-check` red line.

## Files
- scripts/cycle.sh
- scripts/wave-check.sh
- tests/cycle.test.sh
- docs/adr/025-red-receipt.md
- CHANGELOG.md

## Non-goals
- Do not change `fm_field` itself or its other callers; only the three `red` reads move to `fm_raw`.
- Do not touch the other leftovers of red-receipt round 1 (`red_reason` length, worker-test sibling, sealed
  fixtures, hand-forged receipt): they are the next circle's.
- No new verb, flag or worker-prompt change.

## Map slice
memory/map/cycle.md: "Red receipt (0.40.0, ADR-025)" and `repair`; memory/map/scripts.md: wave-check.

## Acceptance criteria
- [ ] A spec with a done marked story and RED findings that all name an unmarked story's file (a doc) gets an unmarked repair, frontmatter byte for byte as an unmarked union.
- [ ] A RED finding naming a marked story's file still gets `red: required` and an empty `red_reason:`.
- [ ] A RED finding that names no file (`[ask 1] ask 1 broke`) keeps `red: required`, even beside an anchored prose finding.
- [ ] A story with no `red:` in its frontmatter and a body line `red: required` is neither gated by `close-story` nor refused as marked by `stamp-red`, and `wave-check` prints no `red-` line for it.
- [ ] ADR-025 D4 states the new rule and the named bypass; CHANGELOG has a 0.40.1 Fixed entry.

## Verification
`git ls-files '*.sh' | xargs -n1 bash -n`
`bash tests/cycle.test.sh`

## Implementation notes
- scripts/cycle.sh: `fm_red` (frontmatter-only `red:`, cut at `#` as fm_field cut it) replaces the three `fm_field … red`
  reads; `repair_unmarks` decides the repair's mark; `cmd_repair` now builds the `## Findings` text once, before the
  frontmatter, and prints the same lines in the same order.
- scripts/wave-check.sh: the red block opens only on a `red:` line inside the frontmatter (awk).
- tests/cycle.test.sh: three repair cases (prose-only unmarked, marked file kept, no-file finding kept) and the body
  `red:` line for wave-check, stamp-red and close-story.
- Re-stamp, with the owner's yes: after the first stamp the body-line fixture was found to land inside
  `## Verification` (close-story read it as a command). The fixture line moved under the title; the receipt was
  re-taken with cycle.sh and wave-check.sh restored to HEAD (0.40.0) from `git show`, then the new code copied back
  unchanged (sha256 checked). The `impl:` hash of both stamps is the same, 4e2280a2.

## Findings

## Red receipt
- command: bash tests/cycle.test.sh
- exit: 1
- tests: c15b5bcf77811218cbed0fef7f54480325cd8a1742c39d1adeea4c4b355c6a66 (tests/cycle.test.sh)
- impl: 4e2280a2f6db80181f5e49ff8ffd9283b69cabd75e2c987f743f7469938858e4
- stamped: 2026-10-28T12:46:26Z

```
red-receipt: an unmarked story built from templates/story.md closes as before
  ok    the template story closes and commits, no receipt asked
red-receipt: close-story on a marked story - the sealed test edited, no implementation change, then a real change closes
  ok    red-12 stamped
  ok    a sealed test edited after the stamp: exit 4
  ok    the implementation unchanged since the stamp: exit 4
  ok    receipt + changed implementation + green: closed, the receipt in the commit
red-receipt: close-story on a marked story that was never stamped
  ok    the unstamped story: exit 4, nothing committed
  ok    the refusal names stamp-red and the story
```
