---
story: model-profiles-02
spec: model-profiles
status: todo
returned:
tier: 3
worker: worker-code
model: opus # owner, 2026-10-18 approval: framework code this spec moves off Sonnet
wave: 1
blocked_by: []
---

# The driver, the build commands and the planner carry the profile's models

## Goal
`vulyk-cycle.js` accepts three optional arguments, `worker_model`, `review_model` and `seat_model`, as the plan's
`## Contracts` says. When they are absent, every dispatch is what it is today. `/vulyk-build` passes the three
arguments from `scripts/model-profile.sh --role worker|review|seat` at the hive launch, and so does the manual fallback
without Workflow. It passes them only when the active profile is not `sonnet-builds`. In the solo path, `lead-review`
gets `model:` only when `--role review` differs from its frontmatter. `/vulyk-review` follows the same rules.
`/vulyk-plan` dispatches the Tier 3 `queen-planner` with `model: <--role planner>` when that is not `opus`, and adds the
line `routine stories: model: haiku` to the planner's brief when `--role routine` prints `haiku`. `queen-planner.md` and
the comment in `templates/story.md` carry the matching story rule: a routine or reusable story (helpers, boilerplate, a
repeated pattern) gets `model: haiku`, with a one-line reason; every other story gets no model line.

## Requirements
> 2. Вариант «Opus пишет, Fable судит»: главная сессия на Opus; Fable делает планы больших задач и архитектуру и проверяет весь код; Opus пишет новое и логику; Haiku пишет рутину и переиспользуемое.
> 4. Экономный вариант: без Fable, Sonnet пишет, Haiku рутину, Opus судит.
> Переиспользуемые методы, логику, процессы пишет Haiku. Что-то новое, планирование, архитектура — это Fable плюс Opus.
> 2. Вариант «Opus пишет, Fable судит»: главная сессия на Opus; Fable делает планы больших задач и архитектуру и проверяет весь код; Opus пишет новое и логику; Haiku пишет рутину и переиспользуемое.

## Files
- .claude/workflows/vulyk-cycle.js
- tests/driver.test.sh
- .claude/commands/vulyk-build.md
- .claude/commands/vulyk-review.md
- .claude/commands/vulyk-plan.md
- .claude/agents/queen-planner.md
- templates/story.md

## Non-goals
- Do not change the Tier 4 reviewer pair (`TOP`/`SECOND`), the Tier 4 abort when `SECOND` is missing or equals `TOP`,
  `CAPS`, or the retry rule (`TOP` on a retry).
- Do not pass any of the three arguments under `sonnet-builds`. A hive's pinned worker or reviewer frontmatter must still
  decide there (ADR-015 D2, amended 2026-10-16).
- Do not add a real `model:` line to `templates/story.md`, only the comment. `top-model.sh --floor` scans that file.
- Do not edit the agent frontmatter of `worker-*`, `lead-review` or `council-*`, and do not edit `cycle.sh`. The
  `model: opus` that `cmd_repair` writes stays.
- Keep the `top-model.sh --floor` ... `Exit 1` text in `vulyk-build.md` `## Hive` that `tests/telemetry.test.sh` asserts.
- Commands call scripts through Bash. Any `!` injection names the script through `${CLAUDE_PROJECT_DIR}`, never a
  relative path (`scripts/injection-check.sh`).

## Map slice
memory/map/cycle.md (`The Workflow driver`); memory/map/agents-and-commands.md (`/vulyk-build`, `/vulyk-review`,
`/vulyk-plan`, queen-planner, lead-review, council seats); the scout report's lines on `vulyk-cycle.js` 43-44, 113, 169-174,
200-202 and `tests/driver.test.sh` 78, 166-228, 303-313

## Acceptance criteria
- [ ] With today's `ARGS`, every existing `driver.test.sh` assertion holds unchanged: the story model passes through,
      the Tier 1-3 reviewer and the seats get `model` undefined, a retry runs on `TOP`, and the Tier 4 pair holds.
- [ ] With `worker_model:'opus'`, a story with no model runs on `opus` and a story with `model: haiku` runs on `haiku`;
      its retry still runs on `TOP`.
- [ ] With `review_model:'fable'`, the Tier 1-3 `lead-review` gets `fable` and the Tier 4 pair is unchanged.
- [ ] With `seat_model:'fable'`, `council-opus` gets `fable`, and so does `council-haiku` when the black-box seat is
      required.
- [ ] `vulyk-build.md` (hive launch, manual fallback, solo reviewer), `vulyk-review.md` and `vulyk-plan.md` name the
      exact `bash scripts/model-profile.sh ...` calls and the rule "only when the profile is not `sonnet-builds`" (or,
      for a single dispatch, "only when it differs from the agent's frontmatter").
- [ ] `queen-planner.md` and the `templates/story.md` comment say when a story gets `model: haiku`: the brief says
      routine is haiku and the story is routine or reusable. The reason goes in one line under `## Goal`. The
      `model: opus` rule for long-horizon work stays.

## Verification
`bash tests/driver.test.sh`
`bash tests/e2e.test.sh`
`bash tests/telemetry.test.sh`

## Implementation notes

## Findings
