---
description: Queen planning mode - deliverable check, brief, recon, grill, decompose into stories, trace, then STOP for approval (--go builds straight through; a document deliverable ends at the report)
argument-hint: <goal description> [--go] [--study]
---

Enter Queen mode for: "$ARGUMENTS"

0. **Deliverable first.** Before any tier, decide what the owner gets back: **changed code** or a
   **document**. A request to validate, audit, monitor, assess, research, compare, or "make me a
   spec / a plan / a report" is study work, and so is `--study` in "$ARGUMENTS". Study work never
   cuts a story, dispatches a worker, or opens a council: write `docs/specs/<slug>/brief.md` (step
   2), do the recon of step 3 with at most two scouts (a study has no tier), and write the answer as
   `docs/specs/<slug>/report.md` - findings with `file:line` evidence, options with the
   recommended one first and why, and the plan the owner could approve next time as a list of
   candidate stories, not story files. Commit it as `study(<slug>): <title>` and stop. The owner
   turns a report into code by running `/vulyk-plan` again on it, in their own words. When the two
   readings are genuinely both possible, ask one question; never guess "code".
1. **Classify the tier** per the routing matrix in CLAUDE.md. Announce it. Tier 0: do it directly,
   no ceremony. Tier 1 through 4 continue below - the only branch left by tier is how much each
   step does. Ceremony floor: brief.md and `## Requirements` quotes exist at Tier 2+; trace-check
   runs whenever stories exist; Tier 0 gets none of it.
2. **Brief.** Write `docs/specs/<slug>/brief.md`: the request VERBATIM as a `> ` blockquote - the
   user's words, not your restatement - piped through `bash scripts/redact.sh`, with the date.
   Everything downstream traces back to this file; a paraphrase here poisons every gate built on
   it. A bug report is a spec too: the error text, the stack trace and the reproduction go in
   verbatim. Tier 1: the brief is the task phrase itself, verbatim.
3. **Recon, not reading - capped.** Check `memory/memory.md` and the relevant `memory/map/` slices
   first. Dispatch `drone-scout` only for territory the map does not cover or marks stale, and
   never more than the tier allows: Tier 1 - one, and only if the location is unknown; Tier 2 -
   one; Tier 3 - two; Tier 4 - four, in parallel. A scout whose question the map already answers
   is a re-read the Queen pays for twice. You do not open source files yourself. This recon is
   where the grill's implementation-variant options come from; it runs before the grill.
4. **Grill.** Follow `templates/grill.md` exactly - it owns every rule of the round: question
   count, phrasing, the recommended-first option, the fixed last question, the straight-through
   opt-in, no-question mode. Run it in this session; when `AskUserQuestion` is absent from the
   session's tool list, run the template's no-question mode. Its output lands in `brief.md`:
   `## Answers` then `## Asks` (numbered from 1, contract C8). Tier 1: skip the grill - `## Asks`
   is the task phrase as its one line.
5. **Plan.** Tier 2: draft the plan inline. Tier 3-4: delegate synthesis to `queen-planner` with
   the brief, scout reports and map pointers attached; Tier 4 also requests a `lead-architect`
   consult on the central design fork. **Tier 4 only: both dispatches carry `model: <TOP_MODEL>`**
   - the gate alias the session brief announced (`bash scripts/top-model.sh` if it scrolled away);
   a Tier 3 `queen-planner` runs on its frontmatter `opus` with no parameter (ADR-012). Plan file
   follows `templates/plan.md`; contracts between concurrent stories are decided here. Tier 1:
   write plan.md directly - a single-story plan still needs the file.
6. **Stories.** `docs/specs/<slug>/` holds plan.md plus one story file per unit of work
   (`templates/story.md`): verbatim `## Requirements` quotes, files, acceptance criteria, quiet
   verification command, map slice pointer, `wave:`/`blocked_by:`, and `model:` - `opus` for every
   story (ADR-012; the retry climbs to the gate model on its own, so no story needs a mark). Stories
   in one wave run concurrently, so their `## Files` must be disjoint. Tier 1: exactly one story.
7. **Check the stories, deterministically.** `bash scripts/wave-check.sh docs/specs/<slug>` and
   `bash scripts/trace-check.sh docs/specs/<slug>` - both free, both at every tier that has a
   story. Fix findings in the story files now.
8. **Coverage, from outside the plan - Tier 3-4 only.** Dispatch `drone-coverage` with exactly two
   paths: the brief and plan.md, never the story files. An absent or partial ask not already
   resolved by `## Asks` rides forward as a `## Assumptions` line in plan.md, never silently.
   Tier 1-2: skip - a plan of one to four stories has nothing a second reader adds.
9. **Stop for approval - the default.** Show the owner the plan in their language: the tier, the
   stories by wave (one line each, with the model each will run on), the `## Assumptions`, and the
   agent count the build will spend. Then wait. On one word of approval, replace the `**Approved:**`
   placeholder in plan.md with the owner and the date, run
   `bash scripts/journal.sh docs/specs/<slug> 02-approved "approved by <owner>" branch`, and
   proceed to step 10. "No" or a change request reopens step 5-7 once; a second one is a new brief.
   **Straight-through, the opt-in:** only with `--go` in "$ARGUMENTS", or when the grill's last
   question recorded the owner asking for it, skip the wait: run
   `bash scripts/cycle.sh briefed docs/specs/<slug> --commit` (no-question mode: `--mode assumed`)
   and echo exactly what it prints. Tier 1 is always straight-through with `--mode mini-brief` -
   one story, one seat, nothing to read.
10. **Launch.** Launch the driver as `/vulyk-build` step 1-2 describes. Never launch the fallback
    driver from here - `/vulyk-build --fallback` is the owner's explicit call.
