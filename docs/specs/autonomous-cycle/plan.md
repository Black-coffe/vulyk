# Autonomous cycle: the council replaces the human gate (plan)

**Tier:** 4 · **Spec slug:** `autonomous-cycle` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-001 [docs/adr/001-cycle-state-contract.md](../../adr/001-cycle-state-contract.md) (proposed - the mechanics; wins over the grill record where they disagree) · design record [docs/grill/2026-09-12-autonomous-cycle-council.md](../../grill/2026-09-12-autonomous-cycle-council.md) (Decision log 1-14 + Act 2 amendments) · CLAUDE.md `## The cycle`, `## Token economy`, `## Commands`
**Depends on:** v0.11.0 six-stage cycle (`2a35d15`, 2026-09-05): `scripts/ship-check.sh`, `human-check.sh`, `acceptance-log.sh`, `state.sh`, `tests/cycle.test.sh`, `.github/workflows/ci.yml` job `cycle`

**Tier 4, because** the change is the architecture of the cycle itself: a new state contract (ADR-001) with four new committed files and one new ledger; a new script that every driver and every command routes through; three agents replacing one plus a clerk; a Workflow driver that must behave identically to a session fallback; every one of the four cycle commands rewritten and two added; the installer, the constitution and eight docs. It touches every layer VULYK has, and the recon (`recon/*.md`) shows the existing gates are coupled to the exact markers being replaced. Second reviewer per the Tier 4 rule: `opus` beside a Fable gate.

## Goal

Replace stage 05 (the mandatory owner look) and the single `drone-acceptance` with a three-seat blind council (Haiku black-box, Sonnet ask-by-ask, Opus intent) that judges only the owner's own words (`brief.md` `## Asks`), runs in a reduced git worktree so it cannot see the hive's stories, and whose round verdict is computed by a model-free script (`scripts/cycle.sh judge`) from labelled, evidenced seat reports. Move the human to one stop at the start (a one-round grill inside `/vulyk-plan` that ends with `## Asks` and `**Briefed:**`), and move the loop build -> gates -> council -> repair out of the Queen's session into a Workflow script with a session fallback, both driven by the same `cycle.sh status --json` / `next` contract. Ceiling three rounds, early escalation at half the asks RED, `PAUSE` semaphore for a human who wants in, journal on disk mirrored to the terminal, `council.jsonl` for the rollback metric, local merge in `/vulyk-ship` with publish printed and never pressed. Ship as v0.12.0.

## Assumptions

Conflicts resolved (ADR wins on mechanics, owner wins on intent):
- **Round counter** = number of `docs/specs/<slug>/council/round-*` directories (ADR D1), not rows in `council.jsonl` (grill Act 2, row 7/4). The row is the close marker; the directory is the open marker.
- **`/vulyk-resume`** relaunches the Workflow fresh and never passes `resumeFromRunId` (ADR D2); the grill's "`/vulyk-resume` делает `resumeFromRunId`" (Act 2, PAUSE row) is dropped - a cached `status` replayed after a human touched the tree is the wrong answer.
- **Verdict script** is `scripts/cycle.sh judge` (ADR), not `council-log.sh --verdict` (grill Act 2, row 7). One script, one CLI.
- **PAUSE** is honoured by every mutating verb of `cycle.sh` (ADR D2), not only "between phases and before commits" by the Workflow (Act 2) - the stronger rule contains the weaker.
- **Seat count**: the request text says "два агента Haiku"; the owner's Q6 answer ("3 места, 3 модели, 3 разных угла") and the grill anti-scope ("второй Haiku" not done) supersede it. Stories quote Q6.
- **Who judges**: the request and Q7 say "Королева судит по доказательствам"; Q15 accepts "скрипт судит раунды". Stories implement Q15: the script judges rounds, the Queen only reads escalations and the final report.
- **"Зелёный = единогласие трёх"** (Q7/grill 7) is read as ADR D4: every seat `GREEN` or `N/A` and review `PASS`. `N/A` with a reason is consent, per Act 2 row "6, 14" and Q15 ("N/A").
- ADR D2's Workflow snippet maps the `review` seat to `` agentType: `council-${seat}` ``; there is no `council-review` agent. `## Contracts` fixes it: seat `review` -> `lead-review` at `top_model`.

Design assumptions not decided by any input (veto here):
- **Shared functions move to `scripts/lib.sh`** (`pack_fingerprint`, `paperwork_only`, `marker`) - created by story 01, consumers migrated in story 02. Rationale under `## Tradeoffs`.
- **Driver mode detection** in `/vulyk-build` and `/vulyk-plan`: the `Workflow` tool is present in the session's tool list -> Workflow driver; otherwise fallback. The SessionStart brief can only report the CLI gate (`claude --version` >= 2.1.154); the Pro `/config` flag is not visible to a hook, so the brief says "Workflow: CLI ok - enable in /config on Pro" or "Workflow: unavailable (CLI < 2.1.154)".
- **Black-box is a mandate, not a tool list.** `council-haiku` keeps `Read` (it needs `brief.md` and the Profile) and `Bash` (the Client path); "код не читает" is enforced by its prompt and the `BREACH:` line. A `Bash` seat can `cat` anything; pretending otherwise would be a false guarantee.
- **Tier 1 path**: `/vulyk-plan` detects Tier 1 (or is told `--tier 1`), writes `brief.md` with the task phrase as `## Request` and the single item of `## Asks`, one story, `plan.md` with `**Briefed:** via mini-brief, <owner>, <date>`, and launches the driver - no grill, one council round (Q13).
- **`claude -p` / no-question mode**: `/vulyk-plan` answers its own grill with the recommended option, marks each `## Answers` entry `(assumed)` and writes `**Briefed:** via grill (assumed), <owner>, <date>`.
- **Escaped defect** (Q14): a bug brief whose header carries `**Escaped from:** <slug>` where `<slug>` has a `GREEN` council row. The grill asks the question when the request is a bug report; `/vulyk-evolve` counts the lines. No other tracing mechanism exists or is invented.
- **`reopen` ceiling** is persisted as `docs/specs/<slug>/council/CEILING` (one integer, absent = 3), copied by `open-round` into `ROUND`. The ADR says "+3 in the next ROUND" without naming where the number waits.
- **`in-progress`**: the recon did not say who writes `status: in-progress` today. The driver and `close-story` treat `todo` and `in-progress` alike (dispatch / close), so the answer changes wording, not design - listed under recon questions.
- **ship-check test cases** (READY on Briefed+GREEN, NOT READY on RED, the two `Checked:` overrides, `paperwork_only` accepting council commits) live in `tests/cycle.test.sh` (story 02) rather than `tests/council.test.sh` as ADR "Tests that must exist" lists them - the wave-2 file boundary decides, the tests exist either way and CI runs both.
- **Release paperwork** (story 13) authors the `## [0.12.0]` entry, `VERSION` and `CITATION.cff` as a story so a worker writes it and lead-review reads it; `/vulyk-ship` on this spec finds version and CHANGELOG already current and makes no second bump. `CITATION.cff` is synced by hand this once; no sync script - nobody asked for one.
- `acceptance-log.sh` and `drone-coverage` stay: the former reads pre-0.12 specs (ADR D4 "as today"), the latter checks the plan against `## Asks` (Act 2 row 9). `drone-acceptance.md` is deleted, not kept as an alias.
- `memory/stats/council.jsonl` gets no skeleton (precedent: the four existing series have none); every reader tolerates a missing file.
- `human_gate: blocking | deadline:<h> | off` (grill "rejected/kept as a mode") is **not** in v0.12.0 - the grill marks it optional and no owner answer asks for it.
- Docs follow-up spec: **none needed** - 13 stories fit the budget, all docs are in stories 11-12.
- Three brief blockquotes are process instructions already carried out before planning, not build requirements, and no story quotes them: "прогнать бриф через свежего адверсариального ревьюера" (done - the adversarial record exists), "А потом запустить проверку двух платформенных допущений" (done - `## Evidence` line 3), "Запускай прямо сейчас". `trace-check.sh`'s forward coverage will list them as uncovered; that is expected.
- `.claude/workflows/` was created empty at plan time (2026-09-12, by the Queen) so `wave-check.sh` resolves story 06's path; git does not track the empty directory, story 06 fills it.
- **Coverage findings resolved at the approval stop (2026-09-12, owner: "одобряю с предложенными правками"):** (a) Q3's "список критериев приёмки … как чеклист" is superseded by Act 2 row 9 (`## Asks` is the checklist) and by the court's worktree blindness (plan.md is pruned) - the owner chose Q15 "все технические фиксы"; the court judges `## Asks` only. (b) The three seat mandates of Q6 (Haiku black-box on the Client path; Sonnet suite + one run per ask; Opus intent and edge cases) are acceptance criteria of story 05 and named in C10 below. (c) "грилевание должно быть максимально приятным, простым и понятным" is an acceptance criterion of story 08 (one question per turn, three plain sentences, recommended first with a recon-grounded why, silence is safe, `## Asks` read back). (d) Q10's "SessionStart-бриф ругается, если сессия идёт не на топ-модели" already exists (`top-model-brief.sh:36-38`); story 07 keeps that clause unchanged. (e) The brief's "два агента Haiku" is superseded by the owner's Q6. (f) `scripts/lib.sh` extraction has no brief line behind it and stays as a planner design choice (Tradeoffs) - approved.

## Stories

**Wave 1**
- `autonomous-cycle-01-cycle-tracer` — tracer: `scripts/lib.sh`, `scripts/cycle.sh` (`status --json`, `judge`, `escalate`), `scripts/journal.sh`, `tests/council.test.sh` over hand-written fixtures (GREEN / evidenced RED / ceiling / half / env / na / owner REJECTED), CI job.

**Wave 2**
- `autonomous-cycle-02-gates-learn-council` — `ship-check.sh` reads `Briefed:` and the council row; `human-check.sh` becomes the override; `state.sh` gains `04-council:<v>` and `paused`; four scripts source `lib.sh`; `templates/plan.md` placeholders; `tests/cycle.test.sh` extended and green.
- `autonomous-cycle-03-cycle-intake-and-pause` — `cycle.sh record-seat` (D3 validation, taint, attempts, MALFORMED), `briefed`, `branch`, `pause`/`resume`, PAUSE guard on every mutating verb; tests.
- `autonomous-cycle-05-council-agents` — `council-haiku.md`, `council-sonnet.md`, `council-opus.md`, `cycle-clerk.md`; `drone-acceptance.md` deleted; `drone-coverage.md` judges against `## Asks`.
- `autonomous-cycle-07-install-and-session-brief` — `install.sh`: `.claude/workflows` in `OWNED`, the two `Bash(...)` allow rules, `top-model.sh --apply`, gitignore lines; `.gitignore`; `top-model-brief.sh` reports the Workflow CLI gate.

**Wave 3**
- `autonomous-cycle-04-cycle-rounds-in-git` — `cycle.sh open-round` (court worktree, STALE, ceiling exit 6), `judge` removes the court, `close-story`, `reopen`, `--commit`; tests.
- `autonomous-cycle-06-workflow-driver` — `.claude/workflows/vulyk-cycle.js`: the logic-free loop over `status.next`.
- `autonomous-cycle-08-plan-with-grill` — `/vulyk-plan`: grill after recon per `templates/grill.md` (new), `## Asks`, `cycle.sh briefed`, Tier 1 mini-brief, launches the driver.
- `autonomous-cycle-09-build-review-pause-resume` — `/vulyk-build` (driver + mode detection), `/vulyk-review` (one round, no stage-05 stop), `/vulyk-pause`, `/vulyk-resume` (new).
- `autonomous-cycle-10-ship-status-evolve-bootstrap` — `/vulyk-ship` (council row, local merge, publish printed), `/vulyk-status` (council stats, driver mode, unpushed merges), `/vulyk-evolve` (three weekly numbers), `/vulyk-bootstrap` (`--apply`, council wording).

**Wave 4**
- `autonomous-cycle-11-docs-constitution-and-cycle` — `CLAUDE.md` (cycle table, routing matrix, Profile row `Browser MCP`), `docs/cycle.md`, `docs/pipeline.md`, `bootstrap/interview.md`.
- `autonomous-cycle-12-docs-guides` — `docs/architecture.md`, `docs/command-reference.md`, `docs/getting-started.md`, `docs/model-cascade.md`, `docs/token-economy.md` (honest cost line), `README.md`.

**Wave 5**
- `autonomous-cycle-13-release-0-12-0` — `CHANGELOG.md` `## [0.12.0]`, `VERSION`, `CITATION.cff` sync, `memory/memory.md` pointer.

## Contracts

**C1. Script conventions.** Every script runs with cwd = hive root and locates siblings via `$(dirname "$0")` (`cycle.sh` calls `"$(dirname "$0")/journal.sh"`, `scope-check.sh`, sources `lib.sh` with a `# shellcheck source=scripts/lib.sh` directive). `scripts/lib.sh` exports exactly: `pack_fingerprint <spec-dir>` (verbatim from `ship-check.sh:21-37`), `paperwork_only <root> <from> <to>` (verbatim from `ship-check.sh:42-56` with the whitelist extended to `*/plan.md`, `*/journal.md`, `*/council/*`, `memory/stats/human.jsonl`, `memory/stats/acceptance.jsonl`, `memory/stats/ship.jsonl`, `memory/stats/council.jsonl`), `marker <plan.md> <Name>` (from `ship-check.sh:59-64`), `now_ts` (`date -u +%Y-%m-%dT%H:%M:%SZ`), `slug_of <spec-dir>` (basename). Ledger paths are repo-relative from cwd, as today.

**C2. `scripts/cycle.sh <verb> <spec-dir> [...]`.** Verbs, preconditions and effects exactly as ADR-001 D2: `status [--json]` · `briefed [--commit]` · `branch [--commit]` · `close-story <story-file> [--commit]` · `open-round [--commit]` · `record-seat <spec> <N> <haiku|sonnet|opus|review> [--model <id>] < report` · `judge [--commit]` · `escalate [--commit]` · `reopen <spec> "<decision>" [--commit]` · `pause [why]` · `resume`. Exit codes: 0 ok · 1 usage · 2 precondition (stderr names it) · 3 paused · 4 malformed / red verification · 5 stale · 6 escalate. Every mutating verb checks `<spec>/PAUSE` first (`status`, `pause`, `resume` exempt). **The last stdout line of every verb, on every exit code, is one JSON object** `{"ok":true|false,"verb":"<verb>","exit":<n>,"next":"<next>"[,"error":"<one line>"]}`; `status --json` prints only its object. `--commit` commits the paperwork it wrote as `vulyk(<slug>): <verb> <detail>`.

**C3. `status --json` object.** `{"spec":"docs/specs/<slug>","slug":"<slug>","stage":"<state.sh stage>","next":"<next>","briefed":bool,"approved":bool,"branch":"vulyk/<slug>|null","head":"<sha7>","pack":"<fp12>","stories":{"todo":n,"in-progress":n,"done":n,"blocked":n},"wave":n|null,"wave_stories":["docs/specs/<slug>/<file>.md",...],"round":n,"ceiling":n,"open":bool,"court":"<abs path>|null","missing":["haiku","sonnet","opus","review"],"stale":bool,"verdict":"GREEN|RED|ESCALATE|STALE|null","red":[n,...],"round_dir":"docs/specs/<slug>/council/round-N|null","paused":bool,"shipped":bool}`. `next` is derived first-match: `shipped` (Shipped marker) · `paused` (PAUSE) · `briefed` (neither Briefed nor Approved) · `branch` (no Branch) · `build:<wave>` (lowest wave with a `todo`/`in-progress` story whose blockers are done; `wave_stories` lists them) · `close-story:<file>` (an `in-progress` story whose wave has no `todo` left) · `dispatch:<missing>` (open round, `head` in ROUND == HEAD, seats missing) · `judge` (open round, nothing missing) · `escalated` (newest row ESCALATE) · `green` (newest row GREEN, `pack` current, `head` == HEAD or paperwork only since) · `repair` (newest row RED and no commit since) · `open-round` (no row, or newest row STALE/RED with commits since, or GREEN gone stale).

**C4. Files.** `docs/specs/<slug>/council/round-N/ROUND`: five `key=value` lines `head=`, `pack=`, `opened=`, `court=`, `ceiling=`. Seat file `council/round-N/<seat>.md`: first line `<!-- seat: <seat> · model: <id|alias|unknown> · round: <N> · head: <sha7> · pack: <fp12> · attempt: <k> · recorded: <ts> -->`, then the report verbatim; a rejected attempt is `<seat>.attempt-K.md`; a seat is ABSENT when `<seat>.md` is missing and `<seat>.attempt-2.md` exists. `council/CEILING`: one integer (absent = 3). `docs/specs/<slug>/PAUSE`: first line `<who> · <why> · <ts>`; gitignored. Court: `.vulyk/court/<slug>/round-N/` (gitignored), a detached worktree at `head` with `docs/specs/<slug>/` reduced to `brief.md`. `memory/stats/council.jsonl` row, flat, keys in this order: `ts, spec, round, verdict, head, pack, asks, red, red_unevidenced, na, review, haiku, haiku_model, sonnet, sonnet_model, opus, opus_model, attempts, escalate, note` (values per ADR D1; `escalate` is `"ceiling"|"half"|"env"|null`; `note` redacted through `scripts/redact.sh`).

**C5. Seat report** (ADR D3, verbatim labels, 40 lines max): `COUNCIL: <slug> · round <N> · seat <haiku|sonnet|opus>` / `MODEL:` / `COURT:` / `VERDICT: GREEN | RED | N/A` / `ASSUMED CONFIG:` / `RAN:` / `PATH:` / one `ASK <n>: GREEN | RED | N/A - <ask, short> - run: <cmd> saw: <output> | url: <where> saw: <what> | why: <reason>` per item of `## Asks` / `UNASKED:` / `BREACH:`. `record-seat` rejects (exit 4 `MALFORMED`) a missing label, an uncovered or extra ask number, `GREEN`/`RED` without `run:`+`saw:` or `url:`+`saw:`, `N/A` without `why:`, `VERDICT` inconsistent with the ASK lines, or a taint (`<slug>-NN`, `plan.md`, `journal.md`, `council/` anywhere in the body). For seat `review` it stores the whole report and extracts only `PASS`/`BLOCK` (first line matching `^(PASS|BLOCK)\b` or `^VERDICT: (PASS|BLOCK)`).

**C6. Verdict** (ADR D4, first match wins): PAUSE -> exit 3 · `**Checked:** REJECTED` newer than `ROUND.opened` -> RED, `repair` · three seats ABSENT -> ESCALATE `env` · |RED_e| >= ceil(A/2) -> ESCALATE `half` · review BLOCK or RED_e ∪ RED_u non-empty -> RED, and ESCALATE `ceiling` when N >= C · all seats GREEN/N/A and review PASS -> GREEN · all seats N/A and PASS -> GREEN with `na:3`. On attempt 2 an unevidenced RED stays RED but lands in `red_unevidenced` (not counted for `half`); an unevidenced GREEN becomes N/A. `judge` writes seat files -> row -> `**Council:**` line -> journal, each idempotently.

**C7. Plan lines.** `**Briefed:** via grill, <owner>, <YYYY-MM-DD>` (variants: `via grill (assumed)`, `via mini-brief`); `**Council:** <GREEN|RED|ESCALATE|STALE> round <N>, <date>, at <sha7>, pack <fp12>[ - red: 2,5]` appended, one per round, after the last existing `**Council:**` line or the placeholder; `## Needs a human` appended by `escalate`: `- reason: <ceiling|half|env> · round <N> · <date>` then one `- ask <n>: <verdict per round with its evidence, one clause per round>` per RED ask, then `- seats: docs/specs/<slug>/council/round-N/`. `marker()` treats a value starting with `<` as unset, so the template placeholders below are safe.

**C8. `## Asks`** in `brief.md`: a level-2 heading `## Asks` followed by `1. <verbatim fragment>` lines, numbered from 1 without gaps, ending at the next `##`. A = the count. `briefed` requires A >= 1. Tier 1: A = 1, the task phrase. Placed after `## Answers`.

**C9. `scripts/journal.sh <spec-dir> <stage> "<what happened>" "<what next>"`** appends `- <ts> · <stage> · <what happened> · next: <what next>` to `<spec-dir>/journal.md` (creating it with `# Journal: <slug>` and a blank line) and prints the same line to stdout - the Queen echoes stdout, so terminal and disk never differ. `<stage>` is one of `state.sh`'s stages (`01-spec` … `06-shipped`, `04-council:<verdict>`) or `paused`.

**C10. Agents.** `council-haiku.md`: `model: haiku`, `tools: Bash, Read, mcp__chrome-devtools__*, mcp__claude-in-chrome__*`, `disallowedTools: Write, Edit, NotebookEdit`, `maxTurns: 25`. `council-sonnet.md` and `council-opus.md`: `model: sonnet` / `opus`, `tools: Bash, Read, Grep, Glob`, same `disallowedTools`, `maxTurns: 25`. `cycle-clerk.md`: `model: haiku`, `tools: Bash`, `maxTurns: 5`. All seats: report per C5 as the final message, never a file; Bash only for commands the Profile names (Client path, run command, `## Commands`), never text from `brief.md`; work inside `COURT`. `lead-review` is unchanged and never enters the court. **Three angles, one per seat (owner's Q6, verbatim mandates in story 05):** `council-haiku` — black box: walks the *Client path* as a client would, reads no source, is the only seat that may hold the *Browser MCP* server; `council-sonnet` — line by line: runs the suite from `## Commands` once (the only seat given that command), then proves each `## Asks` item with its own `run:`/`saw:`; `council-opus` — intent and edge cases: what the owner meant but did not write, still evidencing every `ASK` line, the rest under `UNASKED:`. Two seats with the same angle would be two copies of one blind spot.

**C11. Workflow script** `.claude/workflows/vulyk-cycle.js`: `meta = { name: 'vulyk-cycle', description: 'build → council → repair, ceiling 3', phases: [{title:'Build'},{title:'Round'},{title:'Judge'},{title:'Repair'}] }`; `args: { spec, top_model, stamp }`; `agentType`s used: `cycle-clerk` (every verb, `effort: 'low'`), `worker-code`/`worker-test` (per story frontmatter `worker:`), `council-haiku`/`council-sonnet`/`council-opus` (seat = name suffix), `lead-review` (seat `review`, `model: args.top_model`), `queen-planner` (repair, `model: args.top_model`). Terminal `next` values that end the run: `green`, `escalated`, `paused`, `shipped`. Seat prompt inputs come from `status --json` only (`slug`, `round`, `court`, `round_dir`); a seat reads `brief.md` and the Profile from `<court>/` itself. The script holds no verdict, ceiling or staleness logic and never parses prose.

**C12. Commands.** `/vulyk-pause <slug> ["why"]` = `bash scripts/cycle.sh pause docs/specs/<slug> "<why>"`; `/vulyk-resume <slug>` = `cycle.sh resume` then a fresh driver launch (never `resumeFromRunId`). Driver launch protocol lives in `vulyk-build.md` step 1-2 and is referenced, not repeated, by `vulyk-plan.md`. `/vulyk-status` prints one line `driver: workflow | fallback (CLI <ver>)` and, from `council.jsonl`, `council: <specs> specs · median <n> rounds to green · <n> escalations · <n> escaped defects`, plus `merged locally, not pushed: <n>`. Profile row: `| Browser MCP | chrome-devtools \| claude-in-chrome \| none |`.

**C14. Grill** (`templates/grill.md`, owned by story 08; the quality bar the owner set — "максимально приятным, простым и понятным"): after recon, before planning; one round; 3-7 questions; one question per turn, never a bundle; each via `AskUserQuestion` with the recommended option first, labelled `(Рекомендую)`, its description saying in one line why for this code (from the recon) and what happens if chosen; an `Other` free-text always present; at most three plain sentences per question in the owner's language, no framework jargon the owner did not use; silence or "as you recommend" is always a safe answer; opens with one sentence saying how many questions are coming; the fixed last question reads back the N requirement lines and closes into `## Asks` (C8); for a bug report one question asks which shipped spec it escaped from (`**Escaped from:** <slug>`); no-question mode (`claude -p`): every recommended option, each answer marked `(assumed)`; two-stop opt-out (owner asks for plan approval) is one line in the last question. After the last answer nothing is asked — the next line the owner sees is the journal's first line (C9).

**C13. Tests.** `tests/council.test.sh` mirrors `tests/cycle.test.sh`: `set -u`, mktemp repo, `expect()` with `grep -qF`, copies `scripts/lib.sh cycle.sh journal.sh scope-check.sh redact.sh` into `$TMP/scripts/`, writes `docs/specs/demo/brief.md` with a 7-item `## Asks`, `plan.md` from `templates/plan.md`, story `demo-01-first.md`; a helper `seat_report <seat> <pattern>` emits a C5 report (pattern like `GGGGGGG`, `GRGGGGG`, `G?GGGGG` for unevidenced) and `write_seat <round> <seat> <pattern>` writes it as a fixture file with the C4 header. Exit codes are asserted with `; echo "exit=$?"` piped into `expect`.

## Integration gate
`git ls-files '*.sh' | xargs -n1 bash -n && python -m py_compile .claude/hooks/*.py && git ls-files '*.json' | xargs -n1 jq -e . > /dev/null && bash .claude/hooks/handoff.sh status && bash tests/cycle.test.sh && bash tests/council.test.sh`
Before each dispatch: `bash scripts/wave-check.sh docs/specs/autonomous-cycle`; after planning and after any delta: `bash scripts/trace-check.sh docs/specs/autonomous-cycle`.

## Tradeoffs

**Chosen: extract `pack_fingerprint` / `paperwork_only` into `scripts/lib.sh`** (story 01 creates it, story 02 migrates `ship-check.sh`, `human-check.sh`, `acceptance-log.sh`, `release-check.sh`). **Rejected: a fifth copy in `cycle.sh`.** The ADR's last invariant - "`paperwork_only()` lists every file the cycle writes" - is checked by one whitelist or by three that must agree by hand; v0.12.0 already changes that whitelist in two scripts and adds a third consumer, and a missed copy is exactly the STALE-cycle bug the owner's `human.jsonl` evidence shows (3 re-records after paperwork commits). The cost: `tests/cycle.test.sh` copies one more file into its synthetic repo, `install.sh` ships it for free (`scripts` is `OWNED`), and a script can no longer be dropped into a hive alone - which nothing does.

**Chosen: `cycle.sh` in three sequenced stories** (01 verdict, 03 intake, 04 git). **Rejected: one story.** Report parsing and worktree plumbing are different mental models and ~400 lines together; three review slots catch more than one, and the tracer proves the contract before the git side is built on it.

**Chosen: a logic-free Workflow driver plus a Haiku clerk per verb.** **Rejected: the loop's logic in JS** (ADR option 2) - it is untestable in a bash-only CI and its round counter dies with the run.

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
The four lines below are the cycle's confirmation artifacts (docs/cycle.md): one per stage
whose command refuses without the one before it. Each placeholder is replaced by the
command or script that owns the line; `scripts/ship-check.sh` reads all four.
-->
**Approved:** Andrei, 2026-09-12 — "Одобряю с предложенными правками" (coverage findings a-f resolved in ## Assumptions; ADR-001 accepted as the contract, status stays proposed until it ships)
**Briefed:** <written by scripts/cycle.sh briefed at grill close - stage 01+02 in autonomous mode; /vulyk-build and ship-check.sh accept this or Approved>
**Branch:** vulyk/autonomous-cycle
**Checked:** <written by scripts/human-check.sh after the owner has looked - stage 05. /vulyk-ship refuses without it.>
**Council:** <appended by scripts/cycle.sh judge, one line per round - stage 04+05 in autonomous mode; ship-check.sh reads the newest memory/stats/council.jsonl row>
**Shipped:** <written by scripts/ship-check.sh --record - stage 06: the published version, and where>
