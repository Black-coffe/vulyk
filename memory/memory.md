# Hive memory index

<!-- Pointer index: <= 60 lines, always loaded. Pointers are hints - verify against code before acting.
     Maintained by drone-docs (pointers) and librarian (hygiene). Humans welcome too. -->

## Codebase map
<!-- one line per mapped module, added by /vulyk-bootstrap and /vulyk-map -->
- `scripts/` (every gate/helper script, entry points, exit codes, callers): memory/map/scripts.md
- the cycle state contract as `cycle.sh` implements it (files, verbs, verdict rule, staleness,
  seat/court contracts, both drivers): memory/map/cycle.md
- every `.claude/agents/*.md` and `.claude/commands/vulyk-*.md` (model, tools, report
  contract, what each command runs/never does): memory/map/agents-and-commands.md

## Unmapped territory
- `docs/` narrative pages (architecture.md, pipeline.md, cycle.md, token-economy.md,
  model-cascade.md, command-reference.md, getting-started.md) and `docs/adr/` beyond ADR-001
- `templates/`, `bootstrap/interview.md`, `.claude/hooks/`, `install.sh`, `scripts/vulyk-update.sh`'s
  own upgrade mechanics, `tests/` harness internals beyond what council.test.sh/cycle.test.sh
  cover, `.github/workflows/ci.yml` beyond the two test jobs

## Wiki domains
<!-- load-bearing domain notes in docs/wiki/ -->
- (none yet)

## Verification
<!-- the real ## Commands rows from CLAUDE.md - VULYK's own repo, no compiler, no test runner -->
- Shell syntax, all scripts: `git ls-files '*.sh' | xargs -n1 bash -n`
- Python syntax, hooks: `python -m py_compile .claude/hooks/*.py`
- JSON validity: `git ls-files '*.json' | xargs -n1 jq -e . > /dev/null`
- Hook self-diagnosis: `bash .claude/hooks/handoff.sh status`
- Scope gate, per story: `bash scripts/scope-check.sh <story-file>`
- Story gate, per spec: `bash scripts/wave-check.sh docs/specs/<slug>`
- Ship gate, per spec: `bash scripts/ship-check.sh docs/specs/<slug>`
- Cycle status, per spec: `bash scripts/cycle.sh status docs/specs/<slug> --json`
- Cycle state contract tests: `bash tests/cycle.test.sh`
- Council verdict contract tests: `bash tests/council.test.sh`
- Full suite / build: none exists - VULYK has no test runner and no build step

## Learnings
- Consolidated: memory/learnings/CONSOLIDATED.md (run /vulyk-gc to refresh)
- Human gates rework (2026-09-12): memory/learnings/2026-09-12-human-gates-rework.md — один стоп в начале, дальше агентный совет; «owner looks» как обязательную стадию не возвращать
- Autonomous cycle / council (v0.12.0, 2026-09-13): docs/specs/autonomous-cycle/ — mechanics in docs/adr/001-cycle-state-contract.md (ADR-001), per-spec state in docs/specs/<slug>/journal.md
