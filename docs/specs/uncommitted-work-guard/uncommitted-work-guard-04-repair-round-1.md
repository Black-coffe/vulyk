---
story: uncommitted-work-guard-04
status: done
returned: DONE
worker: worker-code
model: opus
wave: 2
blocked_by: []
red: required
red_reason: git-guard: a main-session cd then checkout over a dirty file is denied
red_verified_at: 2026-11-06T08:29:01Z addd71ffe72e0450e2c2f03ab5e25e2a9cd51599fea1ef599bb0a17adc456989
---

# Repair round 1

## Goal
Make the asks and findings council round 1 left RED pass, and change nothing else.

## Requirements
> 1. Предохранитель: воркерам всегда запрещены git-команды, стирающие работу, главной сессии — если пропадут незакоммиченные файлы (со списком этих файлов), только git, без rm.

## Findings
1. .claude/hooks/git-guard.sh:334 [ask 1] the main-session check must resolve the directory a preceding `cd` in the same command sets, as it already does for `git -C`: with `sub/f` dirty, a `cd sub` followed by `git checkout -- f` in one command runs the status query at the cwd of the call, finds nothing and lets the checkout discard `sub/f` with no deny, while the `-C sub` form of the same checkout is denied - repro: `R=$TMP/r; mkdir -p $R/sub; git -C $R init -q; echo a > $R/sub/f; git -C $R add -A; git -C $R -c user.email=t@t -c user.name=t commit -qm i; echo b > $R/sub/f; python3 -c "import json,sys;print(json.dumps({'tool_name':'Bash','tool_input':{'command':'cd sub && git checkout -- f'},'cwd':sys.argv[1]}))" "$(cd $R && pwd -W)" | bash .claude/hooks/git-guard.sh` prints nothing (the same input with the command `git -C sub checkout -- f` prints the deny).

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
- tests: addd71ffe72e0450e2c2f03ab5e25e2a9cd51599fea1ef599bb0a17adc456989 (tests/maintenance.test.sh)
- impl: 7fd41b476cc61f1ecb04af6215fa609cb4a8c24348d667cbea45c821cd0a0a9f
- stamped: 2026-11-06T08:29:01Z

```
::error::git-guard: a main-session cd then checkout over a dirty file is denied - expected '"deny"' in:
  ok    git-guard: no interpreter exits 0, silent
  ok    git-guard: --check fails on the original fixture
  ok    git-guard: --check fails on the neighbour fixture
  ok    git-guard: --check passes a file that is no hook input
--- git guard: a mod with tool.check
  ok    git-guard: an enabled mod with tool.check gets a brief line
  ok    git-guard: a disabled mod is not named
  ok    git-guard: no such mod, no line
  ok    git-guard: an enabled mod without tool.check, no line
maintenance.test.sh: 370 checks, 6 failed
```

## Implementation notes
- `git-guard.sh`: the main loop follows each `cd` / `chdir` / `pushd` / `Set-Location` / `sl` of the command in
  order (`cd_target`; a bare `cd` is home; on Windows a Git Bash `/e/x` becomes `e:/x`), and `-C` resolves from there.
  Fixes the finding's under-deny (`cd sub && git checkout -- f`) and the review minor's over-deny (`cd docs && git
  checkout .`). Parentheses still split segments, so a cd inside a subshell is taken as lasting: errs toward a deny.
- Review minor fixed in the same file: heredoc bodies are cut before parsing (`drop_heredocs`; `<<<` is not a heredoc
  start), since the reviewer itself was denied writing its report through `cat <<'EOF'`.
- Review minor fixed: `git-guard.sh` is committed as 100755.
- Left: the `--show` 300-line budget spent on paperwork first (scripts/human-check.sh, not in this story).
- Story trimmed per card `full-round-for-a-narrow-fix`: `## Files` and `## Verification` keep only what the fix touches.
- Repro from the finding, re-run: now prints the deny naming `sub/f`.
