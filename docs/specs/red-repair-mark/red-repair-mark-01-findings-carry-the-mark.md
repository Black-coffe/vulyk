---
story: red-repair-mark-01-findings-carry-the-mark
spec: red-repair-mark
status: todo
returned:
tier: 1
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: a prose-only repair carries red: required
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

## Findings
