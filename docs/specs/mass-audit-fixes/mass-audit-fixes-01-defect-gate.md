---
story: mass-audit-fixes-01
spec: mass-audit-fixes
status: todo
returned:
tier: 4
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: defects-check --files
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

## Findings
