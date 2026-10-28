---
story: red-receipt-02-prompts-and-template
spec: red-receipt
status: done
returned: DONE
tier: 3
worker: worker-code
wave: 2
blocked_by: [red-receipt-01-stamp-red-verb]
---

# Workers, planner, solo build and reviewer learn the red receipt; the story template shows the fields

## Goal
The agents and commands that build or judge a story know the order test -> `red_reason` -> `stamp-red` -> code ->
`close-story`, the three new exit-4 messages and the planner's marking rule; `templates/story.md` describes the
three frontmatter fields and the `## Red receipt` section in comments, so a story built from it stays unmarked.
Every verb name, message and rule comes from plan.md `## Contracts` (`stamp-red`, `close-story` gate, prompt order):
quote them, do not reword them. Read story 01's `## Implementation notes` for any message that changed in the build.

Edits, per file (a paragraph or a few lines each; keep each file's existing structure):
- `worker-code.md` and `worker-test.md`: a step before the implementation step for a `red: required` story - the
  five-step order, "no implementation edit before the receipt", "no mock, stub or fixture of logic this story has
  not written yet", "never edit the implementation to produce a red; a red that needs a staged break is reported as
  `NEEDS_CONTEXT`"; in the close step (step 5) the exit-4 handling table from the contract beside today's
  `edited outside ## Files` rule; worker-code.md:62 ("no tests it does not name") stays consistent: the test is the
  file named in `## Files`.
- `queen-planner.md:36-38` and `vulyk-plan.md:78`: the critical list marks `red: required`; the test file in that
  story's `## Files` and its path in `## Verification`; `red_reason` prefilled when the assertion is known; the
  "or a `worker-test` story in a later wave" path is removed for marked stories (kept for unmarked ones).
- `vulyk-build.md:25` (solo path): for a marked story the Queen writes the test and `red_reason`, runs
  `bash scripts/cycle.sh stamp-red <file>` (no `--stamp`), then implements; the same exit-4 messages, same handling.
- `lead-review.md`: in the judged items, for every `red: required` story in the diff read its `## Red receipt` tail
  and `red_reason`; a tail showing a staged break inside the implementation rather than the missing behaviour is a
  major `[ask N]` naming the story; a marked story closed without a receipt cannot occur (the gate), so none is
  asked for.
- `templates/story.md`: three commented frontmatter lines after `blocked_by:` (`# red: required` - set by the planner
  for a branch, loop, parser, money, security or data write; `# red_reason:` - the expected failure text, written by
  the builder before `stamp-red`; `# red_verified_at:` - written by `cycle.sh stamp-red`, never by hand), and one
  comment under `## Findings` saying `stamp-red` appends `## Red receipt` at the end of the file and `close-story`
  refuses a marked story without it.

## Requirements
> 2. Порядок работы: тест → stamp-red → код → зелёный. close-story закрывает критичную историю, только если видит штамп.
> 3. Воркерам запрещено писать реализацию до падающего теста и запрещены моки для ещё не написанной логики.
> 5. Критичную историю помечает планировщик по текущему списку. Тест лежит в той же истории, путь «тест после кода» для неё закрыт.

## Files
- .claude/agents/worker-code.md
- .claude/agents/worker-test.md
- .claude/agents/queen-planner.md
- .claude/agents/lead-review.md
- .claude/commands/vulyk-plan.md
- .claude/commands/vulyk-build.md
- templates/story.md

## Non-goals
- Do not touch `description:` lines or any frontmatter of the agent files (`tests/maintenance.test.sh` caps the
  description bytes; `lead-review.md`'s `cacheTtl` and `SUITE:` protocol stay as they are).
- Do not edit CLAUDE.md, `docs/`, `scripts/`, `tests/` or the driver; do not add a `red:` line to `templates/plan.md`.
- Do not write an uncommented `red:` key into the template: a story built from it must be unmarked.
- Do not invent messages: a message not in plan.md `## Contracts` or story 01's notes is a question, not a guess.

## Map slice
memory/map/agents-and-commands.md `## Agents - frontmatter, job, report` (worker-code/worker-test close rules,
queen-planner, lead-review items 1-4), `## Commands - what each runs` (`/vulyk-plan` step 6 area, `/vulyk-build` solo).

## Acceptance criteria
- [ ] Both worker prompts carry the five-step order, the two prohibitions, the "never stage a break" rule and the
      exit-4 table with the three gate messages and the `stamp-red` refusals, each with its action.
- [ ] `queen-planner.md` and `vulyk-plan.md` step 6 say who marks, that the test is in the same story and sealed by
      its `## Verification` path, and that no later-wave test story exists for a marked story.
- [ ] `vulyk-build.md` solo path names `stamp-red` before the implementation step.
- [ ] `lead-review.md` names the receipt tail as a read for marked stories and the finding it yields.
- [ ] `templates/story.md`: the three lines are comments; the `## Findings` comment names `## Red receipt`;
      `bash tests/cycle.test.sh` (fixtures built from the template) still passes.
- [ ] `bash tests/maintenance.test.sh` passes (no cap broken).

## Verification
`bash tests/maintenance.test.sh`
`bash tests/cycle.test.sh`

## Implementation notes
- worker-code.md, worker-test.md: new step 2 "Red first" (five-step order, both prohibitions, staged-break = NEEDS_CONTEXT); later steps renumbered, so the close step is now step 6; its exit-4 list carries the three gate messages and every stamp-red refusal with its action.
- Decision: `story is not red: required`, `no test to seal`, `nothing to turn green` route to NEEDS_CONTEXT (the story's shape is the planner's), the rest to "fix the test or reason and rerun" per the contract.
- queen-planner.md, vulyk-plan.md step 6: the planner marks `red: required`, test in the same story's `## Files` and `## Verification`, `red_reason` prefilled when known, no later-wave worker-test story for a marked one (kept for unmarked in queen-planner).
- vulyk-build.md solo step 2: test + red_reason, `stamp-red <file>` without `--stamp`, then implement; exit-4 handling points to worker-code.md step 6.
- lead-review.md: judged item 5 "Red receipts".
- templates/story.md: three commented frontmatter lines after blocked_by (column 0 `# `, so `^red:` never matches), `## Findings` comment names `## Red receipt`.
- Messages quoted from plan.md `## Contracts`; story 01's notes changed none.

## Findings
