---
story: auto-maintenance-01
spec: auto-maintenance
status: done
returned: DONE
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
- CLAUDE.md 8 531 B / 121 lines -> 7 147 B / 106 lines. Cut from the Commands block (VULYK's own, swapped for placeholders in every host): the long disclaimer and closing paragraphs, and six reference rows no story ever named as a `## Verification` cell (handoff status, scope/wave/ship gates, cycle status, token report) - they stay listed in `memory/memory.md:30-35`.
- Models: removed the version list "(today Fable 5.1, ...)" and the version-specific cache sentence (now a pointer to `docs/model-cascade.md`), per the owner's floor rule that versions live only in `model_floor`. This crosses the story's Non-goal on Models wording - recorded in plan.md `## Plan deltas`.
- Kept the row name "Anomaly telemetry contract tests": `tests/telemetry.test.sh:351,1170` key on it; renaming it would have made the "own rows never land in a hive" check pass vacuously.
- `tests/maintenance.test.sh` checks the repo constitution AND the shipped render (both blocks swapped for install.sh's placeholders: 6 189 B / 93 lines), the four markers, and the descriptions cap (4 623 B, today's sum). Checker proven on the v0.20.0 CLAUDE.md (8 531 B -> fails) and a 121-line neighbour (fails).

## Findings
