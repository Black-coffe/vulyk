---
story: post-043-tails-02
spec: post-043-tails
status: done            # todo | done | blocked - close-story writes done, a driver writes blocked
returned: DONE
tier: 2
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: trace-autopsy: the innermost Python frame is not the first shown frame
red_verified_at: 2026-10-28T20:12:14Z 53addb2743d708ca3f4dafe7066880e1c213ace8383d632583bc47c4e4f60862
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
- Red first: a fixture brief (`pymix`) with a traceback (`main.py:2`, `core.py:3`) followed by `web/server.js:2`,
  `lib/run.sh:2`, `lib/m1.py:1`. Before the fix the first shown frame was `lib/m1.py:1`, because the whole list was
  reversed and the traceback dropped out of the three shown frames.
- `frames_of` now sorts frames into the Python `File "...", line N` frames and all the others. When a `most recent
  call last` header is present it returns the Python frames reversed, then the others in written order. Without that
  header it returns every frame in written order, unchanged from before. The new `sh`-brief order check pins this.
- Speed check: three timed runs, the best one is compared against the unchanged 1000 ms. Here it took 241 ms.
- `symbol-map.sh` on `trace-autopsy.py`: its only exact importer is `trace-autopsy.sh`. `frames_of` is local, so no
  caller changes.

## Findings

## Red receipt
- command: bash tests/symbol-map.test.sh
- exit: 1
- tests: 53addb2743d708ca3f4dafe7066880e1c213ace8383d632583bc47c4e4f60862 (tests/symbol-map.test.sh)
- impl: 973dd08cff4d1ba8ed38a2bb79f7744f3c4f1092e9c6208de911b167979e31ac
- stamped: 2026-10-28T20:12:14Z

```
  ok    trace-autopsy: no repo frame says so
  ok    trace-autopsy: a build without src/ resolves by its two-part tail
  ok    trace-autopsy: no repo frame still names the ambiguous candidates
  ok    trace-autopsy: twelve frames fit in 8 lines (<= 15)
  ok    trace-autopsy: the overflow folds into a last '... N more' line
  ok    trace-autopsy: no argument exits 2
  ok    trace-autopsy: a brief outside any git repo exits 2
  ok    trace-autopsy: /vulyk-plan step 2 runs it
  ok    trace-autopsy: /vulyk-plan step 2 names autopsy.md
symbol-map.test.sh: 111 checks, 2 failed
```
