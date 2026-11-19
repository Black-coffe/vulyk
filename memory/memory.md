# Hive memory index

<!-- Pointer index: <= 60 lines. Not auto-loaded (nothing imports it): the SessionStart brief points the Queen here and
     it is read at task start. Pointers are hints - verify against code before acting.
     Maintained by drone-docs (pointers) and librarian (hygiene). -->

## Codebase map
<!-- one line per mapped module, added by /vulyk-bootstrap and /vulyk-map -->
- `scripts/` cycle scripts (cycle.sh, lib.sh, ship/acceptance gates): memory/map/scripts.md; checks and tests
  (wave/prompt/portability/defects checks, symbol-map, full-suite): memory/map/scripts-checks.md
- `.claude/hooks/` (SessionStart brief, update check, handoff), `redact.sh`/`telemetry.sh`: memory/map/scripts-hooks.md
- `install.sh` upgrade contract, `vulyk-update.sh`: memory/map/scripts-install.md; PreToolUse guards (`git-guard.sh`,
  `owner-guard.sh`, `court-guard.sh`): memory/map/scripts-guards.md; `hives-behind.sh`: memory/map/scripts-hives.md
- the cycle state contract in `cycle.sh`: memory/map/cycle.md (files, verbs), cycle-state.md (run state, `advance`,
  verdict), cycle-repair.md, cycle-close.md (close-story gates), cycle-suite.md (suite gate, Workflow driver)
- `.claude/agents/*.md`: memory/map/agents-and-commands.md; `.claude/commands/vulyk-*.md`: memory/map/commands.md
  (plan, build, review), memory/map/commands-ship.md (ship, update, rest)
- the pulse mod (`.claude/mods/vulyk-pulse/`, `.claude-plugin/marketplace.json`; no map slice): docs/pulse.md

## Unmapped territory
- `docs/` narrative pages and `docs/adr/` beyond ADR-001; `templates/`, `bootstrap/interview.md`; `.claude/hooks/` bar
  scripts-hooks.md and the defect hooks (wiki); `tests/` internals beyond full-suite.sh; `ci.yml` beyond its jobs

## Wiki domains
<!-- load-bearing domain notes in docs/wiki/ -->
- the defect library as the rules tree (cards, scope, one parser, delivery, gate): docs/wiki/rules-tree.md (ADR-021)

## Verification
<!-- the real ## Commands rows from CLAUDE.md - VULYK's own repo, no compiler, no test runner -->
- Syntax: `git ls-files '*.sh' | xargs -n1 bash -n`; `bash scripts/py.sh -m py_compile .claude/hooks/*.py`;
  `git ls-files '*.json' | xargs -n1 jq -e . > /dev/null`
- Portability (card shell-needs-gnu-or-bash4): `bash scripts/portability-check.sh [<file>...]`
- Hook self-diagnosis: `bash .claude/hooks/handoff.sh status`
- Gates: `bash scripts/scope-check.sh <story-file>`; `bash scripts/wave-check.sh docs/specs/<slug>`;
  `bash scripts/ship-check.sh docs/specs/<slug>`; `bash scripts/prompt-check.sh [--touched <path>...]`
- Cycle status: `bash scripts/cycle.sh status docs/specs/<slug> --json`;
  tokens: `python scripts/token-report.py . --spec <slug>`
- Tests: `bash tests/<suite>.test.sh [--part <topic>]` (`--list-parts`): maintenance, mods, symbol-map, cycle, council,
  telemetry, driver, e2e, full-suite
- Full suite (round-only; capped parts, 300 s each, `--steps`/`--step K`): `bash tests/full-suite.sh`, run by
  `cycle.sh suite`; no build step

## Learnings
- Model ladder, no Haiku below generation 5: docs/adr/007-model-ladder.md; Sonnet executes, Opus judges:
  docs/adr/015-sonnet-execution-rung-and-model-floor.md
- Deliverable before tier, plan stops for approval: docs/adr/008-approval-stop-and-study-work.md
- Red receipt: docs/adr/025-red-receipt.md - `red: required` stories close only after `cycle.sh stamp-red`
- Horizon step (ADR-022): `/vulyk-plan` step 3a, `drone-horizon` lenses, ideas in `horizon.md`, never `brief.md`
- One full suite per round (ADR-023, ADR-029: `cycle.sh suite` into `suite.log`); stories verify with targeted commands
- No background commands in subagents (ADR-024): run suite and checks in the foreground with a `timeout`
- Anomaly telemetry, opt-in: docs/telemetry.md (`scripts/telemetry.sh`, `anomaly-scan.sh`)
- Driver hardening: docs/adr/011-driver-hardening.md; Light VULYK: docs/adr/013-light-vulyk.md
- Auto-maintenance: docs/specs/auto-maintenance/plan.md, docs/self-evolution.md (SessionStart brief runs gc/evolve/map)
- Convergent judge: docs/specs/convergent-judge/ + ADR-001 D3/D4 amendments
- Autonomous cycle: docs/specs/autonomous-cycle/, docs/adr/001-cycle-state-contract.md; human gates rework in
  memory/learnings/CONSOLIDATED.md (run /vulyk-gc to refresh)
