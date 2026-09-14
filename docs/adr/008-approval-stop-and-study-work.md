# ADR-008: The plan stops for approval, and a document is a deliverable

- Status: accepted (2026-09-14, owner: Andrei)
- Date: 2026-09-14
- Spec: docs/specs/lean-cascade (v0.13.0)

## Context

The owner, 2026-09-14, on running v0.12.0 on other hives (`docs/specs/lean-cascade/brief.md`):

> очень долго делает несложные задачи … нужно было провалидировать и промониторить … проект …
> Он вместо того, чтобы промониторить и мне спеку сделать как план, он пошёл и начал писать
> скрипты, и сожрал у меня просто огромное количество лимитов подписочных.

Read against the framework's own text, the complaint is a design, not a bug:

- `/vulyk-plan` step 10 (v0.12): "Proceed straight into the build - no further prompt, no
  summary to approve." The approval stop existed only as an opt-out inside the grill's fixed
  last question; in no-question mode (`claude -p`) every answer was assumed and the build
  started with no human in the loop at all.
- The routing matrix had one pipeline and it ended in code. A request whose result is a
  report, an audit, a monitoring answer or "make me a spec" had no row: it was cut into
  stories and dispatched to workers, because that was the only thing the matrix knew to do.
- Recon before the grill dispatched up to four scouts at every tier, then `queen-planner`,
  `lead-architect` and `drone-coverage` - up to seven agents before the first line of code.
- The fallback driver (no Workflow tool) stepped the whole build -> council -> repair loop
  inside the pinned top-model session, and `/vulyk-build` selected it silently.

ADR-002 already records the owner's earlier ask in the same direction ("покрасить кнопку …
1-2 сабагента, а не 10"); v0.12 answered it by shrinking seats per tier and left the
auto-launch in place. This ADR removes the auto-launch.

## Decision

1. **Deliverable before tier.** `/vulyk-plan` step 0 decides whether the owner gets back
   *changed code* or *a document*. Study work - validate, audit, monitor, assess, research,
   "make me a plan/spec", or `--study` - writes `brief.md` and `report.md` (findings with
   evidence, options recommended-first, candidate stories as a list) and stops. No story
   file, no worker, no council. `state.sh` shows such a spec as `study`. When both readings
   are possible the Queen asks one question and never guesses "code".
2. **The approval stop is the default.** After the stories and the deterministic checks,
   `/vulyk-plan` shows the plan (tier, stories by wave with their models, assumptions, agent
   count) and waits for one word; `**Approved:**` closes stage 02. Straight-through is the
   opt-in: `--go`, or the owner asking for it on the grill's last question. Tier 1 stays
   straight-through (`--mode mini-brief`) - one story, one seat, nothing to read.
   No-question mode cannot approve: it writes the plan and stops unless `--go` was given.
3. **Recon is capped by tier**: 1 scout at Tier 1 (only if the location is unknown) and
   Tier 2, 2 at Tier 3, 4 at Tier 4. `drone-coverage` runs at Tier 3-4 only.
4. **The fallback driver needs `--fallback`.** Without it `/vulyk-build` stops and says
   why in one sentence.
5. **One suite run per close.** The worker runs the verification before returning;
   `close-story` runs it as the record. `lead-review` re-runs only what the diff makes
   suspicious; the seats keep their own contracts (`council-sonnet` still runs the suite
   once - it is the seat whose evidence *is* the run).

## Rejected

- **Keeping one-stop and adding a `--plan-only` flag.** The default is what a new hive
  does on its first request; a flag nobody knows about does not change the OLX outcome.
  The v0.12 argument for one-stop (`docs/cycle.md`: ten `human.jsonl` rows, zero REJECTED)
  measured whether the owner *rejected* plans, not what the build spent when they had not
  read one.
- **A study tier (Tier S).** `cycle.sh tier_of` accepts 1-4 and sizes a court from it; a
  study never opens a court. A deliverable line beside the tier keeps the two questions
  apart and needs no change in the state machine.
- **Dropping the council at Tier 1.** ADR-002's invariant ("never to zero") holds; the
  Tier 1 seat is one Sonnet call.

## Consequences

- A Tier 2+ build costs one more turn of the owner's attention - reading the plan - and
  never starts on a plan they have not read. A study costs the brief, the capped recon and
  one report.
- The v0.12 statement "the one human stop autonomous mode keeps is the grill" is amended to
  "the grill, then the plan"; `docs/cycle.md`, `README.md`, `getting-started.md` and
  `command-reference.md` carry the amendment.

## Revisit when

`memory/stats/ship.jsonl` shows approvals arriving within the same minute as the plan for
a month running - the stop has become ceremony again, and `--go` can become the default
for that hive.
