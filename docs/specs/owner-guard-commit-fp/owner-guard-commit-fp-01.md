---
story: owner-guard-commit-fp-01
spec: owner-guard-commit-fp
status: done
returned: DONE
tier: 1
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: a git commit that only names the record file passes
red_verified_at: 2026-11-14T16:35:17Z 132f4dff9af38f38c1eada819f3467835972bc8b54f2f0c6917a34b8a469bedc
---

# The record is committed by human-check --commit; the guard keeps the strict rule

## Goal
`.claude/hooks/owner-guard.sh` keeps (restores, from bc962e77) the strict record rule: a shell command that names
`memory/stats/human.jsonl` beside the word `ACCEPTED` or `REJECTED` counts as writing a row, a `git add` /
`git commit` of the record included. The false positive that started this spec, an agent committing the row
`human-check.sh` had just written, goes away because the agent no longer makes that commit:
`scripts/human-check.sh ... --commit` commits its own `plan.md` line and record row with `git commit -- <those
paths>`. The callers (`/vulyk-build`, `/vulyk-review`, the docs that name the command) say `--commit`. The guard
reads `--commit` as no part of the spec or the note.

## Requirements
> 1. owner-guard keeps the strict record rule: a shell command naming `human.jsonl` beside ACCEPTED or REJECTED is a row write, a `git add` / `git commit` included; `scripts/human-check.sh --commit` commits its own `plan.md` line and record row with `git commit -- <those paths>`, so no agent command has to name the record beside a verdict, and the callers use `--commit`.

## Files
- .claude/hooks/owner-guard.sh
- scripts/human-check.sh
- tests/defects.test.sh
- .claude/commands/vulyk-build.md
- .claude/commands/vulyk-review.md
- docs/cycle.md
- docs/command-reference.md
- docs/hooks-reference.md

## Non-goals
- No change to the quote rule, to the plan.md marker checks or to any other hook.
- No parsing of what a shell command does to the record (the allowlist and heredoc versions are dropped).
- Checking a row's integrity where it is read is a later spec.

## Acceptance criteria
- [ ] Original case: an agent's own `git add <spec>/plan.md memory/stats/human.jsonl && git commit -m "... ACCEPTED"` is
  denied (subagent and main session), and the refusal names `human-check.sh ... --commit`.
- [ ] `human-check.sh <spec> ACCEPTED "<owner quote>" --commit` (flag after the note or before the spec) passes in the
  main session under the quote rule and is denied to a subagent; inside `bash -c` it is still read.
- [ ] `human-check.sh --commit` commits exactly the plan.md line and the record row, with
  `vulyk(<slug>): human check <VERDICT>`, and leaves anything else staged uncommitted; the note is stored without the flag.
- [ ] Every bypass form the re-checks found (19) is denied to a subagent when it carries a verdict word.
- [ ] Reads without a verdict word pass; the header names the forms left open on purpose.

## Verification
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh`

## Implementation notes
- `owner-guard.sh` restored from bc962e77; the `human-check.sh` reader drops `--commit` words before it takes the
  spec, the verdict and the note (seg reader and the raw-text fallback); the record rule's message names `--commit`.
- `human-check.sh`: `--commit` anywhere among the arguments; `git add` then `git commit -- <plan.md> <record>`;
  a failed commit exits 1 and says the record is written but not committed.
- Known cost of the strict rule: `grep ACCEPTED memory/stats/human.jsonl` is refused (use `tail`, or the Read tool);
  text naming the record beside a verdict goes through the Write tool.
CHANGELOG: `human-check.sh --commit` records and commits the owner's check (its plan.md line and record row only); owner-guard keeps refusing any other command that names the record beside a verdict word, an agent's own `git commit` of it included.

## Red receipt
- command: bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh
- exit: 1
- tests: 132f4dff9af38f38c1eada819f3467835972bc8b54f2f0c6917a34b8a469bedc (tests/defects.test.sh)
- impl: 0a47ce2c1ec24c22aeca8ac4cefdaa2d8c0a4f3f285de2aa59dcc3f799dd5bb0
- stamped: 2026-11-14T16:35:17Z

```
::error::owner guard: a git commit that only names the record file passes - subagent
::error::owner guard: a git commit that only names the record file passes - main session
::error::owner guard: reading the record file passes
::error::owner guard: a heredoc to another file that only mentions the record passes
  ok    owner guard: a redirect into the record is still denied - subagent
::error::owner guard: tee into the record is still denied - subagent
::error::owner guard: an interpreter writing the record is still denied - subagent
  ok    owner guard: a redirect into the record is still denied - main session without a quote
--- this tree's library: green, one info line per .scrub-revs commit (audit-fixes-1113-12)
  ok    defects-check on this tree is green, no ESCAPE (story 04's masked quote of command-injection-follows-cwd)
  ok    the audit of this tree prints one info line per listed commit
defects.test.sh: FAILED
```
