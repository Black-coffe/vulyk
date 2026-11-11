---
story: handoff-1m-01
spec: handoff-1m
status: todo
returned:
tier: 1
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason:
---

# Handoff offered at 70/80/90% of the real window

## Goal
`handoff.py` speaks first at 70% of the session's window (banner and model-facing prompt both offer
`/vulyk-handoff`), then at 80% and 90%. A session missing from the statusbar cache borrows the window Claude Code
last reported on this machine for the same model, so a 1M session is not measured against 200k. The owner's
correction becomes card `handoff-offered-too-early` with a check that runs a given `handoff.py` through three
sessions and fails when it speaks early.

## Requirements
> 1. The VULYK handoff hook offers a handoff at 70%, 80% and 90% of the session's context window and never earlier: on a 1M window at 700k, 800k and 900k tokens.
> 2. A session whose own window is not in the statusbar cache takes the window Claude Code last reported on this machine for the same model, instead of guessing 200k.
> 3. The owner's correction is a defect card with a failing check and an original plus a neighbour fixture.

## Files
- .claude/hooks/handoff.py
- tests/handoff-hooks.test.py
- tests/handoff.test.sh
- scripts/handoff-window-check.py
- docs/defects/handoff-offered-too-early.md
- docs/defects/handoff-offered-too-early.original.fixture
- docs/defects/handoff-offered-too-early.neighbour.fixture
- docs/defects/INDEX.md
- docs/hooks-reference.md

## Non-goals
- No change to the dump, restore, precompact or sessionend modes, nor to the cache-TTL note.
- Do not touch the owner's personal `context_guard.py` (outside this repo).
- Do not remember a borrowed window in the session state: only observed sources are remembered.

## Map slice
memory/map/scripts.md (hooks: handoff)

## Acceptance criteria
- [ ] Default `thresholds_pct` is `[70, 80, 90]`; a pinned `context_limit` or absolute `thresholds` still win.
- [ ] Prompt mode speaks from level 1 ("Gently" at 1, "Strongly" at 2-3, "Do not start" at 3); the level 1 banner offers `/vulyk-handoff`.
- [ ] 151k tokens, no cache for this session, a statusLine copy older than 6 h for the same model with 1M: silent.
- [ ] 650k tokens on a known 1M window: silent; 710k: the prompt offers `/vulyk-handoff`.
- [ ] A copy for another model lends no window.
- [ ] `bash scripts/py.sh scripts/handoff-window-check.py` exits 0 on the hook and 1 on both fixtures (the
      original: the hook as on main 616a3c2e; the neighbour: thresholds moved to 70/80/90 without the window fix).

## Verification
`bash tests/handoff.test.sh`
`bash scripts/defects-check.sh handoff-offered-too-early`
`bash scripts/py.sh -m py_compile .claude/hooks/*.py`

## Implementation notes

## Findings
