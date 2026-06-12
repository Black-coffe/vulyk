---
story: <slug>-NN
spec: <slug>
status: todo            # todo | in-progress | done | blocked
tier: 1                 # routing tier of this story's worker
worker: worker-code     # worker-code | worker-test
---

# <Story title>

## Goal
<one paragraph - what exists after this story that does not exist now>

## Files
<explicit list - Law 3 boundary; the worker may touch nothing else>

## Map slice
<memory/map/<module>.md sections the worker should load>

## Acceptance criteria
- [ ] <observable behavior, not implementation detail>
- [ ] <...>

## Verification
`<exact command the worker runs to prove the criteria>`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
