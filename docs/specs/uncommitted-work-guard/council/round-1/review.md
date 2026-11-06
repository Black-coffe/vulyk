<!-- seat: review · model: claude-fable-5-1 · round: 1 · head: 9163b32 · pack: e26fe2f21746 · attempt: 1 · recorded: 2026-11-06T08:26:44Z · verdict: BLOCK -->
VERDICT: BLOCK
SUITE: ok 744s
MODEL: claude-fable-5-1

## Critical
None.
## Major
1. .claude/hooks/git-guard.sh:334 [ask 1] the main-session check must resolve the directory a preceding `cd` in the same command sets, as it already does for `git -C`: with `sub/f` dirty, a `cd sub` followed by `git checkout -- f` in one command runs the status query at the cwd of the call, finds nothing and lets the checkout discard `sub/f` with no deny, while the `-C sub` form of the same checkout is denied - repro: `R=$TMP/r; mkdir -p $R/sub; git -C $R init -q; echo a > $R/sub/f; git -C $R add -A; git -C $R -c user.email=t@t -c user.name=t commit -qm i; echo b > $R/sub/f; python3 -c "import json,sys;print(json.dumps({'tool_name':'Bash','tool_input':{'command':'cd sub && git checkout -- f'},'cwd':sys.argv[1]}))" "$(cd $R && pwd -W)" | bash .claude/hooks/git-guard.sh` prints nothing (the same input with the command `git -C sub checkout -- f` prints the deny).
## Minor
- .claude/hooks/git-guard.sh:131 a heredoc body or quoted prose is parsed as commands: this reviewer (a subagent) was denied `cat > report.md <<'EOF' ...` because a markdown line inside it mentioned the checkout after `&&`; skipping `<<` bodies would spare workers that write files or tests through Bash.
- .claude/hooks/git-guard.sh is committed as mode 100644 while the wired hooks beside it are 100755 (`git ls-files -s .claude/hooks/`); install.sh chmods on copy, so only a POSIX clone of this repo runs it unexecutable.
- scripts/human-check.sh:591 the 300-line cap is spent in git path order, so for this very pack `.claude/hooks/git-guard.sh` (293 lines) and the spec paperwork come before `scripts/` and `tests/`; excluding `docs/specs/<slug>/` and `memory/stats/` from the shown diff would give the owner code in those 300 lines.
- .claude/hooks/git-guard.sh:334 the same unresolved `cd` over-denies in the other direction: `cd docs` then `git checkout .` on this tree is refused for `memory/stats/skills.json`, a file that command would not touch.
- council/round-1/suite.log says `head=bde477c`, the ROUND head; the commits up to 9163b32 are the suite step paperwork only (ROUND, suite.log, journal.md), so the log is for the code under review.
