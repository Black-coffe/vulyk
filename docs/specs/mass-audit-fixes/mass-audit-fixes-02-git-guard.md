---
story: mass-audit-fixes-02
spec: mass-audit-fixes
status: done
returned: DONE
tier: 4
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: forced checkout -b
red_verified_at: 2026-11-09T13:01:17Z 7bdb8bef885b882ea37fbeacac17ac95fa2d83ab2eb24f901e62d3dd52ac58c7
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
- `.claude/hooks/git-guard.sh`: launcher loop `${VULYK_PY:+"$VULYK_PY"} python3 python py`; stdin read as bytes, `utf-8-sig`.
- S4: `checkout -b/-B/--orphan` with `-f`/`--force` classifies as a whole-tree forced checkout; unforced still passes.
- S5/I8: `story_tier` returns `UNREAD` for a token holding `$`, backtick or `%`, or an unreadable plan.md; main session denied with its own reason. A plan.md with no `**Tier:**` line still passes (story names only "cannot be read").
- S6: continuation joined per tool (Bash `\`+newline, PowerShell backtick+newline) inside `split_segments`, after heredoc cutting; `env`/`env.exe` matched by basename; a subagent verb holding `$`/backtick is denied as unreadable.
- P5: `subprocess.TimeoutExpired` from git status denies with the timeout message; under `--check` a `porcelain` object `{"sleep": S, "timeout": T}` runs a real Python sleep stub through the same `subprocess.run` (chosen over a sentinel so the timeout path itself is exercised; a slow `git` stub on PATH was rejected: 8 s per run).
- `tests/maintenance.test.sh`: new block in the git-guard section, `chk` helper for `--check` payloads.
- Surprise: Git Bash rewrote the `/usr/bin/env git stash` argv for native Python into a Windows path; the helper sets `MSYS2_ARG_CONV_EXCL`. That test edit came after the first red receipt: implementation set aside, base restored, re-stamped (same impl hash), implementation re-applied.
- Surprise: the PowerShell backtick continuation was not denied before (the AC says "stays denied"); it is now.

## Findings
- close-story exit 4 twice: `bash tests/maintenance.test.sh` 441 checks, 2 failed, both `portability-check: the tree ...`
  from `install.sh:1022: heredoc-in-subst` (a `<<'PYFIX'` heredoc inside `$( )`). `install.sh` is not in this
  story's `## Files`; it is wave-mate story 04's uncommitted edit (still `returned:` empty). Every git-guard and law5
  check passes. Needs: story 04 to clear that hit (or close), then rerun this close-story; no change here required. Resolved: story 04 committed 727ecbc.

## Red receipt
- command: bash tests/maintenance.test.sh
- exit: 1
- tests: 7bdb8bef885b882ea37fbeacac17ac95fa2d83ab2eb24f901e62d3dd52ac58c7 (tests/maintenance.test.sh)
- impl: 2e5032f3480147e9d6f53bcbca0f068088019cecaeac94c12b3afb68ee65b77a
- stamped: 2026-11-09T13:01:17Z

```
::error::git-guard: forced checkout -b is denied: git checkout -f -b x - expected 'exit=1' in:
::error::git-guard: forced checkout -b is denied: git checkout -fb x - expected 'exit=1' in:
::error::git-guard: forced checkout -b is denied: git checkout --force -B x - expected 'exit=1' in:
  ok    git-guard: --check fails on the neighbour fixture
  ok    git-guard: --check passes a file that is no hook input
--- git guard: a mod with tool.check
  ok    git-guard: an enabled mod with tool.check gets a brief line
  ok    git-guard: a disabled mod is not named
  ok    git-guard: no such mod, no line
  ok    git-guard: an enabled mod without tool.check, no line
--- plan step 3a: the existing-repo horizon gate
  ok    plan 3a: the existing-repo gate counts a module under ## Unmapped territory beside ## Codebase map
maintenance.test.sh: 441 checks, 19 failed
```
