---
story: gitignore-glob-01
spec: gitignore-glob
status: todo
returned:
tier: 1
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: run from a directory that matches its globs, install.sh still writes the patterns - expected
---

# install.sh writes the .gitignore patterns; the Fable council seats finish their work

## Goal
`install.sh`'s ensure_gitignore writes its wanted lines literally (no glob expansion) from any working directory, and
the council seats `council-opus` and `council-haiku` carry the "# Finishing work" text of Anthropic's "Prompting Claude
Fable 5.2" guide, adapted to a seat.

## Files
- install.sh
- tests/telemetry.test.sh
- .claude/agents/council-opus.md
- .claude/agents/council-haiku.md

## Non-goals
- No effort change for any agent; no other agent file; no other guide section.
- No automatic removal of stray lines an earlier install wrote into a hive's .gitignore.

## Map slice
memory/map/scripts.md (install.sh) · memory/map/agents-and-commands.md (council seats)

## Acceptance criteria
- [ ] From a working directory holding `docs/specs/x/DRIVER`, `docs/specs/x/PAUSE` and `a.vulyk-new`, an upgrade of a hive
      whose .gitignore lacks the block writes the three patterns verbatim and none of those paths.
- [ ] Both seat files carry the finishing-work text; their report contract is unchanged.

## Verification
`bash tests/telemetry.test.sh --part crlf`

## Implementation notes

## Findings
