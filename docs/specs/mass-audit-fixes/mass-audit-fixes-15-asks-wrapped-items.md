---
story: mass-audit-fixes-15
spec: mass-audit-fixes
status: done
returned: DONE
tier: 4
worker: worker-code
wave: 4
blocked_by: [mass-audit-fixes-10]
red: required
red_reason: a wrapped ask item reads as its first line only
red_verified_at: 2026-11-09T14:48:29Z 2e74f2965bcf7c65e67d13c5edacd600a87e082e6b01db0e8a33a2b352ce250d
---

# A wrapped `## Asks` item is read whole

## Goal
`lib.sh` `brief_asks` is the one `## Asks` parser (`trace-check.sh`, `cycle.sh` `briefed` and the repair
quote read it). Today a numbered item is its first line only: an item wrapped onto an indented second line loses
the rest, so every whole-item quote of it is reported "found in NEITHER", silently. On this spec all 31 quotes
failed that way until the Queen put each ask on one line. After this story an indented continuation line (one or
more leading spaces or a tab, non-empty, directly under a numbered item or its earlier continuation) joins that
item with one space; a blank line, a `>` line, a new `N. ` line or a `## ` heading ends it. The quoted-block
fallback (no numbered line) is unchanged. Blocked by story 10, which also edits `lib.sh` and `tests/cycle.test.sh`.

## Requirements
> 16. (Added by the Queen at planning on 2026-11-09, from a side agent's note the owner passed on; confirm at approval.) `brief_asks` keeps a wrapped `## Asks` item whole: an indented continuation line joins the numbered item above it, so `trace-check.sh` and `cycle.sh` read the full ask, not its first line.

## Files
- scripts/lib.sh
- tests/cycle.test.sh

## Non-goals
- Do not change `trace-check.sh` or `cycle.sh`; both already read `brief_asks` and gain the fix through it.
- Do not join `>` lines into a numbered item (the existing "its quoted copy" fixture stays as it is).
- Do not touch `tests/cycle.test.sh` outside `part gates`.

## Map slice
`memory/map/scripts.md` → `lib.sh` helpers; `memory/map/cycle.md` → briefed, trace-check.

## Acceptance criteria
- [ ] In `part gates`, a brief whose item 1 wraps onto an indented line gives `brief_asks` the joined item, and
  `trace-check.sh` accepts a story quoting the whole joined item (0 unfound). This assertion fails on today's
  `brief_asks` (the original case: a wrapped item, first line only).
- [ ] Neighbour form: an item followed by a blank line and then an indented line does not join it, and a
  tab-indented continuation joins like a space-indented one.
- [ ] The existing `brief_asks` fixtures in `part gates` pass unchanged.

## Verification
`bash tests/cycle.test.sh --part gates`

## Implementation notes
- scripts/lib.sh: brief_asks keeps an `open` flag after a numbered item; a `[[:blank:]]+`-indented non-empty line appends to num[n] with one space; any other line clears it, so blank, `>`, `N. ` and `## ` end the item.
- tests/cycle.test.sh (part gates): new qw fixture: space-wrapped item joined, trace-check 0 unfound on the joined quote, tab continuation joins, indented line after a blank does not.
- Decision: an unindented plain text line also ends an item (not listed in the story, the safe reading).

## Findings

## Red receipt
- command: bash tests/cycle.test.sh --part gates
- exit: 1
- tests: 2e74f2965bcf7c65e67d13c5edacd600a87e082e6b01db0e8a33a2b352ce250d (tests/cycle.test.sh)
- impl: 1d770a4a34edffa62a043ca7e33d7956e3b72dc9e9b31756374b461d97e90471
- stamped: 2026-11-09T14:48:29Z

```
::error::a wrapped ask item reads as its first line only: 1. the first ask|2. another ask|
ab-run-fixes-09: every verb's last JSON line carries now, the epoch seconds the driver checkpoint reads
  ok    an ok and a refused verb both carry an integer now within 5 s of the shell clock
G3 (mass-audit-fixes-08): scope-check drops a sibling's declared paths only for a not-done sibling of the same wave
  ok    a wave-1 edit of a file only a wave-2 todo story declares is out of scope
  ok    a same-wave sibling's file is still dropped: changed 2, out of scope 1
G4: a git mv of an out-of-scope file into a declared directory still counts the path it left
  ok    a rename into a declared dir reports out of scope 1
G8 (mass-audit-fixes-08): wave-check reports red-seals-impl when a red story seals its one implementation
  ok    a red story whose verification calls its one implementation script: red-seals-impl
  ok    a suite-only verification is no red-seals-impl
```
