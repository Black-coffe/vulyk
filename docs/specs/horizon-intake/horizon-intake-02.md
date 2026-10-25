---
story: horizon-intake-02
spec: horizon-intake
status: todo
returned:
tier: 2
worker: worker-code
wave: 2
blocked_by: [horizon-intake-01]
---

# Intake wiring and the live run

## Goal
`/vulyk-plan` has a horizon step between recon and the grill. It fires on new ground at Tier 2-4 in an interactive
session, announced in one line with its reason, and is forced or skipped with `--horizon` / `--no-horizon`. It
dispatches `drone-horizon` three times in parallel. The Queen cuts the result to at most three proposals in
`docs/specs/<slug>/horizon.md`. `templates/grill.md` asks those proposals inside the one round. ADR-022 records
the decision; the command reference, architecture page and CHANGELOG describe it. One live run on a sample
new-ground request is recorded in `live-run.md`.

## Requirements
> 1. Если мы видим, что Woolig Plan задает какую-то задачу, которая только относится к текущему проекту, и там дополнительных уточнений не нужно, мы их не спрашиваем.
> 2. Если мы видим, что Woolig Plan — это вообще либо чистый голый проект, либо пользователь задает что-то, чего нету в разработке, нету в программе и много чего нового
> 6. можно предлагать пользователю таким Q&A- сессиям вопросы-ответы, чтобы он еще лучше свой промт определил и усилил.
> 7. Живой прогон: Здесь, на образце - три drone-horizon и отбор по-настоящему, токены через token-report, разрешение WebFetch в обычном режиме.

## Files
- .claude/commands/vulyk-plan.md
- templates/grill.md
- docs/adr/022-horizon-step.md
- docs/command-reference.md
- docs/architecture.md
- CHANGELOG.md
- docs/specs/horizon-intake/live-run.md

## Non-goals
- No change to the round's cap (3-7), to "exactly one round", or to the approval stop.
- No horizon for study work, Tier 0-1 or no-question mode, and no new script: the signal is the Queen's judgement
  on recon facts, stated in one line.
- No edit to `CLAUDE.md`: its routing table does not change, and it sits at its byte budget (ADR-016).
- No hive upgrade and no version bump here: that is ship work.

## Map slice
memory/map/agents-and-commands.md: `/vulyk-plan` (steps 3-4) and `drone-scout` dispatch rules

## Acceptance criteria
- [ ] `vulyk-plan.md` has the step after recon. It names the signal (no `memory/` pointer, no map slice and no code
      hit for the asked capability, or an empty repo), the one-line announcement, the flags, the skip cases, the
      three parallel dispatches with the contract fields, and the Queen's cut to at most three proposals written to
      `horizon.md` with a verdict on every candidate.
- [ ] `grill.md` has rules for horizon questions:
      - they count inside the 3-7 cap;
      - the first option is the recommended one with its reason, and «Не добавлять» is always present;
      - the owner's words adopt a proposal, silence never does;
      - a `не подтверждено` mark stays visible in the question;
      - the fixed last question shows adopted proposals as `(horizon)` ask lines (the upgraded prompt), and they
        enter `## Asks` only when confirmed;
      - no-question mode records proposals as offered, never adopted.
      The rule "options from the recon, never invented" stays for every other question.
- [ ] A request inside existing code still gets today's grill: no horizon dispatch, no extra question.
- [ ] `live-run.md` records the live run:
      - a sample new-ground request;
      - the three lens returns and the Queen's cut;
      - the tokens per dispatch from `token-report.py`;
      - the WebFetch/WebSearch permission result in default mode, against a control;
      - a plain statement that the interactive questions were not run headless.
- [ ] CHANGELOG `[Unreleased]` describes the step in one entry.
- [ ] Known gap: no suite reads prompt text. `solo.test.sh` only proves the Tier 1-2 plan-to-build mechanics still
      run. The text itself is judged by the reviewer, and the step by `live-run.md`.

## Verification
`bash tests/solo.test.sh`

## Implementation notes

## Findings
