---
story: auto-memory-subagent-start-03
status: todo
returned:
worker: worker-code
model: opus
wave: 2
blocked_by: []
red: required
red_reason:
---

# Repair round 1

## Goal
Make the asks and findings council round 1 left RED pass, and change nothing else.

## Requirements
> 1. Когда агент читает файл истории, ему сразу показываются карточки docs/defects/ для файлов её ## Files, до первой правки, каждая карточка один раз на агента.

## Findings
1. .claude/hooks/defects-inject.sh:229 [regression] [ask 1] a card folded into `+N cards` on a story Read must still reach the agent in full at its first Edit of a matching path (the story-Read fold marks folded refs as seen, so the Never lines never arrive) - repro on the head: `printf '{"session_id":"r","tool_name":"Read","tool_input":{"file_path":"E:/Projects/vulyk/docs/specs/auto-memory-subagent-start/auto-memory-subagent-start-01-story-read-cards.md"},"cwd":"E:/Projects/vulyk","agent_id":"w9"}' | CLAUDE_PROJECT_DIR=E:/Projects/vulyk bash .claude/hooks/defects-inject.sh` shows 2 cards and `+3 cards: upgrade-overwrites-host-edits, done-without-real-run, measurement-unlike-reality`; then `printf '{"session_id":"r","tool_name":"Edit","tool_input":{"file_path":"E:/Projects/vulyk/install.sh"},"cwd":"E:/Projects/vulyk","agent_id":"w9"}' | CLAUDE_PROJECT_DIR=E:/Projects/vulyk bash .claude/hooks/defects-inject.sh` prints nothing; the same two payloads through `git show main:.claude/hooks/defects-inject.sh` (defects_lib.py unchanged) print nothing on the Read and the full `upgrade-overwrites-host-edits` / `done-without-real-run` lines on the Edit.

## Files
- .claude/hooks/defects-inject.sh
- .claude/settings.json
- install.sh
- tests/inject.test.sh
- tests/intake.test.sh
- tests/telemetry.test.sh
- docs/hooks-reference.md
- docs/wiki/rules-tree.md
- .claude/hooks/session-start-brief.sh
- scripts/memory-triage.sh
- tests/maintenance.test.sh
- docs/memory-system.md
- .claude/commands/vulyk-gc.md

## Verification
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh`
`bash tests/telemetry.test.sh --part library`
`bash tests/telemetry.test.sh --part wrapper`
`bash tests/maintenance.test.sh`
