---
story: beta-fixes-1113-03
spec: beta-fixes-1113
status: todo
returned:
tier: 3
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: agent_prefix_high skips an agent type VULYK does not dispatch
---

# Less noise in what the owner reads: own agents only, a quiet paperwork head, `--go` from the owner

## Goal
Three small changes. **Ask 4.** The `agent_prefix_high` detector in `scripts/telemetry.sh` (the scan over
subagent transcripts) records a row only when the agent type is one of VULYK's own: a member of the `AGENTS`
list the script already carries. A built-in type (`general-purpose`) or a hive's own agent is skipped, whatever
its prefix. If `docs/telemetry.md` describes the code, its line says so. **Ask 5.** `.claude/agents/lead-review.md`,
the sentence on a `suite.log` whose `head=` is not the reviewed head, gains the exception of plan.md `## Contracts`
T1: a difference of paperwork commits only is the round's own log and is not reported; any other path in the
difference keeps today's `## Minor`. **Ask 6.** `.claude/commands/vulyk-plan.md`, the straight-through `--go`
bullet, gains T2: `--go` only from the owner's own words, never added by the Queen. Both wordings are pinned by
a needle in `tests/maintenance.test.sh`.

## Requirements
> 4. `agent_prefix_high` counts only agents VULYK dispatches (its own agent types), not built-in ones such as `general-purpose`.
> 5. `lead-review` no longer reports a `suite.log` head that differs from the reviewed head only by paperwork commits.
> 6. `/vulyk-plan`: `--go` comes only from the owner's own words, never added by the Queen.

## Files
- scripts/telemetry.sh
- tests/telemetry.test.sh
- docs/telemetry.md
- .claude/agents/lead-review.md
- .claude/commands/vulyk-plan.md
- tests/maintenance.test.sh

## Non-goals
- Do not change the prefix threshold, the other anomaly codes, the `ENUM` / `AGENTS` lists or how any other
  detector treats agent types; one membership test in one detector.
- Do not read `.claude/agents/*.md` from the scan: the set is the script's own list (plan.md `## Assumptions`).
- `lead-review.md`: extend the existing sentence, keep its words (a test elsewhere may pin them); no change to
  the suite line, the BLOCK rule or the five items. If a pin outside `## Files` cannot stay green, return
  `NEEDS_CONTEXT` naming the test.
- `vulyk-plan.md`: the `--go` bullet only; no change to `cycle.sh briefed --go` or to `/vulyk-build`.
- Edit `tests/telemetry.test.sh` only in part `scan`; in `tests/maintenance.test.sh` add the two pins, nothing else.
- Fixture transcripts use stand-ins (`acme-writer`, `Acme`); no hive transcript, slug or path.

## Map slice
`memory/map/scripts-hooks.md` → Entry points (`telemetry.sh`: `scan`, `AGENTS`, `RETIRED_AGENTS`);
`memory/map/agents-and-commands.md` → lead-review (Suite line), `/vulyk-plan` (approval stop, `--go`);
`memory/map/scripts-checks.md` → `prompt-check.sh` (`AGENTS` vs agent files), Tests (`maintenance.test.sh`).

## Acceptance criteria
- [ ] `--part scan`, the original case: a fixture window with a `general-purpose` subagent transcript over the
  prefix threshold and a `worker-code` one over it: the scan records `agent_prefix_high` for `worker-code` only.
  The failing label contains `agent_prefix_high skips an agent type VULYK does not dispatch`.
- [ ] `--part scan`, neighbour: a type that is no VULYK agent but looks like one (`acme-writer`) is skipped too;
  a window with only skipped types records no `agent_prefix_high` row; the existing scan cases pass unchanged.
- [ ] `tests/maintenance.test.sh` fails when `lead-review.md` lacks `only by paperwork commits` and when
  `vulyk-plan.md` lacks `only from the owner's own words`; both pins fail on HEAD before the edits.
- [ ] `lead-review.md` still tells the reviewer to report, under `## Minor`, a log whose head differs by any
  path outside the spec's `plan.md`, `journal.md`, `brief.md`, `council/`, and names the one command that shows it.
- [ ] `bash scripts/portability-check.sh scripts/telemetry.sh .claude/agents/lead-review.md
  .claude/commands/vulyk-plan.md` and `bash scripts/prompt-check.sh --touched <the three prompt and script
  paths>` are clean.
- [ ] `## Implementation notes` ends with three `CHANGELOG:` lines, one per ask.

## Verification
`bash tests/telemetry.test.sh --part scan`
`bash tests/maintenance.test.sh`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each -->

## Findings
