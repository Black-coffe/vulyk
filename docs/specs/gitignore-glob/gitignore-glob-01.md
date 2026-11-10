---
story: gitignore-glob-01
spec: gitignore-glob
status: done
returned: DONE
tier: 1
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: run from a directory that matches its globs, install.sh still writes the patterns - expected
red_verified_at: 2026-11-10T09:19:11Z 9a5305f20e0939dbad3493680b11d8c88c6d4e3b325d4c7941487e902466f043
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
- install.sh ensure_gitignore: `set -f` for the function's body, restored on all three exits unless noglob was already
  on. The test runs an upgrade from a directory holding docs/specs/x/DRIVER, docs/specs/x/PAUSE and a.vulyk-new.
- council-opus.md / council-haiku.md: the guide's "# Finishing work" text after step 3, adapted to a seat (the court's
  blindness and forbidden outward actions are the deliberate blockers); report contract untouched; prompt-check ok.
- Order: test, stamp-red (old code wrote 3 paths, 0 patterns), then the fix.

## Findings

## Red receipt
- command: bash tests/telemetry.test.sh --part crlf
- exit: 1
- tests: 9a5305f20e0939dbad3493680b11d8c88c6d4e3b325d4c7941487e902466f043 (tests/telemetry.test.sh)
- impl: 196de79709faf01b0a537c22af28706803eaf9543775b0f8bd76a64b6d0ede71
- stamped: 2026-11-10T09:19:11Z

```
::error::run from a directory that matches its globs, install.sh still writes the patterns - expected [3 0], got [0 3]
  ok    --check: the retired file would go
  ok    --check: nothing still shipped is marked for removal
  ok    only the retired file is removed
  ok    --upgrade of a hive with no dependency manifest prints no setup offer
  ok    and it is gone, the framework files stay
  ok    a CRLF .gitignore does not get the runtime block twice
  ok    a fresh hive's .gitattributes pins LF for hooks, drivers and the manifest
  ok    and a second run adds no rule
::error::run from a directory that matches its globs, install.sh still writes the patterns - expected [3 0], got [0 3]
telemetry.test.sh: 12 checks, 1 failed
```
