---
story: uncommitted-work-guard-02
spec: uncommitted-work-guard
status: done
returned: DONE
tier: 2
worker: worker-code
wave: 1
blocked_by: []
---

# The diff in the reply before ACCEPTED

## Goal
`scripts/human-check.sh --show <spec-dir>` prints the pack's change for the owner: `git diff --stat` from the spec's
base to HEAD, then the diff, capped (300 lines, then a line naming how many were cut and the command for the rest).
`/vulyk-build`'s `escalated` terminal and its `green` «Выпускаем?» step tell the Queen to paste that output as a
fenced block in the reply text, before asking, and to record ACCEPTED only with the owner's own words.

## Requirements
> 3. Дифф текстом в ответе перед вашим ACCEPTED.

## Files
- scripts/human-check.sh
- .claude/commands/vulyk-build.md
- tests/cycle.test.sh

## Non-goals
- `human-check.sh` still never judges and still exits 0 when recording; `--show` writes nothing.
- No change to `/vulyk-ship`'s gates.

## Map slice
memory/map/scripts.md (human-check.sh, lib.sh `pack_fingerprint`)

## Acceptance criteria
- [ ] `--show` on the test spec prints a stat line and a diff; a diff over the cap ends with the cut line.
- [ ] `--show` on a missing spec dir exits non-zero with a message (missing input is never a silent pass).
- [ ] `vulyk-build.md` names `--show` in both the `escalated` and `green` steps.

## Verification
`bash tests/cycle.test.sh --part ship`

## Implementation notes
- `scripts/human-check.sh --show <spec-dir>`: base = merge-base with the default branch while on the spec branch,
  else the parent of the commit that added `<spec>/plan.md` (the empty tree for a root commit); `diff --stat`, then
  the diff capped at 300 lines and `... N more lines cut; the rest: git diff <base7> HEAD`. Missing spec dir or no
  git repo: exit 2 with a message. Writes nothing; the recording path is unchanged.
- The default-branch lookup is inlined (cycle.sh `default_branch` is not in lib.sh, and lib.sh is not in ## Files).
- `/vulyk-build`: `green` and `escalated` paste `--show` as a fenced block in the reply text; `escalated` says the
  ACCEPTED note is the owner's own words.
- Tests: the `ship` part builds its own small repo on a `vulyk/s` branch (the shared fixture is on main, whose
  diff from the empty tree is all the copied scripts).

## Findings
