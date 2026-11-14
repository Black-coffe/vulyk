---
story: audit-fixes-1113-12
spec: audit-fixes-1113
status: todo
returned:
tier: 3
worker: worker-code
wave: 4
blocked_by: [audit-fixes-1113-06, audit-fixes-1113-08, audit-fixes-1113-09]
red: required
red_reason: a listed commit that adds a new quote is still an ESCAPE
---

# A scrub-only exception holds only for a masked change

## Goal
Story 06 taught `scripts/defects-check.sh` to date quote lines with `git blame --ignore-revs-file
docs/defects/.scrub-revs`, so story 04's path scrub stopped counting as a new owner quote. The list is a plain file
any agent can append to, and then a real new quote in a block card would pass the escape and debt rules. Cut by the
Queen mid-build (plan.md `## Plan deltas`, 2026-11-14) on a note the owner forwarded.
1. A commit listed in `.scrub-revs` keeps a quote line's older date only when that line's text before and after the
   commit differs solely in spans that the new text holds as placeholders (`<...>`, e.g. `<hive>`,
   `<claude-temp>`). Any other difference on that line, and any line the commit adds, dates to the listed commit as
   if it were not listed. The check is made by `defects-check.sh` itself, from git, not from the list.
3. `defects-check.sh --files` (the close-story block gate) does not run a card's check on that card's
   own `fixtures:` files (moved here from story 09; patch lines 725-755 of
   `.vulyk/reports/audit-fixes-1113/story-09-partial.patch`, its test at 833-852 rewritten into
   `tests/defects.test.sh`).
2. The SessionStart brief or the audit names each listed commit in one info line, so the list is visible.

## Requirements
> 14. `leak-check.sh` catches any absolute path outside the VULYK root, the hive roots in the private registry and Claude temp-folder paths, and today's hits in the repo are replaced with stand-ins.

## Files
- scripts/defects-check.sh
- tests/defects.test.sh

## Non-goals
- No change to `.scrub-revs` itself or to any card.

## Acceptance criteria
- [ ] Original case: story 04's commit, listed, over the masked quote of `command-injection-follows-cwd`: no ESCAPE.
- [ ] Neighbour: a listed commit that also changes a quote's words (not only a masked span) -> ESCAPE.
- [ ] Neighbour: a listed commit that adds a new quote line -> ESCAPE (the original red_reason).
- [ ] `tests/defects.test.sh` runs `defects-check.sh` on this tree and finds it green, and its audit prints one info line per listed commit.

- [ ] A story that adds a fixture to a block card and names it in `## Files` closes; the same file under a
  different card is still checked (original case: story 04's two new fixtures, 2026-11-13).

## Verification
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh`

## Implementation notes
