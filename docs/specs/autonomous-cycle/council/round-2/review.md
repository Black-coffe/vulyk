<!-- seat: review · model: fable+opus · round: 2 · head: 4706bc0 · pack: ab62eb9de683 · attempt: 1 · recorded: 2026-09-13T14:03:55Z · verdict: BLOCK -->
VERDICT: BLOCK

Folded review seat, round 2 (Tier 4): lead-review (Fable 5.1) = PASS (0 critical / 4 major / 18 minor); second reviewer (Opus 5) = BLOCK (1 critical / 5 major / 8 minor). Folded verdict = the stricter of the two = BLOCK. Both full reports follow, nothing trimmed.

===== lead-review (fable) =====
VERDICT: PASS

# lead-review - autonomous-cycle, council round 2 (the repaired branch)

Repository `E:\Projects\vulyk`, branch `vulyk/autonomous-cycle` at `4706bc0` (round 2 open at `19667a3`, pack `ab62eb9de683`). All paths relative to that root. MAIN tree only; `.vulyk/court/` never entered; nothing written into the repository. Every probe below ran in a `mktemp` repo seeded the way `tests/council.test.sh` seeds its own.

No critical finding, so PASS. Four majors and eighteen minors follow, none trimmed.

## What I ran and what held

- Syntax gates: `git ls-files '*.sh' | xargs -n1 bash -n`, `python -m py_compile .claude/hooks/*.py`, `git ls-files '*.json' | xargs -n1 jq -e .`, `node --check .claude/workflows/vulyk-cycle.js`, `bash .claude/hooks/handoff.sh status` - all exit 0.
- `bash tests/cycle.test.sh`: exit 0, 36 `ok` lines, 0 `::error::`, 27 s. `bash tests/council.test.sh`: exit 0, 243 `ok` lines (149 at round 1), 0 `::error::`, 3 min 17 s.
- Law 3 over the seven story commits (`git show --name-only` vs each story's `## Files`): 22 -> `vulyk-cycle.js`; 23 -> the three command files; 24 -> the three seat prompts, `lead-review.md`, `CLAUDE.md`, ADR-001, `command-reference.md`; 25 -> `CHANGELOG.md`, `templates/plan.md`, `ci.yml`; 19/20 -> `cycle.sh`, `council.test.sh`; 21 -> those plus `lib.sh`, `cycle.test.sh`. Each also carries its own story file, and 19/20/21 carry `memory/stats/scope.jsonl` - the ride-along delta 6 R4 decided. No file outside a story's list. `CLAUDE.md` marker count is still 4.
- `## Descoped` is empty and I found nothing that should have been there except what M2 and m5 name (a story that delivered less than its own criterion without a line on the record).
- `## Next circle`: every file the sixteen items name is untouched since `f0d206b` (`git diff --stat` empty for `docs/cycle.md`, `docs/pipeline.md`, `install.sh`, `vulyk-evolve.md`, `vulyk-ship.md`, `top-model-brief.sh`, `docs/architecture.md`, `acceptance-log.sh`, `ship-check.sh`, `drone-docs.md`, `vulyk-bootstrap.md`), and each defect is still present where it was: `attempts` counts seat files (`cycle.sh:730`), `row_exists` prefix-matches the round (`:171`), `**Council:**` appends at EOF (`:743`), `drone-acceptance` in `drone-docs.md:14` / `acceptance-log.sh:72` / `ship-check.sh:227`, `cycle.md:25` / `pipeline.md:22` / `bootstrap:9` wording, `repeat` dead in `wave_story_json` (`:1305`), `wave_stories` lists every todo (`:271`), `architecture.md:76`, `install.sh:324,340` unquoted `$wanted`, the `\>` timestamp compare (`:692`), `evolve` `date -r`/`-7 days`, `>>` ledger append (`:737`), `claude --version` in the hook (`:47`), and no `claim`/`release`/`DRIVER`/`--stamp` anywhere in `cycle.sh`. Journal stage `tier:default` is gone - on the record via R21, not silent; `04-council:open` and `resumed` remain. Nothing in the next-circle list was silently fixed or silently broken.
- Live: `status --json` on this spec now returns `round_dir: "docs/specs/autonomous-cycle/council/round-2"`, `tier: 4`, `stale: false`, `missing: [sonnet, opus, review]` - the R25 defect round 1 saw live is gone.

## Round-1 findings - status

Keyed by delta 6's R-numbers; original ids in brackets (lead-review N / second reviewer C-, M-, m-). Test citations are `tests/council.test.sh` scenario names with approximate current line numbers.

| R | Round-1 ids | Status | Evidence |
|---|---|---|---|
| R1 | LR 1, C-1 (critical) | **met** | `cycle.sh:357` routes `repair` through `round_is_stale`; `realverbs` (~1413): `open-round --commit` -> `record-seat` x3 (Tier 2) -> `judge --commit` -> `status` asserts `next:"repair"`, `verdict:"RED"`, `red:[2]`, `round_dir`; a `src/x.txt` commit flips it to `open-round`; rounds 2-3 RED -> `escalated`. |
| R2 | LR 2 (critical) | **met** | `:306` computes `stale` with no seat-file gate, `:349` routes it to `open-round`; `stalerd1` (~1463) asserts `stale:true` + `next:"open-round"` with no seat file and again with one present. |
| R3 | LR 3, C-2 (critical) | **met** | `missing_required_seats` `:149` skips a seat with `attempt-2.md`; `exhaust1` (~1482): two malformed haiku reports -> `missing` = opus,review,sonnet -> after those three `next:"judge"` -> row `haiku:"ABSENT"`. C-2's second half: `lead-review.md:29` states the first-line rule. |
| R4 | LR 4, C-3(b), LR 33 (critical) | **met** | `close-story --commit` stages `memory/stats/scope.jsonl` (`:1401`); `lib.sh:45` whitelists it; `cstory6` (~1130): `close-story --commit` then `open-round --commit` with no `git add -A`, tree clean after both. |
| R5 | LR 5, C-3(a) (critical) | **met** | Fresh gate `:1652-1661` and STALE fold `:1639-1647` call `write_ceiling_escalate` (`:566-573`); `oceil1` (~1258) asserts row/plan line/`## Needs a human`/journal/`status` = `escalated`, idempotent (~1273); `oceilc1` (~1280) `--commit` leaves a clean tree. `escalate` is its own verb (`:788-855`); `esc1`-`esc4` (~1299-1350) cover missing seats, `--reason`/note, judge fallthrough, PAUSE. Driver stops on `ok:false`: `vulyk-cycle.js:117`, `vulyk-build.md` step 2. The STALE-fold gate is not in the suite - I drove it (probe 1): STALE + ESCALATE rows, line, block, journal, `status` = `escalated`, clean tree, second call adds nothing. See m5. |
| R6 | LR 6, C-3(c) (critical) | **met in code** | `vulyk-cycle.js:80,105-111` per-file `attempts`, second red `close-story` -> `stop:{verb,file,error}`; `:131-136` every seat report recorded, one re-ask on exit 4; `vulyk-build.md` `build:<wave>` two-strike rule and `dispatch:<seats>` row match. Not runnable here (no Workflow). Remaining gap: an empty *worker* report (M4). |
| R7 | LR 7, M-4 (major) | **met** | `council/REOPEN` written by `reopen` (`:1726`), `reopen_names_round` (`:455-462`) exact-match, `status` `:353`; `realverbs`: after `reopen --commit` `status` says `open-round` and round 4 opens. |
| R8 | LR 8 (major) | **met** | `ask_rest_of`/`ask_evidenced_of` (`:1020-1028`) shared by `record-seat` and `seat_ask_lines`; `dashev` (~834): `saw: READY - 6/6 ok` accepted at attempt 1, no `unevidenced` header, judged GREEN, `red_unevidenced:[]`. |
| R9 | LR 9, LR 10 (major) | **met** | `taint_reason` `:1004-1016` path-anchored; fixtures ~758-840 cover both lists, plus the live round-1 false positives under the real slug (~801) and a real path / story id still tainted. Seat prompts carry `slug`/`round`/`court` only: `vulyk-cycle.js:56-57`, `vulyk-build.md` dispatch row, `vulyk-review.md` step 3; `round_dir` goes to `lead-review` only (`:58-59`). |
| R10 | LR 11 (major) | **met** | `:700` `half = max(2, ceil(A/2))`; `halffloor1` (A=1 one RED -> repair), `halffloor2`/`2b` (A=2: one RED repair, two RED `half`) ~391-424; A=7 fixtures unchanged. |
| R11 | LR 12, LR 13, C-4 (major / critical-if) | **met as decided; see M1** | (i) delimiter `VULYK_${stamp}_${seat}_${attempt}` in `vulyk-cycle.js:121-124`, `EOF` gone from JS and both commands; `stamp` absent from every seat prompt. (ii) `command_cell_exists` + `verification_segments` `:1265-1290,1346-1365`; `cstory3` (not a cell -> exit 2 naming it), `cstory4` (`&&` segments), `cstory5` (`none - reviewed by lead-review` runs nothing, scope-check still runs) ~1044-1128. I probed the real `CLAUDE.md`: the `\|` rows (`git ls-files '*.sh' \| xargs -n1 bash -n`, the jq row) match, `echo hi` does not. Story 21's own close ran through this gate on the real file. |
| R12 | LR 14, LR 34 (major) | **met** | `vulyk-cycle.js:69-78`: at `st.tier === 4` two `lead-review` dispatches (`TOP`, `SECOND`) folded to the stricter first line, one `record-seat … review`; `reviewPrompt` carries `round_dir`, spec, branch, head and the three pointers; `vulyk-build.md` step 1 passes `second_model`. |
| R13 | LR 15, m-8, LR 29, m-5 (major) | **met** | `CHANGELOG.md` 0.12.0: seats by tier, `env` rule, court as honour clause, both drivers' stop/bound rules, staleness rule, `### Upgrading` says never-deletes / hand removal and drops the "real pre-0.12 install" claim. One stale phrase remains (m14). |
| R14 | LR 16 (major) | **NOT met** | See M2 - the story's note claims a cross-check that its cited source does not contain. |
| R15 | M-1, M-2 (major) | **met** | Three prompts, ADR D5, `CLAUDE.md:99-103`, CHANGELOG restated; `grep read-only` over the prompts/ADR returns only `council-haiku.md:31` (browser navigation, not the court). Reduction commit `:1456-1468`; `courtred1` (~1353): court `status --porcelain` empty, `HEAD:docs/specs/<slug>/plan.md` fails, main HEAD unchanged. Residuals in guides: m10, m11, m12. |
| R16 | M-5, LR 32 (major) | **met** | `:669-679,703-704` any required seat ABSENT with nothing RED and review != BLOCK -> `env`, note names the seats, block lists attempt files; `exhaust1` (haiku ABSENT -> env), `envpartial2` (review ABSENT -> env, ~1512), `envpartial3` (ABSENT + a RED -> repair, ~1527). |
| R17 | M-6 (major) | **met** | `git_commit_or_fail`/`commit_paperwork` `:470-488`, checkout checked `:939-951`, worktree-add failure leaves no `ROUND` `:1446-1454`; `branchfail1`, `lockfail1` (briefed), `wtfail1` ~596-640. Residuals for `close-story` and `open-round` retries: m2, m3. |
| R18 | M-3 (major) | **met** | `:1367-1383` one `bash -c` per line; `cstory2` (`false` then `true` -> exit 4 naming `false`, status stays todo). |
| R19 | M-8, LR 28 (major) | **met** | `vulyk-pause.md` step 2, ADR D6, `command-reference.md:18` all say discarded and re-dispatched. |
| R20 | M-9 (major) | **met** | `vulyk-review.md` steps 2-3 dispatch exactly `missing`; second reviewer only when `review` is missing. |
| R21 | M-10, m-1, LR 23, LR 20 (major) | **met** | `templates/plan.md:3` `<1\|2\|3\|4>` + the refusal sentence; `tier_of` `:107-117` never writes; `open-round` refuses `:1603-1610`; `status` `tier` `:312-316`; STALE fold writes `""` for a non-required seat `:1505-1510`; `tierdefault` (~279: `tier:null`, no `journal.md` created), `notier1` (~297), `oround1` precondition (~1178), `stalenr1` (~1541). |
| R22 | M-11 (major) | **met in YAML** | `ci.yml:159-165,198-204` `jq -e` exactly-once assertions after the real install and after `--upgrade`; the expression is well-formed; not executed locally, as story 25 states. |
| R23 | m-2, LR 24 (minor) | **met** | `lib.sh:42-48` anchored to `docs/specs/*/`, one `is_paperwork_path` for both callers; `cycle.test.sh:146-160` proves `src/council/x` and `src/journal.md` stale a check. |
| R24 | LR 17 (minor) | **met** | `:782-785` RED exits 0; every RED fixture now asserts exit 0 and the exact emit shape (~336-341). |
| R25 | LR 18 (minor) | **met** | `:331-338`; asserted in `realverbs`; visible live on this spec. |
| R26 | m-7 (minor) | **met** | ADR D1 seat-file row `at judge --commit (or the STALE fold)`. |
| R27 | M-7 (major) | next circle, untouched | confirmed above. |

Round-1 minors not listed above (19, 21, 22, 25, 26, 27, 30, 31, 35, m-3, m-4, m-6, m-9, m-10, m-11) are in `## Next circle` verbatim and were verified untouched.

## Critical

None.

## Major

1. `.claude/commands/vulyk-build.md` step 1 and `.claude/commands/vulyk-review.md` step 2 (`stamp="$(date -u +%s)"`), `.claude/workflows/vulyk-cycle.js:28,121-124` - **plan** (delta 6 R11 fixed the stamp as `date -u +%s` and states "unpredictability is the whole guarantee, and is stated as such") - The `record-seat` heredoc delimiter must carry entropy a seat cannot bound from its own clock: a whole-second Unix timestamp taken at run start is guessable by a seat that knows roughly when the run began, so a prompt-injected seat emitting `VULYK_<t>_<seat>_1` for a range of `t` terminates the heredoc before `record-seat`'s 40-line cap or any validation runs - the plan's stated premise does not hold, and a random token from the launcher (`od -An -tx1 -N8 /dev/urandom`, `$RANDOM$RANDOM`, the run id) costs one line in two files and restores it; an unset `args.stamp` also yields the constant `VULYK_undefined_<seat>_1`. Same conditional shape as round-1 finding 12: critical *if* the haiku seat's Browser MCP row is filled or the Client path serves untrusted content; major otherwise (this repo's Profile has neither).

2. `docs/specs/autonomous-cycle/autonomous-cycle-22-driver-acts-on-exit-codes.md` `## Implementation notes` (the R14 bullet) vs `docs/specs/autonomous-cycle/brief.md` `## Evidence` line 3; `.claude/workflows/vulyk-cycle.js:45-47,70,96,127` - **worker** (story 22's criterion named the check, the URL/date/what-changed record, and the "docs unreachable, calls left as they are" alternative) - R14 is not met and the note overstates it: it claims the four Workflow shapes (`parallel` over thunks, `pipeline(items, fn, then)` with a 3-arg shape, `phase(title)`, `agent(prompt, {agentType, model, effort, phase})`) were "cross-checked against the platform's Workflow reference … dated 2026-09-12 per brief.md `## Evidence` line 3, reused rather than re-fetched", but that Evidence line records only the CLI version gate, the Pro `/config` flag, the opt-in rule, the script path, MCP tool patterns and `AskUserQuestion` - nothing about any of those call shapes - so the verification claim rests on a source that does not contain it; the story must record a real fetch (URL, date, what changed) or say plainly the docs were not consulted and the shapes remain unverified. I did not fetch the docs (outside this reviewer's tools); the driver's API surface is exactly as unverified as round 1 left it, now with a note saying otherwise.

3. `.claude/workflows/vulyk-cycle.js:144-149` and `.claude/commands/vulyk-build.md` `repair` row; `scripts/cycle.sh:357` - **plan** (C11's repair prompt is built from `red` only; C3 carries no `review` verdict; neither driver bounds `repair`) - A repair step that lands nothing must end the run, and the Workflow's repair prompt must name the `lead-review` BLOCK when `red` is empty: `status` stays `repair` for as long as no commit lands (probe 5: two consecutive reads, `next:"repair"` both), so both drivers re-dispatch `queen-planner` at the top model on every iteration with no ceiling, and the Workflow's prompt for the most common Tier 2+ RED - review BLOCK with GREEN seats, this spec's own round 1 (`red:[]`) - reads "left the asks numbered [] unresolved … each addressing exactly one of those asks", which invites the planner to cut nothing. Same class as round-1 criticals 5/6 (a step that writes no state is an unbounded loop) with a non-deterministic trigger, so ranked major; the Queen may rank it up.

4. `.claude/workflows/vulyk-cycle.js:96-101` (`if (!reports[i]) continue`) - **plan** (R6 bounded `close-story` exit 4 and the empty *seat* report; it said nothing about an empty *worker* report) - A worker that returns an empty report must count as a miss under the two-attempt bound: today the story is skipped, stays `todo`, the next `status` re-dispatches the same worker, and the `attempts` map never increments, so the bound R6 built does not apply to the one failure mode that bypasses `close-story`. Shape: a worker agent returning nothing (aborted, timed out) - reasoned from the code, not observed.

## Minor

1. `scripts/cycle.sh:498` (`escalate_row_exists`), `:500` (`escalate_council_line_exists` is anchored by the trailing comma - fine), `:553` (`grep -qF "reason: $reason · round $n"`) - **worker** (story 19's note names this class and avoided it in `reopen_names_round`; story 21 built these) - The ESCALATE idempotency checks must match the round number exactly: `"round":1` matches a `"round":10` row and `round 1` matches `round 10` (probe 4), the defect next-circle item lead-review 21 records, now in two new sites; reachable after three `reopen`s.

2. `scripts/cycle.sh:1385,1402` - **plan** (R17's condition says "the re-run after unlocking commits it"; C2 says nothing about a `close-story` whose commit fails) - `close-story` must not leave a story `done` on disk when its commit failed, or must accept the retry: the `sed` lands before `git_commit_or_fail`, the retry answers `already done`, `status` then routes to `open-round`, and `open-round` refuses `working tree not clean` (probe 2) - an honest stop, but one only a hand commit clears, and the suite's `lockfail1` covers `briefed`, not this verb.

3. `scripts/cycle.sh:1623-1631` - **plan** (D1's crash rule; R17 made `ROUND` last-written but said nothing about the retry) - `open-round --commit`'s "already open at current HEAD, no-op" branch must commit a `ROUND` and journal it finds uncommitted: after a failed commit the retry exits 0 and leaves `docs/specs/<slug>/council/` and `journal.md` untracked until `judge --commit` sweeps them (probe 3), so a crash plus a fresh clone in between loses the round counter D1 exists to preserve.

4. `scripts/cycle.sh:1645,1659` vs `:784,853`; `.claude/workflows/vulyk-cycle.js:117`; `.claude/commands/vulyk-build.md` step 2 and step 4 - **plan** (C2 does not say whether exit 6 is `ok:true`; C11's `stop` shape has no `next`) - An escalation recorded by `open-round` must reach the Queen as the `escalated` terminal, not as a generic failed verb: `judge` and `escalate` emit `ok:true` on exit 6 while `open-round` emits `ok:false` with no `error`, so the Workflow returns `stop:{verb:"open-round",exit:6,error:undefined}` and the wake-up step prints an undefined error plus the journal tail instead of `## Needs a human`, and the fallback journals a duplicate `open-round exit 6` line - the record on disk is right, the report is not.

5. `scripts/cycle.sh:1639-1647` (untested); story 21 criterion "Test with `council/CEILING` = 1" for both gates - **worker** - The STALE-fold ceiling gate (the path round-1 finding 5 named first) must have a suite scenario; only the fresh gate is asserted (`oceil1`, `oceilc1`). Probe 1 shows it works today (STALE then ESCALATE row for round 1, plan line, block, journal, `status` = `escalated`, clean tree, second call adds nothing); the next change to `write_stale_row` or the gate cannot be caught.

6. `scripts/cycle.sh:553-560` (`write_escalate_row_for_round`) vs C7 - **worker** (story 21: "`## Needs a human` per C7") - The ceiling block `open-round` writes must list the RED asks of the round it stops (C7: "one row per RED ask with its evidence"): a RED round N judged earlier, then a code commit, then the fresh gate at N = ceiling writes `reason: ceiling`, `note: open-round ceiling`, `seats:` and no ask rows, although the RED row carries them.

7. `scripts/cycle.sh:1464-1466` - **plan** - The court's reduction commit must run with hooks and signing off (`--no-verify`, `-c commit.gpgsign=false`): the court shares the hive's hooks path and config, a pre-commit hook or a signing prompt fails the commit, the `|| true` hides that, and the court's `git status` then shows exactly the deleted-file lines the seat prompt names as a BREACH.

8. `scripts/cycle.sh:515-539` vs `:617-664` and `:1506-1528` - **worker** (story 21 added the third copy) - The seat scan (`<seat>.md` -> verdict, model, attempts; ABSENT when required) now exists three times - `cmd_judge`, `write_stale_row`, `write_escalate_row_for_round` - and must be one helper; a schema change edits three copies.

9. `scripts/cycle.sh:1281-1290,1353-1359` - **plan** (C2's `&&`-segment rule) - A `## Commands` cell that itself contains ` && ` (a hive whose quiet command is `npm run build && npm test`) can never be a verification line: the line is split on ` && ` before the byte-for-byte match, so the rule must match the whole line against a cell first or forbid `&&` inside cells.

10. `docs/command-reference.md:15` - **plan** (story 24 held this file but its criterion named only line 18; story 23 did not hold it) - The `/vulyk-review` entry must match the command after R20/R11: it still dispatches all four seats regardless of `missing` and records with `<<'EOF' ... EOF`.

11. `docs/cycle.md:28,46` - **plan** (R15's restatement listed D5, the prompts, CLAUDE.md and the CHANGELOG; not this guide) - The cycle guide must stop promising "a court that cannot see the hive's stories" / "so none of them can see the hive's own account" - the guarantee R15 withdrew.

12. `docs/adr/001-cycle-state-contract.md:293` - **plan** (story 24's non-goals scoped it out; its worker flagged it) - `## Consequences` must not say "Blindness has a mechanism and a detector instead of an honour clause" beside a D5 that now says the opposite.

13. `docs/adr/001-cycle-state-contract.md:95,145` and the D1 file table - **plan** (delta 6 R7/R21 changed C4; story 24 amended only D1's seat row) - D1 must list `council/REOPEN` (one writer, `reopen`, committed) and `tier=` as `ROUND`'s sixth line, and D2's `record-seat` precondition must read "not stale by `round_is_stale`" rather than "`head` in `ROUND` == HEAD", which story 17 made false.

14. `CHANGELOG.md` 0.12.0 `### Added` ("`lead-review` sits beside the blind seats unchanged") - **worker** (story 25 wrote from delta 6, which amends C10's "lead-review is unchanged" and gives the file a new rule) - The entry must say `lead-review.md` gained the machine-read first line.

15. `.claude/workflows/vulyk-cycle.js:88-90` vs `.claude/commands/vulyk-build.md` `briefed` row - **plan** (pre-existing from story 06; not in round 1) - The two drivers must agree on `next:"briefed"`: the fallback refuses and points at `/vulyk-plan`, the Workflow calls `briefed --commit` and stamps `**Briefed:** via grill` on a spec that was never grilled.

16. `scripts/cycle.sh:1563` vs `.claude/commands/vulyk-build.md` `build:<wave>` row ("never `open-round` on a wave carrying a blocked story") - **plan** - Either `open-round` refuses a `blocked` story or the driver stops claiming it never opens on one: the verb accepts `done|blocked`, so a relaunch after the blocked stop opens the council on the incomplete pack.

17. `.claude/workflows/vulyk-cycle.js:130-136` - **plan** (C2: exit 3 is `paused`) - A `record-seat` answering exit 3 must end the run as the `paused` terminal, not as `stop:{verb:"record-seat",exit:3}` with no `error`; the emit's own `next:"paused"` is the signal.

18. `.claude/commands/vulyk-build.md` step 2 (`journal.sh … 03-building "<verb> exit <n>"`) - **plan** - Journaling a council-stage stop under `03-building` widens the C9 vocabulary gap already in `## Next circle` (lead-review 22); fold it there.

## Worker claims spot-checked

- Story 21: "verified the real hive's own `CLAUDE.md` accepts this story's own `## Verification` line … via a standalone `command_cell_exists` probe" - reproduced: the `\|` rows unescape and match, `echo hi` does not; story 21's own `close-story` also ran through the gate on the real file.
- Story 23: "no `cycle.sh` failure path writes `journal.md` on its own (`open-round`'s ceiling exit 6 is the one exception)" - holds against the current file (`git_commit_or_fail`, checkout failure, MALFORMED, red verification, every exit-2 precondition write no journal line).
- Story 19: the `local a="$1" b="$spec/x"` `set -u` note - `reopen_names_round` (`:458-459`) is split as described.
- Story 25: `.claude/agents/drone-acceptance.md` absent from the tree - confirmed.
- Story 22: the R14 cross-check claim - **does not hold** (M2).
- Story 24: "`grep -rn 'read-only' .claude/agents/council-*.md docs/adr/…` returns nothing about the court" - one hit remains, `council-haiku.md:31`, about browser navigation, not the court; holds as stated.

## Method and limits

- Reproduced in a scratch repo (never the working tree): the STALE-fold ceiling gate (m5), `close-story --commit` under `index.lock` and its retry (m2), `open-round --commit` under `index.lock` and its retry (m3), the `"round":1`/`"round":10` prefix match (m1), `status` staying `repair` with nothing landed (M3).
- Reasoned from the code, not executed: the delimiter guessability window (M1), the empty-worker-report loop (M4), the reduction commit under hooks/signing (m7), the `&&`-cell case (m9). The Workflow driver has still never run; `node --check` is the only thing that has ever executed it (M2).
- Read-only throughout: no writes into the repository, no commits, no `git checkout`/`restore`/`stash`/`clean`; `.vulyk/court/` never entered; the live round 2 was observed through `status --json` only.

===== second reviewer (opus) =====
VERDICT: BLOCK

Second reviewer (Opus 5), Tier 4, spec `autonomous-cycle`, branch `vulyk/autonomous-cycle` at `4706bc0`,
MAIN tree. Round 2. Repair diff `git diff f0d206b...HEAD`; whole change `git diff main...HEAD`.

## What I ran

- `bash tests/cycle.test.sh` — exit 0. `bash tests/council.test.sh` — exit 0, 243 `ok` lines (149 at round 1).
- `git ls-files '*.sh' | xargs -n1 bash -n`, `python -m py_compile .claude/hooks/*.py`,
  `git ls-files '*.json' | xargs -n1 jq -e .`, `node --check .claude/workflows/vulyk-cycle.js` — all clean.
- Nine throwaway `mktemp` repos built from the real `scripts/` and `templates/plan.md`, driving the real
  verbs with `--commit` and reading `status --json` after each: the full happy path (briefed → branch →
  close-story → open-round → 4 seats → judge GREEN), the RED → repair → fix story → round 2 path, the
  exhausted-seat path, the ceiling path, the reopen path, the court-blindness probe, a crash-window probe,
  and a `## Commands` gate probe. No writes to the repository; no `git checkout`/`restore`/`stash`/`clean`;
  `.vulyk/court/` never entered (one repo-wide grep matched files there incidentally — nothing from it is
  used below, and both matches duplicate main-tree files).
- The Workflow script API (`agent` options, `parallel`, `pipeline`, `phase`, `log`, `meta` literal,
  the `Date.now`/`Math.random` ban) checked against the authoritative platform reference, not from memory.

---

# Round-1 findings — status

## Critical

**C-1 · a RED judged with `--commit` routed to a fresh round — MET.**
`scripts/cycle.sh:357-358` now derives `repair` through `round_is_stale`, not plain head equality.
Reproduced (tier 3, 7 asks, one evidenced RED, every verb `--commit`):
`judge` → `{"ok":true,"verb":"judge","exit":0,"next":"repair"}`, and `status` immediately after →
`"next":"repair"`, `"verdict":"RED"`, `"red":[3]`, `"round_dir":"docs/specs/probe/council/round-1"`.
R24's companion change (a RED verdict is a successful judgement, exit 0) is what lets the driver's
`if (!res.ok) fail(...)` not swallow it; both halves are needed and both are in.

**C-2 · a seat that exhausted both attempts stayed `missing` forever — MET.**
`missing_required_seats` (`cycle.sh:142-154`) skips `<seat>.attempt-2.md`. Reproduced: two malformed
haiku attempts → `"missing":["sonnet","opus","review"]`, a third `record-seat` refuses with exit 2
(`haiku ABSENT: attempts exhausted`), and once the other three are recorded `status` reaches `judge`
rather than re-dispatching haiku. The worst instance is closed too: `.claude/agents/lead-review.md:29`
now states the machine-readable first line that `record-seat … review` parses.

**C-3 · the driver discarded every field but `next` — MET, all three parts.**
(a) `cmd_open_round`'s two ceiling gates call `write_ceiling_escalate` before exiting 6
(`cycle.sh:1640-1647`, `:1653-1660`). Reproduced with a seat recorded and a real code commit at
ceiling 1: an `ESCALATE` row with `"escalate":"ceiling"`, a `**Council:** ESCALATE round 1` line, a
`## Needs a human` block, a clean tree after `--commit`, and `status` → `"next":"escalated"`.
`escalate` is a verb of its own now (`cycle.sh:788-856`) with no seat precondition, so the case that
used to exit 2 is recordable.
(b) `vulyk-cycle.js:117` fails the run on `open-round` `ok:false`, so a dirty tree stops instead of looping.
(c) `vulyk-cycle.js:134-136` re-asks a MALFORMED seat exactly once with the `error` verbatim, and
`:80,108-110` caps a story at two failed `close-story` calls — the fallback's two rules the Workflow
driver lacked.
Residual, reported below as a new minor: the ceiling's `emit false open-round 6 escalated` carries no
`error` field, which both drivers are now told to print.

**C-4 · untrusted text reached a shell as syntax — one sink closed, one mitigated, the guarantee overstated.**
Sink 2 is genuinely closed: `cmd_close_story:1349-1364` refuses unless every `&&`-separated segment of
every `## Verification` line is a literal cell of the hive's `CLAUDE.md` `## Commands` table. I ran
`command_cell_exists` against this repository's own table: the five real commands match (including the
`\|`-escaped `git ls-files '*.sh' | xargs -n1 bash -n` row, so the unescaping works under GNU sed 4.9),
`echo pwned` does not.
Sink 1 is mitigated, not closed — see new **major N-M3**: the delimiter is now `VULYK_<stamp>_<seat>_<attempt>`
with `stamp="$(date -u +%s)"`, and both command files call that "a delimiter no report body can guess or
contain". Downgraded from critical to major.

## Major

- **M-1 · court blindness was working-tree-only — MET as R15 decided (restate + one narrowing).**
  Reproduced inside a real court: `git -C $COURT status --porcelain` is now empty and
  `git show HEAD:docs/specs/blind/plan.md` → `fatal: path … does not exist in 'HEAD'`. Still reachable and
  still named as BREACH, exactly as R15 says it would be: `git log --name-only` lists the story file and
  `git show HEAD~1:…/plan.md` prints the full plan. `CHANGELOG.md:14-26` now describes the honour clause
  instead of the old guarantee.
- **M-2 · "read-only" court — MET.** Gone from D5 and all three seat prompts; the shared/writable fact and
  the sonnet seat's suite leftovers are stated. Reproduced that the court is still writable.
- **M-3 · only the last verification command's status was read — MET.** `cycle.sh:1368-1381` runs one line
  per iteration and exits 4 naming the first failing line.
- **M-4 · `reopen` left `status` terminal — MET.** `council/REOPEN` (`cycle.sh:1726`) plus
  `reopen_names_round` in the `escalated` derivation (`:353-354`). Reproduced: three RED rounds → `escalated`;
  `reopen` → `REOPEN` holds `round=3 · <ts>`, ceiling 6, `status` → `open-round`; `open-round` → round 4.
- **M-5 · ABSENT with nothing RED — MET.** `cycle.sh:703-704` + the D4 row. Reproduced: haiku ABSENT,
  sonnet/opus GREEN, review PASS → `ESCALATE`, `"escalate":"env"`, `"note":"haiku ABSENT"`,
  `## Needs a human` pointing at the attempt files, `status` → `escalated`.
- **M-6 · swallowed git failures — MET, with one residual.** `git_commit_or_fail`/`commit_paperwork`
  (`cycle.sh:470-490`) and `cmd_branch:939-949` (a failed checkout exits 2 and writes no `**Branch:**`).
  Residual: `build_round:1464-1467`'s court-reduction commit is still `… || true` — new minor N-m2.
- **M-7 · nothing serialises two drivers — NOT BUILT, decided and recorded.** Plan delta 6 R27 specifies a
  gitignored `DRIVER` semaphore via `cycle.sh claim`/`release` and `--stamp` on the four mutating verbs, and
  `## Next circle` carries my condition verbatim. That satisfies "the decision is on the record"; the defect
  is live until the next circle.
- **M-8 · a seat report produced before a pause is lost — MET by restating.** `/vulyk-pause.md:12-20`,
  ADR D6 and `docs/command-reference.md:18` now all say the report is discarded and the seat re-dispatched.
- **M-9 · `/vulyk-review` dispatched the full court at every tier — MET in the command** (`vulyk-review.md`
  steps 2-3 read `missing`). `docs/command-reference.md:15` still documents the old behaviour — new minor N-m5.
- **M-10 · no Tier 1 in the template, tier defaulting to 4 — MET.** `templates/plan.md:3` offers `<1|2|3|4>`;
  `tier_of` no longer defaults or writes; `open-round` exits 2 naming the line. Reproduced via the suite's
  own fixtures and my own tier-1/2/3 runs.
- **M-11 · install smoke did not prove the allow rules — MET.** `.github/workflows/ci.yml` asserts both rules
  exactly once, on a fresh install and again after `--upgrade`.

## Minor

MET: **m-1** (`tier_of` no longer journals; `status` writes nothing — confirmed across ~40 `status` calls in my
repros, `journal.md` untouched), **m-2** (`is_paperwork_path` anchored to `docs/specs/*/`), **m-5** (the
CHANGELOG's `### Upgrading` says plainly that `--upgrade` never deletes and names `drone-acceptance.md`),
**m-7** (seat files reach git at `judge --commit` — verified `git ls-files` lists all four after judge — and
ADR D1's `Committed` column now says so), **m-8** (the two-driver claim rewritten to what ships).

RECORDED, NOT FIXED — each verbatim in `plan.md` `## Next circle`: **m-3** (gitignore glob), **m-4**
(same-second override), **m-6** (`/vulyk-evolve` mtime + GNU `date`), **m-9** (`/vulyk-ship` outward-facing
sentence), **m-10** (ledger append atomicity), **m-11** (`claude --version` in the session brief).

---

# New findings

## CRITICAL

### N-C1 · `.claude/workflows/vulyk-cycle.js:69-73` · route: `plan`

*Shape: the Workflow driver on a Tier 4 spec — i.e. this spec's own configuration. The fallback driver,
where the Queen folds the two reviews by hand, is not affected.*

The Tier 4 fold builds the `review` seat's report from two `agent()` return values:

```js
]).then(([r1, r2]) => `VERDICT: ${isBlock(r1) || isBlock(r2) ? 'BLOCK' : 'PASS'}\n${r1}\n${r2}`)
```

`agent()` returns **`null`** when the subagent dies on a terminal API error after retries or the user skips
it, and a `parallel` thunk that throws resolves to `null` too — the driver already knows this and guards for
it in the build branch (`:101 if (!reports[i]) continue`). Here it does not. `isBlock(null)` is
`String(null).trim().split('\n')[0] === 'null'`, which matches neither `^BLOCK\b` nor `^VERDICT:\s*BLOCK\b`,
so it is `false`. Two dead reviewers therefore produce the literal report `VERDICT: PASS\nnull\nnull`,
`cmd_record_seat_review` reads `PASS` off the first line and writes `review.md`, and `judge` sees
`review:"PASS"`. With the three blind seats GREEN the round is GREEN, `status.next` is `green`, the driver
returns, and `/vulyk-ship` proceeds on a review nobody wrote.

The same line disables the only guard that catches an unparsable review. At Tier 1-3 a review whose first
line is prose is `MALFORMED`, re-asked once, then ABSENT → `escalate:"env"`. At Tier 4 the driver *prepends*
its own `VERDICT:` line, so `record-seat`'s check can never fire and a reviewer that ignored
`lead-review.md:29` is silently folded to PASS as well.

Routed `plan`: story 22's acceptance criterion says exactly "folded to `VERDICT: BLOCK` if either first line
says BLOCK", and a worker implementing that literally writes this. Nothing in the story, the delta or C11
said an agent can return nothing.

**Condition:** a `review` seat whose reviewer dispatches produced no report must not be recorded as a
verdict at all — the round must reach `record-seat` with something that fails the report contract, or not
reach it — and at Tier 4 a single surviving reviewer must be visible as such rather than folded with a blank.

## MAJOR

### N-M1 · `.claude/workflows/vulyk-cycle.js:96-101`, `scripts/cycle.sh:1299-1306` (`wave_story_json`) · route: `plan`

A worker `agent()` that returns `null` is skipped (`:101`), no `close-story` runs, the story keeps its
`todo` status, the next `status` poll returns the same `build:<wave>`, and the same worker is dispatched
again — with no bound and no record. The `attempts` map counts `close-story` failures only, so R6's cap
never engages. The trigger is ordinary rather than exotic: `wave_story_json` takes `worker:` from story
frontmatter, defaults only when the line is absent, and validates nothing against the agent registry
(`wave-check.sh` does not either — it checks file collisions only), so one typo in a story `queen-planner`
cut — `worker: worker-tset` — is an unknown `agentType` on every iteration. Pre-existing rather than
introduced here, but it is the same unbounded-loop class C-3 was raised for, in the one branch C-3's repair
did not reach.

**Condition:** a wave story whose worker returns nothing must be bounded by the same two-attempt rule a red
verification is, and end the run with the story named rather than re-dispatching forever.

### N-M2 · `.claude/workflows/vulyk-cycle.js:127-138` · route: `plan`

`pipeline`'s contract is that "a stage that throws drops that item to `null` and skips its remaining stages".
The `record-seat` call lives inside stage 2, and `clerk()` throws `BadLine` whenever the clerk's last line is
not JSON. That throw is therefore swallowed by `pipeline` — it never reaches the outer
`catch (e) { if (e instanceof BadLine) return e.line }`, `dispatchStop` stays `null`, and the loop simply
polls `status` again. The seat file was never written, so `missing` still names that seat and the driver
re-dispatches it, indefinitely, with nothing on disk. Every other clerk call in the file is outside a
`pipeline` stage and does propagate. This is also the one path where a malformed `cycle.sh` JSON line (see
N-M5) turns into silence rather than a stop.

**Condition:** a non-JSON clerk line during a seat recording must end the run with the raw line, the same as
every other clerk call, rather than being absorbed by the stage that made it.

### N-M3 · `.claude/commands/vulyk-build.md:59`, `.claude/commands/vulyk-review.md` step 4, `.claude/workflows/vulyk-cycle.js:121-125` · route: `plan`

*Shape: a hive installed by `install.sh` (the two allow rules wired), running unattended with permission
prompts suppressed, whose `brief.md` quotes third-party text — the input `/vulyk-plan` step 2 tells the
Queen to paste verbatim.*

C-4's first sink is narrowed, not closed, and the words around it claim more than the mechanism gives.
R11 chose unpredictability as "the whole guarantee", and `stamp` is `date -u +%s` — a ten-digit wall-clock
second. A council seat holds `Bash`, so it can read the current clock exactly; what it does not know is only
how long ago the stamp was taken. In `/vulyk-review` that gap is one step: step 2 takes the stamp, step 3
dispatches the seats. `seat` is in the seat's own prompt and `attempt` is 1 or 2, so a report that emits a
few dozen candidate `VULYK_<t>_<seat>_1` lines covers the window, terminates the heredoc, and the remainder
of the report is parsed as shell by the clerk. Both command files nonetheless instruct the Queen to record
"through a delimiter no report body can guess or contain", and R11 says "unguessable by the seat" — a
verification claim stronger than the construction supports.

Related and unchanged by the repair, so stating it rather than re-litigating it: the report still travels as
free text inside a Haiku `cycle-clerk`'s prompt, which holds `Bash`. R11 recorded that it rejected base64 and
a clerk-written file, so this is a taken decision, not a silent narrowing — but the residual belongs beside
the delimiter, not behind it.

**Condition:** the delimiter must come from a value a seat cannot bracket from its own clock — or the two
command files and R11 must say what the construction actually buys ("a per-run value the seat is not told",
not "cannot guess").

### N-M4 · `scripts/cycle.sh:1376` (`emit false close-story 4 repair "$vline"`) · route: `worker`

`emit` interpolates `$vline` into the JSON with no escaping, and after R11 `$vline` is guaranteed to be a
verbatim cell of the hive's `## Commands` table. Double quotes in such a cell are ordinary —
`pytest -k "not slow"`, `npm test -- --grep "x"`. Reproduced in a throwaway hive whose table carries
`` `sh -c "exit 1"` ``:

```
{"ok":false,"verb":"close-story","exit":4,"next":"repair","error":"sh -c "exit 1""}
jq: INVALID JSON
```

C2's premise — "the LAST stdout line of every verb, on every exit code, is one JSON object so no driver ever
parses prose" — fails for the single most common non-zero outcome in the build loop. The Workflow driver
turns it into `BadLine` and ends the whole run; the fallback loop is told to read `error` from an object it
cannot parse. A backslash in a cell breaks it the same way.

**Condition:** every value `emit` places in the JSON must be escaped so the last line is parsable whatever
the hive's commands contain.

### N-M5 · `docs/adr/001-cycle-state-contract.md:168-186` (D2's driver sketch) · route: `worker`

The amendment block story 24 added claims D2 was brought in step with R5, R11, R12 and R24. D2's prose was;
its code block was not. It still shows `record-seat ${spec} ${st.round} ${seat} <<'EOF'\n${report}\nEOF` —
the exact pattern R11 exists to forbid and which `/vulyk-build.md` now spells "never `EOF`" — plus
`args: {spec, top_model, stamp}` without `second_model` (C11 as amended by R12), `agentType:
council-${seat}` for the `review` seat, a `schema: LAST_LINE` the real driver does not use, and no exit-code
handling at all. This is the document `reviewPrompt` points every reviewer at and the one a future driver
author copies; `## Resume` two paragraphs below repeats the three-key `args` a second time.

**Condition:** the illustrative driver in D2 must not show a shape an in-force decision forbids, or it must
be removed rather than left as the canonical sketch.

## MINOR

### N-m1 · `scripts/cycle.sh:1645`, `:1659`, `:1212`, `:62` · route: `worker`

Four `ok:false` emits carry no `error` key: `open-round`'s two ceiling exits (6), `record-seat`'s stale exit
(5) and `pause_guard`'s exit (3). Both drivers are now instructed to print it — `/vulyk-build.md` step 2
("print its `error` field") and step 4 ("Print `stop.error`") — so the ceiling stop and a round that goes
stale mid-dispatch both surface as a blank reason. `open-round` exit 6 is also the only exit 6 that is
`ok:false`; `judge` and `escalate` both emit `ok:true` with exit 6, so `ok` and the exit code disagree about
the same event depending on which verb produced it.

**Condition:** every `ok:false` emit must name its reason, and exit 6 must mean the same thing to `ok`
whichever verb reports it.

### N-m2 · `scripts/cycle.sh:1464-1467` · route: `worker`

The court's reduction commit — R15's "one mechanical narrowing that costs two git commands" — is the one
git write still swallowed: `commit -q -m "vulyk: reduce the court to brief.md" >/dev/null 2>&1 || true`.
If it fails (an `index.lock` in the court, a hook, a read-only mount), `open-round` still reports the round
open and the court still advertises the narrowing that is not there: `git status` shows the deletions and
`HEAD:docs/specs/<slug>/plan.md` resolves again. Narrow because the blindness is an honour clause either
way, but it is literally the case R17's condition names.

**Condition:** a court whose reduction could not be committed must not be handed to a seat as if it had been.

### N-m3 · `scripts/cycle.sh:1441` vs `:1483` · route: `plan`

`current_round_dir` treats the *directory* as the open marker; `build_round` creates it first
(`mkdir -p "$rd"`) and writes `ROUND` last, with `clean_court`, a court `mkdir`, `git worktree add` and the
reduction commit in between — seconds, not microseconds. A crash or Ctrl-C in that window leaves a round
directory with no `ROUND`, and nothing repairs it. Reproduced by creating the directory by hand:

```
status:      "next":"dispatch:sonnet"  "round":1  "open":true
open-round:  cycle: crash - round 1 already open at current HEAD, no-op   {"ok":true,…,"exit":0}
record-seat: {"ok":false,"verb":"record-seat","exit":2,"error":"no open round 1"}
```

`open-round` reports success for a round that has no marker, and every subsequent run re-dispatches the seats
before `record-seat` refuses. D1 states "`mkdir` of the directory is the atomic act", which the code does not
implement.

**Condition:** a round directory without its `ROUND` marker must not read as an open round — `open-round`
must rebuild it or refuse, rather than reporting a no-op success.

### N-m4 · `scripts/cycle.sh:438-446` (`review_verdict_of_text`) · route: `worker`

`lead-review.md:29` and story 24 both say `record-seat … review` "parses only that line" — the report's first
line. The code greps the whole report for the first line matching `^(PASS|BLOCK)\b` or `^VERDICT: (PASS|BLOCK)`.
A review whose first line is prose still gets a verdict from wherever such a line first appears, and a line
like `PASS/BLOCK decision: BLOCK` in a body-text discussion scores as PASS (`\b` holds after `PASS` before
`/`). The MALFORMED-on-prose guard C-2 leaned on is therefore weaker than the prompt promises.

**Condition:** the verdict must be read from the line the contract names, so a report that does not open with
it is MALFORMED.

### N-m5 · `docs/command-reference.md:15` · route: `plan`

The `/vulyk-review` paragraph still says the command "Reads `round`, `court` and `round_dir` off
`status --json` - a seat's entire input", dispatches "`council-haiku`, `council-sonnet` and `council-opus`"
unconditionally, and records "with `… record-seat … <<'EOF' ... EOF`". All three contradict decisions story
23 implemented in the command itself: R9 (no `round_dir` to a blind seat — a seat that echoes it back is
tainted), R20 (dispatch only what `missing` names) and R11 (never `EOF`). The file is in story 24's
`## Files`, but only its pause sentence was named in the acceptance criteria.

**Condition:** the command reference must describe the seats, the inputs and the delimiter the commands
actually use.

### N-m6 · `docs/adr/001-cycle-state-contract.md:97` and the D1 table · route: `plan`

D1 is the canonical "loop state is a small set of committed files, each with exactly one writer" table, and
two live state files are absent from it: `docs/specs/<slug>/council/REOPEN` (written by `reopen`, read by
`status` to clear `escalated` — new in this repair) and `docs/specs/<slug>/council/CEILING` (written by
`reopen`, read by `open-round`). The `ROUND` row still lists five fields and omits the `tier=` line R21 added
as the sixth. `plan.md`'s C4 is covered by the delta's "amendments in force" convention; the ADR has its own
amendment section and does not mention any of the three.

**Condition:** every file and field the cycle now writes must appear in D1's table with its writer.

### N-m7 · `scripts/cycle.sh:543`, `:733` vs plan `## Contracts` C4 · route: `worker`

C4 says the council row's `note` is "redacted through `scripts/redact.sh`". `redact` appears nowhere in
`cycle.sh`; both writers print `note` raw into a committed ledger. Today's values are cycle-generated seat
names or a human's `escalate` note, so the exposure is small — but CLAUDE.md's Secrets section names exactly
two writers that pipe through `redact.sh`, and this is a third writer of free text into git that does not.

**Condition:** `note` must pass through the mask its contract names, or C4 must stop naming it.

### N-m8 · `docs/specs/autonomous-cycle/autonomous-cycle-22-…md` `## Implementation notes`, last-but-two bullet · route: `worker`

R14 required the Workflow API surface to be "verified against the platform docs and the outcome recorded".
The note records a cross-check "against the platform's Workflow reference at code.claude.com/docs (dated
2026-09-12 per brief.md `## Evidence` line 3, reused rather than re-fetched this run)". That Evidence line
documents only the Workflow tool's *availability* — minimum Claude Code version, the Pro `/config` flag, the
opt-in rule, the `.claude/workflows/<name>.js` location — and carries no script API at all, so the record the
note points at does not contain the thing it claims was checked, and the story's own honest escape ("or that
the docs were unreachable and the calls were left as they are") was not taken. I checked the four shapes
myself against the authoritative reference and they are correct — `agent(prompt, {agentType, model, effort,
phase})`, `parallel([thunks])` as a barrier, `pipeline(items, …stages)` with `(prev, item, index)` per stage,
`phase(title)`, `log()`, a pure-literal `meta`, and no `Date.now`/`Math.random` — which is why this is minor
rather than major. The two behaviours that follow from that same reference and were *not* accounted for are
N-C1 and N-M2.

**Condition:** a verification note must point at a record that contains what it says was checked, or say the
check did not happen.

---

# Method and limits

- Both suites run in the foreground from the repo root, output read, not assumed.
- **Reproduced in throwaway `mktemp` repos** (never the working tree): C-1, C-2, C-3(a), M-1, M-4, M-5, M-10,
  N-M4, N-m3, plus a full GREEN cycle and a full RED → repair → round 2 cycle with `--commit` on every verb.
  Transcripts quoted inline.
- **Confirmed by reading the code plus a suite assertion I read and watched run green, not by a repro of my
  own:** M-6 (`council.test.sh`'s `index.lock` and worktree-failure cases), M-2's prompt wording, M-8, M-11.
- **Reasoned from code plus the authoritative Workflow reference, not executed** (the Workflow runtime is not
  reachable from a review session): N-C1, N-M1, N-M2. Each rests on a documented runtime behaviour —
  `agent()` returning `null`, `parallel` resolving a throwing thunk to `null`, `pipeline` dropping a throwing
  stage's item — quoted rather than inferred.
- **Reasoned from code only:** N-M3's exploit window, N-m1, N-m2, N-m7.
- `command_cell_exists` was verified against this repository's own `CLAUDE.md` `## Commands` table, not a
  fixture, because the `\|` escape in one row is the case most likely to break.
- I did not re-verify M-7 (deferred by R27), nor the six minors `## Next circle` carries verbatim; I confirmed
  each is recorded there with my condition unchanged, and nothing from round 1 was dropped.
- Read-only throughout: no writes to the repository, no commits, no `git checkout`/`restore`/`stash`/`clean`.
  The live round 2 (`council/round-2/ROUND`, no seats recorded) was observed via `status` only and left alone.
