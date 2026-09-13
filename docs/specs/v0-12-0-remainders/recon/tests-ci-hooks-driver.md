# Scout report: tests/ harness, CI, hooks, Workflow-driver syntax check

Scouted 2026-09-13 at `3e200bb` by `drone-scout`; saved verbatim for `queen-planner`, with two
Queen corrections at the end.

## Purpose
The synthetic-fixture test suite for VULYK's own gate scripts (`scripts/cycle.sh`, `scripts/ship-check.sh`, `scripts/human-check.sh`, `scripts/journal.sh`), the CI wiring that runs them, the SessionStart hook that reports the top-model + Workflow-driver CLI gate, and the JS Workflow-driver (`vulyk-cycle.js`) that a `claude` CLI >=2.1.154 with the Workflow tool enabled would run instead of the in-session fallback loop.

**Tooling caveat:** ripgrep (the Grep tool) silently skips dot-directories (`.claude/…`) unless pointed at an exact file path — broad searches under `.claude` returned false negatives all session. Glob also returned nothing for `tests/*` and `.claude/hooks/*` even though those dirs are populated (confirmed via direct `Read`); treat Glob as unreliable here and use `Read`/`Grep` with exact file paths instead.

## 1. `tests/` — every file

| File | Lines | What it does |
|---|---|---|
| `tests/cycle.test.sh` | 163 | One throwaway git repo, one spec (`demo`), walked stage 01→06 in sequence (not independent scenarios). 8 `echo "…"` section headers. |
| `tests/council.test.sh` | 1661 | One throwaway repo, ~40+ independent scenarios (97 `echo "…"` lines counting both section headers and inline sub-asserts), each with its own `docs/specs/<slug>` (mk_spec). Covers `status --json`, C15 tier scaling, `judge` (green/red/ceiling/half/absent/N-A/reject-override/precondition-fail/pause), `journal.sh`, `briefed`, `branch`, git-failure handling, `record-seat` (D3 malformed/GREEN-RED-evidence/review-verdict-line-1/model-resolution), PAUSE guard, pause/resume, `close-story`, `open-round`, `escalate`, `reopen`, and a final block replaying real `--commit` verb sequences against `status --json` (R1/R2/R3/R7/R25). |
| `tests/handoff-window.test.py` | — | Synthetic matrix for `.claude/hooks/handoff.py`'s context-window resolution; invoked as `python3 tests/handoff-window.test.py .claude/hooks/handoff.py` from CI. |

**Both `.sh` suites share one shape:** `set -u`; `T="$(mktemp -d)"` + `trap rm -rf`; `expect() { local label needle out=$(cat); grep -qF needle in $out }` reading stdout via a pipe; `fail=0` accumulator; `exit $fail`. They `cp` `$SRC`'s real scripts into the fixture repo (never symlink), then `git init` a throwaway repo and drive it with real `git commit`.

**council.test.sh fixture-builder naming convention:** slugs double as scenario names and are the literal `"spec"` key written into `memory/stats/council.jsonl`/`plan.md`, so grep-by-slug is how each scenario re-reads its own row. Examples found: `ceil1`/`oceil1` (ceiling-escalation fixtures — `ceil1` via judge's 3-RED-rounds path L353, `oceil1` via a *fabricated* already-judged RED row + a **separate** `council/CEILING` file set to 1, testing `open-round`'s own ceiling check L1315), `lockfail1` (git `index.lock` present during `--commit`, L611), `cstoryq` (a `close-story` scenario — quoted-command gate per `## Commands`, ~L1137), `cstory1`/`cstory3` (basic and Commands-gate close-story fixtures, L1035/L1076), `half1`/`halffloor1`/`halffloor2`/`halffloor2b` (half-the-asks-RED escalation and its floor `max(2, ceil(A/2))`), `env1`/`envpartial2`/`envpartial3` (ABSENT-seat escalation and its boundary against a real RED elsewhere), `wtfail1` (git-worktree-add failure), `rseat1`/`rseat2`/`pwseat1` (record-seat preconditions and paperwork-vs-real-commit staleness).

**Helper functions** (council.test.sh): `mk_spec <slug> <n-asks>` (brief.md with N-item `## Asks`, plan.md from `templates/plan.md`, one `status: done` story, commits) L53; `set_tier <slug> <n>` (regex-replaces plan.md's `**Tier:** <...>` placeholder) L65; `mk_open_spec` (mk_spec + Approved/Branch filled) L75; `mk_round`/`mk_open_round <slug> <n> [ceiling]` (writes `council/round-N/ROUND` with head/pack/opened/court/ceiling; `_open` variant uses live HEAD, plain uses a fixed `$HEAD7` — comment at L99 explains why judge doesn't care but record-seat does) L85/99; `seat_report <seat> <round> <pattern>` (pattern chars `G/R/N/?` build a C5-shaped report body, indexed by position not `fold -w1` because GNU fold drops a trailing no-newline char — noted bug workaround at L130) L117; `write_seat`/`write_review`/`write_absent` (write the `<seat>.md` file with C4 header) L146/155/164.

**Test hive seeded by council.test.sh:** `scripts/{lib.sh,cycle.sh,journal.sh,scope-check.sh}` copied in; a `.gitignore` mirroring the real one (`.vulyk/`, `docs/specs/*/PAUSE`); a minimal `CLAUDE.md` with a `## Commands` table listing exactly the 5 fixture verification commands used later (`test -f …flag.txt`, `false`, `true`, `sh -c "exit 1"`, `sh -c 'echo a\b; exit 1'`) — **note:** `close-story` now refuses any verification command not a literal cell of this table (R11/C-4), so adding a new close-story scenario means adding its command to this table first.

**To add one scenario:** pick a fresh slug, call `mk_spec`/`mk_open_spec`, optionally `set_tier`, build a round with `mk_round`/`mk_open_round` + `write_seat`/`write_review`/`write_absent`, invoke `council <verb> docs/specs/<slug> [--commit]`, assert via `| expect "label" "needle"` or manual `[ ... ] && echo ok || { fail=1; }`, then `grep '"spec":"<slug>"' memory/stats/council.jsonl` to check the emitted row.

**No test in `tests/` (or anywhere in `scripts/`/`docs/adr`) runs `node` or exercises `.claude/workflows/vulyk-cycle.js`.** There is no fold-harness *file* for `foldReviews` on disk — see Queen correction 2 below.

## 2. `.github/workflows/ci.yml` — every job

| Job | Runs | Notes |
|---|---|---|
| `shell` | shellcheck (`--severity=error` only) then `bash -n` over every `*.sh` + `scripts/git-hooks/*` | no node anywhere |
| `top-model` | inline synthetic-profile matrix calling `scripts/top-model.sh` directly (bash, no node) | tests `--check`/`--apply`, constitution pin override, and asserts the hook's one-line output via `.claude/hooks/top-model-brief.sh` (L83-86) |
| `cycle` | `bash tests/cycle.test.sh` | |
| `council` | `bash tests/council.test.sh` | |
| `handoff-window` | `python3 tests/handoff-window.test.py .claude/hooks/handoff.py` | the only non-bash test |
| `install-smoke` | plants sentinel runtime files, then `./install.sh --check`, real install, `--upgrade`, idempotent re-install, foreign-CLAUDE.md preservation — all bash, checked with `jq`/`grep`/`test` | asserts: `--check` is a true dry run (target dir stays empty) and lists load-bearing paths it would copy; real install produces executable hooks, wires both `Bash(bash scripts/cycle.sh:*)` and `Bash(bash scripts/journal.sh:*)` allow-rules **exactly once**; Profile-block row count matches source CLAUDE.md; never ships `.claude/settings.local.json`'s real content, `.claude/handoff/*`, `.claude/state.json`, or `memory/snapshots/*` (checks by planted-sentinel content, not by path absence, since `top-model.sh --apply` legitimately writes its own `settings.local.json` later in the same run); `--upgrade` repeats every one of those checks and additionally must never touch an already-filled Profile block |

**No job installs or invokes `node`/npm anywhere in the file.**

## 3. `.claude/hooks/top-model-brief.sh` — full flow (61 lines)
1. `VULYK_TOP_MODEL_BRIEF=0` disables it; else resolves `ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"`, requires `$ROOT/scripts/top-model.sh` to exist (else silent exit 0).
2. Runs the resolver 3 separate times: plain (`MODEL`), `--explain` (parsed with `sed` for `plan`/`second reviewer`/`decided by`), `--check` (session-pin status).
3. **Lines 41-58 (Workflow-driver gate):** `command -v claude` then `claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1` — spawns the actual CLI binary once, no caching, no timeout guard in the hook itself. Compares against the literal floor `2.1.154` via `sort -V`. If CLI missing/unparsable → `"Workflow driver: CLI version unknown."` If below floor → `"...unavailable (CLI $CLIVER < 2.1.154, fallback loop in session)."` Else → `"...CLI $CLIVER >= 2.1.154 - enable in /config on Pro."`
4. **No alternative CLI-version source exists** in this file — no env var, no settings key, no cached file is read; every invocation re-spawns `claude --version`.
5. Emits one `[VULYK] top model: …` line and always `exit 0` (fails open throughout — missing resolver, missing CLI, bad profile, all silent).

**Every other file in `.claude/hooks/` (from `.claude/settings.json`'s wiring):**
- `session-start-brief.sh` — SessionStart, first in the array
- `top-model-brief.sh` — SessionStart, covered above
- `vulyk-update-check.sh` — SessionStart
- `handoff.sh sessionstart|sessionend|prompt|stop|precompact` — one script dispatched with a subcommand across 5 events; shells out to `.claude/hooks/handoff.py`
- `session-end-learnings.sh` — SessionEnd
- `skill-usage-counter.sh` — PostToolUse, matcher `"Skill"`
- `context-guard.sh` — PreCompact
- `handoff.py` — python sibling of `handoff.sh`, holds the window-resolution logic and a redaction fallback subset per `scripts/redact.sh`'s own comment at line 13

Bodies of `session-start-brief.sh`, `vulyk-update-check.sh`, `handoff.sh`, `handoff.py`, `session-end-learnings.sh`, `skill-usage-counter.sh`, `context-guard.sh` were not read this pass.

## 4. `.claude/workflows/vulyk-cycle.js` — structure (189 lines)
- `meta` (L1-10): `name: 'vulyk-cycle'`, phases `Build → Round → Judge → Repair`.
- Arg guards (L25-31): reads `args.spec`, `args.top_model`, `args.second_model`, `args.stamp`; if `stamp` isn't a string ≥12 chars, returns `{ stop: { verb: 'launch', error: '...' } }` without throwing.
- `SEAT_AGENT` map (L23): `haiku→council-haiku, sonnet→council-sonnet, opus→council-opus, review→lead-review`.
- `foldReviews(r1, r2)` (L68-81): folds two Tier-4 reviewer reports into one. Empty/null/prose on either side → `NO VERDICT: top=… · second=…` passthrough (never manufactures a verdict); both a parsed `VERDICT: PASS|BLOCK` first line → `VERDICT: <BLOCK if either BLOCK else PASS>` + both bodies concatenated.
- `dispatchSeat(seat, st, note)` (L85-94): Tier 4 review seat fans out to **two** parallel `agent()` calls (`TOP` model and `SECOND` model) then folds; every other seat/tier is a single `agent()` call.
- Build loop (`st.next.startsWith('build:')`, L108-132): dispatches all `st.wave_stories` in `parallel()`, one `agent()` per story routed by `story.worker` (not hardcoded); for each story, empty/null report OR `close-story` exit≠0/≠4 → `fail()`; exit 4 (red verification) *or* an empty report increments a per-file `attempts` counter, `fail()`s on the 2nd miss, else leaves the story open for the next poll.
- `recordSeat` (L142-146, inside the `dispatch:` branch at L138-159): builds a per-seat/per-attempt delimiter `VULYK_${stamp}_${seat}_${attempt}`, calls `clerk('record-seat ...')` with the report as a heredoc body (`null`→empty string, never the literal `"null"`); on exit 4 (MALFORMED) re-asks the seat once with the rejection reason appended, records attempt 2 unconditionally.
- Repair block (L164-179): refuses a second repair dispatch for the same round number in one run (`repaired` Set) via `fail(st, { verb:'repair', round, error:'repair landed nothing for round N' })`; otherwise builds a `reason`/`ask` string from `st.red` and dispatches one `queen-planner` agent call with `model: TOP`.
- **Every `fail(st, {...})` stop shape found** (all via `const fail = (st, stop) => { throw new Stop({ ...st, stop }) }`):
  - `asStop(res) = { verb, exit, error }` — used at L107, L126, L137, L155→L159, L163 (every verb-passthrough failure from `clerk()`)
  - `{ verb: 'build', file, error: 'worker returned no report' }` — L130
  - `{ verb: 'repair', round, error: 'repair landed nothing for round N' }` — L168
- Top-level catch (L184-188): `BadLine` (non-JSON last line from a verb) → returns the raw line; `Stop` → returns `e.result`; anything else rethrows.

## 5. `scripts/lib.sh` — helper list (76 lines total)
- `pack_fingerprint(dir)` L16 — sha256 (or shasum, or a `wc -w` fallback if neither exists) of the sorted list of `story:`-tagged `.md` filenames in a spec dir.
- `is_paperwork_path(path)` L42 — the single whitelist of cycle-written paths, anchored to `docs/specs/*/`.
- `paperwork_only(root, from, to)` L52 — true iff every changed path in a commit range is a paperwork path per the above.
- `marker(planmd, Name)` L66 — extracts a `**Name:** value` line, treating a `<...>` placeholder as absent.
- `now_ts()` L73, `slug_of(dir)` L75.

**No `redact`/mask helper lives in `lib.sh`** — that's a separate file, `scripts/redact.sh` (58 lines): a deterministic, always-exit-0, sed/awk-based credential masker that degrades to `cat` if `sed`/`awk` are missing or the sed dialect rejects the script. Its own comment says `handoff.py` mirrors a subset of these patterns as a built-in fallback.

**No atomic-write helper in `lib.sh`.** `git_commit_or_fail(verb, msg)` and `commit_paperwork(verb, msg, path...)` live in `scripts/cycle.sh` instead (lines 494 and 505) — `git_commit_or_fail` commits already-staged changes and calls `emit false … 2 error "git commit failed"` + `exit 2` on failure; `commit_paperwork` is a no-op if the given paths are clean, else stages and calls `git_commit_or_fail`.

## Queen corrections (2026-09-13, checked on disk after the report)
1. The scout's Glob failed on `docs/specs/`: the tree holds `autonomous-cycle/`, `autopilot-merge/` and `v0-12-0-remainders/`, not the last alone.
2. The "fold harness" is not a file: it is a one-line `node -e` command embedded in
   `docs/specs/autonomous-cycle/autonomous-cycle-26-*.md:54` (extracts `foldReviews` with a regex,
   runs seven assertions, prints `fold ok`). Nothing in `tests/` or CI runs it; the only committed
   node gate is the `node --check` line at `:61` of the same story, which round-3 major 1 showed
   checks nothing for an ES-module file on Node 22.
