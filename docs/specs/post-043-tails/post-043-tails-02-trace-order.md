---
story: post-043-tails-02
spec: post-043-tails
status: todo            # todo | done | blocked - close-story writes done, a driver writes blocked
returned:              # written by whoever builds the story, as its last edit: DONE | NEEDS_CONTEXT | WALL
tier: 2
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason:           # the expected failure text, written by the builder before `stamp-red`
# red_verified_at:      # written by `cycle.sh stamp-red`, never by hand
---

# trace-autopsy frame order and a load-proof speed check

## Goal
A brief holding a Python traceback and `path:N` frames after it shows the innermost Python frame first: only the
traceback's own frames are reversed, the others keep their written order. The trace-autopsy speed check takes the best
of three runs under the same 1000 ms, so a loaded box does not turn it red. Red test first: a fixture brief with a
traceback followed by three plain `path:N` refs must show the innermost Python frame among the shown frames; it fails today.

## Requirements
> 3. trace-autopsy: порядок фреймов при «most recent call last»; тест скорости не зависит от нагрузки.

## Files
- scripts/trace-autopsy.py
- tests/symbol-map.test.sh

## Non-goals
- No new frame forms, no `--rev`, no bisect, no `dist/` mapping (declined in spec trace-autopsy).
- Do not raise the 1000 ms threshold or drop the speed check.
- No change to `symbol-map.py` or its own tests' cases.

## Map slice
`memory/map/scripts.md` (trace-autopsy).

## Acceptance criteria
- [ ] Traceback + three trailing `path:N` refs: the innermost Python frame is the first shown frame; the trailing refs follow in order.
- [ ] A brief with no traceback keeps its written frame order.
- [ ] The speed check reports the best of three runs, threshold unchanged.

## Verification
`bash tests/symbol-map.test.sh`

## Implementation notes

## Findings
