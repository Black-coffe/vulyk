---
story: audit-fixes-1113-18
spec: audit-fixes-1113
status: done
returned: DONE
tier: 3
worker: worker-code
wave: 10
blocked_by: [audit-fixes-1113-17]
---

# The e2e worker stub follows the driver's story-id prompt

## Goal
Story 17 made the Workflow driver hand a worker its story by id ("Your story: <id> - the story file in <spec>/ whose
frontmatter says `story: <id>`"). `tests/e2e.test.sh`'s worker stub still parses the old "Your story: <file>. " form,
gets null, and both e2e parts fail (round-5 suite: `e2e:green` and `e2e:red` FAIL; every other part green). The stub
finds the story file the way a real worker now does: the file in the spec folder whose frontmatter `story:` line
equals the id. Nothing else changes. Cut by the Queen after the real driver launch of 2026-11-14 (owner's narrow-repair
rule: own tests only).

## Requirements
> 3. `/vulyk-ship` pushes a spec branch only to a private origin; with a public origin it asks the owner (landed as Tier 0 in 86e15292); a test pins it.

## Files
- tests/e2e.test.sh

## Non-goals
- No change to the driver, cycle.sh or any other test.

## Acceptance criteria
- [ ] `bash tests/e2e.test.sh --part green` and `--part red` pass, with the driver unchanged.

## Verification
`bash tests/e2e.test.sh`

## Implementation notes
- tests/e2e.test.sh: worker stub parses "Your story: <id> - the story file in <spec>/" and picks the .md in that folder whose frontmatter line is `story: <id>`.
- Driver, cycle.sh untouched; green and red parts pass locally.
