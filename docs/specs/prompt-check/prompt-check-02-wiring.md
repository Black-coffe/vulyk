---
story: prompt-check-02
spec: prompt-check
status: todo
returned:
tier: 2
worker: worker-code
wave: 2
blocked_by: [prompt-check-01]
red: required
red_reason:
---

# prompt-check in close-story and CI

## Goal
`cycle.sh close-story` runs `bash "$HERE/prompt-check.sh" --touched <entries>` when the story's `## Files` (via
`files_of`) holds a path under `scripts/`, `.claude/agents/`, `.claude/commands/` or `templates/`, passing those
entries. Exit 1 refuses the close the way the stray-edit gate does (`emit false close-story 4 repair "prompt-check:
..."`, exit 4, the finding lines on stderr); exit 2 prints one stderr note and the close goes on; a story touching none
of those paths runs nothing new. CI's `shell` job gains one step, `bash scripts/prompt-check.sh`. The docs say it once.

## Requirements
> 5. Линтер работает в CI и close-story.
> Профит: Полная защита от рассинхрона между bash-скриптами и промптами агентов при развитии фреймворка, работает мгновенно в CI и close-story.

## Files
- scripts/cycle.sh
- tests/cycle.test.sh
- .github/workflows/ci.yml
- docs/command-reference.md
- CHANGELOG.md

## Non-goals
- No new `## Commands` row and no CLAUDE.md edit.
- Do not change `scope-check.sh`, the stray-edit gate or `red_gate`; the new block sits beside them in `cmd_close_story`.
- No hive upgrade; `install.sh` already ships `scripts/`.

## Map slice
`memory/map/cycle.md` (close-story, exit codes, `emit`); `memory/map/scripts.md` (`files_of`).

## Acceptance criteria
- [ ] A story whose `## Files` names a command file with a seeded broken backticked flag: close-story exits 4 and names the finding.
- [ ] The same seeded drift, with a story whose `## Files` names only `README.md`: close-story exits 0 (prompt-check not run).
- [ ] A story touching `scripts/` while the drift sits in an untouched prompt: close-story exits 0 and prints the `warn`.
- [ ] The CI `shell` job has a step running `bash scripts/prompt-check.sh`.
- [ ] `docs/command-reference.md` (close-story and the script) and CHANGELOG `[Unreleased]` describe it; no speed figure.

## Verification
`bash tests/cycle.test.sh`

## Implementation notes

## Findings
