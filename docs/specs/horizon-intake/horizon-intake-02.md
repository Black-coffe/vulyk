---
story: horizon-intake-02
spec: horizon-intake
status: done
returned: DONE
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
- [ ] `vulyk-plan.md` has the step after recon. The signal is concrete: the Queen takes two to four terms that name
      the asked capability (its nouns and verbs, not the project's) and searches `memory/memory.md`, `memory/map/`
      and the source (Grep). Zero hits on the capability fires the step; a hit on its container (a folder or a file
      family, such as `.claude/commands/` for a new command) is not a hit. An empty repo fires it too. The one-line
      announcement names the terms and where they were searched. The step also states the flags, the skip cases, the
      three parallel dispatches with the contract fields, and the Queen's cut to at most three proposals written to
      `horizon.md` with a verdict on every candidate.
- [ ] `grill.md` has rules for horizon questions:
      - they count inside the 3-7 cap;
      - the first option is the recommended one with its reason, and «Не добавлять» is always present;
      - «Добавить» is the recommended option only for a `kind: gap` proposal; for `kind: extension` the recommended
        option is «Не добавлять», and the proposal comes second with its cost;
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
      - the WebFetch/WebSearch permission result in default mode, against a control: whether a prompt stalls the
        three parallel dispatches, and how many fetches each one made;
      - a plain statement that the interactive questions were not run headless.
- [ ] CHANGELOG `[Unreleased]` describes the step in one entry.
- [ ] Known gap: no suite reads prompt text. `solo.test.sh` only proves the Tier 1-2 plan-to-build mechanics still
      run. The text itself is judged by the reviewer, and the step by `live-run.md`.

## Verification
`bash tests/solo.test.sh`

## Implementation notes
- The step is `3a` in `vulyk-plan.md`, so no later step number moves (`grill.md`, `council.test.sh` and the command
  reference cite "step 9"). `--horizon` overrides every skip case, no-question mode included: there the proposals are
  recorded as `(offered, not adopted)`, which is how the grill's no-question rule is reachable at all.
- Silence: the round's general rule ("silence selects the recommended option") would have let silence adopt a gap.
  The horizon section overrides it: a silent horizon question is «Не добавлять»; «как рекомендуешь» on a gap adopts.
- Web permission: a side-agent note (2026-10-25) raised that default-mode owners will see up to three prompts. Chosen:
  the announcement line says the prompts may come and that a refusal is safe; ADR-022 records that VULYK grants no web
  permission itself. Rejected: an allow rule from the installer, which would enable network access in every hive
  silently. Owner told in chat.
- Live run: the Queen's session could not dispatch an agent created mid-session (`Agent type 'drone-horizon' not
  found`), so the dispatches ran from headless sessions; `live-run.md` says how. Its findings 1-3 were fixed in
  `drone-horizon.md` inside `horizon-intake-01`, before that story closed.
- Not run: the grill questions (no `AskUserQuestion` headless) and an interactive default-mode session.

## Findings
