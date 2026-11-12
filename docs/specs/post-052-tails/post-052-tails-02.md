---
story: post-052-tails-02
spec: post-052-tails
status: todo
returned:
tier: 2
worker: worker-code
wave: 2
blocked_by: [post-052-tails-01]
---

# Map slices back in shape; ADR-033 accepted

## Goal
The `0.50 command changes (ADR-032)` bullet is back in `agents-and-commands.md`. `scripts.md` (162 lines) is split
by sub-area into 2-3 slices of at most 80 lines each (hooks, install.sh, the other scripts), with no fact dropped and
`memory/memory.md` pointing at each. A maintenance check keeps every `memory/map/scripts*.md` slice <= 80 lines.
ADR-033 reads `Status: accepted` with the owner and the approval date. Map files are written by `drone-docs`,
dispatched by the Queen with this story, then checked against the old slice bullet by bullet.

## Requirements
> drone-docs, чтобы уложиться в лимит, удалил из карты пункт про изменения команд 0.50 (ADR-032); стоит вернуть;
> карта scripts.md по-прежнему примерно 160 строк при лимите около 80;
> ADR-033 «локальные ульи — бета-канал» записан в статусе proposed, его нужно подтвердить;

## Files
- memory/map/agents-and-commands.md
- memory/map/scripts.md
- memory/map/scripts-hooks.md
- memory/map/scripts-install.md
- memory/memory.md
- docs/adr/033-local-hives-are-the-beta-channel.md
- tests/maintenance.test.sh

## Non-goals
- Do not trim `agents-and-commands.md` or `cycle.md` to the cap (not asked).
- Do not fill ADR-033's "Not recorded" sections (the owner: accept as is).
- Do not reword map facts while moving them; refresh only what the code contradicts.

## Map slice
`memory/map/README.md`; `memory/map/scripts.md` whole (it is the thing being split)

## Acceptance criteria
- [ ] `agents-and-commands.md` holds the ADR-032 bullet removed in ba53f294, text as it was.
- [ ] Every `memory/map/scripts*.md` is <= 80 lines and has its own `last-verified:` line; every bullet of the old `scripts.md` is found in one of them (checked by diffing the old bullet heads against the new files).
- [ ] `memory/memory.md` `## Codebase map` lists each new slice with what it covers.
- [ ] `tests/maintenance.test.sh` goes red on a `memory/map/scripts*.md` over 80 lines.
- [ ] ADR-033 `Status: accepted (<date>, owner: Andrei, grill answer «Принять как есть», approved with the post-052-tails plan)`.

## Verification
`bash tests/maintenance.test.sh`

## Implementation notes

## Findings
