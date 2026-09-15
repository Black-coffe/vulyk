# Anomaly telemetry (plan)

**Tier:** 3 · **Spec slug:** `anomaly-telemetry` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-005 (install.sh OWNED set, marked blocks, `shippable()`), ADR-007 (model ladder), `.claude/commands/vulyk-ship.md:11` ("print the command, then stop; never wait" - no agent sends or pushes), `docs/token-economy.md` (hooks fail-open and quiet), `scripts/lib.sh` `is_paperwork_path()` anchoring (memory/map/scripts.md Gotchas).
**Depends on:** v0.13.3 (`7fdb6f1`, installer copies bytes from a source checkout); recon `recon/hooks-and-stats.md`, `recon/weekly-and-publish.md`, and the scout answers of 2026-09-14 folded into A7, A10-A13 below.

## Goal
Every hive running VULYK keeps a committed, append-only anomaly log (`memory/stats/anomalies.jsonl`) fed by five detectors over records that already exist plus one new fail-open hook. One shell script, `scripts/telemetry.sh`, owns all of it: recording, scanning, bundling a week into an anonymized file of codes and numbers only, validating that file, reading consent, and printing (never running) the command that carries the bundle into the VULYK repository - a local commit when the repo is on this machine, a `gh pr create` recipe otherwise. `/vulyk-evolve` gains the weekly step; the constitution gains a `Telemetry` Profile row that is `off` by default. `install.sh` - fresh install and `--upgrade` alike - explains telemetry in the terminal and asks one yes/no question that sets the row, silently defaulting to `off` when no one can answer; `/vulyk-bootstrap` shows the value. The public repo documents what is collected, what never is, how to send, and that the inbox is distilled and cleared weekly. A CI job validates incoming bundles against the schema.

## Assumptions
- **A1 - local VULYK repo detection.** `telemetry.sh publish` treats a checkout as "the VULYK repo on this machine" in this order: `VULYK_LOCAL` env (explicit path, must be a git worktree containing `telemetry/inbox/`); else the hive itself when its `origin` URL contains the origin slug (`VULYK_REPO` env, else `.claude/vulyk-origin`, else `Black-coffe/vulyk`). `~/.vulyk/src` is deliberately NOT a copy target: it is `vulyk-update.sh`'s pull-only release cache, usually detached at a tag, so a commit there goes nowhere. If neither matches, the PR recipe is printed.
- **A2 - thresholds are v1 calibration**, one env var each, defaults baked into `telemetry.sh` and written into every row so `/vulyk-evolve` can recalibrate from data: `VULYK_ANOMALY_CONTEXT_PCT=70` (percent of the resolved window; `VULYK_ANOMALY_CONTEXT_TOKENS=140000` absolute when the window is unknown), `VULYK_ANOMALY_AGENT_PREFIX_TOKENS=50000` (first-turn `input + cache_creation` of a subagent = what the dispatch handed it), `VULYK_ANOMALY_COUNCIL_ROUNDS=3` (max round per spec at or above this), `VULYK_ANOMALY_STAGE_HOURS=24` (gap between consecutive `journal.md` lines). Workers legitimately carry large prefixes; the `agent` token (A12) is what makes the row readable.
- **A3 - version source.** Bundle rows read `.claude/vulyk-version` (written by `install.sh`), falling back to `0.0.0`. In VULYK's own tree that file may not exist; `0.0.0` is acceptable for dogfooding rows.
- **A4 - hive hash input** is `git rev-parse --show-toplevel` as printed (on Windows Git Bash `/e/Projects/hive`). It only needs to be stable per machine, not portable.
- **A5 - `.vulyk/` is already gitignored** (court and report dirs live there); the weekly bundle is written to `.vulyk/telemetry/<week>-<hive>.jsonl` and needs no new ignore entry.
- **A6 - Profile-block exception.** `install.sh --upgrade` today never touches a filled marked Profile block (ci.yml:313). This plan carves exactly one exception: the `| Telemetry |` row - appended when missing, its value replaced when the installer's question was answered. A hand-written Profile without markers is warned, never rewritten (ADR-005 D4.9 stays).
- **A7 - python entry point (resolved by scout).** `handoff.py` `main()` (line 875) dispatches `sys.argv[1]` against `HOOK_MODES` (line 872) in an if/elif chain, and `handoff.sh:10` forwards argv verbatim. `measure` joins that chain as a read-only mode on `handoff.py`; no sibling file.
- **A8 - driver refusal/relaunch** are event-recorded at the two command surfaces that know about them (`/vulyk-build` refusing the fallback, `/vulyk-resume` relaunching), not mined from transcripts. `vulyk-cycle.js` is not touched.
- **A9 - `stage_long` covers closed stages only** (consecutive journal lines). The still-open last stage is not measured in v1 - it would re-fire on every scan until the stage closes.
- **A10 - installer question rule (ask 6; terminal access resolved by scout).** Precedence, first match wins: (1) `--check` never asks and never writes the row; (2) `--telemetry on|off` flag, else `VULYK_TELEMETRY=on|off` env, sets the row without asking; (3) `--telemetry ask` / `VULYK_TELEMETRY=ask` asks even when the row already holds an explicit value; (4) on upgrade, a row already `on` or `off` is left as is, no question; (5) the row is missing (fresh install, or an old hive): when a terminal is reachable the explanation and one `Enable telemetry? [y/N]` question are printed, empty/EOF/anything but `y`/`yes` = `off`; when no terminal is reachable (CI, pipes, non-interactive `vulyk-update.sh`) no prompt, row = `off`. **Terminal access:** `install.sh` never reads stdin today - its only `read` calls are pipeline loops over `find`/`ls` output (lines 70, 256, 503, 520) - so the prompt reads from `/dev/tty`, guarded by `[ -t 0 ] || [ -r /dev/tty ]`, never from a stdin those pipelines consume. `vulyk-update.sh:76` runs `install.sh --upgrade` as a plain foreground call with inherited stdin, so it needs no stdin plumbing - only the `--telemetry` flag / env passed through. Bootstrap shows the value and how to change it (`install.sh --telemetry ask`), asking nothing.
- **A11 - `telemetry/` never ships to hives (resolved by scout).** `copy_tree` (install.sh:491) runs only over `.claude memory bootstrap templates scripts docs/wiki docs/specs docs/adr`; a top-level `telemetry/` is never copied. That is the desired behaviour - the inbox lives in the VULYK repo only - so story 05 adds no exclusion for it. `memory/stats/anomalies.jsonl` IS under a copied tree and needs the runtime exclusion in `shippable()`.
- **A12 - agent token in rows (resolved by scout).** A subagent's `.meta.json` carries `agentType` and `name` (e.g. `worker-01-core`), plus `model`, `taskKind`, `spawnDepth`, `teamName`, `description`, `color`, `planModeRequired`, `permissionMode`. Rows for `agent_prefix_high` / `agent_empty` carry an `agent` token = `agentType` when it is one of the framework's agent names (basenames of `.claude/agents/*.md`), else `other`; every other code carries `""`. A free-form `name` never enters a row.
- **A13 - hook wiring on upgrade (resolved by scout).** `install.sh` `wire_session_hook` (:279-356) knows only the `SessionStart` group; nothing wires Stop or SessionEnd into an existing hive's `settings.json`. Story 05 generalises it (`wire_hook <event> <script>`, idempotent) and wires `anomaly-scan.sh` on Stop and SessionEnd; story 02 edits VULYK's own `settings.json` only.
- **A14 - PR recipe shape (round-1 fix, needs owner nod).** The cross-machine path assumes the sender has no push right on the public repo, so the recipe starts with `gh repo fork <slug> --clone` into a fixed relative directory and opens the PR from the fork with `gh pr create --repo <slug> --head <branch>`. Rejected: `git clone` of the upstream + push - fails for everyone but maintainers. The worker confirms the `gh` flags with `gh repo fork --help` locally; if `--clone` cannot take a directory, a `git clone` of the fork URL follows it.
- **A15 - default week (round-1 fix, needs owner nod).** `bundle`/`publish` without `--week` process the previous ISO week and the current one, one file and one inbox path each, skipping a week with no rows. Rationale: `/vulyk-evolve` counts a rolling 7 days, so a Monday run bundling only the current week silently dropped six days (opus seat, UNASKED 1). Rejected: a "last published" marker file - a ledger with no precedent on the stats shelf; a re-sent week lands on the same `<week>/<hive>.jsonl` path, so idempotence comes from the layout.

## Stories

**Wave 1**
- `anomaly-telemetry-01-tracer-script` (opus, tracer) - `scripts/telemetry.sh` with the enum, both row schemas, `record`/`bundle`/`check`/`consent`/`publish`, `is_paperwork_path` entry, `## Commands` row, `tests/telemetry.test.sh`.

**Wave 2** (all blocked by 01; disjoint files)
- `anomaly-telemetry-02-detectors-and-hook` (sonnet) - `scan` verb, the five detectors, `.claude/hooks/anomaly-scan.sh` on Stop + SessionEnd in VULYK's own `settings.json`, `handoff.py measure`, detector tests.
- `anomaly-telemetry-03-evolve-step-and-driver-events` (sonnet) - the weekly step in `/vulyk-evolve`; `driver_refused`/`driver_relaunched` record calls in `/vulyk-build` and `/vulyk-resume`.
- `anomaly-telemetry-04-public-docs-and-ci` (sonnet) - README section, `docs/telemetry.md`, CHANGELOG lines, `telemetry/inbox/README.md` replacing the placeholder `.gitkeep`, one CI job validating inbox bundles.

**Wave 3**
- `anomaly-telemetry-05-consent-profile-install` (opus) - `Telemetry` Profile row in `CLAUDE.md`, the installer's `/dev/tty` explanation + question on fresh install and upgrade (A10), `wire_hook` for Stop/SessionEnd on upgrade (A13), `vulyk-update.sh` flag pass-through, bootstrap shows the value, `shippable()` exclusion for the log, CI install-smoke cases, local tests.

**Wave 4** (council round 1 fixes - one story per RED ask; blocked by 01, 03, 04)
- `anomaly-telemetry-06-publish-pr-recipe` (opus; ask 2) - the cross-machine recipe becomes fork/branch/add/commit/push/`gh pr create` (A14), both recipes and `check`'s prefix survive spaces, `#`, `&` (review finding 14), default week covers previous + current (A15), `docs/telemetry.md` recipe corrected, suite cases for all three. Opus, not sonnet: the original `publish` was an opus story that the court failed, and a third round costs more than the rung.

## Contracts

### Anomaly code enum (v1, fixed - `telemetry.sh enum` prints it one per line)
| code | detector | value | threshold |
|---|---|---|---|
| `context_high` | main-thread context size (`context_tokens()`) above threshold | tokens | tokens |
| `agent_prefix_high` | a subagent's first-turn `input + cache_creation_input_tokens` above threshold | tokens | tokens |
| `agent_empty` | a subagent transcript whose last assistant entry has no text block (cap death / empty return) | assistant entries | 0 |
| `council_rounds_high` | max `round` per spec in `council.jsonl` at or above threshold | rounds | rounds |
| `stage_long` | gap between two consecutive `journal.md` lines above threshold | hours (integer) | hours |
| `driver_refused` | `/vulyk-build` refused (no `Workflow`, no `--fallback`; by-name call threw) | 1 | 0 |
| `driver_relaunched` | `/vulyk-resume` relaunched the driver fresh | 1 | 0 |
| `scope_breach` | a `scope.jsonl` row with non-empty `out_of_scope` | out-of-scope path count | 0 |

### Agent token set (A12) - `telemetry.sh agents` prints it
The basenames of `.claude/agents/*.md` without extension (today: `council-haiku council-opus council-sonnet cycle-clerk drone-coverage drone-docs drone-scout lead-architect lead-review librarian queen-planner worker-code worker-test`), plus `other`, plus the empty string for rows that are not about an agent. Resolved at runtime from the hive's own `.claude/agents/`; `check` in the VULYK repo resolves it from the repo's `.claude/agents/`.

### Local row - `memory/stats/anomalies.jsonl`, one JSON object per line, exactly these 12 keys, this order (`jq -c`)
`{"v":1,"ts":"<UTC ISO-8601>","code":"<enum>","value":<number>,"threshold":<number>,"vulyk":"<semver>","tier":<0-4>,"model":"<fable|opus|sonnet|haiku|"">","agent":"<agent token|other|"">","spec":"<slug|"">","story":"<slug-NN|"">","ref":"<opaque dedupe id|"">"}`
No `note`, no free text. `ref` is the idempotency key: `record` appends nothing when a row with the same `code` and a non-empty equal `ref` already exists. Suggested refs: `session:<transcript basename>`, `agent:<jsonl basename>`, `council:<spec>`, `stage:<spec>:<journal line no>`, `scope:<ts>:<story>`.

### Bundle row - `telemetry/inbox/<ISO week>/<hive>.jsonl`, exactly these 10 keys, this order
`{"v":1,"code":"<enum>","value":<number>,"threshold":<number>,"vulyk":"<semver>","tier":<0-4>,"model":"<fable|opus|sonnet|haiku|"">","agent":"<agent token|other|"">","week":"<YYYY-Www>","hive":"<12 hex>"}`
`week` = ISO week of `ts` (`date -u +%G-W%V`); `hive` = first 12 hex of sha256 of the repo toplevel path. `ts`, `spec`, `story`, `ref` are dropped. `check` rejects: a non-object line, a key set other than these 10, a `code` outside the enum, non-numeric `value`/`threshold`, `tier` outside 0-4, `model` outside the set, `agent` outside the agent token set, `week` not `^\d{4}-W\d{2}$`, `hive` not `^[0-9a-f]{12}$`, `vulyk` not `^\d+\.\d+\.\d+`, and any string value containing `/`, `\`, `@` or whitespace.

### `scripts/telemetry.sh` verbs (bash, `set -u`, sources `lib.sh`; repo root = `VULYK_HIVE` env else `git rev-parse --show-toplevel`)
- `enum` - prints the codes. `agents` - prints the agent token set. `consent` - prints `on` or `off` from the root `CLAUDE.md` Profile row `| Telemetry | <on|off>... |` (backticks tolerated, first token wins, missing row = `off`).
- `record <code> <value> <threshold> [--spec s] [--story id] [--ref r] [--model alias] [--tier n] [--agent token]` - appends a local row (`mkdir -p memory/stats`), dedupes on (code, ref), maps an `--agent` outside the set to `other`, unknown code = exit 1 on stderr, otherwise exit 0 and silent.
- `scan [--transcript <path>]` - runs every detector, calls `record`; exit 0 always, silent; `VULYK_TELEMETRY_SCAN=0` makes it a no-op.
- `bundle [--week YYYY-Www] [--out <file>]` - bundle rows of that week to stdout or `<file>`; **default (A15, story 06): the previous and the current ISO week**, each week emitted separately; empty output when no rows; exit 0.
- `check <file>...` - exit 0 when every line of every file passes; exit 1 with `<file>:<line>: <reason>` per failure on stderr; the prefix survives `#`, `&` and spaces in `<file>` (story 06).
- `publish [--week YYYY-Www] [--dry-run]` - consent `off`: prints `telemetry: off (Profile row Telemetry) - nothing to send`, exit 0. Consent `on`: for each week in scope (A15) writes the bundle to `.vulyk/telemetry/<week>-<hive>.jsonl`, runs `check` on it, then (A1) copies it to `<repo>/telemetry/inbox/<week>/<hive>.jsonl` and prints the commit command, or prints the PR recipe. **PR recipe (A14, story 06), nine lines in one fenced block:** `gh repo fork <slug> --clone <dir>` · `cd <dir>` · `git switch -c telemetry/<week>-<hive>` · `mkdir -p telemetry/inbox/<week>` · `cp '<bundle>' telemetry/inbox/<week>/<hive>.jsonl` · `git add telemetry/inbox/<week>/<hive>.jsonl` · `git commit -m "telemetry(<week>): <hive>"` · `git push -u origin telemetry/<week>-<hive>` · `gh pr create --repo <slug> --head telemetry/<week>-<hive> --title "telemetry(<week>): <hive>" --body "<one sentence, no paths>"`. Every path in either recipe is quoted. The script never executes `git push`, `git commit`, `git clone`, `gh repo fork` or `gh pr create`. `--dry-run` prints without copying.

### `handoff.py measure` (A7) - `python .claude/hooks/handoff.py measure <transcript.jsonl> [--sidechain]`
A new entry in `HOOK_MODES` and the `main()` chain; reads only. Prints one JSON object: `{"tokens":<newest context size>,"model":"<model id>","first_prefix":<first assistant input+cache_creation>,"assistant_turns":<n>,"last_has_text":<bool>,"agent_type":"<agentType from the sibling .meta.json or "">"}`. `--sidechain` counts entries with `isSidechain: true` (subagent files carry it on every entry). Exit 0; on an unreadable file prints `{}` and exit 0.

### Hook - `.claude/hooks/anomaly-scan.sh`
Wired on `Stop` and `SessionEnd`: in VULYK's own `.claude/settings.json` by story 02; into existing hives by `install.sh`'s `wire_hook` (story 05). Reads `.transcript_path` from stdin, runs `bash scripts/telemetry.sh scan --transcript <path>`; `set -uo pipefail`, early `exit 0` when jq, python or the script is missing; prints nothing.

### `install.sh` `wire_hook <event> <script-relative-path>` (A13)
Generalises `wire_session_hook`: ensures `settings.json` has the `<event>` group and a matcher-less entry whose `command` names the script, idempotent (a second call changes nothing), preserves every other entry byte-for-byte, reports under `--check` and writes nothing. `wire_session_hook` becomes `wire_hook SessionStart ...` or stays as a thin wrapper - the existing SessionStart behaviour and its CI cases must not change.

### Consent row - `CLAUDE.md` Profile table, after *Release / deploy*
`| Telemetry | off - anonymized weekly anomaly bundle (codes and numbers only, docs/telemetry.md); on = /vulyk-evolve prints the send command, never sends |`
The installer writes the same row with `on` or `off` as the first token of the value cell; `consent` reads only that token.

### Installer prompt - `install.sh [--telemetry on|off|ask]`, env `VULYK_TELEMETRY=on|off|ask`
Rule A10. Terminal test: `[ -t 0 ] || [ -r /dev/tty ]`; the question is read with `read -r ... < /dev/tty` (fallback to stdin only when stdin itself is the terminal), never from a stdin a pipeline may be consuming. The explanation (4-6 lines, plain stdout) states: anomalies are logged locally in `memory/stats/anomalies.jsonl`; a weekly bundle holds only codes from a fixed list (the enum names) and numbers, never paths, slugs, story names, emails or free text; it goes into the VULYK repo by a command `/vulyk-evolve` prints and you run; the default is off; see `docs/telemetry.md`. Then exactly one question: `Enable telemetry? [y/N]`. `vulyk-update.sh` forwards `--telemetry`/`VULYK_TELEMETRY` unchanged and does nothing about stdin (it is already inherited).

## Tradeoffs
- **Chosen:** one script with verbs + a step inside `/vulyk-evolve` + a committed log. The log follows the five existing stats files exactly (writer, whitelist, history in git), the weekly cadence is the cadence `/vulyk-evolve` already has, and the print-never-send rule is the ship rule reused. **Rejected:** a separate `/vulyk-telemetry` command - a second weekly ritual the owner would forget, and evolve already reads the same stats shelf for its diagnosis.
- **Rejected:** a gitignored per-machine log - needs new `shippable()` and `ensure_gitignore()` entries with no precedent, loses the anomaly history from the repo, and forces multi-worktree hives to merge logs by hand.
- **Rejected:** automatic push or a scheduler - forbidden by `vulyk-ship.md:11` and the brief's own "print the command" answer.
- **Chosen for ask 6:** the question lives in `install.sh` (the one surface both fresh install and upgrade pass through) and reads `/dev/tty`, bootstrap only reports. **Rejected:** asking in both installer and bootstrap - two questions for one row, and the second one would silently overwrite an answer the owner already gave. **Rejected:** reading stdin - the installer's own pipelines consume it, and a piped `curl | bash` install would swallow the answer.
- **Chosen for A12:** an `agent` token from a closed set, validated by `check`, so a `cycle-clerk` at 55k tokens is distinguishable from a `worker-code` at 55k. **Rejected:** the free-form dispatch `name` - it is owner-chosen text and would leak story names.
- **Chosen for round 1 (story 06):** one story for the one RED ask, folding in the two review items that sit in the same function (`publish` quoting, default week) because the same worker holding `publish` fixes them at marginal cost. **Rejected:** a story per review finding - fourteen of the sixteen findings are GREEN-ask conditions or plan matters that the Queen routes separately (see Plan deltas); cutting them here would exceed the "one story per RED ask" instruction and re-open files story 06 must not touch.

## Integration gate
`git ls-files '*.sh' | xargs -n1 bash -n` · `python -m py_compile .claude/hooks/*.py` · `git ls-files '*.json' | xargs -n1 jq -e . > /dev/null` · `bash .claude/hooks/handoff.sh status` · `bash tests/telemetry.test.sh` · `bash tests/cycle.test.sh` · `bash tests/council.test.sh`; `bash scripts/wave-check.sh docs/specs/anomaly-telemetry` before each dispatch.

## Resolved recon (2026-09-14, drone-scout)
1. `handoff.py` entry point - resolved into A7 (`measure` mode in the `main()` chain).
2. Subagent `.meta.json` fields - resolved into A12 (`agentType` token, closed set).
3. Hook wiring on upgrade - resolved into A13 (`wire_hook`, story 05).
4. `shippable()` and `telemetry/` - resolved into A11 (never copied; only the log needs an exclusion).
5. `install.sh` stdin and `vulyk-update.sh` exec - resolved into A10 (`/dev/tty` prompt; flag pass-through only). No open questions remain.

## Descoped

*(empty)*

## Plan deltas

- **2026-09-15, council round 1 (RED, `red: [2]`, review BLOCK).** Story 06 cut for ask 2 (opus seat: the cross-machine recipe prints `cp` + `gh pr create` with no fork, branch, add, commit or push, so no PR can result). Folded into it: review finding 14 (recipe/`check` quoting) and opus UNASKED (1) (Monday runs drop the previous week) - same function, same worker. Assumptions A14 and A15 need the owner's nod before dispatch.
- **Not cut here - the Queen decides routing.** All six asks judged GREEN by lead-review's own list except as above, but the BLOCK verdict carries conditions on GREEN asks and on the plan: finding 1 (subagent path in `scan`, `tests` case 10 - ask 1, story 02's files), 2 (evolve awk off-by-one - `vulyk-evolve.md`, story 03's file), 3 (env var names on `docs/telemetry.md:210-217` - story 04's file; **overlaps story 06's `## Files`, so it cannot run in wave 4 concurrently - sequence it after 06 or hand it to 06's worker as a one-line extra**), 4 (inbox read-and-clear step: nobody implements it; either a story or a docs correction plus a `## Descoped` line), 5 (Stop-hook scan cost, 31 s), 6 (`agent_empty` on a live transcript), 7 (who commits the hook-written log - `cycle.sh` verb or `ship-check` pass-through), 8-9, 10 (`install.sh` silent drop of the answer), 11 (ADR-005 amendment), 12-13 (paperwork claims), 15-16 (`spec_tier` slug validation; `measure` consumes stdin). Findings 1, 5, 6, 7 change behaviour the seats judged GREEN and are plan-level: recommend one follow-up planner call after the owner picks which conditions gate this ship and which move to a next spec.

**Approved:** Andrei, 2026-09-14
**Briefed:** <written by scripts/cycle.sh briefed - stage 01+02 on the straight-through path (--go, Tier 1): "via grill, <owner>, <date>" (or "via grill (assumed)" / "via mini-brief"). Alternative to **Approved:** above.>
**Branch:** vulyk/anomaly-telemetry
**Checked:** <written by scripts/human-check.sh after the owner has looked - stage 05, and the override for stage 04+05. /vulyk-ship refuses without either this or a GREEN **Council:** line.>
**Council:** RED round 1, 2026-09-15, at 1a91924, pack 9b30072f04a4 - red: 2
**Shipped:** <written by scripts/ship-check.sh --record - stage 06: the published version, and where>
