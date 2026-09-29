---
story: evolve-corrections-count-01
spec: evolve-corrections-count
status: todo
returned:
tier: 1
worker: worker-code
model: sonnet
wave: 1
blocked_by: []
---

# /vulyk-evolve counts the owner's corrections and how many reached docs/defects

## Goal
`bash .claude/hooks/defect-intake.sh --lexicon` prints the hook's own correction lexicon as portable ERE lines, one
per stem or phrase. This keeps one source, so the lexicon cannot fork. `/vulyk-evolve` step 1 finds the litopys CLI
(`command -v litopys`, else the newest `~/.claude/plugins/cache/litopys/litopys/*/bin/litopys`). It runs
`corrections --since <7 days ago> --lexicon <that file>`, and prints
`corrections (7d): <n> by lexicon · <m> in records · <u> not in docs/defects`. A quote counts as filed when
`grep -rF` finds it in `docs/defects/`. There is one line when litopys is absent or older than 0.4.0, and nothing
blocks. The count is evidence for step 3; it never files a card itself.

## Files
- .claude/hooks/defect-intake.sh
- .claude/commands/vulyk-evolve.md
- tests/intake.test.sh

## Non-goals
- No new hook, no SessionStart line (the board withdrew it), no automatic filing of cards.
- Do not change what the hook fires on in its normal UserPromptSubmit path.

## Acceptance criteria
- [ ] `defect-intake.sh --lexicon` exits 0 without reading stdin and prints ERE lines. A stem matches at a word start (`переделайте` matches, `непеределай` does not). A phrase needs both edges (`again!` matches, `against` does not). Both are checked with `grep -E` under a UTF-8 locale.
- [ ] The normal hook path is unchanged: the existing intake cases stay green.
- [ ] `vulyk-evolve.md` step 1 carries the counter block with the CLI lookup, the absent/old fallback line, and the three numbers.

## Verification
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes

## Findings
