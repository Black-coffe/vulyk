# Scout report: commands - ship, update, status, gc and the rest (split from agents-and-commands.md)

Other slices: `agents-and-commands.md` (agents), `commands.md` (plan, build, review, models).

## Commands - what each runs
- **0.53 `/vulyk-update` / `/vulyk-ship`:** the update dry run also shows `tracked memory/stats/skills.json` with the
  command that untracks the local skill counter (quote it, offer to run it); `vulyk-update.sh` refuses a target older than
  the installed version (`scripts-install.md`). `/vulyk-ship` pushes the spec branch only to a private origin
  (`gh repo view --json visibility`); `PUBLIC` or no answer = ask the owner, push nothing.
- **0.51 `/vulyk-update` (upgrade-findings):** step 2 reads three new dry-run lines to the owner: `would merge
  frontmatter <file>` (`kept <key> (yours)`; a key both sides changed parks the file as `keep + new`) and `commands:
  row '<Purpose>'` (a note beside the backticked command, or several commands); step 4 recommends replace-or-merge
  from the `constitution: <N> lines only in the backup` list; step 6 carries the measured-suite lines (over 210 s,
  cut before taking the release) and a cutting recipe. The command only quotes them; the owner fixes the rows.
- **`/vulyk-ship`** - `ship-check.sh` (NOT READY refuses). On `ci: no CI run for <sha>` it asks where `origin` points
  (above); on a private one pushes the spec branch, runs `gh workflow run <file> --ref <branch>`, waits, rechecks; a red
  run is a refusal; only the newest run of each workflow on that commit counts, so a green re-run clears an older red
  (0.47). Stage 03 runs `git merge-tree --write-tree` (0 clean, 1
  conflict never overridden, other = "cannot check"). Release commit; local `merge --no-ff` only on a clean default
  tree, failure → `merge --abort`; `branch -d` (never `-D`). Step 3 (0.53): `lead-review` reads the outward text
  first; a flagged line moves to a private file under `~/.vulyk/` and `lead-review` runs again before the publish command
  is printed. Prints the publish command, never runs it (push, green
  CI, then tag); `drone-docs`/`librarian` only with work; next-brief draft.
  **Step 2a Local beta** (card `public-release-per-change`; only where `install.sh` + `VERSION` are at the root; no
  registry = prints `local beta: no hive registry, rollout skipped`): step 2 makes no bump here (CHANGELOG goes under
  `## [Unreleased]`). 2a bumps `VERSION` and every tracked `.claude-plugin/plugin.json` to the next `X.Y.Z-dev.N`
  (plain `X.Y.Z` -> `X.<Y+1>.0-dev.1`), commits `release: <v> (local, unpublished)`, tags `v<v>` locally (never pushed; the
  only tag ship creates).
  Every ship re-checks each live hold. Before every hive upgrade and again right before the hive commit it asks
  `hives-behind.sh --busy <hive>` (busy/unknown = hold; a path the upgrade did not write stops that hive, no commit).
  Hives get `./install.sh <hive> --upgrade` from the clone, `.vulyk-new` merged by hand, hive commit `chore(vulyk):
  upgrade to <v>`; canaries (`hives-behind.sh --canaries`) first plus one test row from their `## Commands`. Rule:
  at least one canary took the build and every canary that took it is green. A busy canary is held, not red: it
  goes first next ship and the owner is told one hive shape was tested. No canary took the build = every other hive
  held, naming what stops each canary. A red canary reverts its upgrade and holds it and every pending hive. A hive that
  cannot take it gets `| hold <date> <reason>` (<= 7 days). Ends on `hives-behind.sh` exit 0, printing `held` lines.
- **Portable spelling (0.44.0):** command and agent shell blocks call Python as `bash scripts/py.sh ...` and
  date windows as `date -u -d '-N days' ... || date -u -v-Nd ...`; `portability-check.sh` reads their shell
  fences and multi-word inline spans (card `shell-needs-gnu-or-bash4`).
- **`/vulyk-status`** - driver line, council stats, `token-report.py`, `state.sh` table, map freshness,
  `maintenance due|waits for` (0.48: also a `tool.check` brief line, naming a mod that can approve a call git-guard
  denied). Step 1 also prints the lagging-hives summary and RED lines (`hives-behind.sh`) in the VULYK source with a
  registry. Writes only `.claude/state.json`.
- **`/vulyk-evolve`** - `evolve-ledger.py . resolve` + `window`; changeset in worktree on `vulyk/evolve-<date>`;
  step 2: once ≥ 3 `horizon.md` exist, counts `(horizon H` picks against ADR-022's reversal rule.
- **`/vulyk-gc`** - dispatches `librarian`; main session `git rm`s its `Delete:` list. `/vulyk-gc memory`: main
  session alone, one `AskUserQuestion`; step 10 runs `memory-triage.sh --mark`.
- **`/vulyk-update`** step 6 renames the hive's full-suite row to `Full suite / build (round-only)` (ADR-023).
  `/vulyk-pause`/`-resume` wrap `cycle.sh pause`/`resume`; `/vulyk-bootstrap` a no is `| Bootstrap | declined <date> |`.
- **`/vulyk-map`**, **`/vulyk-handoff`**: `!` injections go through `${CLAUDE_PROJECT_DIR}`, never a relative
  script path (`injection-check.sh`); `handoff.sh dump "${CLAUDE_SESSION_ID}"`.

last-verified: 2026-11-14 (0.53.0-dev.1 audit-fixes-1113; split from agents-and-commands.md; ADR-020, 023)
