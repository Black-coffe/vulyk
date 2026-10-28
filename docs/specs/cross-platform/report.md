# Report: cross-platform

**Date:** 2026-10-28 · **HEAD:** `15575a1` (0.43.0) · study work, read only, nothing run on macOS or Linux.

**Scope read:** `scripts/*.sh` (25), `.claude/hooks/*.sh` (10), `install.sh`, `tests/*.sh` (15), `CLAUDE.md` = 52 files.
`tests/fixtures/**` left out: symbol-map input data, never executed. Method: `grep -nE` per pattern, comment
lines dropped, every hit read in context and sorted as **broken** (fails or silently misbehaves on a platform),
**guarded** (has a working fallback) or **noise** (the word inside a string, a regex in embedded Python, a test name).

## Bottom line

The product scripts are mostly portable already: the asked Bash 4+ list has zero real hits, `sha256sum`,
`stat -c`, most `date -d` and every product `timeout` have fallbacks, and paths are clean. What breaks is
concentrated: **10 product files with 14 sites** (one of them parses the reviewer's verdict) and
**12 test files** (110 bare `sed -i`, timeout-dependent asserts, Python resolvers). Four shared helpers in
`scripts/lib.sh` plus one grep gate and one `macos-latest` CI job close it.

## 1. Bash 4+ syntax

Asked list (`declare -A`, `${v,,}`, `${v^^}`, `mapfile`, `readarray`, `|&`, `&>>`): **0 real sites.**
- noise: `.claude/hooks/defects-inject.sh:166` - `re.split(r'[\s;|&<>()]+'...)`, Python regex in the heredoc.

Also checked, not asked: `declare -n/-g/-l/-u`, `local -n`, `[[ -v`, `${a[-1]}`, `coproc`, `;;&`, `;&`,
`globstar`, `wait -n`, `${v@Q}`, negative substring length: 0 sites.
- guarded: `tests/inject.test.sh:76`, `tests/intake.test.sh:84` - `$EPOCHREALTIME` (Bash 5) with a Python fallback.

**Found instead - empty array under `set -u`.** Bash below 4.4 (so macOS `/bin/bash` 3.2) treats
`"${a[@]}"` of an empty array as an unbound variable and aborts. The repo already knows the safe form
`${a[@]+"${a[@]}"}` (6 sites, e.g. `scripts/cycle.sh:2109`, `:3308`, `scripts/vulyk-update.sh:98`).
Unguarded expansions in files with `set -u`: 22. Read in context:
- **broken** `.claude/hooks/vulyk-update-check.sh:56` - `AUTH=()` (`:52`) stays empty without `GITHUB_TOKEN`,
  the usual case: the update check dies on every macOS session start.
- **broken** `scripts/cycle.sh:2426` - `OWN=()` (`:2415`) can stay empty; `:2427` already guards `reset` with
  `${#OWN[@]}`, the `git commit --only -- "${OWN[@]}"` on `:2426` is not guarded.
- **likely** `tests/full-suite.sh:74` - `CMDS=("${EARLY[@]}" "${LATE[@]}")`, `EARLY=() LATE=()` on `:72`;
  aborts whenever one group is empty.
- **not classified** (need per-site reading whether the array can be empty): `scripts/cycle.sh:931,932,2092,2093,2257,2344,2423,2435,3127`,
  `.claude/hooks/anomaly-scan.sh:41`, `scripts/redact.sh:53,65`, `scripts/telemetry.sh:842`,
  `tests/cycle.test.sh` (2), `tests/maintenance.test.sh` (5), `tests/full-suite.sh:73,76`.

## 2. GNU-only utilities and flags

| Tool | Product sites | Tests | Verdict |
|---|---|---|---|
| `timeout` | `scripts/cycle.sh:1990,2003,2016` (verify), `:2529-2532` (court setup); `tests/full-suite.sh:82,97` | see below | product **guarded**: probes `timeout 5 true`, else runs **uncapped** with a warning |
| `sha256sum` | `scripts/lib.sh:36,255-256`, `scripts/telemetry.sh:146`; `scripts/cycle.sh:2123,2160` messages | - | **guarded** (`shasum -a 256`) |
| `sed -i` | `install.sh:1291` | 110 sites, 7 files | **broken** (bare `-i`); `scripts/cycle.sh:118-123` `sed_inplace` is the correct form |
| `grep -P` | - | - | 0 |
| `stat -c` | `.claude/hooks/session-start-brief.sh:11`, `scripts/state.sh:121` | - | **guarded** (`date -r` first, BSD has it) |
| `date -d` | `.claude/hooks/session-start-brief.sh:35`, `.claude/hooks/top-model-brief.sh:54`, `scripts/telemetry.sh:113,135,280` | `tests/maintenance.test.sh:125`, `tests/telemetry.test.sh:444-445` | **guarded** (`-v` / `-jf`) |
| `date -d` | `scripts/state.sh:128` | - | **broken, silent**: `|| echo 0` - on BSD the snapshot epoch is 0 and the `stale` flag never fires |
| `date -I` | - | - | 0 |
| `readlink -f`, `find -printf`, `xargs -r` | - | - | 0 |

`sed -i` in tests, every line (all bare `-i`, BSD reads the script as the backup suffix):
- `tests/council.test.sh` (42): 102,111,112,360,361,484,511,518,877,1063,1064,1620,1637,2051,2108,2150,2158,2164,2165,2229,2230,2270,2506,2550,2566,2596,2616,2654,2676,2964,3091,3092,3231,3232,3260,3261,3683,3794,3805,3942,4046,4067
- `tests/cycle.test.sh` (24): 62,70,73,133,134,185,186,221,255,256,386,505,506,555,565,624,692,818,835,849,892,950,977,1003
- `tests/defects.test.sh` (22): 149,156,188,191,193,195,197,199,202,210,211,215,217,222,256,339,346,356,361,380,382,402
- `tests/telemetry.test.sh` (16): 938,1240,1257,1270,1432,1452,1463,1495,1509,1944,1965,2274,2275,2278,2281,2282
- `tests/maintenance.test.sh` (4): 259,533,535,537 · `tests/inject.test.sh:284` · `tests/solo.test.sh:51`

`timeout` in tests:
- **broken** (no guard, exit 127): `tests/intake.test.sh:333`, `tests/telemetry.test.sh:582,587`.
- **broken** (assert a timeout the product skips without the binary): `tests/council.test.sh:1026-1030`
  (setup timeout -> exit 2), `:4178-4184` (close-story -> exit 4), `tests/cycle.test.sh:1038-1042` (stamp-red -> 124).
- guarded: `tests/full-suite.test.sh:106-114` stubs a dead `timeout` on purpose.

Found, not asked:
- **broken** `scripts/cycle.sh:853` - `sed -n 's/^VERDICT: \(PASS\|BLOCK\).*/\1/p'`. `\|` alternation in a
  basic regex is a GNU extension, not POSIX. If BSD sed does not honour it, `review_verdict_of_text` returns
  empty and every review reads as no verdict. Not run on a Mac: this is a risk from the standard, to be
  confirmed by the first macOS run. `tests/cycle.test.sh:714-722` (`part bsd`) stubs BSD sed but only
  refuses a bare `-i`, so it does not catch this.
- **broken** `tests/symbol-map.test.sh:223,225` - `date +%s%N`; BSD has no `%N`, the arithmetic fails.
- guarded: `tests/full-suite.sh:45` `nproc` falls back to 4 jobs.
- `.claude/hooks/vulyk-update-check.sh:62,78` `sort -V`: reported present on macOS since 10.13/10.14
  (community sources only, see the chat fact-check); unconfirmed.

## 3. Python calls

Three resolver shapes exist:

**A - probe by running (stub-safe):** `scripts/defects-check.sh:67`, `scripts/defects-index.sh:38`,
`scripts/prompt-check.sh:16`, `scripts/symbol-map.sh:15`, `scripts/trace-autopsy.sh:15`
(`"$p" -c 'import sys; sys.exit(sys.version_info[0] != 3)'`); `.claude/hooks/defect-intake.sh:27`,
`.claude/hooks/defects-inject.sh:31` (run, fall through unless exit 0/1). Tested: `tests/inject.test.sh:344-352`,
`tests/intake.test.sh:253-261` stub a `python3` exiting 9009.

**B - presence only (`command -v`), a stub wins:**
- `install.sh:855,953,998,1057,1115` - settings.json merges; a stub turns them into a failed edit.
- `scripts/injection-check.sh:28`, `scripts/leak-check.sh:27`, `scripts/top-model.sh:345`.
- `.claude/hooks/handoff.sh:9` - `exec`s the first found: a stub kills handoff silently, and with it
  `scripts/telemetry.sh:239-242` `measure`, which reuses this wrapper.
- `.claude/hooks/anomaly-scan.sh:8` - presence gate only; the real call goes through `handoff.sh`.
- tests: `tests/defects.test.sh:41`, `tests/inject.test.sh:40`, `tests/intake.test.sh:40`,
  `tests/maintenance.test.sh:15`, `tests/mods.test.sh:32`, `tests/telemetry.test.sh:529`, `tests/token-report.test.sh:37`.

**C - bare `python` (no `python` on macOS 12.3+):** `CLAUDE.md:76` (`python -m py_compile`).
Outside the asked scope, seen on the way: `.claude/commands/vulyk-build.md:56,67`, `vulyk-evolve.md:10,13,90`,
`vulyk-status.md:40`, `vulyk-review.md:9` (the model runs these lines as written).

Stub behaviour is not settled here: the code comments say the Windows Store alias exits 9009, the request
says 49; a side-agent note says a stock Mac without Xcode Command Line Tools has a `/usr/bin/python3` stub
that offers an install and exits non-zero. Neither was observed this session. A run-probe covers every such
exit code, so the fix does not depend on which is right. GitHub's macOS images ship with Xcode, so a
`macos-latest` job will most likely **not** see the macOS stub; the probe needs a stub fixture test, as
`inject.test.sh:344` already does.

## 4. Paths and separators

Clean. No `/proc`, `/dev/shm`, `/sys`, hard-coded `/usr/bin` or drive letters in executable code.
- `/tmp`: `scripts/defects-check.sh:334` only as `${TMPDIR:-/tmp}` fallback; `tests/cycle.test.sh:97` is a fixture string.
- Windows handling, all with fallbacks that are no-ops elsewhere: `.claude/hooks/handoff.sh:8` (`pwd -W || pwd`),
  `scripts/top-model.sh:76-77` (`USERPROFILE` backslashes), `scripts/model-profile.sh:36`,
  `.claude/hooks/ysk-offer.sh:25`, `.claude/hooks/defects-inject.sh:29` (both separators),
  `install.sh:1099` (ripgrep wiring only under `MINGW*|MSYS*|CYGWIN*`), tests' `cygpath ... || printf`
  (`tests/e2e.test.sh:21`, `tests/maintenance.test.sh:432`, `tests/symbol-map.test.sh:184`,
  `tests/token-report.test.sh:39,145`, `tests/council.test.sh:2485`).
- `mktemp` / `mktemp -d` without a template: 38 sites. Works on current macOS as far as known; unconfirmed.

## Count

| Group | Files | Sites |
|---|---|---|
| Product, broken | 10: `scripts/cycle.sh`, `scripts/state.sh`, `install.sh`, `.claude/hooks/vulyk-update-check.sh`, `.claude/hooks/handoff.sh`, `.claude/hooks/anomaly-scan.sh`, `scripts/injection-check.sh`, `scripts/leak-check.sh`, `scripts/top-model.sh`, `CLAUDE.md` | 14 |
| Tests, broken | 12: `council`, `cycle`, `defects`, `telemetry`, `maintenance`, `inject`, `intake`, `solo`, `symbol-map`, `mods`, `token-report` `.test.sh`, `tests/full-suite.sh` | ~125 (110 `sed -i`) |
| Out of scope, same defects | 4 command files | 8 |
| Not classified | 8 files | 19 array expansions |

## Options

**1. Helpers + static gate + macOS CI (recommended).** Development stays on Windows, so any fix without a
gate decays on the next feature; the grep gate gives the answer in seconds on every machine, CI on macOS
catches what grep cannot (BSD behaviour, Bash 3.2 at run time). Both pieces exist in the repo already in
small form (`sed_inplace`, `sha256_tool`, the `part bsd` stub), so this is consolidation, not new design.

Helpers in `scripts/lib.sh` (tests source it too):
- `vulyk_python` - the shape-A probe over `python3 python py`, result cached in `VULYK_PY`, exit 1 when none
  runs. Replaces 5 probe loops and 15 presence resolvers. Hooks that start on every prompt keep the
  cheaper run-and-fall-through form (`defect-intake.sh:27`), and `handoff.sh:9` moves to it (one start, not two).
- `sed_inplace` - moved from `scripts/cycle.sh:118`; 111 call sites switch to it (mechanical).
- `date_epoch <iso>` / `date_shift <days> <fmt>` - GNU `-d`, then BSD `-jf` / `-v`; promoted from
  `scripts/telemetry.sh:111,132,278`; empty on failure, never `0` (fixes `state.sh:128`).
- `run_capped <secs> <cmd...>` - `timeout`, then `gtimeout`, else run uncapped with today's warning; tests
  that assert a timeout `skip` when it returns "uncapped", as `inject.test.sh:352` skips for Python.
- No helper for arrays: the `${a[@]+"${a[@]}"}` idiom, applied site by site.
- `cycle.sh:853` becomes `sed -nE 's/^VERDICT: (PASS|BLOCK).*/\1/p'`.

Gate `scripts/portability-check.sh` over `git ls-files '*.sh'` + `CLAUDE.md` + `.claude/commands/*.md`, exit 1
on a hit, a `# portable: <reason>` line comment as the only allow: bare `sed -i`, `\|` `\+` `\?` in a sed
without `-E`, `date -d` / `stat -c` without `||` on the line, `timeout`/`python3?` invocations or
`command -v python` outside `lib.sh`, `%N`, plus the asked Bash 4+ and GNU lists. Each pattern with a
failing fixture and a neighbour form (Law 6). Wired into the CI shell job and `## Commands`.

CI: one `macos-latest` job running the quick suites (free for public repositories, see the chat fact-check);
the full suite there only if its minutes are tolerable.

**2. Fix the sites inline, no helpers, no gate.** Smallest diff today; the next Windows-only edit is
invisible until a Mac owner reports it.

**3. macOS CI job only.** Real behaviour, zero design; but catches only what tests exercise, takes minutes
per signal, and will not see the Python stub.

## Candidate stories (for a later `/vulyk-plan`, Tier 3: cross-cutting)

1. `portable-helpers` - the four helpers in `lib.sh`; product sites switch (`cycle.sh:853,2426`,
   `state.sh:128`, `install.sh:1291` + resolvers, `handoff.sh`, `injection-check`, `leak-check`, `top-model`,
   `vulyk-update-check.sh:56`, `CLAUDE.md:76`, the 4 command files). `red: required` (parser and branches).
2. `portable-tests` - 110 `sed -i`, timeout skips, `%N`, test resolvers, `full-suite.sh:74`; routine, mechanical.
3. `portability-gate` - the script, fixtures, CI step, `## Commands` row, a `docs/defects/` card.
4. `ci-macos` - the `macos-latest` job; classify the 19 open array sites from its first run.

## Not read or run

- Nothing executed on macOS or Linux; every "broken" verdict is from the code and the POSIX/BSD manuals,
  strongest for `sed -i` and `date -d`, weakest for `cycle.sh:853` (`\|`) and the array sites.
- `*.py`, `.claude/workflows/*.js`, agents and commands beyond the incidental hits above.
- The 19 unclassified array expansions.
- Stub exit codes (9009 vs 49 on Windows; the macOS CLT stub).
