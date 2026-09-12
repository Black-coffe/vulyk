# Scout report: install.sh, scripts/vulyk-update.sh, .claude/hooks/{session-start-brief,top-model-brief,vulyk-update-check}.sh, .claude/settings.json, .gitignore, VERSION

## Purpose
`install.sh` file-by-file copies the VULYK hive into a target project (install: skip existing; `--upgrade`: also replace changed framework-owned files). `scripts/vulyk-update.sh` fetches origin, checks out a tag, and delegates to that tag's own `install.sh --upgrade`. Three SessionStart hooks inject one-line briefs (memory/map state, top-model resolution, update-available notice).

## Entry points
- `install.sh:50` `copy_tree(rel)` — per-tree file copy loop (install/upgrade semantics)
- `install.sh:82` `reset_marked_block()` / `install.sh:106` `reset_commands_table()` — blanks CLAUDE.md marker blocks
- `install.sh:144` `wire_session_hook(script)` — appends a SessionStart hook entry into destination `.claude/settings.json` via inline Python if missing
- `install.sh:229` `ensure_gitignore()` — appends missing VULYK runtime lines to destination `.gitignore`
- `install.sh:256` main copy loop + `:268` skills.json skeleton + `:273-323` CLAUDE.md handling + `:327` version stamp
- `scripts/vulyk-update.sh:76` hands off to `"$SRC/install.sh" "$DEST" --upgrade $CHECK`
- `.claude/hooks/session-start-brief.sh`, `top-model-brief.sh`, `vulyk-update-check.sh` — each `echo`s exactly one `[VULYK] ...` line, fail-open (`set -uo pipefail`, guarded checks, always `exit 0`)

## Key types / contracts
- `OWNED=".claude/agents .claude/commands .claude/hooks .claude/skills/_meta bootstrap templates scripts"` (`install.sh:34`) — only these trees get replaced-if-changed on `--upgrade`; everything else is install-only (copy-if-missing) forever.
- `shippable()` (`install.sh:40-48`) excludes `*/__pycache__/*`, `*.pyc`, `docs/specs/*`, and `memory/learnings/*` (except its README) from ever being copied — these are VULYK's own working content, dir still created but files withheld.
- Top-level copy loop (`install.sh:256`): `for tree in .claude memory bootstrap templates scripts docs/wiki docs/specs docs/adr; do copy_tree "$tree"; done` — `copy_tree` recurses (`find "$rel" -type f`), so it walks the ENTIRE `.claude/` subtree, not a hardcoded file list.

## Dependencies
- `wire_session_hook` needs `python3`/`python` on PATH to edit JSON safely; without it, prints manual-wiring instructions and does nothing.
- `vulyk-update-check.sh` needs `curl`; caches GitHub tag lookups in `.claude/.vulyk-update-cache`, `VULYK_UPDATE_INTERVAL_HOURS` (default 24h) throttles network calls.
- `top-model-brief.sh` shells out to `scripts/top-model.sh` for resolution, `--explain`, and `--check` (pin status).

## Gotchas
- `install.sh` never touches `.claude/settings.json` wholesale (owner's file) — only surgically appends missing SessionStart hook entries (currently wired for `vulyk-update-check.sh` and `top-model-brief.sh` only; `handoff.sh`, `session-start-brief.sh` etc. are NOT auto-wired by `install.sh`).
- `ensure_gitignore`'s "wanted" list (`install.sh:231`) uses `memory/snapshots/` (blanket dir ignore), but VULYK's OWN `.gitignore:7-8` uses `memory/snapshots/*` + `!memory/snapshots/.gitkeep` — inconsistent between shipped vs. own.
- `docs/specs/*` is excluded from shipping but the directory is still created (comment at `install.sh:44`).
- No `permissions` block anywhere in `.claude/settings.json`.

## Answer
1. **New `.claude/workflows/` dir**: shipped automatically — `copy_tree ".claude"` (`install.sh:256`) recurses `find .claude -type f`. BUT it is only force-updated on `--upgrade` if `.claude/workflows` is added to `OWNED` at `install.sh:34`. **`templates/grill.md`**: auto-shipped and `templates` is already in `OWNED`. **`memory/stats/council.jsonl`**: no `.gitignore` entry needed (stats are tracked); no skeleton needed by precedent (only `skills.json` gets `{}` at `install.sh:268`; the four jsonl series have no skeleton) unless its reader can't tolerate a missing file.
2. `scripts/vulyk-update.sh:41` compares `.claude/vulyk-version` (stamped by `install.sh:331`) against the newest `v*` git tag (`sort -V`) from origin (default `Black-coffe/vulyk`, override via `VULYK_REPO` env or `.claude/vulyk-origin`). Clones/fetches into `~/.vulyk/src` (or `$VULYK_SRC`), checks out the tag, execs that tag's `install.sh "$DEST" --upgrade $CHECK` (line 76); after a real run deletes `.claude/.vulyk-update-cache` (line 84). `vulyk-update-check.sh` compares the same stamp against GitHub tags via `curl` (cached, 24h) and prints `[VULYK] update available...` pointing at `/vulyk-update`; never updates itself.
3. `session-start-brief.sh` (`:16`) injects one `[VULYK] <newest map slice + mtime | learnings awaiting GC: N | map STALE... | start at memory/memory.md>` line from `memory/map/*.md` mtimes, `memory/map/.stale`, `memory/learnings/*.md` count. Neither hook reads `.claude/settings.local.json`. `top-model-brief.sh` (`:41`) injects `[VULYK] top model: $MODEL ($NAME) - by <plan/pin>, plan <PLAN>. Dispatch queen-planner, lead-architect and lead-review with model: $MODEL; Tier 4 second reviewer: <SECOND>. <SESSION>. Details: ...` where `SESSION` is the "pinned" vs. **"Queen session NOT pinned to $MODEL - tell the owner: `/model $MODEL` now... and `bash scripts/top-model.sh --apply`..."** clause (`top-model-brief.sh:36-38`), driven by `top-model.sh --check` exit code. No "Workflow mode" string exists anywhere under `.claude/hooks/` — would be a new clause in `top-model-brief.sh`'s line or a new hook.
4. `.claude/settings.json` hooks confirmed: `SessionStart` → `session-start-brief.sh`, `top-model-brief.sh`, `vulyk-update-check.sh`, `handoff.sh sessionstart`; `SessionEnd` → `session-end-learnings.sh`, `handoff.sh sessionend`; `UserPromptSubmit` → `handoff.sh prompt`; `Stop` → `handoff.sh stop`; `PostToolUse` (matcher `Skill`) → `skill-usage-counter.sh`; `PreCompact` → `context-guard.sh`, `handoff.sh precompact`. `"effortLevel": "medium"` (line 3). No `permissions` block.
5. `.gitignore` (30 lines): `.DS_Store`, `Thumbs.db`, `*.swp`; `memory/snapshots/*` + `!memory/snapshots/.gitkeep`; `memory/map/.stale`; `.claude/handoff/`, `.claude/state.json`, `.claude/.vulyk-update-cache`, `.claude/settings.json.vulyk-bak`, `.claude/settings.local.json`; `CLAUDE.local.md`, `__pycache__/`. `docs/specs/` and `memory/stats/` have no gitignore entry (committed by design; `docs/specs/*` is withheld from shipping by `shippable()`, a different mechanism).
