---
story: close-story-scope-refusal-01
spec: close-story-scope-refusal
status: done
returned: DONE
tier: 1
worker: worker-code
model: sonnet
wave: 1
blocked_by: []
---

# close-story refuses an edit outside ## Files

## Goal
In `cmd_close_story` (`scripts/cycle.sh`), right after `bash "$HERE/scope-check.sh" "$STORY"` (around line 1848) and
only with `--commit`: take the paths scope-check counted out of scope for this story, keep those that
`dirty_outside_paperwork` also reports, and if any remain, refuse before verification and before any commit, with the
plan's `## Contracts` stderr line and `emit false close-story 4 repair "edited outside ## Files: <paths>"`. The story
file and every other file stay as they were. With no such path, close-story behaves exactly as today.

Get scope-check's out-of-scope list from its own output (`  ! <path>` lines) or by sharing its logic; keep one source
of truth for what "out of scope" means: scope-check's sibling and paperwork rules must apply unchanged.

The worker agents learn what to do with it: in `.claude/agents/worker-code.md` step 5 and `.claude/agents/worker-test.md`
step 5, one line under exit 4: edited outside `## Files` means undo your own edits to those paths (edit them back, or
delete a file you created; never `git checkout`/`restore`/`stash`, wave-mates share the tree), or, when the story truly
needs them, write the paths under `## Findings` and return `NEEDS_CONTEXT`.

## Requirements
> 1. close-story refuses a worker's edit outside ## Files: exit 4 listing the paths that scope-check counts out of scope and that would leave the tree dirty for open-round, so the worker reverts or returns NEEDS_CONTEXT in its own turn instead of the driver stopping at open-round later.

## Files
- scripts/cycle.sh
- tests/cycle.test.sh
- .claude/agents/worker-code.md
- .claude/agents/worker-test.md

## Non-goals
- No change to `scripts/scope-check.sh` (it records, never blocks) or to `dirty_outside_paperwork` / `is_paperwork_path`.
- No change without `--commit`, and none to open-round or claim.

## Acceptance criteria
- [ ] Cases in `tests/cycle.test.sh`, on its throwaway repo:
  - a story whose diff touches its declared file and one undeclared tracked file: `close-story --commit` exits 4,
    the JSON `error` names the undeclared path, nothing is committed (HEAD unchanged) and the story's `status:` is
    unchanged;
  - after that edit is undone, the same `close-story --commit` exits 0 and the tree is clean;
  - an undeclared untracked new file refuses the same way;
  - an out-of-scope path that is paperwork (`memory/stats/skills.json`) does not refuse;
  - without `--commit`, an undeclared edit does not refuse.
- [ ] The first case goes red with the refusal removed (say so in `## Implementation notes`).
- [ ] Every case that `tests/cycle.test.sh` ran before still passes.

## Verification
`bash tests/cycle.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes
- scripts/cycle.sh: `cmd_close_story` keeps scope-check's output, prints it as before, and with `--commit` intersects its `  ! <path>` lines with `dirty_outside_paperwork`; a non-empty intersection exits 4 before verification and before any commit (stderr and JSON per plan `## Contracts`). scope-check's own rules (siblings, its ledger, the story file) stay the one source of "out of scope".
- tests/cycle.test.sh: section `close-story-scope-refusal`, six cases (tracked stray, nothing committed + status kept, undone then exit 0 and clean, untracked new file, paperwork skills.json passes, no `--commit` passes). With the refusal disabled (`if false`) the first case went red: `exit=0`.
- Worker agents: the exit-4 line says what to do with `edited outside ## Files` (undo own edits without checkout/restore/stash, or NEEDS_CONTEXT).
- Also ran `bash tests/driver.test.sh`: green (it reads worker-code.md for maxTurns only).

## Findings
