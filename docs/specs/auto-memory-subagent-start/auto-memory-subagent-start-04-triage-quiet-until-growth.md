---
story: auto-memory-subagent-start-04-triage-quiet-until-growth
spec: auto-memory-subagent-start
status: done
returned: DONE
tier: 2
worker: worker-code
wave: 3
blocked_by: []
red: required
red_reason: ::error::a triaged size stays quiet until it grows
red_verified_at: 2026-10-28T16:02:09Z 1d1c51233806468f9a032e53dd1d33d0eb2419803356b0617bba8756bbeeb21e
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
- [x] Over the threshold with a mark at the same size: not due. Grown by 19 lines and 2047 bytes: not due. Grown by 20 lines: due. Grown by 2048 bytes: due.
- [x] No mark: due at the threshold, as before.
- [x] `--mark` writes `<lines> <bytes>` (lines counted as the brief counts them) and nothing else; without a `MEMORY.md` it writes nothing and exits 0.

## Verification
`bash tests/maintenance.test.sh`

## Implementation notes
- `memory-triage.sh --mark`: writes `<NR> <bytes>` of `MEMORY.md` to `<repo>/.claude/state/memory-triage.txt` (already git-ignored); no `MEMORY.md` -> no write, exit 0. The header now says this mark is its one write.
- Brief: due needs the threshold AND (no valid mark, or +20 lines, or +2048 bytes past it); a non-numeric mark counts as none. The mark is read only when the file exists, so a fresh repo prints nothing to stderr (checked on this repo).
- `/vulyk-gc` step 10 runs `--mark` whatever was decided; `docs/memory-system.md` says why.

## Findings

## Red receipt
- command: bash tests/maintenance.test.sh
- exit: 1
- tests: 1d1c51233806468f9a032e53dd1d33d0eb2419803356b0617bba8756bbeeb21e (tests/maintenance.test.sh)
- impl: c550f04d1fd7c7e305da202ad211b2c253d1f66d25b7fff3369ec562582d3162
- stamped: 2026-10-28T16:02:09Z

```
  ok    memory-triage: a file without frontmatter lists with type -
  ok    memory-triage: MEMORY.md is not a row
  ok    memory-triage: exactly two rows
  ok    memory-triage: an absent dir says so
  ok    memory-triage: an absent dir exits 0
  ok    memory-triage --index-lines: names the moved file's line
  ok    memory-triage --index-lines: takes a bare file name
  ok    memory-triage --index-lines: leaves other lines out
  ok    memory-triage: writes nothing
maintenance.test.sh: 170 checks, 5 failed
```
