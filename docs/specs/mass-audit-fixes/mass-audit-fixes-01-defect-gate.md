---
story: mass-audit-fixes-01
spec: mass-audit-fixes
status: done
returned: DONE
tier: 4
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: defects-check --files
red_verified_at: 2026-11-09T12:56:41Z a9301a247e5fdedc1ba27e3f9296568df7a78daad4b837989170d2902c8a64b5
---

# The defect-card gate runs on real work; the inject hook costs nothing when no card can match

## Goal
`scripts/defects-check.sh` gains `--files <path>...` so a `block` card's check can run on the files a story
declares (the cycle call site is story 08). `.claude/hooks/defects-inject.sh` treats every non-revoked card as
text again (a `block` card's Never lines reach agents; the hook header no longer says the gate guards them) and
stays in bash until a card can match: it lists card files (`docs/defects/*.md`, `docs/defects/*/*.md`, never
`README.md` or `INDEX.md` in any case, never `fixtures/`), exits 0 before Python when there are none, and for a
tool with no path and no command line exits unless `grep -lF 'tool:'` over those card files hits. The Read skip
stays as it is. Private audit (2026-11-08) findings I1 and O3; contributor item P10-11 rewritten. Marked red:
a new gate branch and a hook branch.

## Requirements
> 1. P10-11 rewritten: `defects-inject.sh` starts no Python when no card can match the tool call, searching card files only (not `docs/defects/README.md`), and exits at once when the hive has no cards (our O3).
> 13. A `block` defect card's check runs in close-story on the story's matching files and a failure refuses the close; the card's never-lines are shown to agents again.
> 11. Every finding of our private audit that the merged branch does not close (Scope E) is fixed, with a regression test wherever code can check it.

## Files
- .claude/hooks/defects-inject.sh
- scripts/defects-check.sh
- .claude/hooks/defects_lib.py
- docs/defects/README.md
- tests/inject.test.sh
- tests/defects.test.sh

## Non-goals
- Do not touch `scripts/cycle.sh`: the `close-story` call of `--files` is story 08 (wave 2), built against the
  contract in plan.md `## Contracts` D3.
- Do not change the `defects-check.sh <arg>` gate form or the no-argument audit; `--files` is a third mode.
- Do not change which tools the PreToolUse matcher covers, or the Read skip for a non-spec file.
- Do not reword existing cards; the README's `block` paragraph is the only prose change.

## Map slice
`memory/map/scripts.md` → Entry points (`defects-index.sh`, `defects-check.sh`), Key contracts;
`memory/map/agents-and-commands.md` → Agents (lead-review bullet, item 3).

## Acceptance criteria
- [ ] `bash scripts/defects-check.sh --files <file>` runs each `block` card's `check:` once per given file that
  matches a glob in its `paths:`; a `cmd:`/`tool:` entry matches no file; exit 0 / 1 (one line per red,
  `<ref> fails on <file>: <first output line>`) / 2 (no python or parser); tested in `tests/defects.test.sh` with
  a block card whose check fails on one fixture file and passes on another.
- [ ] The audit mode reports a `block` card with no glob `paths:` as `block with no file scope`.
- [ ] The hook prints a `block` card's Never lines for a matching Edit like a text card's; `injected_as` has no
  `block` branch; the header line about the gate is gone.
- [ ] In a hive whose `docs/defects/` holds only `README.md` and `INDEX.md`, the hook exits 0 for an Edit, a
  Bash call and an Agent call without starting Python (asserted with a counting interpreter stub, as the
  existing latency tests do).
- [ ] A tool with no path and no command line starts Python only when a card file contains `tool:`; a `tool:`
  line inside `README.md` alone does not count.
- [ ] The failing-test label the new `--files` case prints on failure contains `defects-check --files`.
- [ ] `docs/defects/README.md` says a `block` card's check runs in `close-story` on the story's matching files
  and that its lines are shown to agents like a text card's.

## Verification
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh`

## Implementation notes
- scripts/defects-check.sh: `--files <path>...` third mode; python emits one run per declared block card x matching glob file and exits before the findings; bash prints only `<ref> fails on <file>: <first line>`, exit 0/1; audit adds `block <ref>: block with no file scope`.
- Decision: `--files` reports no debt/index/info lines (close-story reads only the red lines); `block with no file scope` is an info line, not red, and the UNDELIVERABLE exemption for block-with-check stays.
- .claude/hooks/defects-inject.sh: `injected_as` lost its block branch; header comment and output header no longer mention the gate / "no check guards them"; bash lists card files (fixtures/ and README/INDEX any case skipped), exits with none, greps `tool:` over card files only; `reset` calls skip the pre-filter.
- docs/defects/README.md: the `block` status paragraph only.
- tests: defects.test.sh `--files` section (fail/pass fixture, scopes, exit 2 cases, audit line); inject.test.sh BLOCKNEVER/CMDNEVER now expected, O3 empty-hive and README-`tool:` cases.
- .claude/hooks/defects_lib.py unchanged: `card_files` already had the needed exclusions.
- Surprise: the latency part is over its 200/100 ms medians on this loaded box with the HEAD hook too (Bash 234 ms, HEAD copy).

## Findings

## Red receipt
- command: bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh
- exit: 1
- tests: a9301a247e5fdedc1ba27e3f9296568df7a78daad4b837989170d2902c8a64b5 (tests/defects.test.sh, tests/inject.test.sh)
- impl: d1177b63f7aa2aeba15feb5c9fe5f543711cca99aaa3c118501707ad14c3a26e
- stamped: 2026-11-09T12:56:41Z

```
--- defects-check --files: block checks on a story's files (mass-audit 01, D3)
::error::defects-check --files: matching files that pass every block check -> exit 0, no red line
::error::defects-check --files: each check ran once per matching file, not on others
::error::defects-check --files: a file outside every glob, a cmd:/tool: scope, a text and a revoked card run nothing
  ok    defects-check --files: no debt, index or info lines, only red lines
::error::defects-check --files with no file -> exit 2
  ok    defects-check --files with no python -> exit 2
  ok    defects-check --files with no parser -> exit 2
::error::defects-check --files: the audit names a block card with no glob paths: as 'block with no file scope'
--- usage
  ok    two arguments -> exit 2
  ok    an empty argument -> exit 2
defects.test.sh: FAILED
```
