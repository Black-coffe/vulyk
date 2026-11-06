---
story: uncommitted-work-guard-05
status: done
returned: DONE
worker: worker-code
model: opus
wave: 3
blocked_by: []
red: required
red_reason: git-guard: an unresolvable cd target still checks the tree
red_verified_at: 2026-11-06T11:26:14Z cd47e75d55152028aecc82a2a49657b810e7f47e0499139266114ee7f56561b3
---

# Repair round 2

## Goal
Make the asks and findings council round 2 left RED pass, and change nothing else.

## Requirements
No brief ask is RED in round 2 - the findings below are the whole task.

## Findings
1. .claude/hooks/git-guard.sh:292 [regression] when a `cd` target cannot be resolved to an existing folder (a command substitution, a shell variable, a Git Bash path such as `/tmp` on Windows, `cd -`) the main-session check must still query a real tree (keep the previous `here`, or treat the call as unreadable) instead of failing open: `here` becomes `<cwd>/$(git rev-parse --show-toplevel)`, `git -C` of it exits non-zero and `status()` returns `[]` at line 239-240, so the verb passes silently, while the base denied it by querying the call's cwd - repro: `R=$TMP/r; mkdir -p $R/sub; git -C $R init -q; echo a > $R/sub/f; git -C $R add -A; git -C $R -c user.email=t@t -c user.name=t commit -qm i; echo b > $R/sub/f; git show bde477c:.claude/hooks/git-guard.sh > $TMP/base.sh; for c in 'cd "$(git rev-parse --show-toplevel)" && git checkout .' 'cd $R && git reset --hard' 'cd /tmp && git reset --hard' 'cd - && git checkout .'; do python3 -c "import json,sys;print(json.dumps({'tool_name':'Bash','tool_input':{'command':sys.argv[2]},'cwd':sys.argv[1]}))" "$(cd $R && pwd -W)" "$c" | bash .claude/hooks/git-guard.sh; done` prints nothing for all four, and the same loop piped into `bash $TMP/base.sh` prints the deny naming `sub/f` for all four.

## Files
- .claude/hooks/git-guard.sh
- tests/maintenance.test.sh

## Verification
`bash tests/maintenance.test.sh`
`bash scripts/defects-check.sh docs/defects/work-discarded-by-git-verb.md`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Red receipt
- command: bash tests/maintenance.test.sh
- exit: 1
- tests: cd47e75d55152028aecc82a2a49657b810e7f47e0499139266114ee7f56561b3 (tests/maintenance.test.sh)
- impl: 06204cc73340ca486229ba100a95fa7a0f75966deb349e1e049d6a77f63949ce
- stamped: 2026-11-06T11:26:14Z

```
::error::git-guard: an unresolvable cd target still checks the tree: cd "$(git rev-parse --show-toplevel)" && git checkout . - expected 'sub/f' in:
::error::git-guard: an unresolvable cd target still checks the tree: cd $SOMEWHERE && git reset --hard - expected 'sub/f' in:
::error::git-guard: an unresolvable cd target still checks the tree: cd /no/such/folder && git reset --hard - expected 'sub/f' in:
  ok    git-guard: no interpreter exits 0, silent
  ok    git-guard: --check fails on the original fixture
  ok    git-guard: --check fails on the neighbour fixture
  ok    git-guard: --check passes a file that is no hook input
--- git guard: a mod with tool.check
  ok    git-guard: an enabled mod with tool.check gets a brief line
  ok    git-guard: a disabled mod is not named
  ok    git-guard: no such mod, no line
  ok    git-guard: an enabled mod without tool.check, no line
maintenance.test.sh: 379 checks, 7 failed
```

## Implementation notes
- `git-guard.sh`: a cd the hook cannot follow (`$VAR`, `$(...)`, backticks, `cd -`, `popd`, a target that is no
  folder) sets `here` to UNKNOWN; a later git verb is then checked against the whole tree of the call's cwd, pathspecs
  dropped (they are relative to a folder it cannot name). Errs toward a deny.
- When `git status` fails in a resolved folder (on Windows Python reads Git Bash `/tmp` as `C:/tmp`, not a repo), the
  check falls back to the whole tree of the call's cwd instead of reading the failure as "nothing dirty". Found by the
  repro's `cd /tmp` form after the first fix; its test was added by reverting the hook to HEAD, re-stamping the red
  receipt and putting the implementation back.
- `<<` inside a quoted string is not a heredoc start (`quoted()`).
- The executable bit: `git update-index --chmod=+x` right before close-story; the round-1 one was lost by the close.
- Left as named limits: a `cd` into another repo that the hook resolves is checked there; a cd inside `( )` counts as
  lasting.
