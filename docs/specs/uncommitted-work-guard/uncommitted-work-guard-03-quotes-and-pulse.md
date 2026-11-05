---
story: uncommitted-work-guard-03
spec: uncommitted-work-guard
status: todo
returned:
tier: 2
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason:
red_verified_at:
---

# Quoted words are not a correction; the pulse coexistence note

## Goal
In `defect-intake.sh`, a correction word or card key that sits only inside a quote in typed text, between «» or “”
or "" or on `> ` lines, goes to the paste branch ("are these your words?") instead of "file the quote now". The same
word outside the quote still fires the typed branch. `docs/pulse.md` gains a short section: mods that replace
`Spinner` or `TurnDuration` (Claude Skins does) cannot draw beside pulse, the outer one wins, and the per-hive off
switch is the way out.

## Requirements
> 4. Слова-поправки внутри цитаты не считаются поправкой.
> 5. Заметка о конфликте pulse со Skins.

## Files
- .claude/hooks/defect-intake.sh
- tests/intake.test.sh
- docs/pulse.md

## Non-goals
- No model call and no change to the lexicon itself.
- Do not change the pulse mod's code.

## Map slice
docs/wiki/rules-tree.md (Capture)

## Acceptance criteria
- [ ] The original case: typed text quoting a post with «нет, не так» inside guillemets -> the paste-branch line, not the typed-branch line.
- [ ] The neighbour: typed «нет, не так» with nothing around it (a bare correction) still gets the typed-branch line.
- [ ] `docs/pulse.md` names the three shared rows and the off switch.

## Verification
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh`

## Implementation notes

## Findings
