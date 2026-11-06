---
story: uncommitted-work-guard-05
status: todo
returned:
worker: worker-code
model: opus
wave: 3
blocked_by: []
red: required
red_reason:
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
- .claude/settings.json
- install.sh
- .claude/hooks/session-start-brief.sh
- .claude/commands/vulyk-status.md
- docs/defects/work-discarded-by-git-verb.md
- docs/defects/work-discarded-by-git-verb.original.fixture
- docs/defects/work-discarded-by-git-verb.neighbour.fixture
- docs/defects/INDEX.md
- docs/hooks-reference.md
- tests/maintenance.test.sh
- scripts/human-check.sh
- .claude/commands/vulyk-build.md
- tests/cycle.test.sh
- .claude/hooks/defect-intake.sh
- tests/intake.test.sh
- docs/pulse.md

## Verification
`bash tests/maintenance.test.sh`
`bash scripts/defects-check.sh docs/defects/work-discarded-by-git-verb.md`
`git ls-files '*.sh' | xargs -n1 bash -n`
`bash tests/cycle.test.sh --part ship`
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh`
