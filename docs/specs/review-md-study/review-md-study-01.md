---
story: review-md-study-01
spec: review-md-study
status: done
returned: DONE
tier: 1
worker: worker-code
wave: 1
blocked_by: []
---

# The reviewer reads the project's rules for the paths it judges

## Goal
`lead-review` reads the round's diff with the changed paths named, so `defects-inject.sh` delivers the cards for those paths; it reports a diff line that breaks a card's Never or How-to line as an `[unanchored]` major naming the card ref; in round 1 one finding names every place in the diff where its condition fails, and a sibling outside the diff gets one `[unanchored]` line; a security hole or data-loss path the diff adds is anchored to the ask whose code carries it.

## Requirements
> выдели три вещи, которые мы можем взять в Vultr, как следующую доработку
> обязательно с учётом сбережения тех правил и принципов, которые уже туда заложены

## Files
- .claude/agents/lead-review.md
- CHANGELOG.md

## Non-goals
- No new anchor tag, no change to `scripts/cycle.sh`, `record-seat` or the report format.
- No new script or `defects-index.sh` mode; the hook already matches path tokens.
- No security seat, vote, breaker or replay eval.

## Map slice
memory/map: agents-and-commands.md, the lead-review section.

## Acceptance criteria
- [ ] "What you read" tells the reviewer to list `git diff --name-only <range>` and read the diff in one line with every path named after `--`, and to open any card folded into `+N cards`.
- [ ] "What you judge" has a fourth item: a diff line that breaks a delivered card's Never (✗) or How-to (→) line is a Major tagged `[unanchored]` with the card ref; an Allowed (✓) line is not a finding.
- [ ] The finding rule says: round 1, one finding names every place in the diff where its condition fails; a sibling outside the diff is one `[unanchored]` line.
- [ ] (ask 3, if approved) the anchor rule says a security hole or data-loss path the diff adds breaks the ask whose code carries it: `[ask N]`.
- [ ] Probe: the hook fed the reviewer's diff line returns the cards for those paths.

## Verification
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh`

## Implementation notes
- lead-review.md: judge item 4 (cards on touched paths, `[unanchored]` major with the ref), a "What you read" bullet (name-only list, one `git diff <range> -- <paths>` call, open folded cards), the security/data-loss sentence on `[ask N]`, the round-1 class sentence. No script touched.
- Probe 2026-10-21: the hook fed `git diff f8e4fdc~3..f8e4fdc -- docs/defects/README.md .claude/commands/vulyk-ship.md CHANGELOG.md` returned 2 cards in full + `+4 cards`; the same diff without `--` returned none.

## Findings
