# Scout report: PreToolUse guards (split from scripts-hooks.md)

Other slices: `scripts-hooks.md` (SessionStart/handoff hooks, redact, telemetry), `scripts.md`, `scripts-install.md`.

## Purpose
Three PreToolUse hooks in `.claude/settings.json`, each `"onFailure": "block"` (a crash or a missing script blocks the
tools it matches): `git-guard.sh` (`Bash|PowerShell`), `owner-guard.sh` (`Bash|PowerShell|Edit|Write|MultiEdit`),
`court-guard.sh` (`Read|Grep|Glob|Bash|PowerShell`). Same shape in each: bash front half reads stdin with builtins and exits
0 early for an unrelated call; the Python half sits in a no-op heredoc below `exit` (run with `-S`, order `$VULYK_PY`,
python3, python, py; only exit 0 counts as "ran"); `--check <file>` takes hook input from a file, exit 1 = deny (reason on
stdout), exit 0 otherwise. With no Python each denies what it cannot check (below). `docs/hooks-reference.md`.

## git-guard.sh (card `work-discarded-by-git-verb`)
- Denies git verbs that discard uncommitted work or move a ref by force: stash push/save/bare/-u/drop/clear, `checkout
  .|-f|-- <path>`, worktree `restore`, `reset --hard|--merge`, `merge --abort`, `clean -f`, `switch -f`, `branch -D|-f|-M|-C`,
  `checkout -B`, `update-ref`, `rm -f`, `worktree remove -f`. The verbs are also read inside `bash|sh -c`, `pwsh -Command`,
  a heredoc fed to a shell, and a `git -c alias.<n>=<v>` on the same line. Verb lists: `GUARD_VERBS` (bash) and `VERBS`
  (Python), one test compares them.
- Subagent (`agent_id` in the input): every listed verb denied, no `git status`, unreadable quotes denied; `git commit` and
  `git add` denied while any `docs/specs/*/DRIVER` exists; it may run only `cycle.sh` `advance|status|release|suite|
  stamp-red|close-story` (stamp-red never with `--baseline`). Main session: denied only when `git status --porcelain` shows
  the affected paths dirty (clean -f/stash -u: untracked too; a status that times out denies); names 10 then `+N more`; verbs
  losing stashes or commits are subagent-only. Follows `cd`/`-C`.
- Law 5: main session is denied `cycle.sh close-story <story>` when the plan says Tier 3 or 4 (a story token with `$`, a
  backtick, `%`, or an unreadable plan = denied). Subagents and `stamp-red` pass.
- Failure (0.53, fail closed): a Python that crashes on a command naming git = deny; no Python at all = a bash fallback
  denies every listed verb after a `git` word, for any caller. Bad JSON, or a command naming neither git nor `cycle.sh`, passes.

## owner-guard.sh (card `owner-words-by-builder`)
- Guards: `human-check.sh <spec> ACCEPTED|REJECTED`, `cycle.sh briefed ... --go`, a new or changed `**Approved:**` /
  `**Checked:**` line of a `docs/specs/<slug>/plan.md` (Edit/MultiEdit judged on the file after the edit), an ACCEPTED/REJECTED
  row in
  `memory/stats/human.jsonl`, and a shell command that may rewrite a plan.md holding such a line (denied to all, "use Edit").
- Subagent: every guarded call denied. Main session: passes only on the quote rule against the session transcript
  (`transcript_path`; `--check` takes a `transcript` list): `**Approved:**` quotes the owner's latest message written after the
  `vulyk(<slug>): plan` commit; ACCEPTED/REJECTED/`**Checked:**` quote the answer to a one-question AskUserQuestion naming the
  slug (or his next prompt), after the spec's latest verdict, 8+ letters/digits unless a picked option; `--go` needs an owner
  prompt of this session carrying it. No Python or an unreadable transcript: the guarded call is denied with the cause.

## court-guard.sh (blind council seats)
Acts only when `agent_type` is `council-opus` or `council-haiku`. Read/Grep/Glob: a path outside `<project>/.vulyk/court/`
is denied. Bash/PowerShell: path arguments leaving the court (each `cd` followed) are denied; `.vulyk/reports/` and system
locations are allowed; an unreadable
command (open quotes, path built from a variable) is denied; heredoc bodies are text. A git command that reads objects is denied
unless it names pathspecs and none lies in `docs/specs/`. No Python: every call of a blind seat is denied. `record-seat` still
checks the report.

last-verified: 2026-11-14 (0.53.0-dev.1 audit-fixes-1113; headers of the three hooks, settings.json wiring)
