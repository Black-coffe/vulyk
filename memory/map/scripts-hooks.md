# Scout report: .claude/hooks/ (split from scripts.md)

Other slices: `scripts.md` (cycle scripts), `scripts-checks.md` (checks, tests), `scripts-install.md` (install.sh),
`scripts-guards.md` (`git-guard.sh`, `owner-guard.sh`, `court-guard.sh`).

## Purpose
The hook scripts wired into a hive's `settings.json`: the SessionStart brief and update check, the three PreToolUse guards
(`scripts-guards.md`), and the handoff offer; with the helpers those hooks call (`redact.sh`, `telemetry.sh`
(`docs/telemetry.md`), `memory-triage.sh`). `install.sh` wiring: `scripts-install.md`. Defect hooks and `defects_lib.py`:
`docs/wiki/rules-tree.md` and the `defects-*` bullet in `scripts-checks.md`. `defects-inject.sh` matcher (0.53) includes
`PowerShell`; a PowerShell line is read as a Bash one. SessionStart, PreCompact and `defects-inject.sh reset` exit
silently for a subagent (input carries a non-empty `agent_id`; `handoff.py` `mode` check too).

## Entry points
- `.claude/hooks/session-start-brief.sh` - map line, profile/bootstrap offers, `maintenance due: ...` for gc,
  evolve, map, its `[VULYK] memory triage (...)` ask-once line (a no runs `--mark`), (0.48) a line naming an
  enabled plugin whose `hooks/` greps `tool.check` (heuristic; such a mod can approve a call git-guard denied), (0.53) a
  `[VULYK] no Python 3 found ...` line when none of `$VULYK_PY`, python3, python, py runs, and a line for a GitHub template
  copy of VULYK (VULYK's own `docs/specs` and `install.sh`, no `.claude/vulyk-version`, no `v*` tag).
- `.claude/hooks/vulyk-update-check.sh` - SessionStart update check; network at most every
  `VULYK_UPDATE_INTERVAL_HOURS` (default 6, 0.51); cache `.claude/.vulyk-update-cache` = `<epoch> <latest> <UTC time>`
  (no time field = expired); the line ends `(checked <date time> UTC)`. Sources `scripts/version-order.sh`
  (missing: exit 0); latest = `version_newest` over the tags, shown only if `version_newer "$LATEST" "$INSTALLED"`.
- `scripts/version-order.sh` (0.53, sourced; also by `vulyk-update.sh`) - `version_newer <a> <b>` (rc 0 = a newer),
  `version_newest` (newest of stdin lines). Leading `v` dropped; X.Y.Z numeric; a release beats its `-<pre>`; two
  pre-releases compare by the number after the last dot (`dev.10` > `dev.3`); a non-number field = 0. No `sort -V`.
- `.claude/hooks/skill-usage-counter.sh` - PostToolUse `Skill`; counts only project skill folders and `vulyk-*` commands
  into `memory/stats/skills.json` (local, gitignored, never shipped; a key failing the rule is dropped on the next write).
- `.claude/hooks/handoff.py` (0.51, handoff-1m) - offers a handoff at 70/80/90% (`thresholds_pct`) of the real window.
  A session with no statusLine copy of its own takes the window from the newest report for the same model
  (`model_window`, `[1m]` suffix dropped, <= 30 days old); `context_limit` in `.claude/handoff.config.json` pins it.
  `scripts/handoff-window-check.py [<handoff.py>]` is the check of card `handoff-offered-too-early` (3 sessions
  on 1M: silent at 15% and 65%, speaks at 71%; exit 0 / 1 / 2). Given `telemetry.sh` (the path the card also
  fires on, 0.52) it judges the tree's `.claude/hooks/handoff.py` instead.
- `.claude/hooks/handoff.sh` - skips a `python3` that is the Windows Store stub (exit 49) or fails to launch,
  and starts a working Python once per call (0.43.1); `handoff.py` `_REDACT_FALLBACK` mirrors `redact.sh` (same
  masks, incl. the 0.50.2 cookie-header, `*_KEY`/`*_AUTH` and OTP rules; 0.53: Russian/Ukrainian secret keywords too).
- `redact.sh` (stdin mask; masks `passphrase`/`cookie` keywords, an ssh public key body, a URL password with an
  empty user `scheme://:pw@host`; a `Cookie:`/`Set-Cookie:` header whose value holds a name=value pair loses the
  rest of the line (0.50.2); a `*_KEY`/`*_AUTH` name with a 16+ char value, `base64:` prefix optional; an OTP key
  (`OTP`, `TOTP`, optional `_code`); 0.53: Russian and Ukrainian secret keywords, secrets stated in prose,
  credentials passed as command arguments, more service-token/webhook shapes, bare cloud secret keys; ordinary text
  passes byte-identical). When it cannot mask (sed/awk missing, dialect rejected, a filter fails) it withholds: stdout is
  `[VULYK:REDACT-FAILED]`, stderr `redact: degraded: <why>`, `telemetry.sh record redact_degraded` runs, exit 1.
  `human-check.sh` and `acceptance-log.sh` then refuse (`REFUSED`) and record nothing. `human-check.sh ... --commit`
  (0.53) commits only its own plan.md line and record row; it refuses (exit 1, nothing written) when either path
  already holds an uncommitted change, and exits 1 if the commit fails after the write.
  `telemetry.sh` - `enum`, `agents`, `consent`, `record`, `scan`, `bundle`, `check`,
  `publish`, `inbox`; `vulyk_version`: `.claude/vulyk-version`, else `VERSION` beside `install.sh`, else `0.0.0`.
  `ENUM`/`AGENTS` are append-only (removed agents go to `RETIRED_AGENTS`; `ENUM` ends `model_below_floor`,
  `fable_limit_fallback`, `redact_degraded`). `agent_prefix_high` (0.52) fires only when the agent type is in `AGENTS`.
  The scan counts handoff Python starts (0.43.1). Dates go through `date_epoch` /
  `date_shift` (prev ISO week = `date_shift -7 +%G-W%V`).
- `memory-triage.sh` - read-only lister behind `/vulyk-gc memory`; `--mark` is its one write.

## Gotchas
- A hook's missing Python is not uniform: git-guard/owner-guard/court-guard fail closed (`scripts-guards.md`); the update check,
  session brief and handoff fail open (no Python = the feature is off, the brief says so).

last-verified: 2026-11-15 (0.53.0 owner-guard-commit-fp; guards split out to scripts-guards.md)
