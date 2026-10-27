---
story: fable-fallback-02
spec: fable-fallback
status: todo
returned:
tier: 3
worker: worker-code
wave: 1
blocked_by: []
---

# The fallback is recorded: telemetry code, the three commands' redispatch rule, and the reviewer's one-hour cache

## Goal
After this story a Fable-limit fallback leaves three traces. `scripts/telemetry.sh` knows the code `fable_limit_fallback` (append to `ENUM`, a `docs/telemetry.md` row, a `record` case in the test). The three commands that dispatch judges, planner and architect carry the same rule in prose: on the refusal text, redispatch that role once on `opus`, write the journal line, run `telemetry.sh record fable_limit_fallback`, tell the owner in one sentence, and go on; a second refusal stops as today. `/vulyk-build`'s Workflow section does the same for every entry of the driver's returned `fallbacks` (story 01's contract). Separately, `lead-review.md`'s frontmatter gets `experimental:` / `  cacheTtl: 1h`, the only agent that does.

## Requirements
> 1. Когда у судьи, планировщика или архитектора кончается Fable, роль один раз перезапускается на Opus: строка в журнал, код телеметрии, одна строка мне; сборка не встаёт.
> 3. Кэш на 1 час только у ревьюера; через неделю замер расхода и решение, распространять ли.

## Files
- scripts/telemetry.sh
- docs/telemetry.md
- tests/telemetry.test.sh
- .claude/commands/vulyk-build.md
- .claude/commands/vulyk-review.md
- .claude/commands/vulyk-plan.md
- .claude/agents/lead-review.md

## Non-goals
- No `scan` detector for the refusal in transcripts: the code is written by `record` from the command that saw the refusal, nothing else.
- No `cacheTtl` on any other agent file, and no other frontmatter key of `lead-review.md` changes (`model`, `effort`, `maxTurns`, tools stay). Do not touch its suite step: story 03 owns the body.
- No edit to `.claude/workflows/vulyk-cycle.js`, `scripts/cycle.sh`, `scripts/journal.sh` or `cycle-clerk.md`: the driver's `fallbacks` array arrives from story 01; the Queen writes the records with the scripts as they are.
- No new `scripts/` file, no retry of any error other than the Fable-limit text, no fallback family other than `opus`.
- Keep every command's `description:` inside `tests/maintenance.test.sh`'s `DESCRIPTIONS_MAX_BYTES`; the rule goes into the body, not the frontmatter.

## Map slice
- memory/map/scripts.md `## Key contracts` (`telemetry.sh` `ENUM`/`AGENTS` are append-only public contracts), `## Entry points` the `telemetry.sh` bullet
- memory/map/agents-and-commands.md `## Commands` the `/vulyk-build`, `/vulyk-review`, `/vulyk-plan` bullets; `## Agents` the `lead-review` bullet
- memory/map/cycle.md `## Seats by tier and the verdict` (a required seat ABSENT = ESCALATE `env`: the path a second refusal still takes)

## Acceptance criteria
- [ ] `bash scripts/telemetry.sh enum` lists `fable_limit_fallback`; a `record` of it produces a 12-key local row with `code=fable_limit_fallback`, `value=1`, `threshold=0`, `model=fable`, `agent=<the agent type>`, `ref=<slug>:<where>:<agent>`; a repeat with the same `code` and `ref` appends nothing; `bundle` + `check` accept a week holding it. The new test case fails against 0.38.0's `ENUM` (stated in `## Implementation notes`).
- [ ] `docs/telemetry.md`'s code table has the row, the "nine anomaly codes" count is corrected, and the row says who writes it (the commands, after a refused dispatch; never `scan`).
- [ ] `vulyk-build.md`: the solo `dispatch:review` step, the no-Workflow hive loop and the Workflow-return handling each say: refusal text (`You've reached your Fable limit` / `model_requires_usage_credits`) → one redispatch on `opus` with the same prompt → journal line `fallback: <agent> <where> <from> -> opus (Fable limit; ADR-015 exception)` through `scripts/journal.sh` as the launch line is written → `telemetry.sh record fable_limit_fallback` in the form the `driver_refused` call uses → one sentence to the owner; a second refusal is the existing stop. The Workflow section does this once per entry of the driver's returned `fallbacks`.
- [ ] `vulyk-review.md` carries the same rule for the seats it dispatches; `vulyk-plan.md` for `queen-planner` (Tier 3-4) and `lead-architect` (Tier 4).
- [ ] `lead-review.md` frontmatter ends with `experimental:` and `  cacheTtl: 1h`, parses as before (the agent still loads), and no other line of the file changed.

## Verification
`bash tests/telemetry.test.sh --part telemetry && bash tests/maintenance.test.sh`

## Implementation notes

## Findings
