---
story: autonomous-cycle-08
spec: autonomous-cycle
status: todo
tier: 4
worker: worker-code
tracer: false
wave: 3
blocked_by: [autonomous-cycle-03]
---

# `/vulyk-plan` with the grill: one human stop, `## Asks`, `**Briefed:**`, launch

## Goal
`/vulyk-plan` becomes the single place the human is engaged: brief verbatim, cheap recon, one grill round of 3-7 questions per `templates/grill.md` (new), answers verbatim into `## Answers`, the confirmed requirement lines into `## Asks`, `cycle.sh briefed --commit`, plan and stories as today, and the driver launched without an approval stop. Tier 1 gets the mini-brief path; `claude -p` gets the assumed path.

## Requirements
> Встроен в /vulyk-plan, после дешёвой разведки. Порядок: задача → brief verbatim → карта + drone-scout → ОДИН раунд гриля: 3-7 вопросов через AskUserQuestion, рекомендованный первым с «почему для этого кода», варианты реализации — из разведки → ответы verbatim в brief.md ## Answers → план и build без стопа. Протокол гриля — файл в репо (templates/grill.md), не личный скилл.

> система может загрилить, то есть мини-гриль сделать, используя скиллы гриля, человека, чтобы уточнить то, что она не поняла или поняла не до конца, или то, что можно реализовывать разными вариантами. При этом грилевание должно быть максимально приятным, простым и понятным для человека.

> Только мини-гриль. После последнего ответа в гриле система идёт plan → build → совет → коммит без единого ожидания. План показывается в терминале как лог, не как вопрос.

> Tier 1 получает мини-brief (сама фраза задачи verbatim, без гриля) и полный совет в один раунд.

> Далее система сама себе пишет тесты, сама себе пишет план, сама себе пишет, как она будет принимать задачу

## Files
- .claude/commands/vulyk-plan.md
- templates/grill.md

## Non-goals
- Do not write the driver loop or mode detection - the last step says "launch the driver as `/vulyk-build` step 1-2 describes" (story 09) and nothing more.
- Do not remove the `**Approved:**` path entirely: keep a one-line note that an owner who wants the two-stop mode says so in the grill's last question and the command then stops for approval as v0.11 did.
- Do not depend on the personal `grill` skill, a statusbar, or any tool outside Claude Code's own (`AskUserQuestion`, `Agent`, `Bash`).
- Do not change the story/plan templates, `drone-scout`, `drone-coverage` or `trace-check.sh`.
- Do not ask more than seven questions or a second round; what the grill did not ask is a default, written down as such.

## Map slice
`docs/specs/autonomous-cycle/plan.md` `## Contracts` C7 (`Briefed` variants), C8 (`## Asks`), C9 (journal), C12 (launch protocol pointer) and `## Assumptions` (Tier 1 path, `claude -p` mode, escaped-defect header) · `docs/grill/2026-09-12-autonomous-cycle-council.md` Decision 9 and Act 2 rows 9 (`## Asks`), 1 (`Briefed`), 13 (Tier 1) · `docs/specs/autonomous-cycle/recon/scout-commands.md` §Answer 1 row `vulyk-plan.md` (steps 3 and 9 are the stops to remove; step 9 writes `**Approved:**`) and §Gotchas (no `templates/brief.md` exists - the brief recipe stays inline in the command).

## Acceptance criteria
- [ ] `templates/grill.md` states the protocol: when (after recon, before planning), one round, 3-7 questions, each via `AskUserQuestion` with the recommended option first and labelled, its description saying why for this code (from the recon), implementation variants drawn from the recon, an `Other` free-text always present; the fixed last question "these N lines of your request are requirements, the rest is context - confirm or edit" whose answer becomes `## Asks`; when the request is a bug report, one question asks which shipped spec it escaped from (`**Escaped from:** <slug>` in the brief header); no-question mode (`claude -p`, no `AskUserQuestion`): take every recommended option, mark each answer `(assumed)`; the two-stop opt-out.
- [ ] `vulyk-plan.md` steps in order: tier announcement; `brief.md` with `## Request` verbatim through `redact.sh` (unchanged recipe); map + `drone-scout` recon; the grill per `templates/grill.md`; `## Answers` (label + chosen description, verbatim) and `## Asks` (numbered, per C8) appended to `brief.md`; `bash scripts/cycle.sh briefed docs/specs/<slug> --commit` (or `--mode assumed`); `queen-planner` / stories / `wave-check` / `trace-check` / `drone-coverage` as today; the plan printed to the terminal as a journal line, not a question; launch per `/vulyk-build` step 1-2.
- [ ] Tier 1: no recon beyond a `drone-scout` if the location is unknown, no grill; `## Asks` = the task phrase; one story; `cycle.sh briefed --mode mini-brief`; launch.
- [ ] Tier 3-4 brief confirmation (old step 3) and plan approval (old step 9) are gone from the autonomous path; the command never waits after the grill's last answer.
- [ ] Every terminal message the command prints on a state change is the `journal.sh` stdout line, nothing invented beside it.
- [ ] The command's `description:` frontmatter no longer mentions approval.
- [ ] The grill is pleasant by contract, not by taste (`templates/grill.md` states each rule and `vulyk-plan.md` points at it): one question per turn, never a bundle; a question is at most three plain sentences in the owner's language, no framework jargon (no "wave", "tier", "pack", "seat" unless the owner used the word); every option says in one line what happens if it is chosen; the recommended option is first and labelled `(Рекомендую)` with the reason drawn from the recon, not generic; silence or "as you recommend" is always a safe answer; the grill opens with one sentence saying how many questions are coming and closes with the `## Asks` list read back in the owner's own words; nothing else is asked after the last question - the next line the owner sees is the journal's first line.

## Verification
`none — reviewed by lead-review`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
