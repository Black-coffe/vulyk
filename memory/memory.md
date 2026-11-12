# Hive memory index

<!-- Pointer index: <= 60 lines, always loaded. Pointers are hints - verify against code before acting.
     Maintained by drone-docs (pointers) and librarian (hygiene). Humans welcome too. -->

## Codebase map
<!-- one line per mapped module, added by /vulyk-bootstrap and /vulyk-map -->
- `scripts/` cycle scripts (cycle.sh, lib.sh helpers, ship/acceptance gates, `hives-behind.sh`): memory/map/scripts.md
- `scripts/` check scripts and tests (wave/prompt/portability/defects checks, symbol-map, trace-autopsy, full-suite): memory/map/scripts-checks.md
- `.claude/hooks/` (SessionStart brief, `git-guard.sh`, update check, handoff) and `redact.sh`/`telemetry.sh`: memory/map/scripts-hooks.md
- `install.sh` upgrade contract and `vulyk-update.sh`: memory/map/scripts-install.md
- the cycle state contract as `cycle.sh` implements it (files, verbs, `advance`, verdict rule,
  staleness, seat/court contracts, repair, the Workflow driver): memory/map/cycle.md
- every `.claude/agents/*.md` (incl. `drone-horizon`) and `.claude/commands/vulyk-*.md` (model, tools,
  report contract, what each command runs/never does): memory/map/agents-and-commands.md
- the VULYK pulse mod (`.claude/mods/vulyk-pulse/`, marketplace `.claude-plugin/marketplace.json`,
  installed by `install.sh`; no map slice): docs/pulse.md (the watcher mod is retired; `install.sh` `retire_mod` removes it)

## Unmapped territory
- `docs/` narrative pages (architecture.md, pipeline.md, cycle.md, token-economy.md, model-cascade.md, command-reference.md, getting-started.md) and `docs/adr/` beyond ADR-001
- `templates/`, `bootstrap/interview.md`, `.claude/hooks/` (bar scripts-hooks.md and the defect hooks/`defects_lib.py` in the wiki), `install.sh` (contract: scripts-install.md),
  `vulyk-update.sh` mechanics, `tests/` internals beyond full-suite.sh and `--part` (scripts-checks.md), `ci.yml` beyond the `full-suite`/`install-smoke` macOS matrix and `shell` job

## Wiki domains
<!-- load-bearing domain notes in docs/wiki/ -->
- the defect library as the rules tree (cards, Never/Allowed/How-to, scope, one parser, delivery, capture, gate): docs/wiki/rules-tree.md (ADR-021)

## Verification
<!-- the real ## Commands rows from CLAUDE.md - VULYK's own repo, no compiler, no test runner -->
- Shell syntax, all scripts: `git ls-files '*.sh' | xargs -n1 bash -n`
- Python syntax, hooks: `bash scripts/py.sh -m py_compile .claude/hooks/*.py`
- Portability (bash 3.2 / BSD / no bare python; card shell-needs-gnu-or-bash4): `bash scripts/portability-check.sh [<file>...]`
- JSON validity: `git ls-files '*.json' | xargs -n1 jq -e . > /dev/null`
- Hook self-diagnosis: `bash .claude/hooks/handoff.sh status`
- Scope gate, per story: `bash scripts/scope-check.sh <story-file>`
- Story gate, per spec: `bash scripts/wave-check.sh docs/specs/<slug>`
- Ship gate, per spec: `bash scripts/ship-check.sh docs/specs/<slug>`
- Prompt drift (agents/commands/templates vs scripts, no model): `bash scripts/prompt-check.sh [--touched <path>...]`
- Cycle status, per spec: `bash scripts/cycle.sh status docs/specs/<slug> --json`
- Token report, per spec: `python scripts/token-report.py . --spec <slug>`
- Maintenance: `bash tests/maintenance.test.sh`
- Pulse mod / symbol map: `bash tests/mods.test.sh`, `bash tests/symbol-map.test.sh`
- Cycle state contract tests, per part: `bash tests/cycle.test.sh --part <topic>` (`--list-parts`); council and telemetry alike
- Driver contract / end to end / runner: `bash tests/driver.test.sh`, `bash tests/e2e.test.sh`, `bash tests/full-suite.test.sh`
- Full suite (round-only; capped parts, 300 s each, `--steps`/`--step K`): `bash tests/full-suite.sh`; the round runs it via `cycle.sh suite`; no build step

## Learnings
- Model ladder and no Haiku below generation 5 (v0.13.0, 2026-09-14): docs/adr/007-model-ladder.md
- Deliverable before tier, plan stops for approval (v0.13.0, 2026-09-14): docs/adr/008-approval-stop-and-study-work.md
- Red receipt (v0.40.0, 2026-10-28): docs/adr/025-red-receipt.md - `red: required` stories close only after `cycle.sh stamp-red` proves the sealed test red for `red_reason`
- Horizon step (ADR-022, v0.35.0): `/vulyk-plan` step 3a on new ground, three `drone-horizon` lenses, kept ideas in `horizon.md`, never in `brief.md`
- Fast story checks, one full suite per round (ADR-023): stories verify with targeted commands; the `round-only` full-suite row runs once per round (since ADR-029 via `cycle.sh suite` into `suite.log`, not in `lead-review`)
- No reliance on background commands in subagents (ADR-024): run suite and checks in the foreground with a `timeout`
- Anomaly telemetry, opt-in (v0.14.0): docs/telemetry.md - `scripts/telemetry.sh`, `anomaly-scan.sh` (SessionEnd); `publish` only prints a copy recipe
- Driver hardening (v0.15.0): docs/adr/011-driver-hardening.md - clerk retry, self-marked `done`, taint = story file
- Sonnet executes, Opus judges (v0.20.0, 2026-09-28): docs/adr/015-sonnet-execution-rung-and-model-floor.md - workers/scouts/drone-docs on `sonnet`, repair stories `opus`
- Auto-maintenance (v0.21.0, 2026-09-29): docs/specs/auto-maintenance/plan.md, docs/self-evolution.md - SessionStart brief runs gc/evolve/map when due, `scripts/evolve-ledger.py`, `tests/maintenance.test.sh` caps
- Convergent judge (v0.17.0, 2026-09-24): docs/specs/convergent-judge/ + ADR-001 D3/D4 amendments - tier ceiling on RED rounds, no-progress, anchored BLOCK
- Light VULYK (v0.18.0, 2026-09-27): docs/adr/013-light-vulyk.md + docs/specs/token-audit/ - single agent below Tier 3, advance verb, converging council, token-report
- Autonomous cycle / council (v0.12.0): docs/specs/autonomous-cycle/, docs/adr/001-cycle-state-contract.md; human gates rework (2026-09-12) in memory/learnings/CONSOLIDATED.md entries 1-4 (run /vulyk-gc to refresh)
