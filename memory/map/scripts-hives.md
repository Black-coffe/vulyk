# Scout report: hives-behind.sh (split from scripts.md)

Other slices: `scripts.md` (cycle scripts), `scripts-checks.md`, `scripts-hooks.md`, `scripts-guards.md`,
`scripts-install.md`.

- `hives-behind.sh [--check <state>|--canaries|--busy <hive>|--slug <path>]` (card `public-release-per-change`) -
  registry `${VULYK_HIVES_FILE:-~/.vulyk/hives}` (private; one hive per line: `<path>` | `canary` | `hold
  <YYYY-MM-DD> <reason>`; `~/` expands); no arg reads each hive's `.claude/vulyk-version` against `VERSION` and
  judges. Green = on the local build or under a live hold. Red: lags, `none`, `missing`, hold
  expired/malformed/no reason/more than `HOLD_MAX_DAYS` (7) ahead, no hive. `--check <state>` judges a state file
  alone (`local <v>`, `hive <installed|none|missing> <path>[ | hold ...]`); `--canaries` prints canary paths (exit
  1 if none). Exit 0 / 1 / 2 (registry, state or VERSION absent). Env `VULYK_TODAY`, `VULYK_SRC`.
- `--busy <hive>`: `idle` exit 0 / `busy <why>` / `unknown <why>` (both exit 1). Busy on a `docs/specs/*/DRIVER`
  file (the line names `bash scripts/cycle.sh release <spec> <stamp>` to free a stale one) or a `*.jsonl`
  transcript at any depth (Workflow agents write 5 levels down) written in the last 60 minutes under
  `<root>/projects/<slug>/`. Folders `<slug>-*` (session started in a hive subfolder) count only when a fresh
  transcript's `cwd` is the hive or below it (Windows: case-insensitive). `sub_session` (tails-1115): a transcript
  with no `cwd` (a Workflow journal) takes the `cwd` of its session's top transcript `<dir>/<sid>.jsonl`; only
  when neither has one is it busy. Roots
  `$VULYK_SESSION_ROOTS` (space-separated), else `${CLAUDE_CONFIG_DIR:-~/.claude}` plus every `~/.claude*` with
  `projects/`. No transcript folder under any root: `idle no session transcript folder ...` (exit 0) if
  `naming_proven` (some registered hive resolves to its exact `<root>/projects/<slug>/`; path-less registry lines
  prove nothing), else `unknown` (exit 1). `--slug <path>`: non-alphanumeric char -> `-` (Git Bash `/<drive>/x` read as
  `<drive>:/x`). Caller: `/vulyk-ship` step 2a (before each upgrade and hive commit).

last-verified: 2026-11-18 (tails-1115 top-transcript cwd)
