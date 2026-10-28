---
story: post-043-tails-01
spec: post-043-tails
status: done            # todo | done | blocked - close-story writes done, a driver writes blocked
returned: DONE
tier: 2
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: state.sh listed a story for a study spec whose report quotes story: lines
red_verified_at: 2026-10-28T20:01:57Z a69d2d16b2e66aca3118d3df2f3e7f903efe580f5fc092c453380efa3e991867
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
All five tests were written before any code. The receipt is on `state.sh` (`bash tests/cycle.test.sh`). The four other
failure lines come from a run of the same tree just before `stamp-red`. `stamp-red` keeps only the tail of the line it
seals, so these were taken with `bash tests/maintenance.test.sh` and `bash tests/cycle.test.sh --part close`:
- agent in a long span: `::error::prompt-check: an agent name inside a longer span (post-043-tails) exits 1 - expected 'exit=1;' in:`
- no dispatcher: `::error::prompt-check: a cycle.sh without a verb dispatcher is one warn line, not a silent skip - expected '1' in:` (count `0`)
- handoff probe: `::error::handoff.sh status with a stub python3 first on PATH reaches a working Python or exits 0 - expected 'exit=0;' in:` (`exit=49;`)
- linter crash: `::error::prompt-check crash: exit=4 out=...` (exit 4 already, but the JSON line carried no `error` key, so the reason was empty)

Code:
- `prompt-check.py` checks each whitespace token of a span, with surrounding punctuation stripped, against `AGENT_SHAPE`.
  The repo still prints `prompt-check: ok (33 files)`.
- A `cycle.sh` that exists but has no `case "$VERB" in` gives a soft `verb` finding on `scripts/cycle.sh:1`.
- In `close-story`, rc 1 with no `prompt-check: error` line becomes `prompt-check crashed: <last non-blank output line>`,
  or `exit 1 with no output` when there is none. The story is still refused with exit 4.
- `state.sh` `field()` reads only the leading `---` block and exits 1 when the key is absent. A file is a story only
  when its frontmatter has `story:`. Checked against the old `state.sh` over the whole repo: one spec changed.
  `architecture-passport` (its `report.md` quotes the story template) used to show as `01-spec` with one fake story;
  it now shows as `study`.
- `handoff.sh` runs `"$PY" -c ''` (stdin from `/dev/null`) before `exec`. A stub moves on to the next name.

## Findings

## Red receipt
- command: bash tests/cycle.test.sh
- exit: 1
- tests: a69d2d16b2e66aca3118d3df2f3e7f903efe580f5fc092c453380efa3e991867 (tests/cycle.test.sh, tests/maintenance.test.sh)
- impl: 9e0f4217537e15bf582513736bbe309759ad44e0b7966f473a71420e8838ecf8
- stamped: 2026-10-28T20:01:57Z

```
red-receipt: an unmarked story built from templates/story.md closes as before
  ok    the template story closes and commits, no receipt asked
red-receipt: close-story on a marked story - the sealed test edited, no implementation change, then a real change closes
  ok    red-12 stamped
  ok    a sealed test edited after the stamp: exit 4
  ok    the implementation unchanged since the stamp: exit 4
  ok    receipt + changed implementation + green: closed, the receipt in the commit
red-receipt: close-story on a marked story that was never stamped
  ok    the unstamped story: exit 4, nothing committed
  ok    the refusal names stamp-red and the story
```
