# Report: what VULYK takes from Ponytail

**Date:** 2026-10-16 · **Source:** DietrichGebert/ponytail v5.3.1 (6f1c2bf), MIT · **Readers:** Fable 5.1, Opus 5.5, Sonnet 5.5, each independently, then merged by the Queen.

## Bottom line

Six small rules, none of them Ponytail's "ladder" of lazy solutions as a block. VULYK already enforces most of that
ladder mechanically: `## Files` and `scope-check.sh` fix the scope, `trace-check.sh` cuts speculative stories, and a
new dependency is a manifest edit the story must name. What Ponytail adds is where VULYK had no rule at all, mainly
around bug fixes, the limits of "simplest", and tests for risky logic. The owner approved all six on 2026-10-16.

These rules rest on Ponytail's measurements, not on VULYK complaints. The 30-day hive feedback study
(`docs/specs/hive-feedback-2026-10/report.md`) found no defect class for over-building, missed callers or missing tests.

## Adopted

| # | Rule, in VULYK's words | Where | All three agreed | Ponytail's evidence |
|---|---|---|---|---|
| 1 | A bug fix goes to the root: grep every caller of what you touch and fix the shared code once. A root outside `## Files` is `NEEDS_CONTEXT`, never a patch on the named file | `worker-code.md` step 2; `/vulyk-build` solo step 2 | yes | `benchmarks/results/2026-06-22-issue-245-217-comprehension.md:42-52`: Sonnet 4.6 and Opus 4.8 went from 1/6 to 6/6. A prose control ("trace the flow end to end") stayed at 0/3. In the 2026-10-07 Opus 5.5 run every arm passes this task, so the gain depends on the model. Sonnet 5.5 was not measured |
| 2 | Law 2: simplest never drops trust-boundary validation, data-loss handling or security checks | `CLAUDE.md` Law 2, pinned in `tests/maintenance.test.sh` | yes | `2026-06-17-agentic-safety.md:21-22,54-55`: safe runs fell to 98.9% with a bare "Follow YAGNI" and to 94.4% with "YAGNI + one-liners". The skill with this floor stayed at 100% over 450 sessions. It prevents a known regression of minimalism prompts; it shows no gain over having no prompt |
| 3 | A story that adds a branch, loop, parser, or money, security or data-write handling names the test that fails when that logic breaks. One test, not coverage; a trivial change names none | `queen-planner.md`; `/vulyk-plan` step 6 | yes, all three put it at the planner | `2026-10-07-agentic.md:102-105`: a test where the logic needs one in 68% of cases without the skill, 98% with it; injected bugs caught 46% → 66%. Where a test exists, no-skill tests catch more (77% vs 69%) |
| 4 | When the diff changes a signature, a return value or a behaviour, the reviewer reads the callers of what changed; a broken caller is a `[regression]` | `lead-review.md` § What you read | yes | No results file; the README's "100% vs 78%" appears only in an image caption. Adopted on VULYK's own reasoning, as the review-side mirror of rule 1 |
| 5 | `## Files` lists every place the change must reach: callers, tests, fixtures, config, exports | `templates/story.md`; `queen-planner.md` | yes (Opus: optional) | Thin: `scope-rename` and `scope-format` tasks. The reason is VULYK's own: a path missed here comes back as `NEEDS_CONTEXT` and costs a wave |
| 6 | Reports say what was not checked | `CLAUDE.md` Law 4; `CONCERNS` in `worker-code.md` and `worker-test.md`; `/vulyk-plan` step 0 | Fable and Opus for; Sonnet: Law 4 already covers it | `2026-10-07-agentic.md:120`: a blind judge preferred v5 over v4.13 at 110:67, naming this closing line as the main reason. Against no skill the result was 82:106, not significant. A readability gain, not a correctness one |

## Rejected, with the reason

- **The ladder as a block: reuse the codebase, then stdlib, then an installed dependency, then one line.**
  - The repo already does this: `worker-code.md` ("surrounding code's style"), `## Map slice`, and the manifest under `## Files`.
  - Ponytail's own writeup calls the reuse rung "unproven" (`2026-06-22-...md:70,95`).
- **"Correct on edge cases" between equal options.**
  - Ponytail's robustness audit says it is "not fixable by skill text" (`2026-06-16-robustness-audit.md:17`).
  - VULYK puts edge cases in `worker-test` and `council-opus` instead.
- **`shortcut:` code comments and the debt ledger.**
  - A worker writing one is a descope nobody authorised.
  - In VULYK only the owner removes a requirement, through `## Descoped`.
- **The lite, full and ultra levels.** They contradict Law 1: VULYK's grill asks before the plan, not after.
- **Ponytail's review format (`Verdict: Ship.`, four-part findings, `Lean:`).** It breaks the `lead-review` PASS/BLOCK report, which `record-seat` reads by position.
- **The persona, and the comment and one-liner style rules.** Ponytail has no evidence for them, and v5 removed its own persona lines.
- **The subagent injection hook.** VULYK agents load `CLAUDE.md`, and `PreToolUse` injects the defect classes.
- **The rule-copy checker.** VULYK ships one copy per file. The single invariant worth pinning, the Law 2 floor, got its own check.
- **The benchmark harness.** It would be a Tier 3 spec nobody asked for. VULYK already has the matching discipline in Law 6's original-case and neighbour fixtures, and in `docs/self-evolution.md`, which admits always-loaded text only against evidence.

## Wording lesson

Ponytail ran one controlled experiment on wording. A directive that names a tool action changed behaviour: "grep every caller of the function you touch". The same idea written as a principle did not: "trace the flow end to end".

Separately, its eight attempts to fix one bug by adding rule text all scored the same or worse. So when a VULYK rule fails in practice, rewrite it as the action an agent takes, not the property the result should have, and do not pile on more text.

## Cost

`CLAUDE.md` stays inside its 7 168-byte cap: 7 167 B after the change. Rules 2 and 6 cost about 110 B. They were paid for by shortening VULYK-only rows in the `VULYK:COMMANDS` block, which hives never receive.

Hives get the new Law text and none of the trimmed rows. The `Anomaly telemetry contract tests` label stays, because `tests/telemetry.test.sh` uses it as a sentinel.

## Not read or run

- No Ponytail code or benchmark was run. Every figure comes from its results files and was checked against the line numbers above.
- Not read: Ponytail's `examples/`, its i18n READMEs, its band mod, and its host adapters. None of them holds rules.
- These rules have no measurement on VULYK's own work yet. The first specs built under them will tell, through rounds to green in `council.jsonl`.

Full analyses: the three readers' reports, kept outside the repo in the session scratchpad.
