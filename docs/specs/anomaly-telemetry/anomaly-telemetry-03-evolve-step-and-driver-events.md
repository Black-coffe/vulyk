---
story: anomaly-telemetry-03
spec: anomaly-telemetry
status: done
returned: DONE
tier: 3
worker: worker-code
model: sonnet
tracer: false
wave: 2
blocked_by: [anomaly-telemetry-01]
---

# The weekly step in `/vulyk-evolve`; driver refusal and relaunch events

## Goal
`/vulyk-evolve` gains a step that reads the week's anomaly rows into its diagnosis and, when consent is `on`, runs `telemetry.sh publish` and shows the owner the printed command (commit locally, or `gh pr create`) without running it. `/vulyk-build` records `driver_refused` at the points where it refuses to run, and `/vulyk-resume` records `driver_relaunched` when it relaunches the driver, so the fourth detector has a source.

## Requirements
> Раз в неделю логи отправляются в репозиторий VULYK: локально в основной проект, с других машин как pull request.
> раз в неделю отправляли логи в репозиторий Git или тебе в основной проект, если это локальная история. Если это не локальная, а на разных компьютерах, то чтобы отправляли где-то в репозиторий как pull request.
> отказ или перезапуск драйвера
> Журнал пишется всегда, шаг отправки в /vulyk-evolve печатает команду только при on.

## Files
- .claude/commands/vulyk-evolve.md
- .claude/commands/vulyk-build.md
- .claude/commands/vulyk-resume.md

## Non-goals
- No new command (`/vulyk-telemetry` was rejected in the plan). No scheduler, cron, git hook or CI trigger - "weekly" is the owner running `/vulyk-evolve`.
- The step never runs `git push`, `git commit` or `gh`, never waits for the owner, and never edits the printed command by hand - it relays what `telemetry.sh publish` printed, verbatim, and stops (same posture as `/vulyk-ship` step 3).
- Do not implement detection logic in markdown: the consent check, the bundle, the repo detection and the recipes all live in `telemetry.sh` (story 01). The command file calls verbs and reads their output.
- Do not touch `vulyk-cycle.js`, `cycle.sh`, `/vulyk-status`, `/vulyk-ship`, or the evolve step 4 changeset mechanics.
- Do not restate the enum or the schema in the command file - point at `docs/telemetry.md`.

## Map slice
memory/map/agents-and-commands.md (`/vulyk-evolve`, `/vulyk-build` step 1 and the fallback refusal, `/vulyk-resume` relaunch); recon/weekly-and-publish.md Entry points and Answers 1, 3, 5; plan.md `## Contracts` (`consent`, `bundle`, `publish` verbs and their exact output).

## Acceptance criteria
- [ ] `vulyk-evolve.md` has a new step between "Harvest" and "Diagnose" (or as part of the check-in) that: reads `memory/stats/anomalies.jsonl` for the rolling 7-day window and lists counts per code beside the existing council stats; runs `bash scripts/telemetry.sh consent`; on `off` prints the script's one-line notice and moves on; on `on` runs `bash scripts/telemetry.sh publish`, shows its fenced command block to the owner, and states that the command was printed, not run.
- [ ] `--dry-run` still stops after diagnosis; the publish call happens only on the full path, and `publish --dry-run` is used under `--dry-run`.
- [ ] `vulyk-build.md` calls `bash scripts/telemetry.sh record driver_refused 1 0 --spec <slug> --ref driver:<slug>:<date>` at every point where it refuses to start the driver (no `Workflow` without `--fallback`; the by-name/scriptPath call throwing), immediately before the refusal text.
- [ ] `vulyk-resume.md` calls `bash scripts/telemetry.sh record driver_relaunched 1 0 --spec <slug> --ref relaunch:<slug>:<stamp>` when it relaunches the driver fresh.
- [ ] Every added call is a quiet one-liner; no command file prints script output other than the `publish` block.
- [ ] Anomaly counts appear in evolve's diagnosis output as one table row per code; no free text from the log is echoed (there is none in the schema).

## Verification
`none — reviewed by lead-review`

## Implementation notes
- `vulyk-evolve.md` step 2: appended the anomaly-count table (per-code, 7d, zero-filled from `telemetry.sh enum`) and the consent/publish branch inline in the check-in step, rather than inserting a numbered step 2.5 - avoids renumbering steps 3-5 and matches the story's "or as part of the check-in" option.
- `vulyk-build.md`: recorded `driver_refused` at the two refusal points named in the story - the missing-`--fallback` stop in step 1, and a new sentence covering the `Workflow` tool call itself throwing at invocation (the file previously had no branch for that case; added one, scoped to "stop, never retry blindly", per the plan's `by-name call threw` phrasing).
- `vulyk-resume.md`: `driver_relaunched` recorded once `$stamp` is resolved inside step 3's relaunch, before continuing the launch.
- All three calls are quiet one-liners (`telemetry.sh record` prints nothing on success); `publish`'s fenced block is the only script output any of these command files shows the owner, per acceptance criterion 5.
- Interpreted the ambiguous acceptance line "the publish call happens only on the full path, and `publish --dry-run` is used under `--dry-run`" as: publish only runs when consent is `on` (vs. the off-notice branch), and `/vulyk-evolve --dry-run` passes `--dry-run` through to `telemetry.sh publish` rather than skipping it - flagged here since the story text reads ambiguously between "full path" (= consent-on) and "the full (non-dry-run) path".

## Findings
