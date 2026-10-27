---
story: fable-fallback-04
spec: fable-fallback
status: done
returned: DONE
tier: 3
worker: worker-code
wave: 2
blocked_by: [fable-fallback-01, fable-fallback-02]
---

# The gate's scope, the hive-judge rule and the fallback, in the docs and in top-model.sh's hint

## Goal
After this story a hive owner who runs `bash scripts/top-model.sh --help` (or `--explain`) reads in one line that the gate model is for the Tier 4 review, `lead-architect`, the Tier 4 planner and a missed story's retry, and that a hive's own judge script should ask `bash scripts/model-profile.sh --role seat` and pass `--effort` explicitly (the study's F1: a hive's scripts took the gate at `xhigh`). `docs/model-cascade.md` says the same in its gate section, and documents the Fable-limit fallback shipped by stories 01-02 (one redispatch on `opus`, the three records, the exception under `opus-builds`). ADR-015 gains one line recording that exception.

## Requirements
> 4. Модель ворот — только для Tier 4 и повтора истории; свой судья улья берёт семью судьи из профиля и явно задаёт усилие; это написано в документации и в подсказке top-model.sh.
> 1. Когда у судьи, планировщика или архитектора кончается Fable, роль один раз перезапускается на Opus: строка в журнал, код телеметрии, одна строка мне; сборка не встаёт.

## Files
- scripts/top-model.sh
- docs/model-cascade.md
- docs/adr/015-sonnet-execution-rung-and-model-floor.md
- tests/model-profile.test.sh

## Non-goals
- No change to `top-model.sh`'s resolution order, exit codes, `--floor`, `--apply`, or any existing output line: the hint is one added line, printed where `--help` and `--explain` already print text.
- No new `model-profile.sh` flag or role (`--fallback` was rejected in the plan); no edit to `scripts/model-profile.sh`.
- No `CHANGELOG.md`, `VERSION`, `README.md` or `docs/command-reference.md` edits: release paperwork is the Queen's at ship.
- No rewrite of the ADR: one appended line under its decision, dated, naming the exception and the spec.
- Do not document the background suite of story 03 (its outcome is not known to this story); `lead-review.md` is its own protocol.

## Map slice
- memory/map/scripts.md `## Entry points` the `model-profile.sh` / `top-model.sh` bullet
- memory/map/agents-and-commands.md `## Commands` the **Profile-aware dispatch** bullet (which dispatches carry the gate model)

## Acceptance criteria
- [ ] `bash scripts/top-model.sh --help` and `--explain` each print the line `gate: the Tier 4 review, the Tier 4 planner, lead-architect (Tier 4, or a story missed twice), a missed story's retry. A hive's own judge: bash scripts/model-profile.sh --role seat, and pass --effort explicitly.`; every other line and the exit code are as in 0.38.0. If `tests/model-profile.test.sh` pins the help or explain output (recon), the pinned text is updated; otherwise the file is untouched.
- [ ] `docs/model-cascade.md`, section "The gate model follows the plan": the four gate uses are stated as the whole list, followed by the hive-judge sentence (`model-profile.sh --role seat` + explicit `--effort`, with the F1 reason in a clause). A new short subsection "When Fable runs out" states: the refusal text, one redispatch on `opus` for that role, the journal line, the telemetry code `fable_limit_fallback`, the owner's one line, a second refusal stops as today, and that under `opus-builds` this is Opus judging Opus code for that dispatch, the owner's recorded exception; `cacheTtl: 1h` on `lead-review` alone is mentioned with the 2026-11-03 measurement.
- [ ] ADR-015 has one appended line: date 2026-10-27, "a Fable-limit refusal redispatches the role once on `opus`; under `opus-builds` the family that built judges that one dispatch; recorded by journal + `fable_limit_fallback` (spec `fable-fallback`)".
- [ ] No committed line names a host project or a person's folder (public-repo rule): the hive of F1 is described by shape only.

## Verification
`bash tests/model-profile.test.sh && bash tests/maintenance.test.sh`

## Implementation notes
- scripts/top-model.sh: `GATE_HINT` defined once before the flag parse; echoed after the header under `--help` and after the `dispatched for:` line under `--explain`. Versus HEAD, `--help` differs by that one line only; exit codes unchanged.
- tests/model-profile.test.sh: recon found it pins `--explain` against the baa5219 resolver; that comparison now drops the `gate: ` line, and two checks pin the hint in `--help` and `--explain` (78 checks ok).
- docs/model-cascade.md: gate section states the four uses as the whole list plus the hive-judge sentence (F1 described by shape, no hive named); new `### When Fable runs out` subsection (refusal text, one `opus` redispatch, journal line, `fable_limit_fallback`, owner sentence, second refusal = old stop, `opus-builds` exception, `lead-review` `cacheTtl: 1h` with the 2026-11-03 measurement).
- docs/adr/015: one dated *Amended 2026-10-27* line after Decision item 6.

## Findings
