---
story: mass-audit-fixes-14
spec: mass-audit-fixes
status: todo
returned:
tier: 4
worker: worker-code
model: haiku
wave: 4
blocked_by: []
---

# The client's folder name leaves the four public files

## Goal
The four places in the current tree where the client's folder name still appears are rewritten with a neutral
word (the same neutral style the merge used for `X-07`), without changing any behaviour, test
assertion or link target. History is not rewritten here: that follows after this release reaches the hives
(brief `## Answers` 1). `model: haiku`: a routine, mechanical text replacement in named files.

The four files were filled in by the Queen from the private list (they are docs, no test owns them).

## Requirements
> 15. The client's folder name is removed from the current public files (four places); rewriting history is left for after this release reaches the hives.

## Files
- docs/grill/2026-10-07-sdd-course-improvements.md
- docs/specs/constitution-merge/brief.md
- docs/specs/token-audit/evidence/forensics.md
- docs/specs/token-audit/report.md

(Filled by the Queen from the private list; none of the four is named by another story. The name itself
stays out of this file: `bash scripts/leak-check.sh <file>` finds it.)

## Non-goals
- Do not rewrite git history, tags or commit subjects (after the release, by the owner's decision).
- Do not touch the private audit files or the owner's allow-list; they are outside the repo.
- Do not change a test's assertion text beyond the name itself; if a fixture path carries the name, rename the
  fixture and every reference in the same file.

## Map slice
None needed; the change is a word in four named files.

## Acceptance criteria
- [ ] `bash scripts/leak-check.sh <each of the four files>` reports no hit for the name, and the Queen's own
  grep for the name over `git ls-files` returns nothing (she runs it; the term stays out of this file).
- [ ] Every test the four files belong to still passes.

## Verification
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes

## Findings
