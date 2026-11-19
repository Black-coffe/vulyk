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
verb to any caller; a Python that starts and exits other than 0 or 1 on a git command denies it. Every caller is
denied a forced tag and a forced push (forms no agent needs); a subagent also PowerShell's Invoke-Expression,
which the main session may run, its string read as commands. A subagent is also
denied `git commit` and `git add` while a `docs/specs/*/DRIVER` exists, and every `cycle.sh` verb but `advance`,
`status`, `release`, `suite`, `stamp-red` (never `--baseline`) and `close-story`, past a shell option that carries
a value, a verb or script that xargs hands in, a command held in a variable, a wrapper before a pattern or a
variable script word, a wrapper option held in a variable, and a shell's script word held in a variable with a
default (read as its default).
`--check <file>` runs it on a fixture (hook input JSON; a `porcelain` field stands in for `git status`) and exits 1
on a deny. A cd moves the place a subagent's commit is judged in only where it takes effect (not in another
subshell, a child shell's command string, a pipeline, the background, or with two folder words; after `||` the
place counts as held), a command word with a variable only in its folder part is judged by its literal file name,
and one whose default or value from the command names git, cycle.sh, a shell, a wrapper or eval as that program.
The guards stop accidents and shortcuts of a cooperative agent, not an adversary.

Left open (the hook header carries this list word for word):
- rm and Remove-Item, and a ref checkout over an untracked file;
- a script file run by a shell, and any other interpreter that runs git;
- command text piped into a shell, a here-string fed to a shell, an encoded PowerShell command, a PowerShell
  here-string fed to a shell, and wrapper commands the hook does not know (a shell function or alias of the
  session among them);
- an alias defined in git config rather than on the command line;
- a variable or substitution in an argument after the git verb;
- the run state reached by a name the command never spells (a parent folder walked by a recursive tool, a
  folder reached by a cd the hook cannot follow), a redirect glued to the word before it, a target holding an
  unresolved part beside the run state, and a move, copy, unpack or delete of a folder that holds it;
- while a DRIVER holds the repository, a subagent's git verbs off the history list above (tags, plumbing,
  imports, config and remote edits, an alias set in git config), and command positions and global options the
  parser does not know (a git word made by a substitution among them);
- for a subagent, a cycle.sh verb or script handed in by a program other than xargs, a program word behind a
  wrapper option the hook does not know to take a value or behind a command string a wrapper runs, a program
  behind a wrapper held in a variable the command does not set whose words read as no guarded verb, or one
  followed on its line by a git, shell or cycle.sh word, and a command line after a heredoc whose end word the
  hook reads short;
- refused although harmless (known over-denies, 0.55.0): for a subagent, a program word held in a variable the
  command does not set, or sets from a substitution, whatever its words name;
- history rewrites other than a forced tag or push (rebase, amend, reflog expiry, gc pruning, history
  filtering, the other remote forms) by the main session, and by a subagent while no DRIVER holds the repository;
- with no Python: a variable command word, a cd it does not follow (the cwd's DRIVER counts), a forced tag or
  push, PowerShell's evaluate-a-string command, and a cycle.sh verb or script that xargs hands in;
- a mod that answers tool.check (on a personal login it can approve a call this hook denied: the SessionStart
  brief names such a mod).

## Never
- Run `git stash`, `git checkout -- <path>` / `.` / `-f`, `git restore`, `git reset --hard`, `git clean -f`,
  `git switch -f`, `git branch -D` or `git worktree remove --force`, `git rm -f`, `git checkout-index -f` or
  `git read-tree -u --reset` (or any of them through `bash -c`, an alias or a heredoc fed to a shell) over a tree
  with uncommitted work you did not make, or `git branch -f`, `git checkout -B`, `git switch -C` or
  `git update-ref` over commits you did not make: commit it as its own commit, leave it, or ask the owner to run
  the command.

## Allowed
