# A/B-run fixes: Sonnet builds by default, one blind seat, a narrow repair path, fewer stops (plan)

**Tier:** 3 · **Spec slug:** `ab-run-fixes` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-001 (cycle state contract), ADR-008 (approval stop), ADR-013 (light VULYK: roster D1, repair D4), ADR-015 (model ladder, repair on `opus`), ADR-020 (model profiles), ADR-022 (horizon), ADR-023 / ADR-029 (gate split, `cycle.sh suite`), ADR-024 (no background reliance), ADR-025 (red receipt); cards `full-round-for-a-narrow-fix`, `test-gate-one-long-limit` (split gates, never raise the limit), `shell-needs-gnu-or-bash4`, `host-internals-in-public-repo`
**Depends on:** v0.48.0 + branch `fix/law5-and-red-seal` (`d27a4da`, `ed7e7de`, `75273d2`, unreleased)

## Goal
Fix what the A/B run of 0.47.0 found. The run measured equal quality, 1.8x the weighted tokens and 18 stops against 4. Four changes cut the cost:
- `sonnet-builds` is the profile VULYK recommends.
- A Tier 3-4 round has one blind seat.
- The Tier 4 second reviewer runs only when there is a reason for it.
- A one-ask, one-file repair gets a review-only round.

These changes remove the stops:
- The plan is committed before `claim`.
- A worker's leftover edits are re-dispatched, not fatal.
- An unknown story status is an error.
- `verify_run` no longer eats stdin.
- A refused verification line comes with a ready replacement.
- The Queen's cache does not idle past an hour behind the driver.

The front door gets lighter: bootstrap reads facts from the repo, the grill asks in batches, horizon runs only on request, one approval confirms and builds, the installer asks nothing about telemetry, and the litopys offer respects a user-scope install. The README states the run's result honestly. The measurement itself is a separate study spec.

## Assumptions
- Coverage (drone-coverage, 2026-11-08), partial asks carried forward:
  - Ask 5: the narrow repair's verification is the lines of the stories that named the file, not strictly "this file's tests"; kept, since those are the file's covering tests in practice.
  - Ask 6: story 06 also drops the all-areas map at bootstrap start (map built by plan recon) and the bootstrap-end handoff/clear push; added to story 06.
  - Ask 9: a single wave longer than ~55 min still lets the cache lapse (no boundary to return at).
  - Ask 15: story 06's README text must say both that the model cascade was not measured and that the 1M-window claim is unconfirmed; added to story 06.
  - Ask 20: `open-round`'s dirty-tree refusal is unchanged; only `claim`/`advance --claim` re-dispatches.
- **Ask 13 is accepted as is.** The `stamp-red` seal (`d27a4da`, `ed7e7de`) and the Law 5 close-story guard (`75273d2`) are on this branch. No story.
- **Ask 22 is not a story here.** The Queen writes it as a separate study spec, `ab-measurement` (HANDOFF §8: 5 tasks, hidden tests, a blind judge from another vendor, an operator script, the decision threshold written before the runs). It is not run without the owner's «да» (~31M weighted).
- **Out of scope:** F6 and F7 are the host project's own scripts, not VULYK. F8 was partly fixed in 0.39. None of them is an ask.
- **CHANGELOG.** `CHANGELOG.md` would sit in every story's `## Files` and serialize every wave. Instead, each story ends `## Implementation notes` with one `CHANGELOG:` line, and the Queen pastes these lines under `## [Unreleased]` after each wave. CHANGELOG is a paperwork path and is named by no story, so this is not a Law 5 edit.
- **Ask 2, second reviewer.** The fold rule stays "BLOCK if either". A second reviewer called after a BLOCK adds findings to the one repair story (recall). It never overturns the BLOCK.
- **Ask 2, the risk set** is narrow and fixed in code, with no Profile row or env (C3).
- **Ask 3, carry.** A blind seat is carried unless round n-1's repair story touched an ask that the seat's report judged (C4). Blind seats judge every ask, so in practice only a repair of regressions alone carries one.
- **Ask 5, what counts as narrow (C5).** A RED round is narrow when it has exactly one RED item (one RED ask or one anchored finding) and that item reaches exactly one non-test file. The next round is review-only even when the RED came from a blind seat: the owner chose "без слепых мест". A review-only round counts against the ceiling like any other RED round.
- **Ask 4** reverses a measured choice: `docs/token-economy.md` records that workers lost their prefix behind a suite 23 times (~40% of `worker-code`'s cost). The owner's ask rests on the newer A/B evidence. Story 01 states the trade in that doc.
- **Ask 7, a fresh map slice:** the slice exists and no commit touching the area's paths is newer than its `last-verified:` date.
- **Ask 8:**
  - "Existing repo" means `memory/memory.md`'s `## Codebase map` lists at least one module.
  - The batch of 4 is one `AskUserQuestion` call.
  - Only at Tier 3-4 does approval start `/vulyk-build` in the same turn. Tier 2 keeps its fresh-session build.
- **Ask 9, mechanism:** the driver returns `checkpoint` at a wave or gate-step boundary after 50 min, and `/vulyk-build` relaunches it. A single wave longer than ~55 min still idles the cache, and the docs say so.
- **Ask 11:** the parts and the one-step-per-call clerk loop stay (owner rule). Only the commit per step goes.
- **Ask 14:** a new `--telemetry ask` value. A bare install no longer asks and leaves telemetry off. `on|off` are unchanged.
- **Ask 17:** `status` exits 2 with `ok:false`, so a driver run stops loudly where it used to skip in silence.
- **Ask 18 is repro-first** (story 05). If both repro tests pass on HEAD, the story records "not a bug" and keeps the tests. The story's red receipt comes from ask 20's test, because a receipt cannot rest on a test that may be green.
- **Ask 20:** `claim` accepts dirty paths only when they lie in the `## Files` of a `todo` story of the current wave. `open-round`'s refusal is unchanged. The two-miss stop is unchanged.
- **Ask 15 wording:** no host or client project name. The run is "an A/B run on an open-source Laravel app" (owner rule, public repo).
- **No new `## Commands` row** (`CLAUDE.md` byte cap). New tests ride in existing suites and parts.
- **Order.** By price, ask 1 is in wave 1. The council asks (2, 3, 5) cannot share wave 1 with story 01 (`lead-review.md`, `docs/model-cascade.md` and `docs/token-economy.md` overlap), so wave 1 takes the cycle fixes, whose files are disjoint, and the council follows in wave 2. Every wave lands before the round, so the order only matters if a build stops partway. The `mass-audit-fixes` spec follows this one on the same files.

### Recon questions for `drone-scout` (answer before dispatch; each may widen a story's `## Files` or fix a `## Verification` part name)
1. Which `scripts/model-profile.sh` call prints only the active profile name: no argument, `--get`, or the first line of `--explain`? Story 02 names it in `vulyk-plan.md`, and prompt-check rejects an unknown flag.
2. Where are `model-profile.sh --recommend`'s 3 textual importers and 2 textual tests? If `session-start-brief.sh` or `install.sh` prints the recommendation, that file joins story 01. `session-start-brief.sh` is story 06's, in a later wave, which is fine.
3. Does any test assert `cacheTtl` in `lead-review.md`, `worker-code.md` or `worker-test.md`? Look in `tests/maintenance.test.sh`, `tests/telemetry.test.sh` and the prompt-check fixtures. If one does, the file joins story 01.
4. Which test asserts the text of `templates/grill.md` ("one question per turn"), `vulyk-plan.md` step 3a or step 9? It joins story 02, and its command replaces story 02's default `bash tests/maintenance.test.sh`.
5. Parts that tests in `tests/cycle.test.sh` and `tests/council.test.sh` belong to:
   - In `tests/cycle.test.sh`: which part asserts `status`'s story counting, and which asserts `claim`'s dirty-tree refusal? Defaults are `gates` (story 03) and `safety` (story 05).
   - In `tests/council.test.sh`: which parts assert `required_seats_for_tier`, `carry_seats`, Tier 4 `fold_reviews` and `cmd_repair`? Defaults are `roster`, `seats`, `seats` and `verbs` (story 04).
   - What is each named part's current duration against its 300 s cap?
6. How do `fold_reviews` and `vulyk-cycle.js` (`:235-238`) name and find the two Tier 4 review reports? Story 04 keeps the existing names.
7. How does `cmd_repair` build `## Files` (a union of what) and `## Verification`? Story 04's narrow test depends on it.
8. A defect card's `check:` contract: does `defects-check.sh` hand each `*.fixture` to the check command, as `git-guard.sh --check <file>` does? Story 04.
9. What does `.claude/hooks/handoff.py:777` print, and on what condition (percent of which window)? Does `vulyk-bootstrap.md:53` itself tell the owner to `/vulyk-handoff` + `/clear`? Story 06.
10. Which docs beyond those named state the Tier 3-4 roster (`council-opus` beside `council-haiku`) or the Tier 4 "two reviewers"? Candidates: `docs/architecture.md`, `docs/pipeline.md`, `docs/getting-started.md`, `docs/faq.md`. Story 04.
11. Which docs state the installer's telemetry question, the bootstrap's map step, or the "one question per turn" grill? Story 06 (`docs/getting-started.md`, `docs/telemetry.md` are named) or story 02 (`docs/command-reference.md` is named).

## Stories

Ask 13: accepted as is (see `## Assumptions`), no story. Ask 22: separate study spec `ab-measurement`.

**Wave 1**
- `ab-run-fixes-01-model-profile`: `--recommend` always `sonnet-builds`, the `/vulyk-models` quiz order, `cacheTtl: 1h` removed from three agents (asks 1, 4; `red: required`)
- `ab-run-fixes-02-plan-command`: profile in the plan header, no scout for a fresh map, a grill in batches of 4, horizon only by `--horizon` in a mapped repo, approval confirms the asks and starts the T3-4 build, spec committed before the stop (asks 1, 7, 8, 10)
- `ab-run-fixes-03-cycle-fixes`: `verify_run` stdin, unknown `status:` is an error, close-story suggests a ready line, `suite` commits once (asks 11, 16, 17, 19; `red: required`)

**Wave 2**
- `ab-run-fixes-04-council`: one blind seat, the Tier 4 second reviewer on BLOCK or a risk path, no carry over a touched ask, a narrow repair with a review-only round plus its card check (asks 2, 3, 5; `red: required`; `model: opus`)

**Wave 3**
- `ab-run-fixes-05-driver`: leftover edits re-dispatched, a `checkpoint` return before 50 min, the manual-wave repro (asks 9, 18, 20; `red: required`)
- `ab-run-fixes-06-onboarding-readme`: bootstrap from repo facts, docker `exec -u`, no telemetry question, litopys at user scope, the README's honest result (asks 6, 12, 14, 15, 21; `red: required`)

## Contracts
- **C1, roster** (`required_seats_for_tier`, story 04). Tier 1-2: `review`. Tier 3-4: `review` plus exactly one blind seat, `haiku` when `client_path_filled`, else `opus`. `ROUND` keeps freezing `seats=`, and a round opened before this change keeps its frozen seats.
- **C2, Tier 4 second reviewer** (story 04; the driver half must hold for story 05 too):
  - `open-round` freezes `second=risk|none` in `ROUND`. `risk` means a path in the range `lead-review` reads for that round matches C3.
  - When `second=risk`, `status --json` `next` names `dispatch:review,review2,<blind>` at once.
  - When `second=none` and the recorded `review` is BLOCK with no `review2` yet, `next` is `dispatch:review2` once.
  - `judge` folds `review` and `review2` (BLOCK if either) when `review2` exists; otherwise it judges `review` alone.
  - The driver dispatches exactly the seats `next` names, never doubling by tier. `review2` is one `lead-review` on `second_model`.
  - Report file names follow the existing fold. A worker that has to rename one reports it in `INTERFACES`.
- **C3, risk set** (fixed, case-insensitive, matched on the diff's `--name-only` paths):
  - Security: a path segment or file stem equal to, or starting with, `auth`, `security`, `secret`, `crypt`, `permission`, `password` or `credential`, or a file named `.env` or `.env.*`.
  - Data: a segment equal to `migrations` or `migrate`, a file stem `schema`, or a `*.sql` file.
  - It is named in `docs/cycle.md`.
- **C4, carry** (`carry_seats`). A round n-1 blind seat that was GREEN or N/A is carried into round n unless round n-1 has a repair story that touches an ask number the seat's report judged with an `ASK <n>:` line. A repair touches ask N when its `## Requirements` has a line starting `> N. ` or its `## Findings` has `[ask N]`. Rounds with no repair story (STALE, a commit after GREEN) carry as before.
- **C5, narrow repair** (`cmd_repair`, `open-round`, `suite`, `record-seat`):
  - **When.** A RED round with exactly one RED item whose reach (the anchored finding's `path:line`, else the `## Files` union `cmd_repair` builds) is one non-test file.
  - **The story.** `repair` writes the story with `narrow: true`. Its `## Files` is that file, its `exact` tests from `symbol-map.sh --exact`, and `docs/defects/*`. Its `## Verification` is the `## Verification` lines of the stories whose `## Files` named that file. It gets one acceptance line: the class card is added or updated in the same commit. `worker: worker-code` and `model: opus` stay (ADR-015, Law 5).
  - **The next round.** `ROUND` has `seats=review` and `narrow=1`. `suite` writes a finished log keyed to the round head, `SUITE: none - narrow repair round`, and runs no step, so `record-seat` accepts the review. Everything else is a full round, as today.
- **C6, unknown status** (story 03). `status` and every verb that derives it exit 2 with the last line `{"ok":false,"verb":"<verb>","error":"unknown story status '<v>' in <file>"}`. The accepted values are those `cycle.sh` recognises today.
- **C7, close-story hint** (story 03). The refusal of a segment that is not a Commands cell keeps its exit code and message, then prints up to 3 lines `try: <cell>`. These are the non-`round-only` cells whose first two words equal the segment's. With none, it prints one line `try: see ## Commands in <constitution file>`.
- **C8, suite commit** (story 03). `suite --commit` commits `council/round-N/suite.log` only on the call that returns `done:true`. Earlier steps leave it written and uncommitted (it is paperwork). The step, part and cap rules are unchanged.
- **C9, leftover** (story 05). `claim` and `advance --claim` accept a tree whose dirty paths are paperwork, or lie in the `## Files` of `todo` stories in the current wave. The result adds `"leftover":["<story file>",...]`. Any other dirty path is refused as today.
  - The driver's retry of a missed story in `leftover` tells the worker that a previous attempt left edits in its `## Files`: read `git diff`, finish, close. The retry model and the two-miss stop are unchanged.
- **C10, checkpoint** (story 05). The driver args gain an optional `checkpoint_min` (default 50; tests pass 0).
  - Before starting a `build:W` wave, a seat dispatch or the next `gate` step, a driver past `checkpoint_min` since launch returns `{"status":"checkpoint","next":"<status next>","elapsed_min":<n>}`, with `release` in `finally` as now.
  - `/vulyk-build` journals it and relaunches with a fresh stamp.
- **C11, plan header** (story 02). `templates/plan.md` gains `**Model profile:** <name>` on the header block. It is filled by the command from recon Q1, written by the Queen at Tier 1-2 and passed to `queen-planner` at Tier 3-4. It is not a cycle marker.
- **C12, red labels.** Each `red_reason` is the label the story's test prints on failure:
  - 01: `model-profile: --recommend gives sonnet-builds on every plan`
  - 03: `status: an unknown story status is an error`
  - 04: `seats: Tier 3 with a Client path requires review and haiku only`
  - 05: `claim: leftover edits of a wave story are accepted`
  - 06: `brief: no litopys offer when the plugin is enabled at user scope`

**Rejected alternative (ask 9):** `/vulyk-build` ends the Queen's turn with a handoff before a long driver launch. The cache still dies past the hour, and re-entry pays a full re-prefill plus the handoff read. That moves the cost without removing it. A driver that returns at a boundary before 50 min keeps the prefix warm with one short relaunch turn. Also rejected: a Queen-side poll or `/loop`. ADR-024 rules out background reliance, and each poll is a full turn anyway.

## Integration gate
`bash tests/full-suite.sh`

## Descoped

*(empty)*

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
**Approved:** Andrei, 2026-11-08 («да»)
**Briefed:** <written by scripts/cycle.sh briefed - stage 01+02 on the straight-through path (--go, Tier 1): "via grill, <owner>, <date>" (or "via grill (assumed)" / "via mini-brief"). Alternative to **Approved:** above.>
**Branch:** <written by /vulyk-build before wave 1 - stage 03: the branch every story commit lives on>
**Checked:** <written by scripts/human-check.sh after the owner has looked - stage 05, and the override for stage 04+05. /vulyk-ship refuses without either this or a GREEN **Council:** line.>
**Council:** <written by scripts/cycle.sh judge/escalate - stages 04+05: "<GREEN|RED|ESCALATE|STALE> round <N>, <date>, at <sha7>, pack <fp12>[ - red: 2,5]", appended once per round.>
**Shipped:** <written by scripts/ship-check.sh --record - stage 06: the published version, and where>
