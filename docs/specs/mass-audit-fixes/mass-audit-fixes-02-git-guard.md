---
story: mass-audit-fixes-02
spec: mass-audit-fixes
status: todo
returned:
tier: 4
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: forced checkout -b
---

# git-guard: every Python launcher, UTF-8 stdin, and five classified gaps closed

## Goal
`.claude/hooks/git-guard.sh` finds Python the way `lib.sh` does (`$VULYK_PY`, python3, python, py; an exit of 0
or 1 means it ran), reads hook stdin as bytes decoded UTF-8 (BOM tolerated), and closes the gaps the private
audit (2026-11-08) classified: S4 (a forced `checkout -b`/`-B`/`--orphan` discards tracked edits and is denied
like any forced checkout), S5/I8 (a `close-story` story token holding `$`, a backtick or `%`, or whose
`plan.md` cannot be read, is unknown and denied in the main session: the Law 5 half fails closed like the git
half), S6 (a backslash-newline or backtick-newline continuation is joined before lexing; `env` is matched by
basename so `/usr/bin/env git` counts; a verb token holding `$` or a backtick is unreadable for a subagent),
P5 (a `git status` that times out denies with `git status timed out, cannot prove the tree is clean` instead of
allowing). The hook header's "not covered" list is updated to match. Asks 5 and 11 (the rest of P2, the P10-01
class). Marked red: security branches.

## Requirements
> 5. P9-18 / P10-10 extended: `git-guard.sh` tries `$VULYK_PY`, python3, python, py like `lib.sh`, and reads hook stdin as UTF-8 (the rest of our P2).
> 11. Every finding of our private audit that the merged branch does not close (Scope E) is fixed, with a regression test wherever code can check it.

## Files
- .claude/hooks/git-guard.sh
- tests/maintenance.test.sh

## Non-goals
- Do not add coverage of `rm`, `bash -c`, scripts or aliases: the header excludes them on purpose.
- Do not change the main-session rule (deny only when the affected paths are dirty) or the fail-open on bad
  JSON / no Python; this story adds launchers, not a new failure mode.
- Do not touch `docs/hooks-reference.md`: story 13 updates the prose.
- Do not edit `tests/maintenance.test.sh` outside the git-guard block.

## Map slice
`memory/map/scripts.md` → Entry points (`.claude/hooks/git-guard.sh` bullet), Gotchas (bash 3.2 / BSD).

## Acceptance criteria
- [ ] With a PATH holding only `py` (stubbed), a subagent `git reset --hard` payload is denied; with `VULYK_PY`
  set to a working interpreter and no python on PATH, the same.
- [ ] A payload with a UTF-8 BOM and Cyrillic in `command` is parsed and denied where its verb is listed.
- [ ] `--check`, subagent: `git checkout -f -b x` and `git checkout -fb x` are denied; `git checkout -b x` passes.
- [ ] `--check`, main session, Tier 3 plan: `S=docs/specs/x/01.md; bash scripts/cycle.sh close-story "$S"` is
  denied; a story whose `plan.md` is missing is denied; the literal Tier 3 path stays denied, a Tier 1 path passes.
- [ ] `--check`, subagent: `git \<newline>stash`, `/usr/bin/env git stash`, `git $(echo stash)` are denied;
  `git -c core.pager=cat stash push` stays denied; the PowerShell backtick continuation stays denied.
- [ ] `--check` with a `porcelain` field that makes status time out (a stub exceeding the timeout) denies with the
  timeout message; `git status` succeeding keeps today's behaviour.
- [ ] The failing-test label for the S4 case contains `forced checkout -b`.
- [ ] `bash scripts/portability-check.sh .claude/hooks/git-guard.sh` stays clean.

## Verification
`bash tests/maintenance.test.sh`

## Implementation notes

## Findings
