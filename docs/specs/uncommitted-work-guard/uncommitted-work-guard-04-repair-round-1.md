---
story: uncommitted-work-guard-04
status: todo
returned:
worker: worker-code
model: opus
wave: 2
blocked_by: []
red: required
red_reason:
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
