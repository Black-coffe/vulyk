# Grill protocol

Read by `/vulyk-plan` after recon (map + `drone-scout`), before the plan is drafted. Governs
the one interactive round with the human that autonomous mode keeps. Depends on nothing but
Claude Code's own `AskUserQuestion`, `Agent` and `Bash` - never the personal `grill` skill,
never a statusbar.

## When

- Tier 2-4, interactive session (`AskUserQuestion` in the session's tool list): run the round below.
- Tier 2-4, no `AskUserQuestion` (`claude -p`, or the tool otherwise absent - it is never available
  to a subagent): skip straight to "No-question mode".
- Tier 1: skip entirely. `/vulyk-plan` writes the task phrase as the brief's `## Asks` directly - no grill.
- Tier 0: never runs.

## The round

- Exactly one round, never a second. 3-7 questions total, the fixed last question included in the count.
- One question per turn via `AskUserQuestion` - never a bundle, never two questions in one message.
- Open with one sentence, in the owner's language, saying how many questions are coming.
- Each question: at most three plain sentences, in the owner's language. No framework jargon the
  owner did not use first - not "wave", "tier", "pack", "seat".
- Ask only what the recon left ambiguous, or where the code genuinely supports more than one
  implementation. Never ask what the repo, `memory/`, or the brief already answer.
- An implementation-variant question draws its options from the recon (`drone-scout` reports),
  never invented. Every option states in one line what happens if it is chosen.
- The first option is always the recommended one, labelled `(Рекомендую)`, with a one-line reason
  drawn from the recon for *this* code - never a generic reason ("faster", "cleaner", "best practice").
- Every question carries a free-text `Other`.
- Silence, or any phrasing of "as you recommend", is always a safe answer: it selects the
  recommended option.
- A request that reads as a bug report gets one extra question asking which shipped spec it
  escaped from; the chosen slug is written into `brief.md`'s header as `**Escaped from:** <slug>`.
- The fixed last question, always asked, always last: show the N candidate requirement lines
  pulled from `## Request (verbatim)` and ask the owner to confirm or edit them. Its own text also
  offers, in one line, the two-stop opt-out - an owner who wants plan approval back says so here,
  and `/vulyk-plan` then stops for approval before building, as v0.11 did, instead of closing the
  intake straight through.
- Close: once the owner answers the fixed last question, read the confirmed list back to them in
  their own words, one line per item - a statement, not a question - then move straight to planning.
- The round is capped at 7 questions and never repeats. A topic it did not reach is a default, not
  a silent gap: the planner records it under plan.md's `## Assumptions`.
- After the read-back, ask nothing else. The next line the owner sees is `journal.sh`'s stdout line
  (contract C9) - never a summary, never "shall I proceed?".

## Recording answers

Append to `brief.md`, in this order:
1. `## Answers` - one entry per question asked: the question's label plus the chosen option's
   description, verbatim, in the order asked.
2. `## Asks` - the confirmed requirement lines from the fixed last question, numbered from 1
   without gaps (contract C8).

## No-question mode (`claude -p`, `AskUserQuestion` unavailable)

Do not wait on anything. For every question the round would have asked, take its recommended
option and write it to `## Answers` with `(assumed)` appended to the entry. Still derive `## Asks`
from the same fixed-last-question logic - the N candidate requirement lines, all confirmed by
default. `/vulyk-plan` then closes the intake with `--mode assumed`.
