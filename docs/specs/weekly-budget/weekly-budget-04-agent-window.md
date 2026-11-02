---
story: weekly-budget-04
spec: weekly-budget
status: todo
returned:
tier: 4
worker: worker-code
wave: 2
blocked_by: [weekly-budget-02]
---

# The ~400K agent window: frontmatter if M2 proved it, documentation if not

## Goal
If `docs/specs/weekly-budget/measure-window.json` says `"honoured": true`, every VULYK agent file carries
`autoCompactWindow: 400000` in its frontmatter and `docs/model-cascade.md` has one paragraph saying so (agents ~400K, the
Queen's session stays at 1M, measured on which Claude Code version). If it says `false`, no agent file changes and
`docs/model-cascade.md` instead says why there is no per-agent window yet, how the owner caps a session by hand (`/autocompact`),
and why VULYK ships no env var (it would cap the main session too). The owner is told which branch shipped in the return.

## Requirements
> 7. Контекст агентов ~400K, главная сессия 1M.

## Files
- .claude/agents/*.md
- docs/model-cascade.md
- scripts/prompt-check.py
- tests/maintenance.test.sh

## Non-goals
- No `CLAUDE_CODE_AUTO_COMPACT_WINDOW`, no `CLAUDE_CODE_SUBAGENT_EFFORT`, no `settings.json` edit (ADR-028 §4).
- No other frontmatter change: `model:`, `effort:`, `maxTurns:` stay (Fable effort is story 08's, at dispatch).
- `docs/model-cascade.md`: only the context paragraph. The Fable list and "never reached by design" are story 05's.
- `scripts/prompt-check.py` only if `close-story`'s prompt-check refuses the new key; then the smallest change that admits it.

## Map slice
`memory/map/agents-and-commands.md` «Purpose», «Agents» (which files keep `omitClaudeMd`); `memory/map/scripts.md`
«Entry points» (`prompt-check.sh` agent-frontmatter rule).

## Acceptance criteria
- [ ] Branch chosen from `measure-window.json` alone, named in `## Implementation notes`; a missing file -> `NEEDS_CONTEXT`.
- [ ] Honoured: every `.claude/agents/*.md` frontmatter has exactly one `autoCompactWindow: 400000`; nothing else in them moved.
- [ ] Not honoured: no agent file in the diff; the docs paragraph carries the Claude Code version M2 ran on and the ADR-028
      «Revisit when» trigger.
- [ ] Prompt-check passes on the touched agent files.

## Verification
`bash tests/maintenance.test.sh`

## Implementation notes

## Findings
