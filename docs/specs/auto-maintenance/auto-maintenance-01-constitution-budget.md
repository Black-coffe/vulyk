---
story: auto-maintenance-01
spec: auto-maintenance
status: todo
returned:
tier: 2
worker: worker-code
model: sonnet
wave: 1
blocked_by: []
---

# Constitution within budget, held by a failing test (asks 2, 6)

## Goal
CLAUDE.md is at or under ADR-013 D7's cap (7 168 bytes and 120 lines, measured CR-stripped) and a new
`tests/maintenance.test.sh` fails when it is not. The test also caps the summed `description:` lines of
agents and commands (they sit in every session's context) at today's value. The checker is proven on
fixtures: the original case (8 531 B) and a neighbour form (bytes in budget, 121 lines) both fail.

## Requirements
> (2) тест размера всегда загружаемых файлов, который падает при превышении

> 2. Добавить тест размера всегда загружаемых файлов, который падает при превышении.

> Нужно убрать около 1,4 KB. Раздел Commands занимает 2 835 байт, и большая его часть — пояснения, которые нужны только в репо Вулика.

## Files
- CLAUDE.md
- tests/maintenance.test.sh

## Non-goals
- Do not touch the Laws, Routing, Models or Secrets wording; the cut comes from the Commands block's explanatory prose and table rows that can merge.
- Do not move the cut text into a new doc; what the Commands block loses is either redundant with the rows or with `docs/command-reference.md`.
- Do not cap the owner's global `~/.claude/CLAUDE.md` or auto-memory: VULYK does not own them.

## Map slice
`memory/map/agents-and-commands.md` - the constitution rows.

## Acceptance criteria
- [ ] `tr -d '\r' < CLAUDE.md | wc -c` ≤ 7168 and `wc -l` ≤ 120.
- [ ] Both VULYK marker pairs survive intact and a `bash tests/maintenance.test.sh` row sits in the Commands table.
- [ ] `bash tests/maintenance.test.sh` exits 0 on this tree, and exits non-zero when pointed at the 8 531 B fixture or the 121-line fixture.
- [ ] The descriptions cap equals today's measured sum; growth fails the test.

## Verification
`bash tests/maintenance.test.sh`

## Implementation notes

## Findings
