---
id: work-discarded-by-git-verb
title: A git verb run by an agent throws away work nobody committed
status: block
check: bash .claude/hooks/git-guard.sh --check <arg>
fixtures: [docs/defects/work-discarded-by-git-verb.original.fixture, docs/defects/work-discarded-by-git-verb.neighbour.fixture, docs/defects/work-discarded-by-git-verb.shell.fixture]
keys: [git stash, git checkout --, незакоммиченн]
paths: [".claude/hooks/git-guard.sh", "cmd:git +(-C +[^ ]+ +)?(stash|checkout|restore|reset|clean|switch|branch|worktree)"]
---

# A git verb run by an agent throws away work nobody committed
An agent runs a git verb that resets files, stashes them or deletes them, and the uncommitted work in those paths is
gone or parked where nobody looks: runtime counters the session never wrote, or another session's fix lying in the
same tree. Nothing fails at the moment it happens; the loss shows up later as missing data.

## Owner quotes

## Seen in this repo
Two incidents, described by shape (the repo is public):
- The main session restored a runtime stats file from git to tidy the tree before a commit; the counters
  in it were real data that existed nowhere else.
- A build worker in a hive found an uncommitted edit it had not made, took it for a foreign edit and stashed it; it
  was the Queen's own fix, waiting to be committed.

## Cause
A prose rule (`worker-code.md`: never `git stash`, `checkout`, `restore`, `reset` or `clean`) was the only guard. The
main session had none: a dirty file looked like noise to clean up, not like data.

## Check
`.claude/hooks/git-guard.sh` (PreToolUse, `Bash|PowerShell`) denies the verbs that discard work or commits: always for
a subagent, and for the main session when `git status --porcelain` shows the paths dirty or untracked, naming them
(the forms that lose a stash or commits, not tree files, are denied to subagents only). It reads the same verbs
handed to a shell (`bash -c`, `sh -c`, `pwsh -Command`), in a heredoc fed to a shell (`bash <<X`, `cat <<X | sh`),
and through a `git -c alias.<name>=` given on the command line. With no Python a bash fallback denies every listed
verb to any caller; a Python that starts and exits other than 0 or 1 on a git command denies it. A subagent is also
denied `git commit` and `git add` while a `docs/specs/*/DRIVER` exists, and every `cycle.sh` verb but `advance`,
`status`, `release`, `suite`, `stamp-red` (never `--baseline`) and `close-story`.
`--check <file>` runs it on a fixture (hook input JSON; a `porcelain` field stands in for `git status`) and exits 1
on a deny. Not covered, on purpose: `rm` / `Remove-Item`; a script file run by a shell and any other interpreter
that runs git (Python, Node); `pwsh -EncodedCommand` and a PowerShell here-string; an alias defined in git
config; a variable or substitution after the verb; `env` with options; a ref checkout over an untracked file;
`tag -f`, `push --force`, `rebase`, `commit --amend`, `reflog expire`, `gc --prune`, `filter-branch`; and a mod that
answers `tool.check`.

## Never
- Run `git stash`, `git checkout -- <path>` / `.` / `-f`, `git restore`, `git reset --hard`, `git clean -f`,
  `git switch -f`, `git branch -D` or `git worktree remove --force`, `git rm -f`, `git checkout-index -f` or
  `git read-tree -u --reset` (or any of them through `bash -c`, an alias or a heredoc fed to a shell) over a tree
  with uncommitted work you did not make, or `git branch -f`, `git checkout -B`, `git switch -C` or
  `git update-ref` over commits you did not make: commit it as its own commit, leave it, or ask the owner to run
  the command.

## Allowed
