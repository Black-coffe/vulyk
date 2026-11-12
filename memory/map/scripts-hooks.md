# Scout report: .claude/hooks/ (split from scripts.md)

Other slices: `scripts.md` (cycle scripts), `scripts-checks.md` (checks, tests), `scripts-install.md` (install.sh).

## Purpose
The hook scripts wired into a hive's `settings.json`: the SessionStart brief and update check, the `git-guard.sh`
PreToolUse gate, and the handoff offer; with the helpers those hooks call (`redact.sh`, `telemetry.sh` (`docs/telemetry.md`),
`memory-triage.sh`). `install.sh` wiring: `scripts-install.md`. Defect hooks and `defects_lib.py`: `docs/wiki/rules-tree.md`
and the `defects-*` bullet in `scripts-checks.md`.

## Entry points
- `.claude/hooks/session-start-brief.sh` - map line, profile/bootstrap offers, `maintenance due: ...` for gc,
  evolve, map, its `[VULYK] memory triage (...)` ask-once line (a no runs `--mark`), and (0.48) a line naming an
  enabled plugin whose `hooks/` greps `tool.check` (heuristic; such a mod can approve a call git-guard denied).
- `.claude/hooks/git-guard.sh` (0.48, PreToolUse `Bash|PowerShell`; card `work-discarded-by-git-verb`;
  `docs/hooks-reference.md`)
  - denies git verbs that discard uncommitted work: stash push/save/bare/-u/drop/clear, `checkout .|-f|-- <path>`,
  worktree `restore`, `reset --hard`, `clean -f`, `switch -f`, `branch -D`, `worktree remove -f`. Input with
  `agent_id` (subagent): every listed verb denied, no `git status`, unreadable quotes denied. Main session: denied
  only if `git status --porcelain` shows the affected paths dirty (clean -f/stash -u: untracked too); names 10 then
  `+N more`; stash drop/clear and `branch -D` are subagent-only. Follows `cd`/`-C`. Fails open (no python, bad JSON,
  error: exit 0). Python tried in order `$VULYK_PY`, python3, python, py; stdin read as UTF-8 (0.50). `--check <file>`
  (the card's check; `porcelain` field fakes status): exit 1 on deny. Python sits in a no-op heredoc below `exit 0`.
  Not covered: rm, `bash -c`, scripts/aliases.
- `.claude/hooks/vulyk-update-check.sh` - SessionStart update check; network at most every
  `VULYK_UPDATE_INTERVAL_HOURS` (default 6, 0.51); cache `.claude/.vulyk-update-cache` = `<epoch> <latest> <UTC time>`
  (no time field = expired); the line ends `(checked <date time> UTC)`.
- `.claude/hooks/handoff.py` (0.51, handoff-1m) - offers a handoff at 70/80/90% (`thresholds_pct`) of the real window.
  A session with no statusLine copy of its own takes the window from the newest report for the same model
  (`model_window`, `[1m]` suffix dropped, <= 30 days old); `context_limit` in `.claude/handoff.config.json` pins it.
  `scripts/handoff-window-check.py [<handoff.py>]` is the check of card `handoff-offered-too-early` (3 sessions
  on 1M: silent at 15% and 65%, speaks at 71%; exit 0 / 1 / 2).
- `.claude/hooks/handoff.sh` - skips a `python3` that is the Windows Store stub (exit 49) or fails to launch,
  and starts a working Python once per call (0.43.1); `handoff.py` `_REDACT_FALLBACK` mirrors `redact.sh` (same
  masks, incl. the 0.50.2 cookie-header, `*_KEY`/`*_AUTH` and OTP rules).
- `redact.sh` (stdin mask; masks `passphrase`/`cookie` keywords, an ssh public key body, a URL password with an
  empty user `scheme://:pw@host`; a `Cookie:`/`Set-Cookie:` header whose value holds a name=value pair loses the
  rest of the line (0.50.2); a `*_KEY` name (dotted names, glued upper-case `KEY`, and `*_AUTH` names included)
  with a 16+ char value, `base64:` prefix optional (`KEY_VALUE`); an OTP key at the key's end: `OTP`, `TOTP`,
  optional `_code` suffix).
  `telemetry.sh` - `enum`, `agents`, `consent`, `record`, `scan`, `bundle`, `check`,
  `publish`, `inbox`; `vulyk_version`: `.claude/vulyk-version`, else `VERSION` beside `install.sh`, else `0.0.0`.
  `ENUM`/`AGENTS` are append-only (removed agents go to `RETIRED_AGENTS`; `ENUM` ends `model_below_floor`,
  `fable_limit_fallback`). The scan counts handoff Python starts (0.43.1). Dates go through `date_epoch` /
  `date_shift` (prev ISO week = `date_shift -7 +%G-W%V`).
- `memory-triage.sh` - read-only lister behind `/vulyk-gc memory`; `--mark` is its one write.

## Gotchas
- git-guard fails open: no python, bad JSON or an error exits 0, so a missing Python removes the guard.
- The guard does not cover `rm`, `bash -c`, scripts or aliases.

last-verified: 2026-11-12 (post-052-tails split; hook, redact, telemetry bullets moved verbatim; 0.51.0-dev.1 handoff-1m)
