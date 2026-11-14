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

# A record row counts as written only by a command that writes the file

## Goal
`.claude/hooks/owner-guard.sh` stops treating a shell command as writing a `memory/stats/human.jsonl` row merely
because the command names that path and holds `ACCEPTED` or `REJECTED` somewhere (today: line 410). A command
counts as a row write only when it writes to the file, by the same forms the guard already reads for a plan.md
rewrite: a redirect into it (`>`, `>>`), `tee`, `cp` / `mv` onto it, `sed -i` / `awk -i` naming it, or an
interpreter (`python -c`, `node -e`, a heredoc fed to one) naming it. A `git add`, `git commit` (its message
included), `git diff` / `git log` / `cat` / `grep`, or a heredoc that only writes other files and merely contains
the path passes. The subagent rule stays: a subagent is still denied every real write.

## Requirements
> 1. owner-guard counts a shell command as writing a `human.jsonl` row only when it writes to that file (a redirect into it, `tee`, `cp`/`mv` onto it, an interpreter or `sed -i` naming it); a `git add`, `git commit`, a read, or text that only names the path passes, whatever its message says.

## Files
- .claude/hooks/owner-guard.sh
- tests/defects.test.sh

## Non-goals
- No change to the quote rule, to the plan.md marker checks or to any other hook.
- No new escape: a real write into the record by the main session without the owner's quote stays denied.

## Acceptance criteria
- [ ] Original case passes, main session and subagent: `git add <spec>/plan.md memory/stats/human.jsonl && git commit -m "vulyk(<slug>): human check ACCEPTED"`.
- [ ] Neighbours pass: `cat memory/stats/human.jsonl`; a heredoc to a temp file whose body
  names the record path and the word ACCEPTED.
- [ ] Still denied (subagent, and main session without the owner's quote): `echo '{"verdict":"ACCEPTED"}' >> memory/stats/human.jsonl`; `tee -a memory/stats/human.jsonl`; `python -c "open('memory/stats/human.jsonl','a')..."`.
- [ ] The header's left-open list stays true.

## Verification
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh`

## Implementation notes
- `.claude/hooks/owner-guard.sh`: `rewrites_plan` takes a `target` pattern (default the plan.md path); the record
  rule now asks `rewrites_plan(cmd, powershell, target=RECORD)` instead of "names human.jsonl and says ACCEPTED".
  So a git add/commit, a read or a heredoc to another file passes, and any write into the record is guarded
  whatever it says: the red receipt showed `tee -a` and `python -c open(...)` into the record passed before.
- Header: says what counts as a row write, and that with no Python the bash fallback still denies every command
  naming the record (unchanged, fails closed).
- `tests/defects.test.sh`: 9 rows, the original commit case for a subagent and the main session, 3 passing
  neighbours, 4 still-denied writes.
CHANGELOG: owner-guard counts a `memory/stats/human.jsonl` row as written only by a command that writes the file; committing or reading the record passes, and every real write into it is guarded.

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
