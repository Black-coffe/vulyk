---
story: owner-guard-commit-fp-01
spec: owner-guard-commit-fp
status: todo
returned:
tier: 1
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: a git commit that only names the record file passes
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
