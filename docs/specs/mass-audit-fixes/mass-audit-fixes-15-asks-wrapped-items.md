---
story: mass-audit-fixes-15
spec: mass-audit-fixes
status: todo
returned:
tier: 4
worker: worker-code
wave: 4
blocked_by: [mass-audit-fixes-10]
red: required
red_reason: a wrapped ask item reads as its first line only
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

## Findings
