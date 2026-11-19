# Scout report: PreToolUse guards (split from scripts-hooks.md)

Other slices: `scripts-hooks.md` (SessionStart/handoff hooks, redact, telemetry), `scripts.md`, `scripts-install.md`.

## Purpose
Three PreToolUse hooks in `.claude/settings.json`, each `"onFailure": "block"` (a crash or a missing script blocks the
tools it matches): `git-guard.sh` (`Bash|PowerShell`), `owner-guard.sh` (`Bash|PowerShell|Edit|Write|MultiEdit`),
`court-guard.sh` (`Read|Grep|Glob|Bash|PowerShell`). Same shape in each: bash front half reads stdin with builtins and exits
0 early for an unrelated call; the Python half sits in a no-op heredoc below `exit` (run with `-S`, order `$VULYK_PY`,
python3, python, py; only exit 0 counts as "ran"); `--check <file>` takes hook input from a file, exit 1 = deny (reason on
stdout), exit 0 otherwise. With no Python each denies what it cannot check (below). `docs/hooks-reference.md`.
Each header ends in a "Left open" list (cooperative-agent guard, not an adversary); read it there, do not copy it out.
Known over-denies are listed in the headers (0.55.0); the three guards share one rule: no env off-switch for agents.

## git-guard.sh (cards `work-discarded-by-git-verb`; contracts of guards-1115)
- Denies git verbs that discard uncommitted work or move a ref by force: stash push/save/bare/-u/drop/clear, `checkout
  .|-f|-- <path>`, worktree `restore`, `reset --hard|--merge`, `merge --abort`, `clean -f`, `switch -f`, `branch -D|-f|-M|-C`,
  `checkout -B`, `update-ref`, `rm -f`, `worktree remove -f`, `checkout-index -f`, `read-tree -u`. Verb lists: `GUARD_VERBS`
  (bash) and `VERBS` (Python), one test compares them. Verbs are also read inside `bash|sh -c`, `pwsh -Command`, `eval`, a
  heredoc fed to a shell, and a `git -c alias.<n>=<v>` on the same line; wrappers (env, timeout, nohup, nice, sudo, xargs,
  time, exec, command) are looked through to the command word.
- Subagent (`agent_id`; read on every shell call, no text prefilter): every listed verb denied, no `git status`, unreadable
  git arguments denied. Since guards-1115 also denied: a shell call on `.vulyk/state/` (resolved path; the reason names
  Read), a program or script name it cannot read ("spell the script path"), `Invoke-Expression`, and every `cycle.sh` verb
  but `advance|status|release|suite|stamp-red|close-story` (`CYCLE_OK`; stamp-red never `--baseline`; non-literal verb or
  xargs-handed verb denied; `CYCLE_OTHER` lists the denied verbs).
- While a `docs/specs/*/DRIVER` exists in the repo the git command acts on (cd, `-C`, `--git-dir`, `GIT_DIR` followed; an
  unreadable place counts as held), a subagent is denied the history verbs (`HIST_VERBS`: add, commit, merge, rebase, push,
  reset, checkout, switch, rm, update-index except `--chmod`, ...). `close-story` commits the story's paths.
- Every caller: `git tag -f` and forced push denied. Main session otherwise: denied only when `git status --porcelain`
  shows the affected paths dirty (clean -f/stash -u: untracked too; a status that times out denies); names 10 then `+N
  more`; verbs losing stashes or commits are subagent-only. PowerShell `iex` is read as commands for the main session.
- Law 5: main session is denied `cycle.sh close-story <story>` when the plan says Tier 3 or 4 (a story token with `$`, a
  backtick, `%`, or an unreadable plan = denied). Subagents and `stamp-red` pass.
- Failure (fail closed): a Python that crashes on a command naming git = deny; no Python = a bash fallback denies every
  listed verb after a `git` word for any caller, and for a subagent also text rules on run state, cycle.sh verbs, `$` in a
  script word, and (cwd's DRIVER) history verbs. Bad JSON, or a command naming neither git nor `cycle.sh`, passes.

## owner-guard.sh (card `owner-words-by-builder`; contracts of audit-fixes-1113, guards-1115)
- Guards: `human-check.sh <spec> ACCEPTED|REJECTED`, `cycle.sh briefed ... --go`, a new or changed `**Approved:**` /
  `**Checked:**` line of a `docs/specs/<slug>/plan.md` (Edit/MultiEdit judged on the file after the edit, path resolved), an
  ACCEPTED/REJECTED row in `memory/stats/human.jsonl` (any shell command naming that record beside a verdict word counts,
  a git commit of it included; the one way is `human-check.sh <spec> <verdict> "<note>" --commit`), and a shell command that
  may rewrite a plan.md holding such a line (denied to all, "use Edit").
- Subagent: every guarded call denied; plus (guards-1115) a Write/Edit/MultiEdit under `.vulyk/state/` ("a subagent cannot
  write a run-state record"), a shell command that may write a file named `plan.md` or `human.jsonl`, a `git add|commit`
  whose pathspec covers the record, a commit message that may carry a verdict word, and unclosed quotes. Program words are
  looked through wrappers and variables; text handed to a shell is read. Shell reads of run state are git-guard's.
- Main session: a spelled-otherwise guarded call is denied while a prefilter word stays whole; a plain call passes only on the
  quote rule against the session transcript (`transcript_path`; `--check` takes a `transcript` list): `**Approved:**` quotes the
  owner's latest message after the `vulyk(<slug>): plan` commit; ACCEPTED/REJECTED/`**Checked:**` quote the answer to a
  one-question AskUserQuestion naming the slug (or his next prompt), after the spec's latest verdict, 8+ letters/digits unless a
  picked option; `--go` needs an owner prompt of this session carrying it. No Python or an unreadable transcript: denied
  with the cause (no Python: every plan.md Edit counts as guarded).

## court-guard.sh (blind council seats; contracts C1 audit-fixes-1113, C2 guards-1115)
Acts only when `agent_type` is `council-opus` or `council-haiku`. The court is the round folder
`<project>/.vulyk/court/<slug>/<round>/` the call stands in (input cwd, then each followed `cd`); another round's court is
denied; a call in no court may name a court path only while exactly one court exists. Paths are judged resolved (links, `..`,
case, Git Bash spellings). Read/Grep/Glob outside the court and `.vulyk/reports/` is denied; Bash/PowerShell: path arguments
leaving the court denied, `.vulyk/reports/` and system locations allowed (never one resolving into the project or the main
session's temp working folder). Commands found in every command position, wrappers and `$( )`/eval/`sh -c` strings
read; an unreadable command, variable-built program name or a cd with several folders/CDPATH is denied. Git by allowlist
only: `status`, `version`, `rev-parse`, `ls-files` (globals `-C`, `--no-pager`, `-P`); `<rev>:<path>` naming `docs/specs/`
denied in every verb. Heredoc bodies are text. No Python: every blind-seat call denied. `record-seat` still checks the report.
Seat agents begin each Bash call with `cd <COURT> &&` (agent files).

last-verified: 2026-11-17 (guards-1115; headers of the three hooks, git-guard.sh GUARD_VERBS/HIST_VERBS/CYCLE_OK)
