---
story: weekly-budget-02
spec: weekly-budget
status: todo
returned:
tier: 4
worker: worker-code
wave: 1
blocked_by: []
---

# M2: is `autoCompactWindow` in agent frontmatter honoured

## Goal
`docs/specs/weekly-budget/measure-window.json` says whether a subagent whose frontmatter carries `autoCompactWindow: 400000`
compacts near 400K on the installed Claude Code (2.1.312 changelog: a subagent's window can lower, never raise), with the token
count at which it did. Story 04 reads only this file to decide between frontmatter and documentation.

## Requirements
> 7. Контекст агентов ~400K, главная сессия 1M.
> чтобы они не убивали весь контекст

## Files
- docs/specs/weekly-budget/measure-window.json
- tests/maintenance.test.sh

## Non-goals
- No file under this repo's `.claude/agents/`: the probe agent lives in a temp project dir outside the repo
  (`<tmp>/.claude/agents/budget-probe.md`), cwd = that dir, and is deleted afterwards.
- No `CLAUDE_CODE_AUTO_COMPACT_WINDOW` and no `/autocompact` change: they would also move the main session.
- One run, no control arm (a control costs another ~450K): the 967K default threshold is the documented control.
- No raw transcript, session id or path in the committed file.

## Map slice
`memory/map/agents-and-commands.md` «Purpose» (frontmatter is model/effort/turn cap). Read research-cc-updates.md §2.

## Acceptance criteria
- `tests/maintenance.test.sh` gains a check that fails unless `docs/specs/weekly-budget/measure-window.json` exists, parses and carries a boolean `honoured` (the JSON row alone cannot fail: close-story verifies before `git add`).
- [ ] One headless `claude -p` session (model `haiku` or `sonnet`, at or above the floor) dispatches the temp probe agent
      (`autoCompactWindow: 400000`, Read only) to read generated text files totalling ~450K tokens; the subagent transcript is
      inspected for a compaction marker (a compact boundary or summary entry) and the pre-compaction token count.
- [ ] `measure-window.json`: `{"cc_version","probe_model","tokens_fed","compacted":true|false,"compacted_at_tokens":<int|null>,
      "honoured":true|false,"evidence":"<the transcript field name that showed it>","gaps":[...]}`; `honoured` is true only when
      a compaction happened below ~450K; `gaps` states that a generated-text reader is not a real worker (tool mix, cache).
- [ ] A run that could not measure (died, no subagent transcript, no marker type identifiable) -> `returned: NEEDS_CONTEXT` with
      what was tried in `## Findings`. `honoured: false` is a result, not a stop.

## Verification
`bash tests/maintenance.test.sh`

## Implementation notes

## Findings
