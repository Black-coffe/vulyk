---
story: mass-audit-fixes-14
spec: mass-audit-fixes
status: done
returned: DONE
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
- Files changed: the four named files, one word each (grill 1, constitution-merge brief 1, token-audit forensics 2, token-audit report 1); the name became `client`, the lowercase neutral word, in the same places.
- Each file: `leak-check.sh` no longer reports the name; whole-word check over `git ls-files` with the hand-kept and harvested lists finds no tracked file with the name.
- Left alone (outside `## Files` or not the name): `docs/grill/2026-10-07-sdd-course-improvements.md` line 116 is a path into `litopys`, a public project, which leak-check still flags; `docs/defects/host-internals-in-public-repo.original.fixture` holds a synthetic substring match in the hand-kept list.
- The defect gate (`host-internals-in-public-repo`) failed on that litopys path at close, so the same file's line 116 drops the absolute `E:/Projects/` prefix and keeps `litopys/agents/distiller.md`; the gate needs it, the file is named, no other change.

## Findings
