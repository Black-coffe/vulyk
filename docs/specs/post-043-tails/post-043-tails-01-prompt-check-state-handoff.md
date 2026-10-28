---
story: post-043-tails-01
spec: post-043-tails
status: todo            # todo | done | blocked - close-story writes done, a driver writes blocked
returned:              # written by whoever builds the story, as its last edit: DONE | NEEDS_CONTEXT | WALL
tier: 2
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason:           # the expected failure text, written by the builder before `stamp-red`
# red_verified_at:      # written by `cycle.sh stamp-red`, never by hand
---

# prompt-check minors, state.sh frontmatter, handoff.sh Python probe

## Goal
prompt-check finds an agent name anywhere in a backticked span, warns instead of silently skipping the verb check when
`cycle.sh` has no dispatcher, and a crash inside `close-story` refuses the story with its own reason. `state.sh` takes
story fields from the frontmatter only, so a report quoting the story template is not a story. `handoff.sh` runs only a
Python that answers `-c ''`. Order: write all five tests first, before any code. The red receipt is on `state.sh`, the
fix with the widest reach (a misread hides a real story from `/vulyk-status`): a study spec whose `report.md` quotes
`story:` / `status:` lines must list no story; it fails today, and its failure text is `red_reason`. The other four
tests fail in the same `stamp-red` run; for each, copy its failure line from that run into `## Implementation notes`
(owner, 2026-10-28: «Штамп на state.sh + запись»). Not a stamp: the reviewer checks those lines against the tests.

## Requirements
> 1. Три замечания prompt-check в коде: имя агента внутри длинного фрагмента; предупреждение вместо тихого пропуска глаголов; падение линтера в close-story — отказ со своей причиной.
> 2. handoff.sh проверяет, что Python настоящий, прежде чем запускать.
> 4. state.sh читает story/status только из frontmatter.

## Files
- scripts/prompt-check.py
- scripts/cycle.sh
- scripts/state.sh
- .claude/hooks/handoff.sh
- tests/maintenance.test.sh
- tests/cycle.test.sh

## Non-goals
- No path check in prompt-check (declined H2 of spec prompt-check), no change to which findings block a story.
- No other `close-story` branch, no change to `prompt-check.sh` exit codes 0/1.
- No new `state.sh` stage or marker; no change to how stages are derived.
- No change to `handoff.py`, `context_guard.py` or the hook wiring.
- Do not touch `docs/architecture.md` (story 03).

## Map slice
`memory/map/scripts.md` (prompt-check, state.sh, hooks); `memory/map/cycle.md` close-story prompt-check branch.

## Acceptance criteria
- [ ] A command prompt carrying `` `Agent drone-ghost` `` fails prompt-check with an `agent` error; today's repo still prints `prompt-check: ok`.
- [ ] A `cycle.sh` without `case "$VERB" in` gives one `prompt-check: warn` line and exit 0.
- [ ] In `close-story`, a prompt-check rc 1 with no `prompt-check: error` line refuses with exit 4 and a non-empty reason naming the crash.
- [ ] `state.sh` lists no story for a study spec whose `report.md` quotes `story:` / `status:` lines in its body; the 06-shipped case still holds.
- [ ] With a `python3` on PATH that exits 49, `handoff.sh status` still reaches a working Python or exits 0.

## Verification
`bash tests/maintenance.test.sh`
`bash tests/cycle.test.sh`

## Implementation notes

## Findings
