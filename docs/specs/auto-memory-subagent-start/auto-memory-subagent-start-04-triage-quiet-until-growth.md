---
story: auto-memory-subagent-start-04-triage-quiet-until-growth
spec: auto-memory-subagent-start
status: todo
returned:
tier: 2
worker: worker-code
wave: 3
blocked_by: []
red: required
red_reason: ::error::a triaged size stays quiet until it grows
---

# Memory triage stays quiet until the index grows

## Goal
`bash scripts/memory-triage.sh --mark` writes the current `MEMORY.md` line and byte counts to
`.claude/state/memory-triage.txt` under the repo root (git-ignored, per machine). This is its only write.
`/vulyk-gc memory` runs it as its last step, whatever the owner answered. The SessionStart brief keeps the
160-line / 20 KB threshold, but with a mark present it reports triage due only once `MEMORY.md` has grown
by at least 20 lines or 2048 bytes past the marked size. With no mark, it behaves as today.

## Requirements
> «После разбора /vulyk-gc memory запоминает размер MEMORY.md; сигнал вернётся, только когда файл вырастет ещё на 20 строк или 2 КБ.»

## Files
- .claude/hooks/session-start-brief.sh
- scripts/memory-triage.sh
- tests/maintenance.test.sh
- .claude/commands/vulyk-gc.md
- docs/memory-system.md

## Non-goals
- No Profile decline row.
- No change to the thresholds or to what the triage itself does.

## Map slice
memory/map/scripts.md: `memory-triage.sh`, the SessionStart brief.

## Acceptance criteria
- [ ] Over the threshold with a mark at the same size: not due. Grown by 19 lines and 2047 bytes: not due. Grown by 20 lines: due. Grown by 2048 bytes: due.
- [ ] No mark: due at the threshold, as before.
- [ ] `--mark` writes `<lines> <bytes>` (lines counted as the brief counts them) and nothing else; without a `MEMORY.md` it writes nothing and exits 0.

## Verification
`bash tests/maintenance.test.sh`

## Implementation notes

## Findings
