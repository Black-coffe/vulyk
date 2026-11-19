# docs-1115 - doc contradictions (plan)

**Tier:** 1 · **Spec slug:** `docs-1115` · **Brief:** [brief.md](brief.md)
**Model profile:** opus-builds
**Governed by:** the owner's 2026-11-17 rule for this repo (two rounds at most, checks sized to the change, Fable and
Opus only); card `outward-artifact-carries-internals`; no concrete bypass spelling in any doc.
**Depends on:** `main` at 0.54.0-dev.5 (guards-1115, tails-1115 merged).

## Goal
Bring the docs, README, wiki and map slices in line with the code at HEAD for the inventory's docs-only items and the
doc lines the two code specs handed on, so the public 0.54.0 ships docs that describe it. The Queen builds it herself
(Tier 1, one story); one Fable reviewer judges it; the docs tests run, the full suite once before merge.

## Assumptions
- Item numbers resolve in the private `tails.md`; an item already fixed at HEAD is closed with a one-line note.
- `memory/map/` lines are written through `drone-docs` dispatched with `model: opus` (workers and the Queen do not
  edit `memory/` by hand); every other file the Queen edits directly.
- T88 and T99 follow the owner's A10 and A11 exactly; T91 takes one wording for the `memory/memory.md` contract
  (who writes it: drone-docs and the librarian; a hint to verify), the cap line matched to the file.
- No publish: the ship step merges locally and rolls the hives; the GitHub push and tag wait for the owner's word.

## Stories
**Wave 1**
- `docs-1115-01-doc-contradictions` — every named doc sentence matches the code; the handed-on map and command lines.

## Contracts
none

## Integration gate
`bash tests/full-suite.sh`

## Descoped

## Plan deltas

**Approved:** <Tier 1 runs straight through>
**Briefed:** via mini-brief, Andrei, 2026-11-18
**Branch:** vulyk/docs-1115
**Council:** ESCALATE round 1, 2026-11-18, at 3ff53718, pack 48c9ac58f82d

## Needs a human
- reason: ceiling · round 1 · 2026-11-18
- ask 1: BLOCK by the reviewer - see docs/specs/docs-1115/council/round-1/review.md
- ask 2: BLOCK by the reviewer - see docs/specs/docs-1115/council/round-1/review.md
- seats: docs/specs/docs-1115/council/round-1/
**Checked:** ACCEPTED by Andrei, 2026-11-18, at 206bc402 - Принимаю (Рекомендую)
**Shipped:** 0.54.0-dev.6, 2026-11-18, at fe058bf5 - merged to main (local) after the owner's ACCEPTED; branch CI skipped on the owner's override for this spec (origin public); 6 hives on dev.6, 9 held; public 0.54.0 pending solo-gate-1118, a real hive build, outward review and the owner's word
