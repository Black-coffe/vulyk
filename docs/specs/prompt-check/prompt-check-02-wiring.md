---
story: prompt-check-02
spec: prompt-check
status: done
returned: DONE
tier: 2
worker: worker-code
wave: 2
blocked_by: [prompt-check-01]
red: required
red_reason: ::error::prompt-check refusal: exit=0
red_verified_at: 2026-10-28T18:38:06Z 6f2e5b08c2d9cf7f30ffd8d502ac4ad22d15deaa41767be74cf7da711d8ef2ca
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
- `cmd_close_story`: the block sits after `red_gate` and before the verification run, so a refusal costs no suite. Trigger: a `## Files` entry under the four prefixes; `--touched` gets every `## Files` entry, so a story that edits `scripts/telemetry.sh` or `docs/architecture.md` beside a prompt owns those findings too. Skipped when `scripts/prompt-check.sh` is absent (a hive before the upgrade, the older test fixtures).
- Exit 1: the checker's output on stderr, `emit ... 4 repair "<first error line>"` (emit escapes the JSON). Exit 2+: one note, the close goes on.
- Tests: three cases at the end of `tests/cycle.test.sh --part close` on a seeded drifted `.claude/commands/x.md`.
- CI: one step in the `shell` job. Docs: the close-story clause in `docs/command-reference.md`, CHANGELOG `[Unreleased]`, no speed figure.

## Findings

## Red receipt
- command: bash tests/cycle.test.sh
- exit: 1
- tests: 6f2e5b08c2d9cf7f30ffd8d502ac4ad22d15deaa41767be74cf7da711d8ef2ca (tests/cycle.test.sh)
- impl: 1e936b64107f66663d72432d56ebc05bf19ffedc3993c00bf7d040569b814076
- stamped: 2026-10-28T18:38:06Z

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
