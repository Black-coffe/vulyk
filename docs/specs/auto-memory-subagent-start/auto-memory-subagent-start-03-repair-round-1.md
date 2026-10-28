---
story: auto-memory-subagent-start-03
status: done
returned: DONE
worker: worker-code
model: opus
wave: 2
blocked_by: []
red: required
red_reason: ::error::a card folded on a story Read arrives in full at the first Edit
red_verified_at: 2026-10-28T15:49:17Z 5cfedfae721e0fe47f650075f271c03ecab6ce2aab181d0cc88b0dc75eeb1b0e
---

# Repair round 1

## Goal
Make the asks and findings council round 1 left RED pass, and change nothing else.

## Requirements
> 1. Когда агент читает файл истории, ему сразу показываются карточки docs/defects/ для файлов её ## Files, до первой правки, каждая карточка один раз на агента.

## Findings
1. .claude/hooks/defects-inject.sh:229 [regression] [ask 1] a card folded into `+N cards` on a story Read must still reach the agent in full at its first Edit of a matching path (the story-Read fold marks folded refs as seen, so the Never lines never arrive) - repro on the head: `printf '{"session_id":"r","tool_name":"Read","tool_input":{"file_path":"E:/Projects/vulyk/docs/specs/auto-memory-subagent-start/auto-memory-subagent-start-01-story-read-cards.md"},"cwd":"E:/Projects/vulyk","agent_id":"w9"}' | CLAUDE_PROJECT_DIR=E:/Projects/vulyk bash .claude/hooks/defects-inject.sh` shows 2 cards and `+3 cards: upgrade-overwrites-host-edits, done-without-real-run, measurement-unlike-reality`; then `printf '{"session_id":"r","tool_name":"Edit","tool_input":{"file_path":"E:/Projects/vulyk/install.sh"},"cwd":"E:/Projects/vulyk","agent_id":"w9"}' | CLAUDE_PROJECT_DIR=E:/Projects/vulyk bash .claude/hooks/defects-inject.sh` prints nothing; the same two payloads through `git show main:.claude/hooks/defects-inject.sh` (defects_lib.py unchanged) print nothing on the Read and the full `upgrade-overwrites-host-edits` / `done-without-real-run` lines on the Edit.

## Implementation notes
- Finding 1: on a story Read the folded refs are no longer written to the dedup state (`if tool != 'Read': shown += rest`); a fully shown card still is. Reviewer's repro on this repo now prints `upgrade-overwrites-host-edits` at the Edit of `install.sh`. Test: eight `big/**` cards, Read folds big-07/08, the Edit shows `✗ BIG08`, big-01 not repeated.
- Minor (wc -l): the brief counts lines with `awk 'END { print NR }'`, so a last line without a newline counts; test added.
- Minor (indented bullet): not changed. `scope-check.sh` and `close-story` read `## Files` as column-0 `- ` lines too; one format for all readers.

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

## Red receipt
- command: bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh
- exit: 1
- tests: 5cfedfae721e0fe47f650075f271c03ecab6ce2aab181d0cc88b0dc75eeb1b0e (tests/inject.test.sh, tests/intake.test.sh, tests/maintenance.test.sh, tests/telemetry.test.sh)
- impl: 2f44ffd262c29583003f9adaf33ca4f6d1308b2e2964dd410ff3955fbc8ef5a0
- stamped: 2026-10-28T15:49:17Z

```
        
  ok    a card shown in full on the story Read is not repeated at the Edit
--- latency
  median defects-inject.sh (Bash): 145 ms over 30 calls (YouTube_AI library copy; target <= 200 ms)
  ok    median latency, Bash, <= 200 ms
  median defects-inject.sh (Edit): 144 ms over 30 calls (YouTube_AI library copy; target <= 200 ms)
  ok    median latency, Edit, <= 200 ms
  median defects-inject.sh (Read, not a story): 70 ms over 30 calls (YouTube_AI library copy; target <= 100 ms)
  ok    median latency, non-story Read, <= 100 ms
inject.test.sh: 77 checks, 1 failed
```
