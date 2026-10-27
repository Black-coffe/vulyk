# Fable-limit fallback, a warm reviewer cache, the gate's narrow scope (plan)

**Tier:** 3 · **Spec slug:** `fable-fallback` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-015 (the family that builds never judges; this spec records one exception), ADR-020 (model profiles: `opus-builds` puts every judge on Fable), Law 2 (smallest change, no new script unless a test needs one), Law 6 (a branch names the test that fails), `docs/telemetry.md` (`ENUM` is append-only, bundle rows carry codes and numbers only), `tests/maintenance.test.sh` caps (`DESCRIPTIONS_MAX_BYTES`), the public-repo rule (no host names in committed files)
**Depends on:** the study `docs/specs/fable-budget/report.md` (be030a1, F3 and F5); 0.38.0 (`.claude/workflows/vulyk-cycle.js` dispatch via `agent(prompt, {agentType, model})` in `caught()`, seats re-dispatched once on a rejected report; `scripts/telemetry.sh record`; `lead-review` `SUITE:` line, 0.36.0)

## Goal
When a Fable dispatch comes back with the Fable-limit refusal, the build goes on instead of stopping: the Workflow driver and the three commands that dispatch judges, planner and architect (`/vulyk-build`, `/vulyk-review`, `/vulyk-plan`) redispatch that one role once on `opus`, and the event is recorded three ways: a journal line, the telemetry code `fable_limit_fallback`, and one sentence to the owner. A second refusal stops the build as today. `lead-review` gets a one-hour prompt cache (its frontmatter alone) and, if a probe shows the parent waits for a subagent's background command, starts the full suite in the background and reads the diff while it runs; if the probe fails, that story stops with the measurement and the suite step stays as it is. The docs and `top-model.sh`'s own hint say what the gate model is for (the Tier 4 review, `lead-architect`, the Tier 4 planner, a missed story's retry) and what a hive's own judge script should ask instead (`model-profile.sh --role seat`, plus an explicit `--effort`). The detector is the refusal text from `## Recon`; nothing else is retried.

## Assumptions
- **The fallback family is a constant, `opus`, for every Fable role** (review, both blind seats, the Tier 4 top reviewer, the Tier 3-4 planner, the architect, a missed story's retry on the gate). It lives as one named constant in the driver and as the word `opus` in the three commands; no `model-profile.sh --fallback` flag (see `## Rejected`). Under `opus-builds` this means Opus judges Opus code for that one dispatch: the owner's choice (brief, Request), recorded by the journal line, the telemetry row and a one-line amendment to ADR-015 (story 04).
- **Detection is the refusal text only**: `You've reached your Fable limit` or `model_requires_usage_credits` in the dispatch's returned text or in the error `caught()` swallowed. An Opus or Sonnet limit, a five-hour limit (`usage_limit_reached`) or any other API error is not matched and behaves as today.
- **One redispatch per dispatch, never a third call.** The refused call wrote no seat report, so the redispatch is not a second attempt: the `attempt-<k>` numbering and the rejected-report redispatch are untouched. A refusal on the redispatch is the existing path (absent seat, missed story).
- **On the Workflow path the record is written when the driver returns.** The driver has no shell but `cycle-clerk`, whose verbs stay `advance|status|release`; it reports every fallback in its return value and console, and `/vulyk-build` writes the journal line, runs `telemetry.sh record` and tells the owner then. On the solo path and the no-Workflow hive loop the Queen does all three right after the redispatch. Widening the clerk's verbs was rejected (below).
- **Only `lead-review` gets `experimental:` / `  cacheTtl: 1h`** (ask 3), in story 02 beside the other protocol edits. Measurement, not a story: on **2026-11-03** the Queen compares `lead-review`'s spend per dispatch (API-price-weighted, the study's yardstick) for the week since the merge against the week before, with the rewrite share beside it (baseline 31% of cache writes, break-even 37.5%), tells the owner the result and recommends whether the field spreads; the owner decides; the note must say which account ran it, because `1h` is ignored while a subscription is on usage credits (`## Recon`).
- **Ask 2 rests on a probe whose stop rule is inside story 03**: step 1 measures whether the parent receives a subagent's return only after that subagent's background Bash command ends; a failed probe ends the story with `returned: NEEDS_CONTEXT`, the measurement under `## Findings`, and no edit to the suite step. The Queen then tells the owner and proposes the alternative herself (brief, ask 2): the driver or the Queen runs the suite before dispatching the reviewer, at the cost the study names (the reviewer no longer measures the suite itself). `maxTurns` of `lead-review` and `CAPS` in the driver do not change in this spec.
- **The fallback fires on any dispatch that ran on Fable** (ask 1 names the judge, planner and architect; under `sonnet-builds` a missed story's retry also runs on the Fable gate, so the one helper covers it too). A dispatch on another family never receives the Fable refusal, so for workers and Haiku the helper is a no-op. The ADR-015 line in story 04 is the record of the owner's exception (Opus judging Opus), not a new rule.
- **The gate list is stated as it is, not as the ask shortened it** (ask 4): `lead-architect` also runs on the gate when a story misses twice at any tier (`.claude/commands/vulyk-build.md`), so the hint names it with that condition.
- **Asks 5, 6 and 7 are the Queen's post-build steps, not stories** (no story quotes them): (5) `modelSettings.claude-fable-5-1.effortLevel` from `xhigh` to `high` in both accounts' settings files outside this repo; (6) the YouTube_AI judge scripts after that hive's build of video 8, as its own small task, `--model opus` on every run until then; (7) release 0.39.0 together with horizon-audit, then the six hives' upgrade from 0.38.0 with an audit of their edits, YouTube_AI last. Each of 5-7 is ticked in the build's final report to the owner; until (6) lands, the Queen says `--model opus` to the owner whenever that hive's judges are run.
- `CHANGELOG.md` and `VERSION` are release paperwork the Queen writes at ship (precedent `post-037-tails`); the CHANGELOG line for story 03 depends on the probe's outcome.
- `## Verification` names `tests/telemetry.test.sh --part telemetry` for the stories that touch `scripts/telemetry.sh` and `lead-review.md`: the `record` row contract lives in that part (post-037-tails, story 02). Recon confirms which part asserts on `lead-review.md`'s suite step (lines ~49-54, 82, 94) and whether `tests/council.test.sh` or `tests/model-profile.test.sh` pin a code list or `top-model.sh`'s help text; a yes adds that file to the story named below before dispatch, a no changes nothing.
- Known wave-check noise, accepted: `verify-gap` on stories 02 and 04 (prose files have no test of their own).
- Story 03 carries `model: opus` (a probe to design and read, and a reviewer protocol whose failure mode is a missing `SUITE:` line). Stories 01, 02, 04 carry no model line: no story is routine enough for `model: haiku` once the two-line `cacheTtl` edit is folded into 02.

## Stories

**Wave 1** (parallel; `## Files` disjoint)
- `fable-fallback-01-driver` — `vulyk-cycle.js`: the refusal detector, one redispatch on `opus` for any dispatch not already on it, `fallbacks` in the return value and a console line; the failing case in `tests/driver.test.sh` (ask 1).
- `fable-fallback-02-record-and-commands` — `telemetry.sh` `ENUM` gains `fable_limit_fallback` (+ `docs/telemetry.md` row, test case); `/vulyk-build`, `/vulyk-review`, `/vulyk-plan` get the redispatch rule and the three records (journal, telemetry, owner line); `lead-review.md` frontmatter gets `experimental: cacheTtl: 1h` (asks 1, 3).

**Wave 2**
- `fable-fallback-03-review-background-suite` — the probe, then `lead-review` starts the suite in the background and reads the diff meanwhile; stop rule on a failed probe (ask 2). Blocked by 02. `model: opus`.
- `fable-fallback-04-gate-docs` — `top-model.sh` hint, `docs/model-cascade.md` (gate scope, hive judge rule, the fallback), ADR-015 one-line amendment (asks 1, 4). Blocked by 01, 02.

## Contracts
- **Refusal detector** (story 01 provides in the driver; story 02 writes the same words into the commands): a dispatch is *refused* when the text it returned, or the message of the error `caught()` swallowed, contains `You've reached your Fable limit` or `model_requires_usage_credits`. Nothing else matches.
- **Driver fallback** (story 01; `/vulyk-build` consumes the return, story 02): `const FALLBACK_MODEL = 'opus'` beside the `RETRY` logic. Every `agent()` dispatch (workers, the retry, `review`, `review-top`, `review-second`, `opus`, `haiku`) goes through one helper: on a refused result whose `model` is not already `FALLBACK_MODEL`, it dispatches once more with the same prompt and `agentType` and `model: FALLBACK_MODEL`; a second refusal returns the refused result to the existing path. Each fallback is pushed to `fallbacks: [{agent, where, from, to}]` (`agent` = the agent type, `where` = `round-<n>/<seat>` or the story id, `from` = the model passed or `""`, `to` = `opus`) and printed as one console line `fallback: <agent> <where> <from> -> opus (Fable limit)`. The driver's final return value carries `fallbacks` (an empty array when none). The clerk is never used for it.
- **Telemetry code** (story 02): `fable_limit_fallback`, appended to `ENUM` in `scripts/telemetry.sh` and to the table in `docs/telemetry.md`: value `1`, threshold `0`, `model` = `fable` (the family refused), `agent` = the agent type token, `ref` = `<slug>:<where>:<agent>` (the dedupe key, stays home). Written by `scripts/telemetry.sh record` in the argument form the `driver_refused` call in `vulyk-build.md` already uses; never by `scan`. `check` accepts it because it is in the enum; older bundles are unaffected (append-only).
- **Journal line and owner line** (story 02): `fallback: <agent> <where> <from> -> opus (Fable limit; ADR-015 exception)` through `scripts/journal.sh`, the way `/vulyk-build` writes its launch line; then one sentence to the owner in the Queen's next message. Workflow path: one of each per entry in the driver's `fallbacks` when it returns. Solo path (`dispatch:review`, `/vulyk-build` step 3) and the no-Workflow hive loop, and `/vulyk-review`, `/vulyk-plan`: right after the redispatch, same words.
- **`lead-review` frontmatter** (story 02): after the existing keys, `experimental:` and on the next line `  cacheTtl: 1h`; no other frontmatter key changes. **`SUITE:` line** (story 03): line 3 stays `SUITE: ok|FAIL|TIMEOUT <N>s budget <B>s|none` with the same meaning and the same `timeout $((${VULYK_SUITE_TIMEOUT:-590}+5))` wrapper; the reviewer never returns before the suite's result is known; `record-seat` and `judge` are untouched.
- **Gate hint** (story 04): `scripts/top-model.sh --help` and `--explain` print one line: `gate: the Tier 4 review, the Tier 4 planner, lead-architect (Tier 4, or a story missed twice), a missed story's retry. A hive's own judge: bash scripts/model-profile.sh --role seat, and pass --effort explicitly.` Exit codes and every existing output line unchanged.

## Rejected
- `model-profile.sh --role <role> --fallback` (the study's candidate story 1): a flag, a test and a driver argument to deliver one word the owner fixed as `opus` for every role and profile. A second profile that wants another fallback adds the flag then; today it is a constant and a documented exception.
- The driver writing the journal line and the telemetry row itself through `cycle-clerk`: the clerk is the driver's only shell and its verbs (`advance|status|release`) are a whitelist on purpose (ADR-011). The record is a few minutes late on the Workflow path; it is still written once per event and never lost, because it rides the driver's return value.
- Claude Code's own `fallbackModel` chain: by the docs (brief, `## Recon`) it never fires on billing or rate-limit errors, and this is one.

## Integration gate
`bash tests/full-suite.sh`

## Descoped

- Ask 2, the background suite in `lead-review`: the story 03 probe failed (a subagent returns before its background command ends and is never told it ended); the owner chose to drop the ask on 2026-10-27. The suite step stays as it is; story 02's one-hour cache carries F3, and the 3.11 spend comparison checks it.

## Plan deltas

<!--
The lines below are the cycle's confirmation markers (docs/cycle.md); each placeholder is replaced by
the command or script that owns it, and scripts/ship-check.sh reads them all. Approved is the owner's
word, the stop at Tier 2-4; Briefed is written by `cycle.sh briefed` instead, at Tier 1 ("via
mini-brief"), with `--go`, or in no-question mode ("assumed"). Either closes stage 02. Council and
Checked close stages 04+05 together: a GREEN council row is enough on its own, and Checked is the
owner's override in either direction, newest timestamp wins. No line of this comment may start with
a marker: the scripts read the first line that does.

There is no default tier: `cycle.sh open-round` refuses to open a round while the `**Tier:**` line above
is missing or unparsable.
-->
**Approved:** Andrei, 2026-10-27 («Одобряю»)
**Briefed:** <written by scripts/cycle.sh briefed - stage 01+02 on the straight-through path (--go, Tier 1): "via grill, <owner>, <date>" (or "via grill (assumed)" / "via mini-brief"). Alternative to **Approved:** above.>
**Branch:** vulyk/fable-fallback
**Checked:** <written by scripts/human-check.sh after the owner has looked - stage 05, and the override for stage 04+05. /vulyk-ship refuses without either this or a GREEN **Council:** line.>
**Council:** <written by scripts/cycle.sh judge/escalate - stages 04+05: "<GREEN|RED|ESCALATE|STALE> round <N>, <date>, at <sha7>, pack <fp12>[ - red: 2,5]", appended once per round.>
**Shipped:** <written by scripts/ship-check.sh --record - stage 06: the published version, and where>
