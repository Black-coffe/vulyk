# v0.12.0 remainders: the cycle, both drivers and the installer keep their word (plan)

**Tier:** 4 · **Spec slug:** `v0-12-0-remainders` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-001 [docs/adr/001-cycle-state-contract.md](../../adr/001-cycle-state-contract.md) (C1-C15, D1-D5 - the state contract every cycle.sh story amends in place) · ADR-004 [docs/adr/004-driver-mutual-exclusion.md](../../adr/004-driver-mutual-exclusion.md) (the DRIVER semaphore, accepted 2026-09-13 - story 11 builds it as written) · ADR-005 [docs/adr/005-installer-upgrade-contract.md](../../adr/005-installer-upgrade-contract.md) (proposed 2026-09-13: ship set D1, manifest D2, constitution blocks D3, the eleven install-smoke assertions D4 - stories 07 and 10 build exactly this) · ADR-006 [docs/adr/006-worker-status-channel.md](../../adr/006-worker-status-channel.md) (proposed 2026-09-13: the worker writes `returned:` into its story, `close-story` refuses anything but `DONE` - stories 08 and 09) · CLAUDE.md `## Commands` (the only legal `## Verification` cells)
**Depends on:** v0.12.0 (`a7e8c5d`, merged 2026-09-13): `scripts/cycle.sh`, `scripts/lib.sh`, `tests/council.test.sh`, `.claude/workflows/vulyk-cycle.js`, `/vulyk-build`, `install.sh` at `3e200bb`; `docs/specs/autonomous-cycle/plan.md` `## Next circle` and `council/round-3/review.md` (the defect list, file:line at `3e200bb`). Second reviewer per the Tier 4 rule: `opus` beside a Fable gate.

## Goal

Close what v0.12.0 shipped with known holes, runtime first: the Workflow driver gets a real test that executes it (not `node --check`) and its terminal stops say what actually happened (a red verification, a missing second reviewer, a paused tree); a walled worker's story can no longer be closed because the worker records its outcome in the story and `close-story` reads it there; `cycle.sh` fixes the eighteen behavioural defects the three council rounds recorded (round-number prefix matches, `attempts` counting files, `**Council:**` at EOF, blocked stories dispatched, `done` stamped before a failing commit, `ok:false` without a reason, the ceiling block without its RED rows, the court reduction commit hidden by `|| true`, and the rest); a `DRIVER` semaphore refuses a second driver on the same spec, exactly as ADR-004 decided; the SessionStart brief stops spawning the CLI; and the installer stops leaking VULYK's own ADRs and wiki, learns to remove retired files through a manifest, and carries the missing `## Profile`/`## Commands` blocks into an upgraded constitution so the council can be run on every hive. Docs, ADR prose and CHANGELOG stay for the second spec (PG2).

## Assumptions

- **ADR-006 decides M3 (option 2b)**: the worker writes `returned: DONE | NEEDS_CONTEXT | WALL` into its story's frontmatter as its last edit; `cmd_close_story` exits 4 `error: "returned <value>"` (`returned: missing` when empty) before scope-check and before verification; neither driver changes for this (exit 4 is already a miss). The `schema`-on-`agent()` option is rejected there and appears nowhere in this plan.
- **This spec's own stories carry the key.** Every story file here already has an empty `returned:` line, and every worker dispatched for this spec sets it to `DONE` as its last edit - story 08 lands the gate in wave 3, and any story closed after that commit is refused without it. Until story 09 lands the protocol in `worker-code.md`/`worker-test.md`, the Queen's dispatch prompt carries the one sentence.
- **ADR-005 is followed as written** (D1-D4): the plan restates its line shapes in K6/K7 for the two workers; where the ADR and K6/K7 differ, the ADR wins and the worker says so in its notes. Recon (2026-09-13): the markers wrap only the tables (`## Profile` at `CLAUDE.md:136`, `PROFILE:START` at 154, `:END` 166; `## Commands` 168, `COMMANDS:START` 173, `:END` 204, prose between heading and marker), so D3's "from the preceding heading through `:END`" carries that prose with the block. `docs/wiki/` is empty and `docs/adr/` holds only numbered ADRs, so the README allow arm is a no-op today, kept because the brief says README stays. One addition beyond the ADR, flagged for the owner: when a block was inserted, the closing line at `install.sh:452` says so instead of claiming `CLAUDE.md` was not touched (ask 5's "not touched" phrases must be true after ask 7 runs).
- **Round-1 minor m-3 (gitignore glob) is verified closed by recon, no story**: `install.sh:340-342` writes each entry with `echo "$line"` byte for byte (`recon/install-and-update.md`).
- **Exit 6 means "escalation recorded", `ok:true`, `next:"escalated"`, from every verb** (`judge`, `escalate`, `open-round` alike). Rejected: making `judge`/`escalate` emit `ok:false` to match `open-round` - an escalation is a successful recording, and both drivers already treat `ok:false` as a failed verb.
- **r2m16 is resolved on the verb side**: `open-round` exits 2 (`error: "story <id> is blocked"`) when any story is `blocked`; `status --json` and the `/vulyk-build` sentence are unchanged. Rejected: a new `next` value - the vocabulary is the driver contract and the refusal already reaches both drivers as a named stop.
- **r2m15 is resolved by the Workflow refusing**: on `next:"briefed"` the driver returns `stop:{verb:'briefed', error}` and never calls `briefed --commit`; the fallback already refuses (`vulyk-build.md:55`), so only the driver changes.
- **Semaphore scope is ADR-004's four verbs** (`open-round`, `record-seat`, `judge`, `close-story`) plus `pause`/`resume` releasing. With no `DRIVER` file the four verbs proceed without `--stamp` (hand runs, the suite, an owner's `cycle.sh` call); the file is the claim. `/vulyk-review` claims and releases like a driver (story 13). `escalate`, `reopen`, `briefed`, `branch` are not gated.
- **r2m8 (the seat scan in three copies) is not an ask.** Story 01 fixes `attempts` in every copy; unifying the helper goes to `## Next circle`.
- **Verification for installer and hook stories is the `bash -n` cell**, the precedent `autonomous-cycle-14` closed with; recon confirms `cycle.sh:1291-1301` reads the cell's `\|` as a literal `|` before the match. The real proof is the CI job plus a hand smoke run in `mktemp -d`, both named in acceptance criteria.
- **ADR-004 stays as accepted intent**; its "Revisit when" fires with story 11, and folding the built contract into ADR-001 D1/D2 is ADR prose - second spec (PG2), listed under `## Next circle`. ADR-005's `docs/wiki` invariants and the recon vocabulary line are likewise docs work for the second spec.
- **`tests/driver.test.sh` executes the driver the way the round-3 review parsed it**: `export` stripped, body compiled as `AsyncFunction(args, agent, parallel, pipeline, phase, log)`. Recon confirms the file is `export const meta` (lines 1-10) then bare top-level statements with top-level `return`s and one `try/catch` closing at 184-188, no `export default` - that compile is the right parse.
- **Editing `docs/specs/autonomous-cycle/autonomous-cycle-22-*.md`** (a `done` story of a shipped spec) is a record correction, not a reopen; story 03 names the path so `scope-check.sh` accepts it.
- **Coverage check (drone-coverage, 2026-09-13) read ask 5 as partial**: the plan defers "ADR-005's docs/wiki invariants" to the second spec. Clarified: story 07 enforces the `docs/wiki/*` exclusion now (D1 deny arm, acceptance criterion "no `would copy docs/wiki/` line"); only the `docs/wiki/` *note* describing ADR-005's invariants is second-spec docs work. Ask 5 is fully carried.

## Stories

**Wave 1** - four disjoint file sets; the driver test harness and the ledger fixes start here
- `v0-12-0-remainders-01-cycle-judge-ledger` - `scripts/cycle.sh` + `tests/council.test.sh`: LR19 attempts, LR21/r2m1 exact round match, LR25 `**Council:**` by C7, m-10 atomic append, m-4 same-second override, N-m7 note through redact.
- `v0-12-0-remainders-02-driver-test-harness` - `tests/driver.test.sh` (new), `CLAUDE.md` `## Commands` row, `ci.yml` job `driver`: the real parse, the fold harness, the stub loop, `skipped` without node.
- `v0-12-0-remainders-03-records-describe-the-driver` - story 22 R14 note and ADR-001 D2 paragraph (`:174-187`, `:296`) describe the driver as it is (X-M2, X-M3, minor 1, M1's ADR sentence); ADR-001 D2 exit-code line gains ADR-006's `returned:` clause.
- `v0-12-0-remainders-04-gates-drop-drone-acceptance` - `ship-check.sh:190` same-second override, `ship-check.sh:227` / `acceptance-log.sh:72` / `drone-docs.md:14` stop naming `drone-acceptance`; `tests/cycle.test.sh` scenario.

**Wave 2**
- `v0-12-0-remainders-05-cycle-open-round-honest-stops` - `cycle.sh` + suite: r2m3, r2m16, r2m5, r2m6, N-m3, r2m7/N-m2, r2m4/N-m1 (every `ok:false` names its error; exit 6 uniform). blocked_by 01.
- `v0-12-0-remainders-06-driver-stops-tell-the-truth` - `vulyk-cycle.js` + driver suite: M2/X-M1, X-M4, no-`args` guard, whitespace report, r2m17, r2m15, exit-6 scenario. blocked_by 02.
- `v0-12-0-remainders-07-installer-ships-the-truth` - `install.sh` + `ci.yml` install-smoke: asks 5 and 7 per ADR-005 D1 (ship set), D3 (`ensure_marked_block`, sidecar, warnings, shared placeholder printers), D4 assertions 1, 7-11; the `docs/specs/*/DRIVER` gitignore entry. blocked_by 02 (ci.yml).

**Wave 3**
- `v0-12-0-remainders-08-cycle-close-story-owns-its-commit` - `cycle.sh` + suite: r2m2, LR31, r2m9, and ADR-006's `returned:` gate with `cstoryr1..r4`. blocked_by 05.
- `v0-12-0-remainders-09-workers-record-their-outcome` - `worker-code.md`, `worker-test.md`, `templates/story.md`, `/vulyk-build` `build:<wave>` row, three driver-suite scenarios proving the driver never read the prose (ADR-006). blocked_by 06.
- `v0-12-0-remainders-10-installer-manifest` - `install.sh` + `ci.yml`: ask 6 per ADR-005 D2 (manifest, removal rule, `leave (yours)`, `unlisted (kept)`), D1's manifest arm, D4 assertions 2-6, 11. blocked_by 07.

**Wave 4**
- `v0-12-0-remainders-11-cycle-driver-semaphore` - `cycle.sh` + suite + `.gitignore`: ask 3, `claim`/`release`, `--stamp` on four verbs, `pause`/`resume` release (K3). blocked_by 08.
- `v0-12-0-remainders-12-session-brief-no-cli` - `.claude/hooks/top-model-brief.sh` + `ci.yml` top-model job: ask 4. blocked_by 10 (ci.yml).

**Wave 5**
- `v0-12-0-remainders-13-drivers-hold-the-semaphore` - `vulyk-cycle.js`, driver suite, `/vulyk-build`, `/vulyk-review`: both drivers claim, pass `--stamp`, release on every exit. blocked_by 11, 09.

## Contracts

**K1. `emit` invariants (all verbs).** Every last-line object with `"ok":false` carries a non-empty `"error"` naming the reason (the precondition, the git failure, `paused`, `held by <stamp>`, `stale`, `returned <value>`). Exit 6 is always `{"ok":true,"verb":"<judge|escalate|open-round>","exit":6,"next":"escalated"}`. Exit 3 is always `{"ok":false,"exit":3,"next":"paused","error":"paused: <first line of PAUSE>"}`. Exit 4 from `close-story` is `{"ok":false,"verb":"close-story","exit":4,"next":"repair","error":"<verification line> | returned <value> | returned: missing"}`. The driver (story 06) treats any clerk line with `exit:3` as the `paused` terminal and any `ok:true` line by re-polling `status`. `open-round` on a `blocked` story: `{"ok":false,"verb":"open-round","exit":2,"next":"open-round","error":"story <id> is blocked: <file>"}`. Unchanged otherwise: C2 exit codes, C3 keys.

**K2. Driver stop shapes** (`vulyk-cycle.js` return value, read by `/vulyk-build` step 4): `{verb, exit, error}` for a failed verb; `{verb:'build', file, error}` after two misses, where `error` is the last miss's own text - the `close-story` line's `error` when that miss was an exit 4 (a red verification or `returned <value>`), `'worker returned no report'` when the worker returned null/empty/whitespace; `{verb:'launch', error}` for a missing `args`, a bad `stamp`, or a Tier 4 spec whose `second_model` is missing or equal to `top_model`; `{verb:'briefed', error:'spec not briefed: run /vulyk-plan'}`; `{verb:'repair', round, error}` unchanged. Terminal `next` values unchanged (`green`, `escalated`, `paused`, `shipped`).

**K3. DRIVER semaphore** (ADR-004, built by story 11, honoured by story 13). File `docs/specs/<slug>/DRIVER`, gitignored (`.gitignore` entry `docs/specs/*/DRIVER`; `install.sh` `ensure_gitignore` ships the same entry - story 07; the council suite's fixture `.gitignore` at `tests/council.test.sh:30` is a literal `printf` and gains the same line). Content: two lines `stamp=<stamp>` and `claimed=<ts>`; only `stamp=` is read. Verbs: `claim <spec> <stamp>` - creates the file under `set -o noclobber`; exit 0 when created or when the existing stamp equals `<stamp>`; exit 2 `error:"held by <other>; run: bash scripts/cycle.sh release <spec> <other> if that driver is dead"` otherwise; honours PAUSE (exit 3). `release <spec> <stamp>` - removes the file when the stamp matches or the file is absent (exit 0); exit 2 `held by <other>` on a mismatch. `pause` and `resume` remove the file unconditionally and journal `driver released`. `open-round`, `record-seat`, `judge`, `close-story` accept `--stamp <stamp>`: when `DRIVER` exists and `--stamp` is absent or differs, exit 2 `held by <stamp>` before any effect (checked right after the PAUSE guard); when `DRIVER` is absent they proceed. No `--commit` on `claim`/`release`. Both drivers: claim once after the stamp is taken (Workflow: first clerk call; fallback: step 1), pass `--stamp $stamp` on the four verbs, release on every exit path including a `stop`.

**K4. `tests/driver.test.sh` stub interface** (story 02 creates; 06, 09, 13 add scenarios). Bash file in the suite shape (`set -u`, `expect`, `fail` accumulator, `exit $fail`); prints `skipped: node not found` and exits 0 when `command -v node` fails. One node program (heredoc on stdin) that: reads `.claude/workflows/vulyk-cycle.js`; strips `export ` at line start; compiles the rest as `new (async function(){}).constructor('args','agent','parallel','pipeline','phase','log', body)` (the file is bare top-level statements with top-level `return`s, so this is the runtime's own shape); asserts a garbage file with `export` fails that compile (the inverse check that `node --check` could not do); runs the `foldReviews` harness from `autonomous-cycle-26` line 54 verbatim (prints `fold ok`); and exposes `run(args, script)` where `script = { clerk: [...], agents: [...] }`. Stubs: `agent(prompt, opts)` - when `opts.agentType === 'cycle-clerk'` shifts the next `clerk` entry (a JSON string, or an object the stub serialises) and pushes `{verb, cmd: prompt}` to `calls`; otherwise shifts the next `agents` entry (a string, `null`, `'   '`) and pushes `{agentType, model, prompt}` to `calls`; `parallel(thunks)` = `Promise.all` with a throwing thunk resolved to `null`; `pipeline(items, ...stages)` = sequential stages, a throw drops the item to `null`; `phase`/`log` push to `phases`/`logs`. Each scenario prints `ok <label>` or `FAIL <label>`; the bash side greps them through `expect`. The verb of a clerk call is parsed from the prompt with `/scripts\/cycle\.sh (\S+)/`; the story file argument with `/close-story (\S+)/`.

**K5. Worker outcome in the story file** (ADR-006, stories 08 and 09). Frontmatter key `returned:` after `status:`, empty in a fresh story (`templates/story.md`: `returned:              # written by the worker as its last edit: DONE | NEEDS_CONTEXT | WALL`). The worker sets it to the same word its `STATUS:` line carries, as its last edit; on `NEEDS_CONTEXT` the exact question goes under `## Findings`. `cmd_close_story` reads it after the `status:` case and before `scope-check.sh`: `DONE` proceeds; anything else exits 4, `next: repair`, `error: "returned <value>"` or `"returned: missing"`, `status:` unchanged, no commit. Neither driver reads a report to decide; `/vulyk-build` runs `close-story` on every non-empty return and counts exit 4 as a miss whatever its `error` says. `blocked` is written only by a driver after the second miss.

**K6. Manifest and removal** (story 10; ADR-005 D1/D2 verbatim wins on any difference). `.claude/vulyk-manifest`: one path per line, LF, `LC_ALL=C sort`, hive-root-relative, forward slashes, no `./`, listing exactly the paths `copy_tree` found shippable this run (copied, updated or skipped-as-existing); never the manifest, the stamp, `CLAUDE*.md` or `AGENTS.md`; written in the stamp's guarded block on every non-`--check` run; `--check` prints `would write    .claude/vulyk-manifest (<n> paths)`; committed by the hive, not gitignored; `shippable()` returns 2 for it. Removal, after the copy loop and before the new manifest: a path in the old manifest, absent from the new ship set, with `owned()` true, is deleted and printed `remove         <path>` (`--check`: `would remove   <path>`, nothing deleted); a dropout outside `OWNED` is printed once `leave (yours)  <path>`; parent directories stay. No old manifest on `--upgrade`: delete nothing, print `unlisted (kept) <path>` for each file under an `OWNED` tree absent from the ship set, write the manifest. Fresh install: manifest written, no removal, no report.

**K7. Constitution blocks on `--upgrade`** (story 07; ADR-005 D3 verbatim wins). `ensure_marked_block <file> <MARKER> <label>` (placeholder on stdin) runs for `VULYK:PROFILE` and `VULYK:COMMANDS` in both "already a constitution" branches (`CLAUDE.md` and the sidecar `CLAUDE.vulyk.md`; the foreign `CLAUDE.md` beside a sidecar is never opened). Both markers present: nothing. Exactly one marker: `WARNING`, nothing written. Neither marker but the preceding heading (`## Profile` / `## Commands`) exists: `WARNING: ## Profile exists without VULYK:PROFILE markers - left as-is`, nothing written. Neither marker, heading absent: insert the source's whole section (from its `## <heading>` line through `<MARKER>:END` - heading, the prose between heading and `START`, markers, body replaced by the placeholder) immediately before the first later `## ` heading of the source present verbatim in the target, else at EOF; print `insert         CLAUDE.md '## Profile block' (placeholders)` (`--check`: `would insert   ...`). After the pass, on every `--upgrade`, per block: `  profile: <n> rows still hold <fill in: <label>, <label>, ...` or `  profile: filled` (same for `commands`). The placeholder text of each block lives in two print functions shared by `reset_commands_table` and `ensure_marked_block`. The `ensure_gitignore` list gains `docs/specs/*/DRIVER`.

**K8. `CLAUDE.md` `## Commands` row** (story 02 adds; 06, 09, 13 name it): `| Driver contract tests | \`bash tests/driver.test.sh\` |`, placed after the `Council verdict contract tests` row. The verification line of a driver story is exactly `bash tests/driver.test.sh`.

**K9. CI jobs.** Story 02 adds job `driver` (`actions/checkout` at the same major the other jobs use, `actions/setup-node` with `node-version: 22`, then `bash tests/driver.test.sh`). Stories 07 and 10 extend `install-smoke` in place with ADR-005 D4's eleven assertions (07: 1, 7, 8, 9, 10, and 11's part after 7; 10: 2, 3, 4, 5, 6, and 11's part after 3); existing steps untouched. Story 12 extends the `top-model` job's hook assertions (`ci.yml:83-86`). No story renames or reorders a job.

## Integration gate
`git ls-files '*.sh' | xargs -n1 bash -n && python -m py_compile .claude/hooks/*.py && git ls-files '*.json' | xargs -n1 jq -e . > /dev/null && bash .claude/hooks/handoff.sh status && bash tests/cycle.test.sh && bash tests/council.test.sh && bash tests/driver.test.sh`
Before each dispatch: `bash scripts/wave-check.sh docs/specs/v0-12-0-remainders`; after planning and after any delta: `bash scripts/trace-check.sh docs/specs/v0-12-0-remainders`.

## Tradeoffs

**Chosen: `cycle.sh` in four sequenced stories by verb region** (01 judge/ledger, 05 open-round, 08 close-story/status/`returned:`, 11 semaphore), each adding failing-then-passing scenarios to `tests/council.test.sh`. **Rejected: one story for all eighteen defects** - one 1900-line file, one worker, one review slot for the ledger, the court, the story gate and a new verb pair is the shape that produced three rounds last time; four slots each hold one mental model.

**Chosen: a bash-wrapped node test that executes the driver against stubs, with a `driver` CI job.** **Rejected: keeping `node --check` plus the fold harness** - the round-3 review showed `node --check` exits 0 on garbage for an ES-module file, and three of the seven majors sit in code that has never run.

**Chosen: exit 6 becomes `ok:true` everywhere; `open-round` refuses a blocked story with exit 2.** **Rejected: new `next` values (`blocked`, `escalated-by-open-round`)** - the `next` vocabulary is the whole driver interface; a named `ok:false` error and a uniform exit 6 reach both drivers without widening it.

**Chosen: the `returned:` gate folded into the close-story story (08), the worker protocol in its own story (09).** **Rejected: a fifth `cycle.sh` story** - the check is one `case` in the function story 08 already rewrites; the protocol edit touches four other files and needs no `cycle.sh`.

## Next circle
- Живой тест Haiku-места, в словах владельца: «Сразу после шипа ты апгрейдишь один хайв (VPN — на нём уже воспроизведены все три хвоста), заполняешь Client path руками и прогоняешь там одну задачу Tier 3; результат кладётся в ## Next circle этого плана как первый пункт.»
- Docs, ADR prose and CHANGELOG (PG2): LR22/r2m18 journal vocabulary, LR27, LR30 (`repeat` dead in `wave_stories`), LR35, r2m10/N-m5, r2m11, r2m14, m-6, m-9; round-3 minors 2/X-m3 (one first-line rule in both parsers), 3/X-m1 (`json_escape` all control chars), 4, 8, 9, X-m2 (`--model` from the driver, `review_model` column); r2m8 (one seat-scan helper); ADR-004 folded into ADR-001 D1/D2 as the built contract; ADR-005's `docs/wiki` invariants and the recon vocabulary line; ADR-005/006 status `proposed` -> accepted by the owner.

## Descoped
<!-- Mid-build narrowing, appended by the Queen as it happens - never silent. Each line:
what was dropped, why, and the single line quoted from the human authorizing it. Only
the human removes a requirement. -->

*(empty)*

## Plan deltas
<!--
Queen-written, from a worker's RETURN REPORT (never from a diff), one entry per change
to the plan after approval: new story cut, story files expanded, contract changed.
Each entry: date, trigger, decision, what was rejected. One-line notice to the human
when it happens. trace-check.sh accepts these entries as a quote source for stories
born after approval - a delta is requirement change on the record.
-->

<!--
The six lines below are the cycle's confirmation artifacts (docs/cycle.md): one per stage
whose command refuses without the one before it. Each placeholder is replaced by the
command or script that owns the line; `scripts/ship-check.sh` reads all six. **Briefed:**
and **Approved:** are alternatives - autonomous mode vs. the two-stop mode - either closes
stage 02. **Council:** and **Checked:** likewise close stages 04+05 together: a GREEN
council row is enough on its own, and **Checked:** is the owner's override in either
direction, newest timestamp wins (ADR-001 D1/D4).

There is no default tier: `cycle.sh open-round` refuses to open a round when this file's
`**Tier:** <1|2|3|4>` line above is missing or unparsable, rather than silently sizing the
council for the largest court.
-->
**Approved:** <owner, date - stage 02, the unconditional gate. /vulyk-build refuses without this line.>
**Briefed:** via grill, Andrei, 2026-09-13
**Branch:** vulyk/v0-12-0-remainders
**Checked:** <written by scripts/human-check.sh after the owner has looked - stage 05, and the override for stage 04+05. /vulyk-ship refuses without either this or a GREEN **Council:** line.>
**Council:** <written by scripts/cycle.sh judge/escalate - stages 04+05: "<GREEN|RED|ESCALATE|STALE> round <N>, <date>, at <sha7>, pack <fp12>[ - red: 2,5]", appended once per round.>
**Shipped:** <written by scripts/ship-check.sh --record - stage 06: the published version, and where>
