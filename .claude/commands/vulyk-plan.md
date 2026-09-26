---
description: Queen planning mode - deliverable check, tier, brief, recon, grill, stories, trace; Tier 1 builds straight through, Tier 2-4 stop for approval (--go opts out; a document deliverable ends at the report)
argument-hint: <goal description> [--go] [--study]
---

Plan: "$ARGUMENTS"

0. Deliverable first. Decide what the owner gets back: changed code or a document. A request to
   validate, audit, monitor, assess, research, compare, or "make me a spec / a plan / a report" is study
   work, and so is `--study`. Study work never cuts a story, dispatches a worker or opens a council:
   write `docs/specs/<slug>/brief.md` (step 2), recon as in step 3 with at most two scouts, and write
   `docs/specs/<slug>/report.md`: findings with `file:line` evidence, options with the recommended one
   first and why, and the candidate stories the owner could approve next time (a list, not story
   files). Commit it as `study(<slug>): <title>` and stop. The owner turns a report into code by running
   `/vulyk-plan` again, in their own words. When both readings are genuinely possible, ask one question.
1. Tier. Classify per the constitution's routing table and announce it with a one-line reason. Tier 0:
   do it now, no paperwork. Tier 1-4 continue. The floor: `brief.md` with `## Asks` at Tier 1+,
   verbatim `## Requirements` quotes in stories at Tier 2+, `wave-check.sh` and `trace-check.sh`
   whenever stories exist.
2. Brief. Write `docs/specs/<slug>/brief.md`: the request verbatim as a `> ` blockquote, piped through
   `bash scripts/redact.sh`, with the date. A bug report's error text, stack trace and reproduction go
   in verbatim too. Everything downstream traces back to this file, so never paraphrase it.
3. Recon. Read `memory/memory.md` and the relevant `memory/map/` slices first. A targeted question about
   a file or two: read them yourself. Dispatch `drone-scout` only for broad or unmapped territory:
   Tier 1 none (one if the location is unknown), Tier 2 at most one, Tier 3 at most two, Tier 4 at most
   four, in parallel.
4. Grill, Tier 2-4. Follow `templates/grill.md`; it owns every rule of the round. Its output lands in
   `brief.md` as `## Answers` then `## Asks`. Tier 1 skips it: `## Asks` is the task phrase as item 1.
5. Plan. Tier 1-2: write plan.md yourself from `templates/plan.md`. Tier 3-4: dispatch `queen-planner`
   with the brief, scout reports and map pointers; Tier 4 also consults `lead-architect` on the central
   design fork, and both Tier 4 dispatches carry `model: <top_model>` (`bash scripts/top-model.sh`).
   Tier 3 passes no model parameter.
6. Stories, from `templates/story.md`, each with `model: opus`. At Tier 1-2 you build them yourself in
   order, so cut by review unit: Tier 1 exactly one story, Tier 2 one to three. At Tier 3-4 each story
   is one worker's job, and it earns its own worker only when it runs in parallel with its wave-mates
   on disjoint `## Files`; fold the rest together.
7. Check. `bash scripts/wave-check.sh docs/specs/<slug>` and `bash scripts/trace-check.sh
   docs/specs/<slug>`. Fix what they report in the story files now, including any `## Verification`
   segment that is not a `## Commands` cell.
8. Coverage, Tier 3-4. Dispatch `drone-coverage` with exactly two paths, brief.md and plan.md. An absent
   or partial ask rides forward as a `## Assumptions` line in plan.md, never silently.
9. Close the plan.
   - Tier 1 runs straight through: `bash scripts/cycle.sh briefed docs/specs/<slug> --commit --mode
     mini-brief`, then `/vulyk-build <slug>` in this session.
   - Tier 2-4 stop for approval by default. Show the plan in the owner's language: the tier, the stories
     by wave (one line each), the `## Assumptions`, and what the build will spend (Tier 2: you build,
     one reviewer per round; Tier 3-4: the workers and seats). Wait. On approval, fill `**Approved:**`
     with the owner and the date, run `bash scripts/journal.sh docs/specs/<slug> 02-approved "approved
     by <owner>" branch`, and commit the spec directory (`vulyk(<slug>): approved`). A "no" or a change
     request reopens steps 5-7 once; a second one is a new brief.
   - Straight-through opt-in, only with `--go` or when the grill's last answer asked for it: instead of
     waiting, `bash scripts/cycle.sh briefed docs/specs/<slug> --commit` (`--mode assumed` in
     no-question mode) and continue.
10. Launch.
   - Tier 2 after approval: tell the owner to `/clear` and run `/vulyk-build <slug>` in a fresh
     session. The build needs the files, not this planning conversation. Stop here.
   - Tier 2 with `--go`, and Tier 3-4: run `/vulyk-build <slug>` now.
