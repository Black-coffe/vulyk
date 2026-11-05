---
story: uncommitted-work-guard-03
spec: uncommitted-work-guard
status: done
returned: DONE
tier: 2
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: intake: «нет, не так» in guillemets asks the owner first
red_verified_at: 2026-11-05T21:52:46Z 8276b0698cabab7c5123b37f41a076384bc56450b2307fda679c0baafc0f385d
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
- `.claude/hooks/defect-intake.sh`: `QUOTES` («…», “…”, „…“, "…" on one line, `>` lines) is cut out of the typed text
  after the pastes and fences, and the quoted pieces join the paste pass (no timecodes there). A word or key outside
  the quote still files at once. The explicit-phrase pass is unchanged (it reads quotes too, as before).
- The neighbour AC reads «нет, не так» as prose delimiters: the bare typed `нет, не так` files at once; a message that
  is only a guillemet quote goes to the ask, as the Goal says.
- `docs/pulse.md`: «Other mods on the same rows» names `Spinner`, `AbovePrompt`, `TurnDuration`, Claude Skins, the
  outer-one-wins rule (VULYK does not pick the order) and the per-hive off switch.
- `docs/hooks-reference.md` still describes the intake without the quote rule: not in this story's ## Files.

## Findings

## Red receipt
- command: bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh
- exit: 1
- tests: 8276b0698cabab7c5123b37f41a076384bc56450b2307fda679c0baafc0f385d (tests/intake.test.sh)
- impl: f37c326ebee9ce1772eb0b4c06d6173140c85611b8dc5a940e1f99d37915eeb1
- stamped: 2026-11-05T21:52:46Z

```
::error::intake: «нет, не так» in guillemets asks the owner first - expected 'whether these are their words' in:
  ok    median latency <= 200 ms
--- --lexicon exports the lexicon as ERE lines
  ok    --lexicon exits 0 without reading stdin
  ok    a stem matches at a word start (переделайте)
  ok    neighbour: a stem inside a word does not match
  ok    a phrase with a punctuation edge matches (again!)
  ok    neighbour: a phrase needs both edges (against)
  ok    a capitalised Cyrillic stem matches under a UTF-8 locale
  ok    one ERE line per stem and phrase of the hook's own lists
intake.test.sh: 82 checks, 6 failed
```
