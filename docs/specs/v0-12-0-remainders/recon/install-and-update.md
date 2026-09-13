# Scout report: install.sh + scripts/vulyk-update.sh

Scouted 2026-09-13 at `3e200bb` by `drone-scout`; saved verbatim for `queen-planner`.

## Purpose
`install.sh` copies the VULYK framework into a target repo (fresh install or `--upgrade`), deciding file-by-file what ships, what's replaced, and what's left alone. `scripts/vulyk-update.sh` is the wrapper an owner runs after the SessionStart hook notices a new release: it clones/fetches the origin repo and hands off to that release's own `install.sh --upgrade`.

## Top-level structure of install.sh (457 lines)
Flow order (all functions are defined top-to-bottom, then invoked at the bottom):
1. `install.sh:15-30` — parse args (`DEST`, `--check`, `--upgrade`), resolve `SRC`/`VER`.
2. `install.sh:34-35` — `OWNED` list + `owned()` — framework-owned trees, replaced on `--upgrade`.
3. `install.sh:49-65` — `shippable()` — allow/deny rules (return 0/1/2).
4. `install.sh:67-87` — `copy_tree()` — the copy loop.
5. `install.sh:103-125` — `reset_marked_block()` — generic marker-block reset (keeps markers).
6. `install.sh:127-153` — `reset_commands_table()` — calls `reset_marked_block` twice: `VULYK:COMMANDS` (127-139) and `VULYK:PROFILE` (140-152).
7. `install.sh:155-161` — read `PREV` version stamp, print banner.
8. `install.sh:168-245` — `wire_session_hook()` — appends a SessionStart hook entry into `.claude/settings.json` via Python if missing.
9. `install.sh:254-312` — `wire_permissions()` — appends two `Bash(...)` allow rules into `.claude/settings.json`.
10. `install.sh:320-345` — `ensure_gitignore()`.
11. **Main flow, `install.sh:347-457`:** the `copy_tree` loop over trees (347) → `ensure_gitignore` (348) → `wire_session_hook` x2 (349-350) → `wire_permissions` (351) → create empty dirs/seed `skills.json` (352-360) → `CLAUDE.md` handling (362-416) → copy `AGENTS.md` if absent (416) → stamp `.claude/vulyk-version` (418-425) → pin top model via `scripts/top-model.sh --apply` (427-444) → `chmod +x` on hooks/scripts (446-448) → final message (450-457).

## Key types / contracts

**`shippable(f)` — `install.sh:49-65`.** Return codes: `0` = ship, `1` = vulyk's own dev content (never shown even in `--check`), `2` = gitignored runtime artifact (shown as `would skip (runtime)` only in `--check`). Exact deny rules:
- `*/__pycache__/*`, `*.pyc` → 1
- `docs/specs/*` → 1 (dir still created; **note: `docs/adr/*` and `docs/wiki/*` are NOT matched by any case arm — they fall through to `return 0`, i.e. they ARE shipped**)
- `memory/learnings/*` → 1, except `*/README.md` → 0
- `.claude/settings.local.json`, `.claude/settings.json.vulyk-bak` → 2
- `.claude/state.json`, `.claude/.vulyk-update-cache`, `.claude/vulyk-version` → 2
- `.claude/handoff/*`, `memory/map/.stale`, `CLAUDE.local.md` → 2
- `memory/snapshots/*` → 2, except `*/.gitkeep` → 0

**Confirms the brief's premise (item 1):** `docs/adr` is copied — `install.sh:347` includes `docs/adr` in the tree loop, and `shippable()` has no case arm excluding `docs/adr/*`, so ADR files ship on both install and `--upgrade` (existing files are merely skipped, not overwritten, per the generic copy-loop rule — see below).

Quoted claims that contradict this:
- `install.sh:10` (in the file header comment): `"... and still never touches what is yours: CLAUDE.md, memory/, docs/specs|adr|wiki, .claude/rules."`
- `install.sh:452`: `echo "Done. Upgraded framework files only; your CLAUDE.md, memory/, specs, ADRs and wiki were not touched."`
Both are printed/asserted unconditionally, but `docs/adr` and `docs/wiki` are not in `OWNED` (`install.sh:34`, so they're never "replaced" on upgrade — that half is true) yet they ARE copied for new files on both install and upgrade (not "never touched" — new ADR/wiki files a fresh release ships will land in the target). The claim is accurate only for *existing* files (never overwritten because not in `OWNED` and the copy loop skips existing non-owned files); it's misleading/false as a blanket "never touches" statement for new files added by a release under `docs/adr` or `docs/wiki`.

**`copy_tree(rel)` — `install.sh:67-87`.** For each file: if `shippable` fails, skip (log only for code 2 in `--check`). If dest file exists: only overwritten when `UPGRADE` set AND `owned(f)` true AND content differs (`cmp -s`) → "update"; else "skip (exists)". If dest file absent: copied fresh ("copy"). **Nothing is ever removed from the target** — no delete/prune logic anywhere in the file. **No manifest of shipped files exists** — neither in the repo, nor in `.claude/`, nor referenced by `vulyk-update.sh`. The only persistent installer-state file is `.claude/vulyk-version` (`install.sh:418-425`), a single-line semver stamp (`printf '%s\n' "$VER"`), read back at `install.sh:155` and by `.claude/hooks/vulyk-update-check.sh:26` and `scripts/vulyk-update.sh:41`. A manifest, if added, would naturally live as a sibling stamp, e.g. `.claude/vulyk-manifest` or `.claude/vulyk-shipped-files`, written alongside the version stamp at `install.sh:418-425` and consulted inside `copy_tree` (`install.sh:67-87`) to decide removals.

**`CLAUDE.md` handling on `--upgrade` — `install.sh:362-416`.** Never overwritten in any branch. Three cases: (a) dest `CLAUDE.md` is already a VULYK constitution (matched by `^# VULYK Constitution` title OR presence of `VULYK:COMMANDS:START` marker, `install.sh:366-367`) → left untouched; if content differs from source, prints `diff "$DEST/CLAUDE.md" "$SRC/CLAUDE.md"` hint (`install.sh:376`); also warns if `TOP_MODEL = opus` is still pinned (378-386). (b) `CLAUDE.vulyk.md` already exists → left untouched, diff hint via `git log` + `diff` against `CLAUDE.vulyk.md` (390-394). (c) neither → copies source `CLAUDE.md` to `CLAUDE.vulyk.md` and blanks its Commands/Profile tables via `reset_commands_table` (397-398), telling the user to add `@CLAUDE.vulyk.md`.

Markers found (grep of file): only two marker families exist — `VULYK:COMMANDS:START/END` and `VULYK:PROFILE:START/END` (both handled identically by `reset_commands_table`, `install.sh:127-153`). No other `VULYK:<NAME>` markers exist in install.sh. On fresh install, both blocks get reset to placeholders (COMMANDS table `install.sh:129-138`; PROFILE table `install.sh:141-151`, **8 rows**: Stack, Package manager/runner, Where source lives, Test framework, Commit convention, Configurations that exist today, Client path, Browser MCP, Release/deploy — matches CI's dynamic row-count check at `.github/workflows/ci.yml:170-173`). On `--upgrade`, `reset_marked_block`/`reset_commands_table` are **never called** in the upgrade branch — the whole `CLAUDE.md` block (362-416) only calls `reset_commands_table` for the fresh-copy case (398, 400, 412) and never inside the "already a VULYK constitution" branch, so an upgrade never touches an already-filled Profile/Commands block (confirmed by CI test `.github/workflows/ci.yml:206-214`).

**`ensure_gitignore()` — `install.sh:320-345`.** Entries list at `install.sh:322`: `.claude/handoff/ .claude/.vulyk-update-cache .claude/settings.json.vulyk-bak .claude/state.json .claude/settings.local.json CLAUDE.local.md memory/snapshots/ memory/map/.stale __pycache__/ .vulyk/ docs/specs/*/PAUSE`. Written literally: the loop at `install.sh:340-342` does `echo "$line"` for each missing entry, appended verbatim via the `{ ... } >> "$file"` block (334-343) — the glob string `docs/specs/*/PAUSE` is written byte-for-byte as a line in `.gitignore`, no escaping/expansion (word-splitting on `$wanted` at 324/340 relies on no internal spaces in any entry). Matching uses `grep -qxF "$line" "$file"` (exact literal match, line 325/341) so idempotent re-runs don't duplicate.

**`--check` dry-run mode.** Exact printed line prefixes (all two-space indented under the banner): `would skip (runtime) <f>` (72), `would update   <f>` (77), `would copy     <f>` (83), `would reset    <name> '<label>' -> placeholders` (116), `would wire     .claude/settings.json -> SessionStart: <script>` (173), `would wire     .claude/settings.json -> permissions.allow: cycle.sh, journal.sh` (262), `would add      <n> VULYK runtime entries to .gitignore` (330), `would create   memory/ and docs/ trees` (356), `would stamp    .claude/vulyk-version = $VER` (420), `would pin      Queen session to the resolved top model (...)` (434). `set -euo pipefail` at top (13) but no explicit `exit` codes are set anywhere in the file — script relies on natural exit status (0 on success given `|| true` guards throughout non-critical steps); no path returns non-zero deliberately, so `--check` and real runs both exit 0 barring an unhandled command failure.

## `scripts/vulyk-update.sh` (89 lines) — end to end
1. Args: `[project-dir] [--check] [--version X.Y.Z]` (`:19-28`), default `DEST="."`.
2. Resolves origin repo: `VULYK_REPO` env → `.claude/vulyk-origin` file (`:35-36`) → default `Black-coffe/vulyk` (`:38`).
3. Cache location: `VULYK_SRC` env, default `~/.vulyk/src` (`:39`) — a **plain git clone**, not inside the target's `.claude/` (that path, `.claude/.vulyk-update-cache`, is a *different* thing — see below).
4. Reads installed version from `$DEST/.claude/vulyk-version` (`:41`), prints project/installed/origin.
5. Clone-or-fetch the cache repo (`:49-55`): `git clone` if absent, else `git fetch --tags`.
6. Resolves target tag: `--version` pins exactly (`v${WANT#v}`, `:58`); otherwise newest `v*` tag by `sort -V` (`:60-63`).
7. Verifies tag exists (`:64-65`), checks it out detached (`:67`).
8. Delegates entirely to that release's own installer: `"$SRC/install.sh" "$DEST" --upgrade $CHECK` (`:76`) — no copying logic of its own (stated explicitly `:12-13`).
9. On success (not `--check`): deletes `$DEST/.claude/.vulyk-update-cache` (`:84`, a *separate* file — see below) so the update-check hook re-probes fresh; prints CHANGELOG link (`:85-87`).
Exit codes: `set -euo pipefail` (`:17`); explicit `exit 1` on missing dir (`:30`), missing git (`:32`), bad `--version` value (`:23`), unknown flag (`:24`), no tags published (`:61`), tag not found (`:65`). No dedicated success exit code (falls through, natural 0).

**How a hive learns a new version exists:** separate from `vulyk-update.sh` — `.claude/hooks/vulyk-update-check.sh` (SessionStart hook, lines 1-68+): compares `.claude/vulyk-version` stamp against GitHub tags API, caching the result in `$ROOT/.claude/.vulyk-update-cache` (format: `"$NOW $LATEST"` one line, written `hook:65`) with a default 24h refetch interval (`VULYK_UPDATE_INTERVAL_HOURS`, default 24, `hook:38`). Fails open on any error (no network/no stamp/no curl/corrupt cache → silent exit 0, `hook:9-11,18-29`). It never applies anything — only prints a `[VULYK]` context line telling the model to ask the owner before running `vulyk-update.sh`.

## Dependencies
Inbound: CI workflow `.github/workflows/ci.yml` job `install-smoke` (`:116-231`) exercises `install.sh` directly (not `vulyk-update.sh`). `vulyk-update.sh` is invoked by an owner/agent after `vulyk-update-check.sh` flags a new version.
Outbound: `install.sh` calls `scripts/top-model.sh --apply` (`:439`) and reads `python3`/`python` for JSON edits. `vulyk-update.sh` calls `git` and the fetched release's own `install.sh`.

## Gotchas
- The header/footer claims at `install.sh:10` and `install.sh:452` about ADRs/wiki "never touched" are **overstated** — true only for pre-existing files, false for new files a release adds under `docs/adr/` or `docs/wiki/` (they get copied in since not excluded by `shippable()` and not gated by any "existing dest only" check for non-owned trees — copy_tree always copies new files regardless of ownership; only *overwriting existing* files is gated by `owned()`+`UPGRADE`). So new ADR/wiki files DO ship silently on both install and upgrade.
- No manifest anywhere means there's no way to detect/remove framework files that a later release deleted — installs only ever grow.
- Two different files are both casually called "the cache" in nearby comments: `~/.vulyk/src` (git clone cache, `vulyk-update.sh:39`) vs `$DEST/.claude/.vulyk-update-cache` (hook's version-check cache, one-line stamp). Don't conflate them when writing the fix.
- `ensure_gitignore`'s `wanted` list is space-split (`for line in $wanted`, `:324/340`) — adding any future entry containing a space would silently break both the missing-count and the write loop.
- `reset_marked_block` deliberately keeps `:START`/`:END` markers after resetting (historical bug noted in comments `install.sh:97-100`) — any manifest/marker design added later should follow the same "markers survive" pattern.
