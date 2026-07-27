---
story: <slug>-NN
spec: <slug>
status: todo            # todo | in-progress | done | blocked
tier: 1                 # routing tier of this story's worker
worker: worker-code     # worker-code | worker-test
tracer: false           # true on the FIRST story of an epic - see Tracer below
---

<!--
Size budget: keep this file under ~1500 tokens (~6 KB). A story that does not fit is
an epic wearing a disguise - split it. The budget is the mechanism: it forces the
planner to decide what matters instead of pasting everything it read.
-->

# <Story title>

## Goal
<one paragraph - what exists after this story that does not exist now>

## Files
<!--
MACHINE-READABLE. One repo-relative path or glob per line, prefixed with "- ".
No prose, no comments on the same line - `scripts/scope-check.sh` parses this block
and compares it against the actual diff. Prose here silently breaks the scope gate.
This list is also the Law 3 boundary: the worker may touch nothing else.
-->
- path/to/file.ext

## Non-goals
<!--
What a capable worker will be tempted to do here and must NOT. This is the highest-value
section in the template: models expand scope when the task looks small next to their
capability, and an explicit stop-list is cheaper than a review round.
Write what THIS story invites, not generic prohibitions - "do not also migrate the old
callers" beats "do not write bad code". If the list reads as noise, that is a signal the
goal is under-specified, not that the section is useless.
-->
- <...>

## Map slice
<memory/map/<module>.md sections the worker should load>

## Acceptance criteria
- [ ] <observable behavior, not implementation detail>
- [ ] <...>

## Verification
`<exact command the worker runs to prove the criteria>`

## Tracer
<!--
Only when `tracer: true`. The first story of an epic should cut through every layer with
the thinnest possible slice - one route, one record, one assertion - before the remaining
stories add breadth. Half the time the slice changes what the rest of the epic should be,
and finding that out on story 1 is far cheaper than on story 6.
Name here which layers the slice must touch.
-->

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
