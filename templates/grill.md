# Grill protocol

Read by `/vulyk-plan` after recon (map + `drone-scout`) and, on new ground, its horizon step, before the plan is drafted. Governs
the one interactive question round before the plan is written (the plan approval that follows
it is a stop, not a round). Depends on nothing but
Claude Code's own `AskUserQuestion`, `Agent` and `Bash` - never the personal `grill` skill,
never a statusbar.

## When

- Tier 2-4, interactive session (`AskUserQuestion` in the session's tool list): run the round below.
- Tier 2-4, no `AskUserQuestion` (`claude -p`, or the tool otherwise absent - it is never available
  to a subagent): skip straight to "No-question mode".
- Tier 1: skip entirely. `/vulyk-plan` writes the task phrase as the brief's `## Asks` directly - no grill.
- Tier 0: never runs.

## The round

- Exactly one round, never a second. 3-7 questions total.
- Questions go in batches of up to 4 per `AskUserQuestion` call: 3-4 questions are one call, 5-7 are two.
  A batch never holds a question whose options depend on another answer in the same batch.
- Open with one sentence, in the owner's language, saying how many questions are coming.
- Each question: at most three plain sentences, in the owner's language. No framework jargon the
  owner did not use first - not "wave", "tier", "pack", "seat".
- Ask only what the recon left ambiguous, or where the code genuinely supports more than one
  implementation. Never ask what the repo, `memory/`, or the brief already answer.
- An implementation-variant question draws its options from the recon (`drone-scout` reports),
  never invented (horizon questions, below, are the one exception). Every option states in one line what happens if it is chosen.
- The first option is always the recommended one, labelled `(Рекомендую)`, with a one-line reason
  drawn from the recon for *this* code - never a generic reason ("faster", "cleaner", "best practice").
- Every question carries a free-text `Other`.
- Silence, or any phrasing of "as you recommend", is always a safe answer: it selects the
  recommended option. On a horizon question silence is «Не добавлять» (below).
- A request that reads as a bug report gets one extra question asking which shipped spec it
  escaped from; the chosen slug is written into `brief.md`'s header as `**Escaped from:** <slug>`.
- There is no confirm question. The requirement lines are confirmed at the approval stop
  (`/vulyk-plan` step 9): `## Asks` is shown with the plan, and one word from the owner approves both;
  a correction edits `## Asks` and the plan is shown again.
- The round is capped at 7 questions and never repeats. A topic it did not reach is a default, not
  a silent gap: the planner records it under plan.md's `## Assumptions`.
- After the last batch, ask nothing else until the plan is on disk. The approval stop is not a
  question - it is the asks and the plan shown once, and one word from the owner.

## Horizon questions

When `/vulyk-plan` ran its horizon step (step 3a), `docs/specs/<slug>/horizon.md` holds at most three proposals.
Each becomes one question of this round. Every rule of the round above still applies, with these additions:

- They count inside the 3-7 cap, in this order: ordinary questions whose answer changes what gets built, then
  horizon `gap` proposals, then `extension` ones. A proposal the cap leaves
  out stays in `horizon.md` as offered, never adopted.
- Options: «Добавить» (the proposal, with its cost in one line) and «Не добавлять», always both, plus `Other`. The
  recommended option comes first with its reason: «Добавить» only for a `kind: gap` proposal; for `kind: extension`
  «Не добавлять» is recommended and the proposal comes second, with its cost.
- A `не подтверждено` mark from the proposal stays visible in the question text.
- The owner's own words adopt a proposal: a picked «Добавить», an `Other` that takes it up, or «как рекомендуешь»
  on a gap. Silence never adopts one: unlike other questions, a silent horizon question is «Не добавлять».
- Each adopted proposal becomes one more `## Asks` line, `(horizon) <ask line>`, as the owner's choice, never as an
  owner quote; the approval stop shows it with the other asks, and the owner can strike it there.

These are the one exception to "options from the recon, never invented": their options come from `horizon.md`.
Every other question keeps that rule.

## Recording answers

Append to `brief.md`, in this order:
1. `## Answers` - one entry per question asked: the question's label plus the chosen option's
   description, verbatim, in the order asked. A horizon entry opens with `(horizon H<n>)`, `H<n>` the
   proposal's number in `horizon.md`, and ends with its pick: `adopted`, `declined`, or
   `(offered, not adopted)` in no-question mode.
2. `## Asks` - the candidate requirement lines pulled from `## Request (verbatim)`, as the answers
   shaped them, numbered from 1 without gaps (contract C8); the owner confirms or edits them at the
   approval stop. An adopted horizon proposal is one of these lines, `(horizon) <ask line>`.

The blind court never sees a proposal or `horizon.md`. It does see the owner's recorded decisions on
them, because `## Answers` is part of `brief.md`; its verdicts stay on `## Asks`.

## No-question mode (`claude -p`, `AskUserQuestion` unavailable)

Do not wait on anything. For every question the round would have asked, take its recommended
option and write it to `## Answers` with `(assumed)` appended to the entry. Still derive `## Asks`
the same way - the N candidate requirement lines, all confirmed by default. The horizon step is
skipped here unless `--horizon` forces it; a forced step records each
proposal in `## Answers` as `(horizon H<n>) ... (offered, not adopted)` and never adds it to `## Asks`. No-question mode cannot approve a plan either: `/vulyk-plan` writes the plan and stops
unless `--go` was given, in which case it closes the intake with `--mode assumed`.
