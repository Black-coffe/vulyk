# Report: ab-measurement — how to measure VULYK against bare Claude Code honestly

**Bottom line.** Run after `ab-run-fixes` and `mass-audit-fixes` ship. Start with the L + L2 pair in `sonnet-builds`. It costs
about 24 M weighted and answers the main question: does VULYK pay for itself on the second task in the same repo? The full
set of five tasks is about 31 M per repeat. Nothing here is run without the owner's «да».

## What the last run could not tell (autopsy §6)

n = 1 per side; one Tier 4 task; workers on Opus (`opus-builds`), so the cascade was not measured; the 403 requirement
lived only in the hidden checklist; the operator was an agent polling a screen (56 min of polling delay on side B);
bootstrap was charged to the single task; both sides ran on the same day.

## Design

1. **Tasks, frozen before any run, in two repos.** XS (one-file bug fix), S (Tier 1, ~100 lines), M (Tier 2, ~500 lines),
   L (Tier 3-4, the size of the last run), L2 (a second L task in the *same* repo after bootstrap, to test whether the map
   pays back). Everything a test checks is written in the task text.
2. **Hidden tests.** An acceptance suite (the repo's own test runner + an API script) written from the task text before the
   runs, stored outside both clones, run with one command as the container's own user. A UI checklist only for what a test
   cannot reach.
3. **Sides.** A = bare Claude Code; B = VULYK in `sonnet-builds` (the shipped default after `ab-run-fixes` ask 1);
   B-`opus-builds` optional. Same model build, same base commit, different days.
4. **Blind judge from another vendor.** Every side of B touches all four Anthropic families, so the only clean judge is
   another vendor's model (an OpenAI account the owner holds). It gets the task text and an anonymized diff without
   `.claude/`, `docs/specs/`, `memory/` and framework commits, and scores correctness, coverage, repo conventions and
   unrequested changes on a fixed rubric.
5. **Scripted operator.** Answers fixed in advance («Recommended» or a given text); a question is detected from the session
   `.jsonl` event, not by polling the screen. Operator minutes = stops x a constant.
6. **Metrics per run.** Weighted and the four token kinds (`study/tools/calls.py` from the host hive's study), dollars from
   the price list on the run date, wall time, stops by class (necessary / ceremony / framework bug), judge score, hidden-test
   pass share, fix count.
7. **Repeats.** One repeat first (L + L2), three for the final call; the report gives the median and the spread.

## Decision threshold (written before any run)

VULYK stays on a project class if, on L/L2, **at equal quality the cost is ≤ 1.2x and stops ≤ A + 2**, or if **quality by
the judge or the hidden tests is higher at a cost ≤ 1.5x**. Lose both everywhere: VULYK comes off the projects.

## Cost (estimate from the last run, not a measurement)

| Task | A | B (1.8-2.3x) | Pair |
|---|---:|---:|---:|
| XS | 0.2 M | 0.4-0.5 M | ≈ 0.7 M |
| S | 0.45 M | 0.8-1.0 M | ≈ 1.4 M |
| M | 1.5 M | 2.7-3.5 M | ≈ 4.6 M |
| L | 4.5 M | 8.1 M (with bootstrap) | 12.6 M |
| L2 | 4.5 M | 7.0 M | ≈ 11.5 M |
| **one repeat** | 11.2 M | 19-20 M | **≈ 31 M** |

Three repeats ≈ 93 M. The judge is outside the Anthropic subscription (~10 calls x ~50 k per run). Wall time ≈ 50-60 h of
machine if repeats run in sequence on one Docker host. B's numbers should drop after `ab-run-fixes`; the autopsy's
estimate is 4.9-5.6 M for L, which is itself unmeasured.

## Not read or run

The hidden tests, task texts and operator script do not exist yet. The scale factors for XS-M are the autopsy's guesses.
The judge account and its API cost were not checked.

## Candidate stories (for a later `/vulyk-plan`, after the owner's «да»)

1. Freeze the five task texts and the rubric (owner reviews).
2. Write the hidden acceptance suites, outside the clones.
3. The operator script (answers file + `.jsonl` question detector).
4. The judge harness (diff anonymizer + rubric prompt + score sheet).
5. A runner that logs metrics per run with `calls.py`, and the report template with the threshold above.
