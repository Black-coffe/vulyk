# Cross-platform: portable helpers, a static gate and a macOS CI leg (plan)

**Tier:** 3 · **Spec slug:** `cross-platform` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-025 (red receipt), ADR-023 (`round-only` rows, one full suite per round), ADR-021 + `docs/wiki/rules-tree.md` (defect cards, Law 6), ADR-005 (installer contract), ADR-015 (model per story), `docs/defects/command-injection-follows-cwd.md` (injections name scripts via `CLAUDE_PROJECT_DIR`)
**Depends on:** study `docs/specs/cross-platform/report.md` (`15575a1`, the site inventory; its line numbers are of that commit); `post-043-tails` merged first (it edits `handoff.sh`, `state.sh`, `scripts/prompt-check.*`, `tests/cycle.test.sh`, `tests/maintenance.test.sh`, `tests/symbol-map.test.sh` - the same files, so this spec branches from its merge)

## Goal
Make every shell script, hook, test and command prose of VULYK run on Windows Git Bash, Linux and a stock macOS
(`/bin/bash` 3.2, BSD `sed`/`date`, no `timeout`, no bare `python`) and keep it that way. Four helpers in
`scripts/lib.sh` (`vulyk_python`, `sed_inplace`, `date_epoch`/`date_shift`, `run_capped`) plus a thin `scripts/py.sh`
replace every ad-hoc resolver and GNU-only call; `cycle.sh`'s verdict parser becomes `sed -nE`; every `"${a[@]}"` under
`set -u` is guarded; `install.sh` sources `lib.sh`; a grep gate `scripts/portability-check.sh` (defect card, fixtures,
run from the Maintenance suite and CI's `shell` job) fails on any regression; and CI runs `full-suite` and `install-smoke`
on `macos-latest` as well, pinned to the stock bash and asserting it. Timeouts work on a Mac without coreutils through a
Python fallback, so no timeout test skips.

## Assumptions
- **Build after `post-043-tails` ships.** It is in flight on the same files (list above). The report's `file:line` sites
  move by a few lines; workers find them by content (the report names the construct), never by line alone.
- **Agents count as product prose** (ask 3 «всех продуктовых»): `.claude/agents/lead-review.md` runs the suite under a bare
  `timeout`; story 02 carries it and the gate scans `.claude/agents/*.md` too. Veto here if agents should stay out.
- **Prose reaches the helpers without new CLIs.** Commands keep today's same-line idiom for dates
  (`date -u -d '7 days ago' +%F 2>/dev/null || date -u -v-7d +%F`, as `top-model-brief.sh:54`), which the gate accepts;
  `lead-review.md` wraps the suite as `bash -c '. scripts/lib.sh && run_capped <secs> <row>'`. Only `python` gets a
  wrapper (`bash scripts/py.sh`, the owner's answer 1). Rejected: `scripts/run-capped.sh` and `scripts/date-shift.sh`
  CLIs - two shipped scripts for three prose lines, and `prompt-check.sh` would then police two more names.
- **No new `## Commands` row.** `CLAUDE.md` is 7153 of the 7168 B cap (`tests/maintenance.test.sh:31`); the `py.sh` cell
  takes +12 (the Queen counted +13), leaving no room. The gate runs inside `tests/maintenance.test.sh` (the `Maintenance`
  row, so the full suite and every maintenance-verified story run it) and as a named step of CI's `shell` job.
- **The `Python` cell is touched by no open story**, so changing it mid-spec stales nothing; no story of this spec names
  it in `## Verification`. A hive keeps its own `## Commands` block on upgrade (`install.sh` carries it verbatim), so the
  new cell reaches hives only through VULYK's own constitution - ask 9 is satisfied by `command_cell_exists` matching the
  new text byte for byte and by the existing upgrade tests leaving a filled block alone - both now tested explicitly
  (Contracts, ask 9). A hive whose own cell says `python ...` keeps it: on a Mac that hive edits its own row.
- **Hooks never source `lib.sh`.** They must exit 0 when the hive lacks it (fail-open) and must not pay two interpreter
  starts on every prompt: `handoff.sh` adopts the run-and-fall-through form of `defect-intake.sh:27` (run the candidate,
  fall through unless it exited 0 or 1); `defect-intake.sh` and `defects-inject.sh` are already in that form and stay.
  Same-line `||` fallbacks already present in hooks (`session-start-brief.sh:35`, `top-model-brief.sh:54`, the `stat -c`
  and `sha256sum` sites) stay as they are; the gate's rule accepts a same-line `||`.
- **The five run-probe loops** (`defects-check.sh:67`, `defects-index.sh:38`, `prompt-check.sh:16`, `symbol-map.sh:15`,
  `trace-autopsy.sh:15`) consolidate onto `vulyk_python` (they live in `scripts/`, already under `set -u`); their
  `exit 2 no python` contract is unchanged.
- **Every unguarded `"${a[@]}"` / `"${a[*]}"` in a `set -u` file is guarded**, whether or not it can be empty (owner,
  item 1: «не оставляй 19 неклассифицированных мест»); `"${#a[@]}"`, `"$@"` and array literals keep their form unless the
  literal itself expands an array that can be empty (`tests/full-suite.sh:74`).
- **`date_epoch` never prints `0`**: empty output and exit 1 on an unparsable input. `state.sh` treats an empty epoch as
  «unknown, report stale» rather than «fresh» (the silent BSD bug of `state.sh:128` inverted, loud).
- **`run_capped`'s Python fallback is a file**, `scripts/run-capped.py` beside `lib.sh` (ships with `scripts/`), not a
  heredoc: testable on its own and readable. `timeout`, then `gtimeout`, then Python, else uncapped with today's warning;
  `0` or empty seconds = uncapped, silently (as `VULYK_SUITE_TIMEOUT=0`).
- **Test files sourcing `lib.sh` inherit `set -u`.** A suite that is not `set -u`-clean today must be made so inside the
  same story (its file is in `## Files`); a worker who finds the fallout larger than a few guards reports `NEEDS_CONTEXT`.
- **The gate reads prose inside code only**: in `.md` files only backticked spans and fenced blocks are scanned, so a
  sentence about «a timeout escalates» is not a hit. In `.sh` files heredoc bodies are skipped for the Bash-4 rule
  (`defects-inject.sh`'s Python regex). `tests/fixtures/**` is data and is excluded; `docs/defects/*.fixture` are not
  `*.sh` and never enter the tree scan. `scripts/lib.sh` is exempt from the `python`, `timeout`, `date` and `sed -i` rules
  (the helpers' home); the gate's own pattern table is written so it does not match itself (or the file is excluded, the
  worker says which). The one bypass is a same-line `# portable: <reason>`; the gate prints how many it honoured.
- **macOS CI proves the stock platform** (ask 5 is about a stock Mac; the PATH pinning is how the job tests one, prompted by a side-agent note, unverified): a `bash -> /bin/bash` symlink dir goes first on PATH (child `bash` calls resolve
  through PATH), and the job fails unless `bash --version` reports 3.2, `sed --version` fails (BSD) and no `timeout`
  is on PATH. GitHub's image details (Homebrew bash 5, gnubin, `jq`, a Python stub) are unverified: the job asserts, and
  installs through brew only what an assertion finds missing. `install-smoke`'s own steps use `sed -i` and `md5sum`; story
  05 makes them BSD-clean. No Windows CI (owner's answer 3). A red macOS leg after merge is a repair or the next circle,
  never a `continue-on-error`.
- **Routine stories run on Haiku** (the Queen's dispatch: `model-profile.sh --role routine` prints `haiku`): 03 and 04 are mechanical test switches; a miss
  retries on the gate model as usual.
- **Verification timing**: stories name `--part` cells and the short suites; `mods`, `solo`, `e2e`, `driver` and the whole
  council/telemetry suites run once per round in the full suite.
- **Not story files**: `docs/` narrative pages, `memory/memory.md:38-39` and the map slices (`drone-docs` at ship),
  `CHANGELOG.md`/`VERSION` (ship), hive rollout (`/vulyk-update` after release, not a story).

## Stories

**Wave 1**
- `cross-platform-01-helpers` — the four helpers + `py.sh` + `run-capped.py` in `lib.sh`; `cycle.sh` (`sed_inplace` moved out, `:853` to `sed -nE`, `run_capped` at verify and court setup, arrays); the `CLAUDE.md` Python cell; red tests in `tests/cycle.test.sh` (`red: required`)

**Wave 2**
- `cross-platform-02-product-sites` — `install.sh` sources `lib.sh`; every product resolver, date and array site; hooks; command and agent prose; `tests/telemetry.test.sh`
- `cross-platform-03-council-tests` — `tests/council.test.sh`: 42 `sed_inplace`, the two timeout cases without `skip` (`model: haiku`)
- `cross-platform-04-suite-tests` — `defects`, `inject`, `intake`, `solo`, `symbol-map`, `mods`, `token-report` suites, `tests/full-suite.sh` and `tests/full-suite.test.sh` (`model: haiku`)

**Wave 3**
- `cross-platform-05-gate-ci` — `scripts/portability-check.sh`, the defect card + four fixtures, its tests and the tree run in `tests/maintenance.test.sh`, CI `shell` step and the `macos-latest` matrix (`red: required`)

## Contracts
- `vulyk_python` (lib.sh): probes `python3`, `python`, `py` by running
  `"$p" -c 'import sys; sys.exit(sys.version_info[0] != 3)' </dev/null >/dev/null 2>&1`; sets `VULYK_PY` to the first
  that passes and returns 0; returns 1 with `VULYK_PY` empty when none does. A preset non-empty `VULYK_PY` is trusted
  (cache and test seam). Call it in the current shell, never in `$(...)`.
- `bash scripts/py.sh <args...>`: `vulyk_python`, then `exec "$VULYK_PY" "$@"`; no Python: one stderr line
  `py.sh: no python 3 found (tried python3 python py)`, exit 2. Roots `lib.sh` at its own `BASH_SOURCE`, not the cwd.
- `install.sh` (ask 7): right after `SRC` is set from `BASH_SOURCE` (`install.sh:18`), `. "$SRC/scripts/lib.sh"`;
  a missing file is `install.sh: scripts/lib.sh not found beside install.sh - run from a full checkout`, exit 2, nothing
  written. Covered starts: `bash <checkout>/install.sh`, `<checkout>/install.sh` (shebang), either from any cwd, and
  `scripts/vulyk-update.sh` running the release's own copy; a symlink to `install.sh` is not supported (exit 2).
- Ask 9 is checked, not assumed: story 01 proves `close-story` accepts the new cell and refuses the old one; story 02
  proves `install.sh --upgrade` keeps a hive's filled `## Commands` block (old `python` cell included) byte-identical.
- `sed_inplace <sed-args...> <file>`: `sed -i.bak "$@"` then `rm -f "<file>.bak"`; the last argument is the one file;
  exit status is sed's. Moved verbatim from `cycle.sh:118-123`; `-E` and `-n` pass through.
- `date_epoch <when>` -> epoch seconds on stdout for `YYYY-MM-DD` and `YYYY-MM-DDTHH:MM:SSZ` (UTC); GNU `date -u -d`,
  else BSD `date -ju -f`; empty output and exit 1 when neither parses it. Never `0`.
- `date_shift <±days> [<+fmt>]` -> `date -u` of now shifted by that many days, default `+%Y-%m-%d`; GNU `-d "N days"`,
  else BSD `-v±Nd`; empty and exit 1 on failure. `prev_week` / `week_of` in `telemetry.sh` are expressed through these.
- `run_capped <secs> <cmd> [args...]`: runs `cmd` with stdin/stdout/stderr inherited; exit 124 on timeout, else the
  child's exit. Order: a `timeout` that passes `timeout 1 true` -> `timeout -k 10 <secs>`; else `gtimeout -k 10`; else
  `"$VULYK_PY" scripts/run-capped.py <secs> <cmd...>` (`subprocess.Popen(start_new_session=True)`, SIGTERM to the group,
  10 s grace, SIGKILL; on Windows kill the process; exit 124); else run uncapped and print
  `run_capped: no timeout, gtimeout or python 3 - running <cmd> uncapped` to stderr. `<secs>` `0` or empty: run uncapped,
  silently. `VULYK_VERIFY_TIMEOUT`, `VULYK_SETUP_TIMEOUT`, `VULYK_SUITE_TIMEOUT` keep their meanings.
- `bash scripts/portability-check.sh [<file>...]`: no argument = tree scan (`git ls-files '*.sh'`, the constitution,
  `.claude/commands/*.md`, `.claude/agents/*.md`, minus `tests/fixtures/**`); with arguments = those files only (the card's
  `check: ... <arg>`). stdout: one `portability-check: <file>:<line>: <rule>: <text>` per hit, then
  `portability-check: ok (<n> files, <m> allowed)` or `portability-check: <k> hit(s)`. Exit 0 clean / 1 any hit / 2 usage,
  a named file missing, or nothing to scan - never a warn-only mode. Rules: `bash4` (`declare -A`, `${v,,}`, `${v^^}`,
  `mapfile`, `readarray`, `|&`, `&>>`), `sed-i` (bare `sed -i`), `sed-bre` (`\|` `\+` `\?` in a sed without `-E`/`-r`),
  `grep-P`, `stat-c`, `date-d` (`date -d`, `--date`, `date -I` with no same-line `||`), `pct-n` (`%N`), `readlink-f`,
  `find-printf`, `xargs-r`, `timeout` (`timeout`/`gtimeout` in command position outside `lib.sh`), `python`
  (`python`/`python3`/`py` in command position, `command -v`/`which`/`type` of them, outside `lib.sh`), `array`
  (`"${name[@]}"` / `"${name[*]}"` not preceded by `${name[@]+` in a file carrying `set -u`/`-eu`/`-euo`/`-o nounset`).
  Allow: same-line `# portable: <reason>`.
- Defect card `docs/defects/shell-needs-gnu-or-bash4.md` (`status: block`, `check: bash scripts/portability-check.sh
  <arg>`, four fixtures `docs/defects/shell-needs-gnu-or-bash4.<sed-i|sed-bre|array|python>.fixture`).
- CI: `full-suite` and `install-smoke` run on `strategy.matrix.os: [ubuntu-latest, macos-latest]`; a macOS-only step pins
  PATH and asserts bash 3.2 / BSD sed / no `timeout`; `shell` gains `run: bash scripts/portability-check.sh`.

## Integration gate
`bash tests/full-suite.sh`

## Descoped

*(empty)*

## Plan deltas

<!--
The lines below are the cycle's confirmation markers (docs/cycle.md); each placeholder is replaced by
the command or script that owns it, and scripts/ship-check.sh reads them all. Approved is the owner's
word, the stop at Tier 2-4; Briefed is written by `cycle.sh briefed` instead, at Tier 1 ("via
mini-brief"), with `--go`, or in no-question mode ("assumed"). Either closes stage 02. Council and
Checked close stages 04+05 together: a GREEN council row is enough on its own, and Checked is the
owner's override in either direction, newest timestamp wins. No line of this comment may start with
a marker: the scripts read the first line that does.

There is no default tier: `cycle.sh open-round` refuses to open a round while the `**Tier:**` line above
is missing or unparsable.
-->
**Approved:** Andrei, 2026-10-28 («Jlj,hz.» - «Одобряю» typed in the Latin layout; both planner decisions kept)
**Briefed:** <written by scripts/cycle.sh briefed - stage 01+02 on the straight-through path (--go, Tier 1): "via grill, <owner>, <date>" (or "via grill (assumed)" / "via mini-brief"). Alternative to **Approved:** above.>
**Branch:** vulyk/cross-platform
**Checked:** <written by scripts/human-check.sh after the owner has looked - stage 05, and the override for stage 04+05. /vulyk-ship refuses without either this or a GREEN **Council:** line.>
**Council:** <written by scripts/cycle.sh judge/escalate - stages 04+05: "<GREEN|RED|ESCALATE|STALE> round <N>, <date>, at <sha7>, pack <fp12>[ - red: 2,5]", appended once per round.>
**Shipped:** <written by scripts/ship-check.sh --record - stage 06: the published version, and where>
