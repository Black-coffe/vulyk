<!-- seat: review · model: fable+opus · round: 3 · head: 69f0a50 · pack: c0a97d497e2a · attempt: 1 · recorded: 2026-09-13T15:18:15Z · verdict: PASS -->
VERDICT: PASS

Folded review seat, round 3 (Tier 4): lead-review (Fable 5.1) = PASS (0 critical / 3 major / 9 minor); second reviewer (Opus 5) = PASS (0 critical / 4 major / 5 minor). Folded verdict = PASS only because both pass. Both full reports follow, nothing trimmed; every major and minor is next-circle material.

===== lead-review (fable) =====
VERDICT: PASS

# lead-review - autonomous-cycle, council round 3 (the ceiling round)

Repository `E:\Projects\vulyk`, branch `vulyk/autonomous-cycle` at `69f0a50` (round 3 open at `7bc6f7b`, pack `c0a97d497e2a`, tier 4). All paths relative to that root. MAIN tree only; `.vulyk/court/` never entered; nothing written into the repository; every probe ran in a `mktemp` repo seeded with the suite's own helpers. Repair diff reviewed: `git diff 19667a3...HEAD` (21 files). Whole change: `git diff main...HEAD`.

No critical finding, so PASS. Three majors and nine minors follow, none trimmed. The two things the merge should know first: the driver's only "syntax gate" verifies nothing on this machine (major 1), and the second-miss stop the repair added lies about why it stopped (major 2).

## What I ran and what held

- Syntax gates: `git ls-files '*.sh' | xargs -n1 bash -n`, `python -m py_compile .claude/hooks/*.py`, `git ls-files '*.json' | xargs -n1 jq -e .`, `bash .claude/hooks/handoff.sh status` - all exit 0. `node --check .claude/workflows/vulyk-cycle.js` exits 0 too, but see major 1: on Node v22.23.1 it exits 0 for *any* file that contains `export`, garbage included. I parsed the driver for real (export stripped, `AsyncFunction` constructor with `args/agent/parallel/pipeline/phase/log` as parameters): it parses; so did the round-2 driver.
- `bash tests/cycle.test.sh`: exit 0, 36 `ok`, 0 `::error::`. `bash tests/council.test.sh`: exit 0, 260 `ok` (243 at round 2, 149 at round 1), 0 `::error::`. Output read from the saved log, not assumed.
- Story 26's `foldReviews` harness (the one-line `node -e` in its criteria): prints `fold ok`. It is a real test: the old `isBlock` file throws `no foldReviews`, and each null/empty/prose case asserts the first line is not `VERDICT:`.
- Story greps: `pipeline(`, `EOF`, `isBlock`, `worker-code`, `Date`, `Math.random` absent from the driver; `GREEN`/`RED`/`stale`/`paperwork` only in comments; `ceiling` only in `meta.description`; 188 lines. `date -u +%s`, `cannot guess`, `no report body can guess` absent from both command files. `<<'EOF'`, `schema: LAST_LINE`, `council-${seat}`, `instead of an honour clause` absent from ADR-001.
- Law 3 over the repair commits (`git show --name-only` vs each story's `## Files`): `ce88e5f` (28) -> the two command files; `1befb2b` (26) -> `vulyk-cycle.js`; `1958af9` (29) -> ADR-001 + story 22 (its diff is 1 insertion / 1 deletion - the one bullet the criterion allows); `7bc6f7b` (27) -> `cycle.sh`, `council.test.sh`, `memory/stats/scope.jsonl` (the R4 ride-along). Each carries its own story file. `dedfb71`/`d25b34e` (plan + story cuts) and `69f0a50` (`ROUND` + journal) are the Queen's and `open-round`'s. No file outside a story's list.
- `## Descoped` is still empty and I found nothing that belongs there: story 26's dropped `res.error` text and story 29's two API gaps are both on the record in the stories' notes (see major 2 and minor 7 for what is still owed).
- `## Next circle` - every file the round-1 and round-2 items name outside the repair diff is untouched (not in the diff stat: `docs/cycle.md`, `docs/pipeline.md`, `install.sh`, `vulyk-evolve.md`, `vulyk-ship.md`, `vulyk-bootstrap.md`, `top-model-brief.sh`, `docs/architecture.md`, `acceptance-log.sh`, `ship-check.sh`, `drone-docs.md`, `command-reference.md`, `CHANGELOG.md`, `lib.sh`). Inside the three touched runtime files each recorded defect is still where it was, at its new line: `attempts` counts seat files (`cycle.sh:753-754`), `row_exists` prefix-matches the round (`:185-188`) and so do `escalate_row_exists`/the `reason` grep (`:520-523`, `:583`), `**Council:**` appends at EOF (`:574`, `:767`, `:786`, `:1558`), `wave_stories` lists every todo of the wave (`:295`, `WAVE_STORIES="$wave_files"` not `$ready`), `repeat` is dead in `wave_story_json` (`:1323-1330`), `&&` split before the cell match (`:1305-1314`), `close-story` writes `done` before `git_commit_or_fail` (`:1409` vs `:1426`), `open-round`'s no-op branch (`:1652-1653`), the four `ok:false` emits without `error` (`:78` pause, `~:1228` stale, `:1669`, `:1683`), `open-round` accepts `blocked` (`:1591`), the reduction commit `|| true` (`:1488-1490`), the seat scan in three copies (`:541-560`, `:683-700`, `:1535-1551`), no `redact` anywhere, journal stages `04-council:open` (`:1510`) / `resumed` (`:1795`), a round dir without `ROUND` still reads as open (`:108-118`). Driver: `briefed --commit` still stamped by the Workflow (`vulyk-cycle.js:105-107`) while the fallback refuses (`vulyk-build.md:55`); `record-seat` exit 3 still a generic stop (`:155`); the `build:<wave>` row still ends "never `open-round` on a wave carrying a blocked story" (`vulyk-build.md:57`); step 2 still journals under `03-building`. Nothing in the list was silently fixed or silently broken. Every round-2 minor delta 7 did not fold is present verbatim (LR 1-11, 14-18; N-m1/m2/m5 on the lines of LR 4/7/10; N-m3, N-m7); the four it folded (N-m4 -> story 27; LR m12, m13, N-m6 -> story 29) are delivered - checked below under R28 and R34.
- Live, read-only: `status --json` on this spec returns `next:"dispatch:sonnet,review"`, `round:3`, `tier:4`, `stale:false` (head `7bc6f7b` vs HEAD `69f0a50`, paperwork only), `verdict:"RED"`, **`review:"BLOCK"`**, `red:[]` - the R30 key is there and says exactly what round 2 needed it to say.
- `docs/wiki/` is empty; no recorded invariant to check against.

### The Workflow reference, weighed

Story 22's corrected R14 bullet is honest and I confirm it against what it says: the page it fetched (`https://code.claude.com/docs/en/workflows`, 2026-09-13) confirms `agent()` returning `null` and says nothing about a throwing `parallel` thunk, a throwing `pipeline` stage, or `phase` as an `agent()` option. The bullet names all three as unverified and routes them to story 26's file in a CONCERNS line. So R35 is met as written. Beyond the page, this session's own Claude Code ships the Workflow tool's script reference (the `workflow-authoring` skill text, read 2026-09-13), and it states all three: `agent(prompt, opts?: {label?, phase?, schema?, model?, effort?, isolation?, agentType?})`; `parallel`: "A thunk that throws (or whose agent errors) resolves to `null` in the result array - the call itself never rejects"; `pipeline`: "A stage that throws drops that item to `null` and skips its remaining stages"; `agent()` "Returns null if the user skips the agent mid-run or the subagent dies on a terminal API error after retries"; the body runs "in an async context" and its own examples `return` at top level; `meta` must be a pure literal; `Date.now`/`Math.random` throw. Every shape and behaviour R28/R29/R32 rest on is therefore backed by the tool's own reference, which is one source, not two - the public page is the second and is silent. What has still never happened: the driver executing. `node --check` is not a check (major 1); the fold harness and my parse are the only two things that have ever run any of its code.

## Round-2 findings - status

Keyed by delta 7's R-numbers; round-2 ids in brackets (LR = lead-review round 2, N- = second reviewer). Suite citations are `tests/council.test.sh` scenario names with approximate current lines; probes are mine, in a throwaway repo.

| R | Round-2 ids | Status | Evidence |
|---|---|---|---|
| R28 | N-C1 (critical), N-m4 (folded) | **met** | `vulyk-cycle.js:68-81` `foldReviews`: folds only when both first lines match `/^VERDICT:\s*(PASS\|BLOCK)\b/`, else `NO VERDICT: top=… · second=…` + both bodies, `(no report)` for null/empty; `:89` sends it unchanged; `:144` `report ?? ''` so a null seat is an empty body. Harness `fold ok`. Verb side `cycle.sh:456-468` reads line 1 only, `:470-474` drops the C4 header before reading a stored file (the worker's "surprise" - real, and without it every judged review would read MALFORMED/BLOCK at `:683`); `:1059-1064` exit 4 with the exact error string. Suite `rrev`/`rrevb`/`rrev3` (~906-950): BLOCK on line 1 -> BLOCK; PASS on line 1 over a body `PASS/BLOCK decision: BLOCK` -> PASS; prose line 1 with `VERDICT: PASS` on line 3 -> exit 4, `attempt-1.md`; the driver's `NO VERDICT` shape -> exit 4, `attempt-2.md`, `missing` without review, `judge` -> `review:"ABSENT"`, `escalate:"env"`. Probe a: an empty body (the `?? ''` path) -> exit 4, `review.attempt-1.md`. Probe f: the fold's both-verdict output recorded, `judge` reads BLOCK from the stored file's line 2. |
| R29 | LR M4, N-M1 (major) | **met in code** | `vulyk-cycle.js:117-132`: `if (!reports[i]) continue` gone; a falsy report skips `close-story` and trips the same `attempts` map; second miss -> `stop:{verb:'build', file, error}`. `vulyk-build.md:57` `build:<wave>` row says the same for the fallback; step 4 (`:86-93`) applies the blocked/`lead-architect` rule to any `stop` carrying `file`. Not runnable here. Residual: the stop's `error` is a fixed string that is false on one of the two paths - major 2. |
| R30 | LR M3 (major) | **met** | `vulyk-cycle.js:164-179`: `repaired` Set per run, second `repair` for the same `st.round` -> `stop:{verb:'repair', round, error}` before any dispatch; prompt names `st.review`, and with `red:[]` says the review seat's BLOCK (or an owner REJECTED) is why, points at `<round_dir>/review.md`, asks one story per critical/major; "each addressing exactly one of those asks" only when `red` is non-empty. `cycle.sh:335-345`, `:381`: `"review"` = newest row's `review` verbatim, `null` with no row. Suite `realverbs` rounds 4-5 + `freshreview` (~1539-1565): `.review=="BLOCK" and .red==[] and .next=="repair"`, then `"PASS"` after GREEN, `null` on a fresh spec; `status1` key list has `review`. Live: this spec's own status says `review:"BLOCK"`. `vulyk-build.md:62` `repair` row: once per round number, same prompt, stop on a repeat `repair`. |
| R31 | LR M1, N-M3 (major) | **met** | `vulyk-build.md:15-18` and `vulyk-review.md:24-26`: `stamp="$(od -An -tx1 -N8 /dev/urandom \| tr -d ' \n')"`, never `date`; both say the report travels as free text in the clerk's prompt and the delimiter is "a per-run random value the seat is never told" (`vulyk-build.md:60`, `vulyk-review.md:48-50`); the forbidden sentences grep empty. `vulyk-cycle.js:28-31`: `typeof stamp !== 'string' \|\| stamp.length < 12` -> `stop:{verb:'launch', error}` before the first `clerk()`; step 1 passes `stamp` in `args` (`vulyk-build.md:25`). |
| R32 | N-M2 (major) | **met** | `grep -c 'pipeline('` = 0; seats dispatched under `parallel` (`:147`), recorded in a plain `for` (`:149-158`) where `recordSeat`'s `clerk()` throws `BadLine` straight to the one catch (`:184-185`). The premise (a `pipeline` stage that throws drops the item) is confirmed by the tool's own reference, above. |
| R33 | N-M4 (major) | **met** | `cycle.sh:42-53` `json_escape` (backslash first, then `"`, tab, newline), `:55-66` every `emit` value through it. Suite `cstoryq`/`cstorybs` (~1136-1178): fixture cells `sh -c "exit 1"` and `sh -c 'echo a\b; exit 1'`, `close-story` exit 4, last line satisfies `jq -e .`, `jq -r .error` equals the cell byte for byte - a real test (without the helper the first line is not JSON). Residual: control characters other than tab/newline are not escaped - minor 3, no input path found. |
| R34 | N-M5 (major); LR m12, LR m13, N-m6 (folded) | **met** | ADR D2 code block gone, one paragraph (`:174-187`) names the canonical file, the four `args`, the Tier 4 fold, "never manufactures a verdict from a blank"; `## Resume` (`:194-195`) names the same four. D1 (`:98-100`): `ROUND` six fields ending `tier=`, `council/REOPEN` (writer `reopen`, `round=<N> · <ts>`, read by `status`), `council/CEILING` (writer `reopen`, read by `open-round`) - both match `cmd_reopen` (`cycle.sh:~1742` writes `CEILING`, `~1750` appends `round=N · ts` to `REOPEN`). D2 `record-seat` precondition (`:150`) "not stale by `round_is_stale`". `## Consequences` (`:294`) now agrees with D5. Amendments bullet `D1/D2` (`:79-81`) names delta 7 / R34. One new false sentence inside the replacement paragraph - minor 1. |
| R35 | LR M2, N-m8 (major/minor) | **met** | Story 22's R14 bullet (`autonomous-cycle-22…md:72`) opens `R14 (corrected 2026-09-13 by story 29):`, says what the old bullet claimed and why the Evidence line could not carry it, records URL, date, each of the six shapes and three behaviours with the page's wording, and marks the three the page does not confirm as unverified, routed to story 26's file. Weighed above. |

Round-2 minors: every one not folded is in `## Next circle` verbatim and verified untouched (list above); the four folded ones are delivered under R28 and R34.

## Critical

None.

## Major

1. `docs/adr/001-cycle-state-contract.md:296` ("kept logic-free so that a `node --check` is all it needs where node exists"); story 22 and story 26 acceptance criteria ("`node --check … passes`"); story 27's note "the four syntax gates pass" - **plan** (no story told a worker what `node --check` does with an ES-module file; every round's reviewers, me included, reported it as a passed gate) - The driver's syntax gate must fail on a syntax error: on the Node this repo runs (v22.23.1, module detection on) `node --check` exits 0 for any `.js` file containing `export` whatever follows it - reproduced with `export const meta = {a:1}` + `this is not javascript at all (((` -> exit 0, the same file as `.mjs` -> `SyntaxError`, the same garbage without `export` -> exit 1 - so the one check the ADR says the driver needs, and that three stories claimed as passed, checks nothing; a real parse exists (strip `export`, compile the body as an async function, which is what the runtime does) and the driver passes it today, but no gate on the record runs it and CI runs no node at all. Overstated coverage of exactly the file that has never executed.

2. `.claude/workflows/vulyk-cycle.js:130` (`fail(st, { verb: 'build', file, error: 'worker returned no report' })`) and `.claude/commands/vulyk-build.md:86-93` (step 4 appends `stop.error` to the story's `## Findings` and hands it to `lead-architect` "with both failures") - **plan** (story 26's criterion dictated that literal string for the second miss "in any order"; the worker built it and flagged in its notes that the red-verification `res.error` is lost) - The second-miss stop must carry the failure that actually happened: when the second miss is a red `close-story` (exit 4 after an empty report, or two reds) the run stops with `error: 'worker returned no report'`, the failing verification line in `res.error` is discarded, and the wake-up step writes that false sentence into the story file and into the `lead-architect` prompt as the record of why the story blocked - an invented fact on the one path that dispatches a top-model consult. Reasoned from the code (no Workflow runtime here); the branch is unambiguous.

3. `.claude/workflows/vulyk-cycle.js:113-127` vs `.claude/commands/vulyk-build.md:57` (`As each *non-empty* return says STATUS: DONE -> close-story`) - **plan** (pre-existing since story 06/22, not introduced by 26-29, and not in either earlier review; C11 says the driver never parses prose, so a worker holding story 26 could not have read a status line) - A worker that returned `NEEDS_CONTEXT`/`WALL` must not have its story closed: the Workflow driver runs `close-story` on every non-empty report, `cmd_close_story` checks nothing about what the worker said, and with `## Verification` = `none — reviewed by lead-review` (three of the four stories in this very repair) it runs scope-check only, stamps `status: done` and commits - so the Workflow driver marks a walled story done and opens the council on it, while the fallback's row reads `STATUS: DONE` first. Shape: a story whose verification cannot fail on an untouched tree (`none`, or a suite that was already green); a red verification catches the rest. A `schema` on the worker `agent()` would give the driver the status without parsing prose - stated as an observation, the condition is what matters.

## Minor

1. `docs/adr/001-cycle-state-contract.md:177-178` ("`build:<wave>` fans workers out over `pipeline()`") - **worker** (story 29 held the file; the driver at `19667a3` and at `1befb2b` uses `parallel()` for workers, and story 26 removed every `pipeline(`) - The paragraph that replaced the forbidden sketch must describe the canonical driver as it is: workers go out under `parallel` (`vulyk-cycle.js:113`), and `pipeline` appears nowhere in the file the paragraph points at.

2. `scripts/cycle.sh:456-468` vs `.claude/workflows/vulyk-cycle.js:71` - **plan** (delta 7 R28 wrote the verb's rule as `^VERDICT: (PASS|BLOCK)\b` or `^(PASS|BLOCK)\b`, and story 26's criterion wrote the fold's as `/^VERDICT:\s*(PASS|BLOCK)\b/`; nobody said they must be the same rule) - The first-line rule must be one rule in both places: probe c - a report opening with bare `BLOCK` is accepted by the verb (Tier 1-3, `verdict: BLOCK` in the header) but at Tier 4 the fold calls it `NO VERDICT` and burns the one re-ask on a report the contract accepts; probe d - `VERDICT:BLOCK` (no space) is the reverse, rejected by the verb and accepted by the fold (harmless there, the fold rewrites the line); probe b - a leading blank line is MALFORMED at the verb while the fold's `trim()` reads past it. Cost today: one wasted re-ask of both reviewers at Tier 4; the asymmetry is what will confuse the next author.

3. `scripts/cycle.sh:42-53` (`json_escape`) - **plan** (story 27's criterion listed exactly `\`, `"`, tab, newline) - `json_escape` must escape every control character below 0x20, not the two named: a CR or `\x01` in a value still yields a line `jq` rejects (probed on the helper in isolation). I found no path by which such a byte reaches `emit` today - `verify_of` strips trailing whitespace including CR (probe e: a CRLF story closes cleanly, last line valid JSON), `taint_reason` returns fixed strings, `## Commands` cells are one line - so this is a contract statement ("one JSON object under every input", C2 per R33) that the helper does not fully honour rather than a reproduced failure.

4. `.claude/commands/vulyk-review.md:40-46` (the Tier 4 fold: "`BLOCK` if either one blocks, `PASS` only if both pass") - **plan** (delta 7 R28 fixed the Workflow fold and said the fallback "is not affected"; story 28 was told to change only the stamp line and the delimiter sentence) - The command's fold rule must say what a reviewer that returned nothing folds to: a blank neither blocks nor passes, so the sentence is undefined for it, and the Queen folding by hand is the only thing between a dead reviewer and a hand-written `VERDICT: PASS`; the driver's rule (fold only two `VERDICT:` lines, otherwise send `NO VERDICT` and let `record-seat` reject it) is one sentence away.

5. `.claude/workflows/vulyk-cycle.js:27,88` (`SECOND = args.second_model`, `model: SECOND`) - **plan** (R31 guarded `stamp` alone) - At Tier 4 a launch without `second_model` must be refused the way one without `stamp` is: `model: undefined` inherits the session model, so the "second reviewer on a different model" silently becomes two reviews on one model and the fold records it as the Tier 4 pair.

6. `.claude/workflows/vulyk-cycle.js:25-31` - **plan** - A launch with no `args` at all must reach the `stop:{verb:'launch'}` guard rather than a `TypeError` on `args.spec` two lines above it; the reference says `args` is `undefined` when not provided.

7. `docs/specs/autonomous-cycle/autonomous-cycle-22-…md:72` (the "flagged below in the CONCERNS line" clauses) and `autonomous-cycle-29…md:65` - **plan** (story 29 correctly routed two API gaps to the owner of `vulyk-cycle.js`; story 26 had already landed and nothing in `plan.md` or `journal.md` answers them) - The two gaps story 29 raised - `phase` inside `agent()`'s options, and the throw-to-`null` behaviour of `parallel`/`pipeline` - must be closed on the record, not left as an open CONCERNS line the next reader has to re-investigate: the tool's own script reference (quoted above) documents both, so one line in the plan or story 22 saying so, with that source named, retires them.

8. `.claude/workflows/vulyk-cycle.js:32` (`log(\`vulyk-cycle: ${spec} · stamp ${stamp}\`)`) - **plan** (story 26 named "absent from every seat prompt"; a narrator line is not a seat prompt) - A value whose only job is to be unknown to the seats should not be printed anywhere: the narrator line lands in the Queen's transcript, which the learnings hook persists; no seat sees it, so this is gratuitous rather than a breach.

9. `.claude/workflows/vulyk-cycle.js:168` (`stop:{verb:'repair', round, error}`) vs C11's `stop:{verb, file, error}` - **plan** (delta 7 R30 introduced `round` in the stop shape without amending C11's text; `vulyk-build.md:90-93` reads it correctly) - C11 must list the `repair`/`launch` stop shapes it now returns, so the wake-up step and the contract agree on the key set.

## Worker claims spot-checked

- Story 26: harness passes; `grep -c 'pipeline('` = 0; 188 lines; "flagged in CONCERNS … loses the original `res.error` text" - true, and that is major 2.
- Story 27: "Fixed 5 pre-existing fixtures" - `dashev`, `runev`, `realverbs` rounds 1 and 2-3, `exhaust1` reordered to `VERDICT: PASS` first (diff); "surprise: `review_verdict_of()` passes the whole stored file" - true, `:470-474` drops the header, probe f shows `judge` reading BLOCK off a stored fold.
- Story 28: greps empty; "`vulyk-review.md` step 3 untouched" - the diff touches only step 2 and step 4.
- Story 29: greps empty; "the story-22 diff is one bullet" - 1 insertion, 1 deletion; D1's `REOPEN`/`CEILING` rows match `cmd_reopen`; "confirmed against `build_round`, which writes head/pack/opened/court/ceiling/tier in that order" - the live `round-3/ROUND` has exactly those six lines in that order; "fans workers out over `pipeline()`" - **does not hold** (minor 1).

## Method and limits

- Reproduced in throwaway repos (never the working tree): probe a (empty review body -> exit 4 + attempt file), b (leading blank line -> exit 4), c (bare `BLOCK` accepted), d (`VERDICT:BLOCK` rejected), e (CRLF story -> `close-story` exit 0, last line valid JSON), f (fold output recorded, `judge` -> `review:"BLOCK"`); `node --check` on four synthetic files (major 1); `json_escape` on six inputs in isolation (minor 3).
- Reasoned from the code, not executed: every Workflow-driver path (R29, R30, R32, majors 2 and 3, minors 2's Tier-4 half, 5, 6, 8, 9) - the runtime is not reachable from a review session; the driver was parsed as an async function body and its `foldReviews` was run through the story's harness, nothing more.
- The Workflow API question was weighed against two sources: the public page story 29 fetched (silent on three items) and the tool's own script reference served by this session (states all three). Named as such above; the driver has still never run.
- Read-only throughout: no writes into the repository, no commits, no `git checkout`/`restore`/`stash`/`clean`; `.vulyk/court/` never entered; the live round 3 was observed through `status --json` and `cat ROUND` only and left alone.

===== second reviewer (opus) =====
VERDICT: PASS

Second reviewer (Opus 5), Tier 4, spec `autonomous-cycle`, branch `vulyk/autonomous-cycle` at `69f0a50`,
MAIN tree. Round 3 — the ceiling round. Repair diff `git diff 19667a3...HEAD`; whole change
`git diff main...HEAD`. Read-only throughout: no writes to the repository, no commits, no
`git checkout`/`restore`/`stash`/`clean`; `.vulyk/court/` never entered.

No critical finding, so PASS. Four majors and five minors follow, none trimmed. The round-2 critical
(N-C1) and all five round-2 majors are met; the evidence is below, finding by finding.

## What I ran

- `bash tests/cycle.test.sh` — exit 0, 36 `ok`, 0 `::error::`. `bash tests/council.test.sh` — exit 0,
  260 `ok` (243 at round 2), 0 `::error::`. Both in the foreground, output read.
- `node --check .claude/workflows/vulyk-cycle.js` — clean; the file is 188 lines.
- Story 26's `foldReviews` harness, verbatim from the story's acceptance criterion — prints `fold ok`.
- A `mktemp` hive built from the real `scripts/` + a fixture `CLAUDE.md` `## Commands` table, driving
  the real `close-story` with backslash-bearing and quote-bearing cells, reading the raw last line
  through `od -c` and `jq`.
- A second `mktemp` hive with CRLF-written `CLAUDE.md` and story file, to test the escape residue.
- A node harness mirroring `vulyk-cycle.js:117-132` byte for byte, to drive the two-miss stop shape.
- **The Workflow script API checked against the reference Claude Code itself loads to author a
  Workflow script** (the `workflow-authoring` skill on this machine) — not from memory and not from
  the single web page story 29 fetched. This is the round's mandate item and it changes three of
  story 29's recorded conclusions; see **X-M2**.

---

# The mandate question: do the fixes rest on unconfirmed runtime behaviour?

**No. All three behaviours R28/R29/R32 rest on are documented, and so is the fourth thing story 29
flags as a mismatch.** Quoting the authoritative reference:

| Behaviour the driver relies on | What the reference says |
|---|---|
| `agent()` returns `null` | "Returns null if the user skips the agent mid-run or the subagent dies on a terminal API error after retries (filter with `.filter(Boolean)`)." |
| a throwing `parallel` thunk resolves to `null` | "A thunk that throws (or whose agent errors) resolves to `null` in the result array — the call itself never rejects." |
| a throwing `pipeline` stage drops its item | "A stage that throws drops that item to `null` and skips its remaining stages." |
| `phase` as an `agent()` option key | `agent(prompt, opts?: {label?, phase?, schema?, model?, effort?, isolation?, agentType?})` — and: "opts.phase explicitly assigns this agent to a progress group (**use this inside pipeline()/parallel() stages** to avoid races on the global phase() state)." |

So `dispatchSeat`'s `phase: 'Round'` inside `agent()`'s options is not a mismatch — it is the
documented remedy for exactly the situation it is used in (an `agent()` call inside a `parallel`
thunk). Story 29's R14 note records it as a defect to fix; acting on that would remove correct,
recommended code. The other two rows are recorded there as "unverified by VULYK"; they are
documented. That is **X-M2** below. The nested `parallel` inside a `parallel` thunk that
`dispatchSeat` uses at Tier 4 is also a shape the reference shows in its own composing example, and
`meta.phases` matches the four `phase()` titles as the reference requires.

---

# Round-2 findings — status

## Critical

**N-C1 · the Tier 4 fold recorded a verdict nobody wrote — MET.**
`foldReviews` (`vulyk-cycle.js:68-81`) folds only when both first lines match
`/^VERDICT:\s*(PASS|BLOCK)\b/`; anything else returns `NO VERDICT: top=… · second=…` with both
bodies verbatim, `(no report)` for a blank side. Story 26's harness passes (`fold ok`) — including
`null,null`, one-sided null, empty string, and a prose first line, none of which produce a
`VERDICT:` first line, and the survivor's body is kept. `recordSeat` (`:144`) sends `report ?? ''`,
so `String(null)` never reaches the heredoc. The other half of the fix is script-side and I watched
the whole chain run green in `council.test.sh`: a prose first line is MALFORMED even with
`VERDICT: PASS` on line 3 (`attempt-1.md` kept); the driver's own `NO VERDICT:` fold shape is
MALFORMED as a second rejection; `attempt-2.md` written, no `review.md`, review ABSENT; every other
seat GREEN → `ESCALATE`, row `escalate:env`, `review:"ABSENT"` — the `envpartial2` shape, where the
surviving report is readable in the attempt files. The condition is satisfied in both halves.

## Major

**N-M1 · an empty worker report was unbounded — MET.** `vulyk-cycle.js:117-132`: `if (!reports[i])
continue` is gone; an empty or null report and a red `close-story` share one `attempts` map keyed by
file; `close-story` is not run on an empty report; the second miss for one file ends the run with
`stop` naming the file. Reproduced with the node harness. (The *text* of that stop is a new major —
**X-M1**.)

**N-M2 · `pipeline` swallowed a `BadLine` — MET.** `grep -c 'pipeline(' .claude/workflows/vulyk-cycle.js`
= 0. Seats are dispatched under `parallel` (`:147`) and recorded in a plain sequential `for` loop
(`:149-158`), so `clerk()`'s `BadLine` reaches the one outer catch that returns the raw line
(`:185`). A non-4 record-seat failure is remembered and the loop still records every remaining seat
before failing — the "a seat's report is always recorded" rule survives the restructure. The premise
I reasoned from is confirmed by the reference quoted above.

**N-M3 · the delimiter's entropy was the clock — MET, both halves.**
`.claude/commands/vulyk-build.md:15` and `.claude/commands/vulyk-review.md:24`:
`stamp="$(od -An -tx1 -N8 /dev/urandom | tr -d ' \n')"`, 16 hex characters, taken once;
`grep -n 'date -u +%s'` over both files is empty. The overstated sentence is gone from both:
`grep -n 'cannot guess\|no report body can guess'` is empty, and in its place both say the report
travels as free text inside the clerk's prompt and the delimiter is "a per-run random value the seat
is never told" — which is what the construction actually buys. `vulyk-cycle.js:29-31` refuses to
launch when `args.stamp` is not a string of at least 12 characters, before the first clerk call, so
the constant `VULYK_undefined_<seat>_1` is unreachable. `stamp` appears in no seat prompt.

**N-M4 · `emit` wrote unescaped values into the last line — MET.** Reproduced through the real verb,
not the fixture: a hive whose `## Commands` cell is `` `sh -c 'echo a\b; exit 1'` `` yields
`{"ok":false,"verb":"close-story","exit":4,"next":"repair","error":"sh -c 'echo a\\b; exit 1'"}` —
`jq -e .` valid, `jq -r .error` byte-identical to the cell. A Windows-path cell
`` `sh -c 'echo C:\path\to\x; exit 1'` `` likewise. `json_escape` (`cycle.sh:42-53`) runs backslash
first, then quote, then tab/newline, and `emit` pushes `verb`, `next` and `error` through it. The
suite asserts both cases byte for byte and I watched them pass. Residual: only those four
characters — **X-m1**.

**N-M5 · ADR D2's driver sketch showed the forbidden shape — MET.** The code block is gone;
`grep -n "<<'EOF'\|schema: LAST_LINE\|council-\${seat}" docs/adr/001-cycle-state-contract.md` is
empty; `## Resume` (`:195`) names the same four `args`. D1 gained `council/REOPEN` and
`council/CEILING` rows with `reopen` as writer, the `ROUND` row gained `tier=` as its sixth field,
D2's `record-seat` precondition now reads "not stale by `round_is_stale`", and `## Consequences:291`
no longer contradicts D5. The replacement paragraph carries one new wrong claim — **X-M3**.

## Minor

**FIXED:** **N-m4** — folded into R28. `review_verdict_of_text` (`cycle.sh:456-468`) reads
`sed -n '1p'` only, so `PASS/BLOCK decision: BLOCK` in a body no longer scores (asserted in the
suite); `review_verdict_of` (`:470-473`) drops the C4 header with `sed '1d'` before reading line 1 —
the worker caught that `judge` passes the stored file, whose own line 1 is the header, and every one
of the three callers fails closed on an empty result (`ABSENT` at `:559`/`:1550`, `BLOCK` at `:683`).
**N-m6** — D1 now lists every file and field the cycle writes.

**RECORDED, NOT FIXED — each verbatim in `plan.md` `## Next circle`, condition unchanged:**
**N-m1** (folded with LR r2 minor 4), **N-m2** (folded with LR r2 minor 7), **N-m3** (the
`ROUND`-marker crash window — still live, unchanged), **N-m5** (folded with LR r2 minor 10),
**N-m7**. **N-m8** is met in form — the note now points at a real fetch with a URL and a date — but
its conclusions are wrong on three counts: **X-M2**.

## C-4 residue

Sink 2 (the `## Commands` gate) is unchanged and still closed: `cmd_close_story:1370-1388` refuses
unless every `&&`-separated segment of every `## Verification` line is a literal cell of the hive's
table, and the gate runs before the execution loop. Sink 1 is narrowed further by R31 — the stamp is
now 16 random hex rather than a wall-clock second — and, more to the point, the words around it now
match the mechanism. The residual itself is unchanged and now stated rather than denied: the report
still crosses a Haiku clerk's prompt as free text, and the hive's allow rule
`Bash(bash scripts/cycle.sh:*)` (`install.sh` `wire_permissions`, untouched this round) prefix-matches
the whole command string, so anything past a broken heredoc runs under the same grant. That is the
taken decision, not a silent narrowing.

---

# New findings

## CRITICAL

None. Nothing in stories 26-29 reproduced as a defect against a contract or an ask.

## MAJOR

### X-M1 · `.claude/workflows/vulyk-cycle.js:121-130` · route: `plan`

The two-miss stop always reads `error: 'worker returned no report'`, including when both misses were
red verifications and the worker reported each time. Reproduced with a node harness mirroring the
block byte for byte: a story whose worker returns a report and whose `close-story` answers
`{ok:false, exit:4, error:"bash tests/council.test.sh"}` twice ends the run with
`{"stop":{"verb":"build","file":"docs/specs/x/x-01.md","error":"worker returned no report"}}` — the
failing verification line is discarded.

This is the one channel the Workflow driver has to the Queen on that path, and `/vulyk-build.md`
step 4 tells her to "append the error to its `## Findings`", so a blocked story is documented with a
sentence that is false and `lead-architect` is consulted without the command that failed. Story 27
exists to make that `error` parsable and exact; story 26 throws it away on the single most common
terminal build outcome. The fallback driver does not have this problem — its `build:<wave>` row says
to append "the `error`, the worker's own `## Findings`, or 'worker returned no report'", so the two
drivers now disagree on the same contract.

Routed `plan`: story 26's acceptance criterion specifies this literal stop shape, and the worker
flagged the consequence in its own notes (`## Implementation notes`, bullet 2) rather than silently
diverging.

**Condition:** a two-miss build stop must name the failure that actually occurred — the verb's own
`error` when the last miss was a red verification, "no report" only when the worker returned nothing.

### X-M2 · `docs/specs/autonomous-cycle/autonomous-cycle-22-driver-acts-on-exit-codes.md:72` · route: `worker`

The corrected R14 note is honest about its source and quotes it accurately, but three of its
conclusions are wrong against the platform reference Claude Code loads to author a Workflow script:

1. It records `phase: 'Round'` inside `agent()`'s options as a "mismatch, flagged below", and the
   worker's CONCERNS line hands that to the next circle. The reference lists `phase` in `agent()`'s
   options signature and recommends it specifically inside `parallel()`/`pipeline()` stages — which
   is precisely where `dispatchSeat` (`vulyk-cycle.js:87,88,93`) uses it. Acting on this "gap" would
   remove correct code and reintroduce the progress-group race the option exists to prevent.
2. "a throwing `parallel` thunk resolving to `null` — NOT stated anywhere on this page". The
   reference states it outright.
3. "a throwing `pipeline` stage dropping its item — NOT stated either". The reference states it
   outright.

The page the worker fetched is a narrower document than the authoring reference; the fetch record is
faithful to it, and the escape story 29 offered ("say plainly the docs were not consulted") was
correctly not taken. The defect is that the note's *verdict* — "they stay unverified by VULYK rather
than confirmed", plus one invented mismatch — is now the record R14 closes on, and R28/R29/R32 are
recorded as resting on behaviour nobody confirmed when in fact all three are documented. Per the
protocol's "claims about verification are findings too", this one is inverted in both directions at
once: it understates what is verified and invents one defect that is not there.

**Condition:** the R14 record must reflect the platform's own Workflow-authoring reference — the
three runtime behaviours the driver relies on are documented, and `phase` inside `agent()`'s options
is a documented option, not a mismatch — so that no future circle spends a story removing it.

### X-M3 · `docs/adr/001-cycle-state-contract.md:178` · route: `worker`

The paragraph that replaced D2's sketch says the driver's `build:<wave>` branch "fans workers out
over `pipeline()`". It does not: `vulyk-cycle.js:113-116` uses `parallel()`, and R32 removed
`pipeline` from the file entirely (`grep -c 'pipeline(' = 0`). The build branch also calls
`clerk('close-story …')` per story, so a future driver author who follows this sentence and
restructures the branch as a pipeline reintroduces exactly the `clerk()`-inside-a-stage defect R32
exists to forbid — the same failure mode N-M5 named, in the text written to fix N-M5, in the document
`reviewPrompt` points every reviewer at.

**Condition:** D2's pointer paragraph must describe the driver that exists, so that no shape an
in-force decision forbids can be read out of it.

### X-M4 · `.claude/workflows/vulyk-cycle.js:27,85-89` · route: `plan`

*Shape: a Tier 4 spec launched through the Workflow driver with `args.second_model` absent or equal
to `top_model` — a launcher mistake, not a code path the driver can reach on its own.*

`args.stamp` gets a hard guard because an unset stamp is visible in the delimiter. `args.second_model`
gets none, and its absence is invisible: `agent(…, {model: undefined})` inherits the session model,
so both `lead-review` dispatches run on `top_model`, `foldReviews` folds two correlated draws as
though they were independent, and `record-seat` stores one `review` verdict with nothing to
distinguish the case. CLAUDE.md's routing matrix makes "a second reviewer on a *different* model" the
defining property of Tier 4; the driver is the component that implements it and the only one that
could notice it did not happen. Nothing downstream can: see **X-m2**.

**Condition:** a Tier 4 run must not proceed with a second reviewer that is absent or identical to
the first — the driver refuses at launch the way it refuses a missing stamp, or the round records
that the fold ran on one model.

## MINOR

### X-m1 · `scripts/cycle.sh:42-53` (`json_escape`) · route: `worker`

The helper escapes `\`, `"`, tab and newline — the four story 27 names — but JSON forbids every
control character below U+0020. A carriage return, ESC, backspace or form feed in a value reaching
`emit` still produces a last line `jq` rejects: I confirmed `{"…","error":"npm test\r"}` and an
ESC-bearing value are both `parse error: Invalid string: control characters … must be escaped`. I
could **not** reproduce this through a real story file: I wrote a hive with CRLF `CLAUDE.md` and a
CRLF story and `close-story` still emitted a clean line, because the shells that would produce the CR
strip it on read. So this is a residue of my round-2 condition ("parsable whatever the hive's
commands contain"), not a live break — and the driver fails loudly (`BadLine`) rather than silently
if it ever happens.

**Condition:** `json_escape` must cover every character JSON requires escaped, not the four the
fixture exercises.

### X-m2 · `.claude/workflows/vulyk-cycle.js:145` and `scripts/cycle.sh:757` · route: `plan`

`recordSeat` never passes `--model`, so every seat the Workflow driver records carries `model:` empty
in its C4 header and `unknown` in the ledger row — on every Workflow-driven round, at every tier. The
`review` seat is worse off still: the row schema has `haiku_model`, `sonnet_model` and `opus_model`
but no `review_model` at all, so a Tier 4 round leaves no record anywhere of which two models
produced the folded verdict. `council/round-2/review.md`'s own header reads `model: fable+opus` only
because the Queen recorded that round by hand. Pre-existing rather than introduced here, but R28 made
the fold the mechanism that carries Tier 4's model diversity, and this is where that fact goes to die.

**Condition:** a recorded seat must carry the model that produced it, and a folded Tier 4 review must
name both.

### X-m3 · `.claude/workflows/vulyk-cycle.js:71,75` vs `scripts/cycle.sh:462` · route: `worker`

The driver accepts `/^VERDICT:\s*(PASS|BLOCK)\b/` — any whitespace, or none — while
`review_verdict_of_text` requires the single literal space of `^VERDICT: (PASS|BLOCK)\b`, which is
what `.claude/agents/lead-review.md:29` promises ("exactly `VERDICT: PASS` or `VERDICT: BLOCK`"). A
reviewer writing `VERDICT:BLOCK` is folded and normalised at Tier 4 but MALFORMED at Tier 1-3, so the
same report gets two different fates depending on the tier.

**Condition:** both parsers must accept the same first line, the one the agent contract names.

### X-m4 · `docs/specs/autonomous-cycle/autonomous-cycle-22-…md:72` · route: `worker`

The same R14 note cites `vulyk-cycle.js:71,74-77` for `dispatchSeat`; after story 26's rewrite
`dispatchSeat` is at `:85-94`. Stories 26 and 29 landed in the same wave, so the citation was stale
the moment it was written.

**Condition:** a line citation in a record must point at the file as it ships.

### X-m5 · `.claude/workflows/vulyk-cycle.js:121` · route: `worker`

`if (reports[i])` treats any non-empty string as a report, so a worker that returns only whitespace
runs `close-story` instead of counting as a miss. Story 26 says "empty/null"; `"   "` is neither by
that test but is by any useful one. Narrow — it costs one `close-story` call and the story still lands
in the same two-attempt bound the next iteration.

**Condition:** a report with no content must be a miss whether or not it contains whitespace.

---

# Method and limits

- Both suites run in the foreground from the repo root, output read, not assumed: `cycle.test.sh`
  36 `ok` / 0 errors, `council.test.sh` 260 `ok` / 0 errors, both exit 0.
- **Reproduced in throwaway `mktemp` repos** (never the working tree): N-M4 (two cells, raw bytes and
  `jq` round-trip), X-m1's negative result (the CRLF hive). **Reproduced with a node harness
  extracted from the shipped file:** N-C1 (story 26's own harness), X-M1.
- **Confirmed by reading the code plus a suite assertion I read and watched run green:** N-C1's
  script half (the `NO VERDICT` → `attempt-2` → ABSENT → `escalate:env` chain), N-m4, N-M4's fixture.
- **Confirmed by grep against the shipped files:** N-M2, N-M3, N-M5, the story 26 forbidden-string
  greps, `node --check`.
- **Checked against the platform's own Workflow-authoring reference on this machine**, quoted rather
  than paraphrased: every claim in the mandate section and X-M2. The Workflow runtime itself is not
  reachable from a review session, so X-M4 is reasoned from code plus that reference, not executed;
  its severity rests on a launcher mistake and says so.
- **Reasoned from code only:** X-M3, X-m2, X-m3, X-m5.
- `status.tier` and `missing` both read the round's frozen `tier=` (`cycle.sh:316,329`), so the
  driver's Tier-4 branch and the seat list cannot disagree — checked because the fold depends on it.
  `status.round` is the highest round directory, so the `repaired` Set keys distinctly per round —
  checked because a shared key would refuse the second repair of a run.
- `wire_permissions` is byte-identical to round 2 (`git diff 19667a3...HEAD -- install.sh` empty); I
  re-read it rather than assume.
- I did not re-verify M-7 (deferred by R27, still live), nor the round-1 and round-2 minors
  `## Next circle` carries; I confirmed each of my own is recorded there with its condition unchanged,
  and nothing from either round was dropped.
- The live round 3 (`council/round-3/ROUND`, opened at `69f0a50`) was observed through `git` only and
  left alone.
