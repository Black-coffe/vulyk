# Changelog

All notable changes to VULYK are documented here. `/vulyk-evolve` changesets append entries automatically (one line per change, with rationale).

## [0.23.0] - 2026-09-29

What the editorial board took from Hindsight (study `docs/specs/hindsight-memory/`), turned into checks
rather than prose. Hindsight itself is not installed: its plugin is deprecated by its own authors, and it
lets the agent read lessons without ever enforcing them.

### Added
- **The defect gate sees three things it could not.** `scripts/defects-check.sh` reports each one new = red
  and older than the library's README = one `old` line, the same rule as debt, so an upgraded host does not
  go red for cards it already had.
  - `UNDELIVERABLE`: a card shown as text with no `paths:`. No hook can ever deliver it, and `area:` is a label,
    not a glob. On YouTube_AI this finds 8 old cards and 1 new one.
  - `OVERLAP`: one normalised key on two live cards, which splits the class's quotes. A key contained in another
    card's key is only an `ambiguous key` line.
  - `ESCAPE`: a block card got an owner quote after its `check:` line, with no fixture or check change since.
  - The verdict counts each kind, and there are 18 new cases in `tests/defects.test.sh`.
- **`redact.sh` masks nine more token shapes**: Telegram bot, GitLab `glpat-`, npm, PyPI, HuggingFace, Groq,
  SendGrid, Stripe `sk_live_`/`rk_live_` and Slack webhook paths. `handoff.py`'s fallback mirrors them. Near-misses stay
  untouched: a git sha, a base64 word, `sk-learn`, an ISO timestamp. The samples are built at run time, so no
  token-shaped literal lands in git.
- **`/vulyk-gc` refuses a gutted `CONSOLIDATED.md`.** Its commit step is one shell line that always prints
  `entries a→b, bytes a→b` and does not commit when either falls by more than half. `tests/maintenance.test.sh`
  runs that line from the command file.

### Deferred
- The count of unfiled owner corrections in `/vulyk-evolve` ships with litopys's `corrections` command.
- YouTube_AI's own fixes (`paths:` for its text cards, `claude -p` out of SessionEnd) are made in that repo.

## [0.22.0] - 2026-09-29

A green build ends with one question, and an unconfigured project is offered its setup. Someone who knows
only plan, build, update and handoff no longer has to remember `/vulyk-ship` or `/vulyk-bootstrap`.

### Added
- **«Выпускаем?» after a green council.** The `green` terminal of `/vulyk-build` and `/vulyk-review` asks
  the owner once with `AskUserQuestion`, in the owner's language, the yes option first. A yes runs
  `vulyk-ship` through the Skill tool in the same session: merge, version, record. A no, or a session with
  no `AskUserQuestion` (`claude -p`), gets the old one-line recommendation. Push and publish stay the
  owner's: ship prints them and never runs them. `tests/maintenance.test.sh` fails if either command's
  green terminal loses the question, the Skill call or the fallback.
- **The SessionStart brief offers `/vulyk-bootstrap` once.** While the constitution's Profile block
  (`CLAUDE.vulyk.md` if present, else `CLAUDE.md`) still holds a `<fill in` row, one line asks the Queen
  to offer bootstrap before the owner's first task and to run it only on a yes. It is never offered in the
  VULYK repo itself (`telemetry/inbox/` exists), and a `| Bootstrap | declined <date> |` Profile row
  silences it for good. A `<fill in` outside the Profile block does not count. 11 new fixture cases.

### Fixed
- **The failure marker of `tests/cycle.test.sh` lives outside the fixture repo.** It used to sit inside the
  throwaway repository, where a first failure could dirty later stage-03 cases and be committed by
  `git add -A`. The story-12 label now says that both `anomalies.jsonl` and `skills.json` pass through.

### Docs
- ADR-010 §F carries a dated note that 0.21.1 reversed its Story 12 line for `skills.json`.
- README's roadmap gains the v0.21.0 / v0.21.1 line; `docs/cycle.md` stage 06 and `docs/hooks-reference.md`
  describe the question and the offer.

## [0.21.1] - 2026-09-29

### Changed
- **The ship gate no longer stops on the skill counter.** `ship-check.sh` stage 03 now passes a tree dirty only in
  `memory/stats/skills.json` and/or `anomalies.jsonl`, and names them. The `PostToolUse(Skill)` hook rewrites the counter on
  every Skill call, and since 0.21.0 maintenance itself runs through the Skill tool. This reverses ADR-010's Story 12
  line ("real dirt"); the owner delegated the decision. Any other dirty path still blocks.

### Fixed
- **`tests/cycle.test.sh` can fail again.** Its 60 piped `x | expect` checks ran in a subshell, so a failure printed
  `::error::` and the suite still exited 0. A marker file now carries the failure to the exit. It fails on the old gate
  (exit 1) and passes on this one (86 checks).
- The old "skills.json alone blocks" case passed for the wrong reason: `scope-check` had just dirtied `scope.jsonl`.
  The case now asserts its precondition.

## [0.21.0] - 2026-09-29

Maintenance runs itself. `/vulyk-gc`, `/vulyk-evolve` and `/vulyk-map` had never run in this repo: 36 of 41
learnings were empty stubs, and no evolve branch had ever existed. Nobody should have to know these commands.
The study behind it: `docs/specs/rrsi-self-improvement/report.md` (Google Research's RRSI against VULYK, three
research streams that cross-examined each other). The spec: `docs/specs/auto-maintenance/`.

### Added
- **The SessionStart brief says what is due, and the Queen does it.** Only when something is due, a second
  line appears: `maintenance due: gc / evolve / map (...)`. It tells the main session to run each one
  through the Skill tool once the owner's task is done, on the default branch with a clean tree, without
  asking, and to report what changed in one line. The triggers:
  - gc: stub learnings, or 10+ raw ones;
  - evolve: never run, or 7+ days since the last run, with a council round since then; overdue at 28
    days, at which point it asks the owner once whether to retire it;
  - map: the post-merge stale flag.

  An unmerged `vulyk/evolve-*` branch is reported as "waits for the owner's review". A quiet hive gets
  no extra line, and the brief is shorter than before (384 B against 412 B).
- **The evolve hypothesis ledger** `memory/stats/evolve.jsonl`, owned by `scripts/evolve-ledger.py`
  (`add`, `run`, `resolve`, `window`, `last`, `pending`).
  - The owner's verdict is read from git: a merged branch is accepted, a branch deleted unmerged is
    rejected.
  - Evolve reads the last 40 proposals plus every older rejection, one line each. A rejected hypothesis
    comes back only with newer evidence.
- **Admission rules in `/vulyk-evolve`.**
  - Always-loaded text grows only against owner-signed evidence: a verbatim quote in a defect class
    that code cannot check, or an accepted ADR.
  - A change with no measurable effect must cut bytes.
  - Every number is printed with its n.
  - Each change answers three critic questions: does it remove a safeguard without a replacement, does
    it add a loop without an exit, is it drawn from a single spec?
- **Evolve builds in its own worktree** on `vulyk/evolve-<date>`, with one commit per change, and never
  touches the owner's tree. In the VULYK repo, the telemetry inbox is cleared inside that worktree, so
  the bundles leave the default branch only through the owner's merge.
- **`tests/maintenance.test.sh`, a failing context budget.**
  - The constitution must stay within 7 168 B and 120 lines (ADR-013 D7). This applies to both the repo
    copy and the render a host receives.
  - Agent plus command descriptions must stay within 4 623 B.
  - The checker is proven on the original case (8 531 B) and on a neighbour form (121 lines).
  - It also covers the due logic and the ledger: 46 checks.

### Changed
- **CLAUDE.md drops from 8 531 B / 121 lines to 7 147 B / 106 lines.**
  - The cuts come from VULYK's own Commands block, which every host replaces anyway: the long prose, and
    six reference rows. Those rows stay in `memory/memory.md`.
  - The version numbers are gone from Models, per the floor rule: versions live only in `model_floor`.
  - The constitution a host receives was already within the cap (6 266 B), and is now 6 173 B.
- **`/vulyk-gc` finally deletes.** The librarian has no shell, so every gc had been told to delete files
  it could not. The librarian now lists `Delete:`, and the main session runs `git rm` and prunes the
  snapshots. gc commits its own result with a pathspec.
- **The noisy `signal:` line in `/vulyk-evolve` is gone.** It compared weekly counts of 0–2.
- **The installer no longer ships VULYK's own ledgers.** `human`, `scope`, `ship` and `evolve.jsonl` went
  into every fresh hive and would have fed that hive's evolve with VULYK's history. Hives that already
  hold them keep them.
- **The evolve ledger is paperwork** (`is_paperwork_path` in `scripts/lib.sh`), like every other
  `memory/stats` ledger: its commit on the default branch never stales a council round. Found by
  `drone-docs` after the merge.
- **CI runs `tests/maintenance.test.sh`.** In a shallow clone the historical 8 531 B case is skipped,
  and the other 45 checks run.
- **`evolve-ledger.py add` runs under `MSYS_NO_PATHCONV=1`.** The first real evolve run found that Git Bash on
  Windows rewrote a hypothesis starting `/vulyk-status` into `C:/Program Files/Git/vulyk-status` in the ledger.

### Removed
- The false `learnings awaiting GC: N` count, which counted stubs and README.
- This repo's 36 stub learnings. The 4 real ones are merged into `memory/learnings/CONSOLIDATED.md`.

## [0.20.0] - 2026-09-28

Sonnet 5.5 shipped, and the ladder is re-cut by kind of work, not by budget
([ADR-015](docs/adr/015-sonnet-execution-rung-and-model-floor.md)). **Sonnet executes, Opus
orchestrates and judges, Fable holds the gate.** The family that builds never judges. A model
floor now makes "never below the newest" a checked rule rather than a hope. Evidence and sources:
`docs/specs/sonnet-5-5-ladder/report.md`.

### Changed
- **Workers build on Sonnet.** A story's `model:` defaults to `sonnet`: in the `cycle.sh` default,
  the story template, `queen-planner` and `/vulyk-plan`. The planner writes `opus` only for a
  long-horizon or judgment-heavy story, with a one-line reason. `worker-code` and `worker-test` run at
  `effort: medium`. Their prompts now carry Anthropic's two Sonnet 5.5 remedies:
  - keep working until the story is closed;
  - build nothing beside what the story names.

  Why: a story is well-scoped by construction. Sonnet 5.5 led Opus 5.5 on Terminal-Bench 4.0 (70.6%
  against 66.4%, Anthropic's table) at half the price per token.
- **A repair story after a RED round is written with `model: opus`** (unchanged, now deliberate): it
  climbs a rung above the Sonnet work the round judged wrong.
- **The retry climbs a rung on every plan.** Sonnet goes to Fable on Max, and to Opus on Pro and
  API, where it used to be the same Opus reading the same wall.
- **At Tier 3 the reviewer is no longer the writer's model.**
- **`drone-scout` and `drone-docs` move to Sonnet** (`effort: low`). `cycle-clerk` stays on Sonnet,
  which now resolves to 5.5.
- **The black-box seat (`council-haiku`) moves to Opus.** It judges, and the builders are now Sonnet.
  The old plan to move it to Haiku 5.5 is dropped. Haiku gets only the clerk, and only once a Haiku
  at or above the floor ships.
- The SessionStart brief and `top-model.sh --explain` name the family and its floor
  (`fable (Fable >= 5.1)`) instead of a version that goes stale the day a model ships.

### Added
- **The model floor.** `model_floor` in `scripts/lib.sh` is the one place versions live today:
  `fable 5.1 · opus 5.5 · sonnet 5.5 · haiku 5.5 unreleased`. Routing names families only.
  `unreleased` means no Haiku meets its line yet, so the bare `haiku` alias counts as below it; the
  day a Haiku 5.5 ships, the word goes. `VULYK_MODEL_FLOOR` overrides line by line for a hive that
  runs lower on purpose; the families it does not name keep their default.
- **`bash scripts/top-model.sh --floor`** checks, before the fact, every place an alias can be
  remapped:
  - the six model env vars;
  - the `env` and `model` keys of the user, project and local settings;
  - the `model:` of agent frontmatter, the story template and every story in `docs/specs/`;
  - a `CLAUDE_CODE_USE_BEDROCK|VERTEX|FOUNDRY` provider with no family pin. Claude Code's own table
    has `sonnet` resolving to 4.5 there.

  It exits 1 on a finding. The SessionStart brief prints the result every session.
- **Telemetry code `model_below_floor`** is the after-the-fact check. `scan` reads the model ID each
  main and subagent transcript actually ran on. It records one row per transcript below the floor,
  with the family, the agent, the version run and the floor. The brief counts the last 7 days' rows.
  The enum grows to 10 codes, and older bundles still validate.

### Fixed
- **`handoff.py measure --sidechain` returned an empty `model` for every subagent.**
  `context_tokens()` skips sidechain lines. It now takes the newest real model ID of the subagent's
  own turns, which is what the floor check reads.

### Upgrade notes
- A plain upgrade moves routing, because it lives in agent frontmatter and scripts. Your
  constitution's `## Models and effort` paragraph still says "Opus 5.5 is the workhorse" until you run
  `--constitution replace`, or edit that paragraph by hand.
- Stories already written with `model: opus` keep running on Opus. Only new stories, and stories
  with no `model:` line, default to Sonnet.
- On Bedrock, Vertex or Foundry, run `bash scripts/top-model.sh --floor` once. Pin
  `ANTHROPIC_DEFAULT_OPUS_MODEL` / `ANTHROPIC_DEFAULT_SONNET_MODEL` to your provider's 5.5 IDs, or set
  `VULYK_MODEL_FLOOR` deliberately lower.
- **Not measured yet:** Sonnet 5.5's cost per closed story. The first Tier 3 spec on 0.20 is the
  check: `python scripts/token-report.py . --spec <slug>`, against a 0.19 Opus-worker spec. If
  Sonnet costs more, the story default goes back to `opus`, a two-line change.

## [0.19.1] - 2026-09-27

### Fixed
- **New hooks are wired in the host's own form, and they run.** 0.19.0 copied a
  `bash.exe -c '"…/x.sh"'` wrapper but dropped its closing quote. Every new hook then died with
  "unexpected EOF" and exit 2, and exit 2 on PreToolUse blocks every Edit, Write and Bash.
  `install.sh` now reads a sibling VULYK hook as head, script, argument and tail. It reproduces that
  form exactly, with the argument where the host puts it (`… defects-inject.sh" reset'`). That covers
  plain, quoted bash, `bash -c '…'`, `${CLAUDE_PROJECT_DIR}` and a launcher such as
  `node …/vulyk-hook.mjs x.sh`. A form that does not parse falls back to the plain one.
  A `reset'` already in place is read as the argument `reset`, so a second run adds nothing.
  An entry for one of our hooks whose quotes do not close is repaired in place (`repair` in the output).
- **A CRLF manifest no longer marks every framework file "remove".** With `core.autocrlf=true`, the
  removal loop kept each line's `\r`, so no path matched and real retirements were skipped. CRs are now
  stripped from the manifest, and from the `.gitignore` and constitution lines the installer matches, so
  a CRLF `.gitignore` no longer gets the runtime block again on every run.
- **Hooks check out with LF.** `.gitattributes` in a hive now also pins `*.sh`, `.claude/hooks/*.py`
  and `.claude/vulyk-manifest` to LF, as it already did the Workflow driver. CRs are stripped from
  every shipped script on each run. VULYK's own `.gitattributes` adds `*.js` and `*.json`.
- **The gate runs every declared `block` check again.** `defects-check.sh <arg>` ran only effectively
  `block` cards, so a `status: block` card with a `check:` and fewer than two fixtures was skipped.
  YouTube_AI's pre-show gate went from all its checks to 0 after the upgrade. The gate now runs the check
  of every card that declares `block`, and reports the card as
  `block without fixtures (check runs, not earned)`. Fixtures still decide the audit and debt.
  `defects-inject.sh` no longer injects such a card either, because its check speaks for it.

### Upgrade notes
- A hive that took 0.19.0 with a wrapper form (Varto's `bash.exe -c '"…"'`) must run the update
  again. The run rewrites the three broken `defect-intake.sh` / `defects-inject.sh` entries in the
  host's form. Until then, every Edit, Write and Bash in that hive is blocked.
- A launcher host such as fibi-next, whose new hooks 0.19.0 wired bare, still works. To get the
  launcher form, delete those three entries and re-run the update.
- A defect library without fixtures runs its `block` checks in the gate again. Those cards still owe
  debt until they have two fixtures.

## [0.19.0] - 2026-09-27

Owner corrections become defect classes with failing checks ([ADR-014](docs/adr/014-defect-library.md)).
In YouTube_AI one defect, clipped speech, came back in three videos in a row although the lesson had
been written down twice. A pilot found why:
- the code produced the defect;
- its warning exited 0;
- the detector measured the wrong edges.

The pilot's defect library then took video 3 to acceptance with no remarks. This release makes that
library a framework mechanism. Evidence: grill `docs/grill/2026-09-27-self-learning-corrections.md`, pilot feedback
`docs/grill/2026-09-27-self-learning-pilot-feedback.md`, plan `docs/specs/self-learning/plan.md`.

### Added
- **Defect library, `docs/defects/`.** One card per defect class holds the owner's verbatim quotes,
  cause, never/allowed, `check:`, `fixtures:`, `keys:` and `paths:`, with `status: block | text | revoked`.
  - A card counts as `block` only when it has a `check:` and at least two fixtures: the original case
    and a neighbour-form negative. Every fixture must fail the check.
  - There is no warn status.
  - The skeleton `docs/defects/README.md` ships to every hive and is never overwritten.
- **`scripts/defects-check.sh [<arg>]`.**
  - Without an argument it audits the library: effective status, blind fixtures, debt.
  - With an argument it is the gate before showing work: every `block` check runs against `<arg>`.
  - **Debt:** a class with two or more quotes, not effectively `block`, and a quote committed after the
    library was created (git blame time). Debt fails the gate, so a repeat becomes a failing check.
- **`defect-intake.sh` (UserPromptSubmit).** It reads only the human's text: task-notifications, system
  reminders, cross-session messages, pasted content and code fences are stripped first. It fires on a
  timecode, a RU/UK/EN correction lexicon or a card's `keys:`, and adds one line pointing at the
  matching classes. It never blocks. Median latency is about 70 ms on Windows.
- **`defects-inject.sh` (PreToolUse on Edit|Write|MultiEdit|NotebookEdit|Bash).**
  - Before an edit or command that touches a `text` card's `paths:` (file globs or `cmd:` regex over
    the whole command line), it injects the card's never-lines, within a 4,000-character budget.
  - It injects once per session and agent, and again after compaction or clear
    (`defects-inject.sh reset` on SessionStart).
  - `block` cards are not injected: their check speaks.
- **Manual wave dependency.**
  - `blocked_by: [manual:<id>]` holds a wave until `bash scripts/cycle.sh manual-done <spec> <id> [note]`.
    That command writes and commits `docs/specs/<slug>/manual/<id>`.
  - `next` reports `manual:<ids>` and never builds a later wave past it. The Workflow driver stops
    before any dispatch, naming the command.
  - `wave-check.sh` lists declared manual steps.
- **Law 6** in the constitution: a correction joins its defect class; a checkable class gets a failing
  check with two fixtures in the same work; repeated classes without one are debt; a check that only
  warns is not a check.
- **Anomaly code `sessionend_llm`.** It fires when a SessionEnd hook calls `claude -p`: SessionEnd
  hooks get at most 60 s, so such distillation is killed.
- **litopys offer.** The session-start brief asks the owner once to install litopys at project scope,
  unless it is installed or the Profile has `| Chronicle | none (declined <date>) |`.

### Changed
- `lead-review`: a check the asks lean on that names the defect but exits 0 is a major. With
  `docs/defects/` present, the reviewer runs `defects-check.sh`, and red debt on a touched class is a
  major.
- `council-opus`: measures the observable itself; a project gate's green is not its `saw:`.
- `install.sh`:
  - `wire_hook <event> <script> [matcher] [arg]`; an entry without a matcher joins the first group
    that has none;
  - `docs/defects/README.md` ships;
  - `.claude/state/` is gitignored and never ships.

### Fixed
- `blocked_by` parsing in `cycle.sh` and `wave-check.sh` cut a value at its second colon.

### Upgrade notes
- The three hooks are wired on upgrade. A hive without `docs/defects/` sees no change until it adds
  cards.
- Existing libraries in the reference format (YouTube_AI) are read as is. Their `block` cards without
  `fixtures:` count as `text` until two fixtures are added, and cards without `paths:` are never
  injected. Expect debt from `defects-check.sh` on first run: fix it by adding fixtures, not by editing
  quote dates.
- Law 6 reaches a hive's constitution only through `--constitution replace`.

## [0.18.1] - 2026-09-27

### Fixed
- **An upgrade no longer corrupts the updater that runs it.** `install.sh --upgrade` overwrote
  framework files in place. When the upgrade ran through the hive's own `scripts/vulyk-update.sh`,
  the still-running old script read the new file from its old byte offset and executed its tail.
  This happened on the first 0.17 → 0.18 upgrade: `v0.18.0: command not found`, then a bogus
  "publishes no version tags" error, after the upgrade itself had finished. Files are now copied
  beside the target and renamed over it, so the running process keeps its old file. The fix works
  whatever version the running updater is. `tests/telemetry.test.sh` reproduces the incident.

### Upgrade notes
- A hive whose constitution lacks the `VULYK:COMMANDS` markers (katan and skervik among the
  owner's hives) gets a refusal from `--constitution replace`. Wrap its `## Commands` table in
  `<!-- VULYK:COMMANDS:START -->` / `<!-- VULYK:COMMANDS:END -->`, then run the replace.

## [0.18.0] - 2026-09-27

Light VULYK ([ADR-013](docs/adr/013-light-vulyk.md)). A token audit over 1,844 sessions
([docs/specs/token-audit/report.md](docs/specs/token-audit/report.md)) found that a median task processed
84.9M raw tokens (13.5M weighted) and dispatched 67 subagents, 43 of them `cycle-clerk`. Spend split into
near-equal thirds: the Queen 30.5%, workers 30.4%, review machinery 30.7%. The instruction bundle every
subagent re-read was 23% of all spend, extra council rounds took 29.5% of the spend of the tasks that had
them, and 56% of driver runs stopped before a verdict. This release cuts agents, not what they are told.

### Added
- **`cycle.sh advance <spec> [--stamp <s>] [--claim] [--ingest]`: one call per agent boundary.**
  - Runs `branch`, `open-round`, `judge` and `repair` until the next thing only an agent can do, and prints one JSON line with `steps`, `rejected` and `status`.
  - `--ingest` records the seats' files from `.vulyk/reports/<slug>/round-<n>/<seat>.attempt-<k>.md`; a missing file is an empty attempt, and Tier 4's `review-top`/`review-second` are folded in bash.
  - A stop keeps `verb:"advance"` and names `failed`; a step that leaves `next` unchanged stops with exit 2.
- **`cycle.sh repair`: the repair story, written mechanically.** `<slug>-NN-repair-round-<n>.md` quotes the RED and anchored asks as `> N. text`, copies the findings verbatim, and takes Files and Verification from the done stories. It is idempotent, and `trace-check.sh` accepts the `## Asks` quotes. No `queen-planner` in a repair.
- **`scripts/token-report.py <project> [--spec] [--since] [--json]`.** Raw and weighted tokens, dispatches by agent type and rounds per spec, read from the transcripts; it reproduces the audit's per-spec figures. `/vulyk-status` and `/vulyk-evolve` print it. The `totalTokens` a Workflow run prints is the sum of final contexts, not spend.
- **`status --json` gains `since`, `seat_attempt` and `seats`** at the end; `ROUND` gains `seats=` and `since=`.
- **Tests.** `tests/e2e.test.sh` runs the real driver against the real `cycle.sh` (green in one round; anchored BLOCK → mechanical repair → carried seat → green). `tests/solo.test.sh` walks the Tier 1–2 loop the Queen runs herself (pass; block → escalate → reopen → repair → pass; an owner's REJECTED). Also `tests/token-report.test.sh`, and `tests/council.test.sh --quick` (~3 minutes).

### Changed
- **Routing (ADR-013 D1).**
  - Tier 1–2 are solo: the Queen builds the stories, runs `cycle.sh advance` from her own Bash and dispatches one `lead-review` per round. No driver, no clerk, no court.
  - Tier 3–4 keep the hive: workers in waves through the Workflow driver, seats `opus` + `review`, and `haiku` only when the Profile's *Client path* is filled. Tier 4's `review` folds a second reviewer.
  - Round ceilings are unchanged (1 / 2 / 3 / 3). Law 5 binds from Tier 3.
- **The council converges (D3).**
  - The roster is frozen into `ROUND` at open. A blind seat that was GREEN or N/A in round n−1 is carried into round n (`carried: round <n-1>`, not counted in `attempts`).
  - From round 2, `lead-review` reviews only `since..head` against the previous round's findings.
  - No court worktree is built when no blind seat is required. `reopen` routes to `repair` (`env` or a stale round → `open-round`).
- **`lead-review` judges the asks and correctness only.**
  - BLOCK needs an anchored critical or major line with a reproducing command or `file:line`. At most five minors.
  - It runs the full-suite command once under `timeout 540`; a timeout is a minor.
  - It runs on `opus` at Tier 1–3. The gate model (`TOP_MODEL`) is passed only at Tier 4 (with the second reviewer), to `lead-architect`, to the Tier 4 `queen-planner` and to a missed story's retry.
- **Workers close their own stories (D5).**
  - They run `close-story … --commit [--stamp]` and rerun it on exit 4 up to three times, then set `returned: WALL`.
  - Verification runs once, inside `close-story`, under `timeout ${VULYK_VERIFY_TIMEOUT:-540}` where a working GNU `timeout` exists.
  - `close-story` on a done story with a clean tree is `ok:true`.
- **The Workflow driver makes one clerk call per agent boundary (D6).**
  - The sequence is `advance --claim`, then `advance` after each wave or `advance --ingest` after each council dispatch, then `release`. A happy Tier 3 run costs 4 clerk calls (was ~19–30).
  - A missed story is retried once on the gate model; a second miss stops the run. A rejected seat is re-dispatched once with the rejection. The iteration cap is 40.
  - Without the Workflow tool, the Queen runs the same `advance` loop and dispatches with the Agent tool.
- **The constitution** is 7.3 KB / 116 lines (was 16.2 KB / 211): Laws, routing, models, Secrets, Profile, Commands. The ladder, the cycle, the token economy and evolution live in `docs/` and the `/vulyk-*` commands. `/vulyk-build` is 6.1 KB (was 16.2 KB). No MUST/NEVER shouting in agents or commands.
- **`omitClaudeMd: true`** on `cycle-clerk`, `council-opus`, `council-haiku`, `drone-scout`, `drone-coverage`, `drone-docs` and `librarian` (Claude Code ≥ 2.1.271). `council-opus` runs at `effort: medium`; `queen-planner` gets `maxTurns: 40`, `lead-architect` 30.
- **Gates.**
  - `claim` refuses a tree dirty outside paperwork; a re-claim by the holder skips the check.
  - `VERSION` and `CHANGELOG.md` are paperwork.
  - `scope-check` ignores the files of not-done sibling stories.
  - `wave-check` reports `## Verification` segments that are not `## Commands` cells.
  - Everywhere VULYK reads the constitution, it reads `CLAUDE.vulyk.md` if present, else `CLAUDE.md`.
- **Faster `cycle.sh`.** The hot paths are plain bash now: `status` 0.62 → 0.32 s, `record-seat` 3.5 → 1.1 s, `judge` 2.3 → 1.4 s; the full council suite runs in 531 s (was 752 s).
- **Hooks.** The handoff is restored only after `/clear` or compaction, capped at 4 000 characters. `anomaly-scan.sh` runs on `SessionEnd` only.

### Removed
- **`council-sonnet`.** It returned 0 RED in 16 rows of VULYK's own ledger and was GREEN in 80 of 101 rounds across 20 hives. `record-seat` still accepts `sonnet` so old rounds stay readable, and `telemetry.sh` keeps it as a legal agent token.
- **`session-end-learnings.sh` and `VULYK_AUTOLEARN`.** The hook wrote empty stubs; the Chronicle plugin replaces it.
- **Driver-side logic:** `queen-planner` in repairs, the JS review fold, the fallback prose loop and `--fallback`.
- **Dead settings:** `"effortLevel"` in `.claude/settings.json` (no effect on Opus 5.5); `status: in-progress` and `tracer:` in the story template; the ADR-001 pointer and "find reasons this change should NOT merge" in the reviewer prompt.

### Fixed
- **Sidecar hives.** `close-story`'s `## Commands` check read `CLAUDE.md` in a hive whose constitution is `CLAUDE.vulyk.md`.
- **Unbounded review loop.** A review without `VERDICT:` was re-dispatched with no counter: one Tier 4 spec saw 44 `lead-review` runs. A seat now gets at most two dispatches per round.
- **Release commit.** It staled a GREEN round.
- **Dirty tree.** A stray owner file stopped a run at `open-round`, after the build; `claim` now refuses it before the build.
- **Slow suites.** One could die silently at the Bash tool's 10-minute cap; now `close-story` fails with exit 4, `verification timed out after <N>s`. The budget covers the whole run, every line and repeat.
- **Owner overrides.** A round turned RED by the owner's REJECTED check now puts the owner's note into the repair story; without it the story had no condition to meet.
- **`## Needs a human`.** It now names the asks the reviewer blocked on, not only seat REDs.

### Upgrade notes
- **Replace the constitution to get the saving.** A plain upgrade never touches your constitution; it prints the size difference and the command. Run either:
  - `bash /path/to/vulyk/install.sh <project> --upgrade --constitution replace`
  - `bash scripts/vulyk-update.sh . --constitution replace`

  Either one writes the 0.18 constitution, carries over your `VULYK:PROFILE` and `VULYK:COMMANDS` blocks and telemetry row, and keeps the old file as `<name>.pre-0.18.md`. It refuses a constitution without the two markers. Hand-written sections outside the blocks stay only in the backup. A hive with a 15–31 KB constitution gets the per-dispatch prefix saving only after the replace.
- **What `--upgrade` removes.**
  - `council-sonnet.md` and `session-end-learnings.sh` go through the manifest, unless you edited them; an edited file stays, with a note.
  - The learnings hook is unwired from `SessionEnd`, and `anomaly-scan.sh` from `Stop`.
  - `.claude/worktrees/` is added to `.gitignore`.
- **Open rounds.** A round opened before 0.18 has no `seats=` line; it is judged against its tier's 0.18 roster.

## [0.17.0] - 2026-09-24

### Changed
- **The council judge measures convergence, not a round count (spec `convergent-judge`, ADR-001 D3/D4 amended).**
  - **Why:** `council.jsonl` across 17 hives showed 9 of 21 specs spending 3+ rounds while 9 were GREEN at round 1; RED rounds were mostly a `lead-review` BLOCK with every seat GREEN, and GREEN rounds were followed by repair waves on PASS-with-majors.
  - **Tier-scaled ceiling:** Tier 1 = 1 round, Tier 2 = 2, Tier 3-4 = 3; `reopen` adds the same again. Only rounds that ended RED count - GREEN and STALE rounds never do; an `ESCALATE ceiling`/`no-progress` round counts as ended RED (owner's decision, 2026-09-24, plan A11).
  - **`no-progress`:** the same ask RED (seat-evidenced or review-anchored) in two consecutive rounds escalates at once.
  - **Anchored BLOCK:** `lead-review` blocks on any critical **or major** finding and tags each `[ask N]`, `[regression]` or `[unanchored]` under `## Critical` / `## Major`; a BLOCK with only `[unanchored]` findings is recorded PASS with note `review BLOCK unanchored`, its findings go to the next circle, not a repair wave. A BLOCK without the tagged layout is MALFORMED at `record-seat` and re-asked once; malformed twice, the review is ABSENT and the round escalates `env` (owner's decision, 2026-09-24). Rows gain `review_asks`.
  - **Both drivers** hand `queen-planner` the anchor rule; the Workflow banner states the tier ceiling.
- **The installer no longer ships `memory/stats/council.jsonl`;** `--upgrade` removes the seeded `autonomous-cycle` rows from a hive that has no such spec.

## [0.16.0] - 2026-09-22

### Changed
- **Opus 5.5 is the workhorse (ADR-012, supersedes the rungs of ADR-007).**
  - **What moved:** the Queen, the Tier 1–3 `queen-planner`, `worker-code`, `worker-test`, `drone-scout`, `drone-docs`, `drone-coverage` and `librarian` now run on `opus` (Opus 5.5 since Claude Code 2.1.280).
  - **Why:** Artificial Analysis measured Opus 5.5 at `medium` level with Fable 5.1 at `high` for about a third of the cost. It also beats Sonnet 5 per task.
  - **What stays on Sonnet:** `council-sonnet` (model diversity in the court), `council-haiku`, `cycle-clerk` and the distiller. The last three move to Haiku 5.5 when it ships. Haiku 4.5 is still never dispatched.
- **`TOP_MODEL` names the gate, not the Queen.**
  - **What it covers:** `lead-review`, `lead-architect`, the Tier 4 planner and a missed story's retry get the plan-resolved alias: Fable 5.1 on Max, Opus 5.5 on Pro.
  - **Resolver:** `scripts/top-model.sh --apply` / `--check` now pin and compare the Queen's session against `opus`.
  - **Hook:** `top-model-brief.sh` prints `[VULYK] gate model:`.
  - **Upgrade note:** upgrading re-pins an existing hive's Queen from `fable` to `opus`.
- **The retry climbs to the gate.** `vulyk-cycle.js` dispatches a story's second attempt with `model: top_model`, where it used to hard-code `opus`. `cycle.sh status --json` defaults a story's `model` to `opus` instead of `sonnet`. On Pro the retry runs on the same model as the first attempt; ADR-012 records that gap.
- **Effort is back in agent frontmatter.**
  - **Evidence:** re-measured on Claude Code 2.1.280, `effort:` now overrides the session level (`low` → ~660, `max` → ~3 200 output tokens on Opus 5.5).
  - **Levels:** drones, `librarian` and `cycle-clerk` run at `low`; workers and `drone-coverage` at `medium`; planner, architect and gate at `high`.
  - **Docs:** `docs/model-cascade.md` records both the July "ignored" finding and the new one.

## [0.15.0] - 2026-09-15

### Fixed
- **Clerk retry on a non-JSON last line.** `clerk()` in `.claude/workflows/vulyk-cycle.js` re-dispatches once before ending a run; for `branch`, `close-story`, `open-round`, `record-seat` and `judge` the second dispatch is a `status <spec> --json` re-check instead of the mutating verb itself, the same shape already used for a MALFORMED seat report.
- **Hook-written files are cycle paperwork.** `is_paperwork_path` in `scripts/lib.sh` now accepts `memory/stats/skills.json` and one-level `memory/learnings/*.md`, and the open-round dirty-tree listing lists an untracked-only directory file by file (`-uall`) so `open-round` and `paperwork_only()` stop treating them as a dirty tree.
- **`close-story` tolerates a self-marked `status: done`.** `cmd_close_story` in `scripts/cycle.sh` journals and proceeds when a worker's own `status: done` still has an uncommitted diff in its files, instead of refusing outright.
- **Taint is the story file, not the bare id.** `taint_reason()` in `scripts/cycle.sh` flags a story-file path (`<slug>-NN-<title>.md`, `docs/specs/<slug>/<slug>-NN`); a bare `<slug>-NN` token is no longer taint.

### Changed
- **Mutating verbs carry post-verb status; the driver polls three times fewer per round.** `branch`, `close-story`, `open-round`, `record-seat` and `judge` in `scripts/cycle.sh` embed the post-verb `status` object in their exit-0 JSON; the driver in `.claude/workflows/vulyk-cycle.js` polls `status` only at loop start and after a parallel step, three fewer polls on a steady Tier 3 round.

## [0.14.0] - 2026-09-15

### Added
- **Anomaly telemetry, opt-in.** `memory/stats/anomalies.jsonl` logs eight anomaly codes locally on every hive - context size, subagent prefix cost, empty subagent returns, council round count, stage duration, driver refusals/relaunches, scope breaches - via `scripts/telemetry.sh`.
- **The five detectors and the fail-open hook.** `scripts/telemetry.sh scan`, wired on `Stop` and `SessionEnd`, runs all five and records through `record`, silently, without breaking a session when `jq`/`python`/the script are missing.
- **The weekly evolve step.** `/vulyk-evolve` reads the week's anomaly rows into its diagnosis and, with consent on, prints (never runs) the `telemetry.sh publish` send command for the owner to push.
- **Consent.** A `Telemetry` Profile row (`off` by default) and one installer question (`Enable telemetry? [y/N]`, `/dev/tty`, `--telemetry on|off|ask` / `VULYK_TELEMETRY`) gate every send; nothing is ever sent automatically.
- **Docs.** README and the new [docs/telemetry.md](docs/telemetry.md) state exactly what is measured, what never leaves the machine, and how a bundle reaches the project as a pull request.
- **CI.** A `telemetry-inbox` job validates every `telemetry/inbox/**/*.jsonl` with `scripts/telemetry.sh check`.

## [0.13.3] - 2026-09-14

### Fixed
- **Installer normalizes the driver every run.** 0.13.2 relied on the `.gitattributes` rule and a
  re-checkout, which did nothing when the rule was already present, while `copy_tree` copied the
  driver's bytes from a source checkout that git had not re-smudged (unchanged content, only
  `.gitattributes` moved between tags) - so an upgrade put CRLF back into every hive. The
  installer now strips CR from `.claude/workflows/*.js` after every copy, rule or no rule.

## [0.13.2] - 2026-09-14

### Fixed
- **Driver line endings.** `.claude/workflows/vulyk-cycle.js` had no `eol=lf` rule, so a Windows
  checkout (`core.autocrlf=true`) produced CRLF and the Workflow tool refused the script
  ("script contains control characters"); sessions launched from a hand-made LF copy instead.
  `.gitattributes` now pins `.claude/workflows/*.js` to LF, and `install.sh` appends the same
  rule to a hive's `.gitattributes` (marked block, append-only) and re-checks the driver out.
- **Driver call.** `/vulyk-build` calls the Workflow tool by `scriptPath`, not `name: vulyk-cycle`.
  The by-name call is refused ("script contains control characters") even on an LF working copy,
  so its cause is not the line endings and is unknown; `scriptPath` is the supported call.

## [0.13.1] - 2026-09-14

The four majors the Fable `lead-review` filed against v0.12.1 (kept at
`docs/specs/v0-12-0-remainders/council/round-1/review.fable-attempt.md`) and the week's
turn-cap conclusion, built as spec `fable-review-remainders`: nine stories, two council rounds
(RED on a Fable BLOCK, then GREEN), not one empty agent return.

### Fixed
- **Installer (major 1).** `--upgrade`'s anchor-insert path spliced the Profile/Commands block
  through a second `awk -v` pass, so the Browser MCP row's `\|` gained two cells and gawk
  warned. The splice is now line-number + `head`/`printf`/`tail`, byte-identical to the EOF
  path; the CI D4.7 scenario asserts the row's content, not its count.
- **Council suite (majors 2, 3).** `run_wall_probes` sets `fail=1` on any non-`ok` branch
  result; every pinned copy goes through `pin_cycle`, which prints `unavailable: <reason>` and
  fails the suite when `git show` cannot produce it; `PIN_MUST_FAIL` asserts that a named probe
  is red at its pinned sha. The LR31 scenario now puts a ready story and a not-ready `todo` in one
  wave and is red at `eb3203a`. The `council` CI job checks out with `fetch-depth: 0`.
- **`release` under PAUSE (major 4).** `cmd_release` no longer calls `pause_guard`: it removes
  only its own stamp file, which `pause` already removed, and exits 0 as the two drivers and
  story 13 always claimed. ADR-001 D2 lists `release` beside `status`/`pause`/`resume`.

### Changed
- **A cap death has a name.** The Workflow driver and the fallback loop classify a failed
  dispatch three ways, for workers, seats and the reviewer: `threw: <message>`, `returned empty -
  turn cap suspected (<agent>, maxTurns <N> in .claude/agents/<agent>.md)` (a `CAPS` table
  mirrors the frontmatter), and `returned no report` - decided by the verbs (`close-story` exit 4
  with `returned:` missing, `record-seat` exit 4), never by grepping the report's prose (round-1
  critical 1). `tests/driver.test.sh` proves each.
- **`record-seat --file <path>`.** The seat's report no longer travels as a heredoc inside the
  clerk's prompt. The driver hands each seat and the single reviewer a path under
  `.vulyk/reports/<slug>/round-N/<seat>.attempt-K.md`, the seat writes its report there as its
  last action, and the clerk runs one short `record-seat --file` line; exit 2 `file:` falls back
  to the heredoc. Verified live in this spec's own two rounds - every report was on disk before
  its agent returned. Tier 4's folded review stays on the heredoc (flagged for the next circle).

## [0.13.0] - 2026-09-14

The framework stops doing more than it was asked. Read against its own text after two other
hives ran v0.12.0: the plan launched the build with no approval stop, a request whose answer
was a document was cut into stories anyway, up to seven agents ran before the first line of
code, the same suite ran up to four times (twice per story, twice per round), and a missed
story was retried on the model that missed it. Each of those is a line in ADR-007/008 and a diff here.

### Changed
- **Deliverable before tier (ADR-008).** `/vulyk-plan` step 0 names what the owner gets back.
  Study work - validate, audit, monitor, research, "make me a spec", or `--study` - writes
  `brief.md` + `report.md` and stops: no story, no worker, no council. `state.sh` shows it as
  `study`. The routing matrix, README and cycle.md carry the row.
- **The approval stop is the default (ADR-008).** After stories and the deterministic checks
  `/vulyk-plan` shows the plan and waits for one word (`**Approved:**`). Straight-through is
  the opt-in: `--go`, or the owner asking on the grill's last question; Tier 1 stays
  straight-through. No-question mode can no longer approve a plan. `templates/grill.md`'s
  fixed last question offers the opt-in instead of the old opt-out.
- **The model ladder (ADR-007).** Lead = `TOP_MODEL`, senior = `opus`, mid = `sonnet`, junior
  = `haiku` only once a Haiku 5 exists - until then `council-haiku`, `cycle-clerk` and the
  `VULYK_AUTOLEARN` distiller run on `sonnet`, and Haiku 4.5 is never dispatched. `status
  --json`'s `wave_stories` carry `"model"` (story frontmatter `model:`, default `sonnet`); the
  Workflow driver and the fallback loop pass it on the first dispatch and **`opus` on a story's
  second dispatch** - a miss climbs one rung instead of retrying on the model that missed.
- **Tier 2 requires `sonnet` + `review`** (C15 amended, ADR-002 marked amended): the intent and
  black-box seats join at Tier 3, as before. `cycle.sh required_seats_for_tier`, the council
  suite's tier-2 scenarios, `docs/cycle.md` and the constitution updated together. Recorded as a
  plan delta under the owner's ask 2; one line reverts it.
- **Recon capped by tier** in `/vulyk-plan`: 1 scout at Tier 1 (only if the location is
  unknown) and Tier 2, 2 at Tier 3, 4 at Tier 4; `drone-coverage` at Tier 3-4 only.
- **One suite run per close.** `lead-review` no longer re-runs the whole suite on top of
  `close-story`'s recorded green - it runs only what the diff makes suspicious and says which.
- **The fallback driver needs `--fallback`.** `/vulyk-build` refuses to step the loop inside
  the pinned top-model session unless the owner asked for exactly that.
- **`CLAUDE.md` cut from 236 to ~200 lines, 60 of them the Profile and Commands blocks the installer needs.** The top-model essay, the effort essay and the
  council prose moved to `docs/model-cascade.md` and `docs/cycle.md`; the constitution keeps the
  laws, the routing matrix with the deliverable rule, the ladder, the cycle table, the token
  economy, the profile and the commands. Every subagent reads this file on every dispatch.

### Added
- `docs/adr/007-model-ladder.md`, `docs/adr/008-approval-stop-and-study-work.md`.
- `tests/driver.test.sh`: the retry scenario asserts the second dispatch carries `model: opus`
  and the first the story's own model. `tests/council.test.sh`: tier 2 = `sonnet review`; an
  extra recorded seat is still accepted; `wave_stories` fixtures carry `"model"`.
## [0.12.1] - 2026-09-14

The remainders of v0.12.0: the council and driver run to the end, and every stop says why.
Seventeen stories on `vulyk/v0-12-0-remainders`; shipped on the owner's override after the
council's own seats died at their 25-turn cap (raised to 60 here; the Fable review passed).

### Fixed
- `cycle.sh judge`/`escalate` count, match and write the ledger correctly; `open-round`
  refuses honestly (every refusal names itself, the ceiling block carries its RED rows, the
  court commit is real); `close-story` reads the worker's `returned:` (ADR-006), owns its
  commit, matches a `## Commands` cell containing `&&` whole; `wave_stories` lists only ready
  stories. The council suite proves each fix against the commit it fixes.
- The Workflow driver has a test that executes it; its stops say what happened (a red
  verification, a missing second reviewer, a paused tree); both drivers claim, stamp and
  release the `DRIVER` semaphore (ADR-004).
- The installer ships no ADRs or wiki, carries missing Profile/Commands blocks into an
  upgraded constitution, keeps a manifest and removes what a release retired (ADR-005).
- The session brief stops spawning the CLI for a gate it cannot decide.

### Changed
- `worker-code`/`worker-test` `maxTurns` 30/40 -> 90; council seats and `lead-review` 25 -> 60 -
  every dead subagent return this week was a turn cap, none a model.

## [0.12.0] - 2026-09-13

Stage 05 stops being a person and becomes a council: blind agent seats, scaled to the
task's own tier, judge the owner's own words against the code, the loop between plan and
merge runs mostly without the Queen, and the human moves to one stop at the start plus an
override anywhere after.

### Added
- **The council replaces the mandatory owner look, sized to the task's own tier (C15).**
  Required seats: Tier 1 - `council-sonnet` alone; Tier 2 - `council-sonnet`,
  `council-opus`, `lead-review`; Tier 3-4 - the full court, adding `council-haiku` (black
  box: walks the *Client path* like a client, reads no source) to the other three; Tier 4
  alone adds a second reviewer on a different model. `council-sonnet` works line by line:
  runs the suite from `## Commands` once, then proves every `brief.md` `## Asks` item with
  its own `run:`/`saw:`; `council-opus` judges intent and edge cases - what the owner meant
  but did not write. Each blind seat is a clean-context subagent
  working inside a shared, writable git worktree (`.vulyk/court/<slug>/round-N/`) whose
  working tree holds `brief.md` alone - an honour clause with a detector, not a filesystem
  guarantee: the court's git history is out of bounds (`git log`, `git show`, `git diff`
  against any commit, and the deleted-file lines of `git status` are a BREACH), and any
  writes a seat leaves behind are discarded by `judge`. `lead-review` sits beside the blind
  seats unchanged, judging code rather than intent. `scripts/cycle.sh judge` - never a
  model - computes the round verdict from the required seats' labelled reports: GREEN needs
  every required seat GREEN or N/A (with a reason) and `lead-review` PASS; RED fires on one
  evidenced RED ask (a `## Asks` item that fails, with a command/output or a URL) or a
  `lead-review` BLOCK; every required seat ABSENT, or an ABSENT seat with nothing RED,
  escalates as `env`; half the asks RED escalates early as `half`. Only a non-paperwork
  commit - one that touches more than `plan.md`, `journal.md`, `council/*` or the stats
  ledgers - stales an open round. Ceiling three rounds, then `## Needs a human` in plan.md
  and a stop. Every round's verdict, the asks judged, the red count and the models used
  land in `memory/stats/council.jsonl` - the metric the rollback decision reads.
  - `scripts/cycle.sh` (`status --json`, `open-round`, `record-seat`, `judge`, `escalate`,
    `reopen`, `close-story`, `briefed`, `branch`, `pause`, `resume`) is the one state machine
    both drivers below read and write; every mutating verb refuses under a `PAUSE` semaphore
    file. `scripts/journal.sh` writes the one-line-per-state-change log at
    `docs/specs/<slug>/journal.md`; `scripts/lib.sh` holds `pack_fingerprint`,
    `paperwork_only` and `marker`, shared by every gate.
  - **The Workflow driver**, `.claude/workflows/vulyk-cycle.js`, loops over
    `cycle.sh status --json` through a Haiku `cycle-clerk` and performs whatever `next`
    names - dispatch a wave, open a round, dispatch a seat, judge, cut a repair story - with
    no verdict or prose-parsing logic of its own. Where the Workflow tool is unavailable
    (Claude Code < 2.1.154, or Pro without the flag), `/vulyk-build`'s session fallback
    drives the same state machine through the same scripts, and now matches the Workflow
    driver on the two points that used to diverge: either driver ends the run on a verb's
    `"ok":false` result - an escalation recorded on disk, a stop surfaced rather than
    retried - except a `record-seat` exit 4, which gets one re-ask of that seat with its
    error verbatim before a second failure leaves it ABSENT; and either driver caps a story
    at two failed `close-story` attempts, ending the run `blocked` on the second rather than
    looping. A RED round routes both drivers to `repair`, never a silent fresh round. The
    Queen wakes twice: the final report or an escalation.
  - **`/vulyk-pause <slug> ["why"]` and `/vulyk-resume <slug>`** let a human step in at any
    stage without waiting to be asked; resume always relaunches the driver fresh, never a
    cached run.
  - **The mini-grill**, folded into `/vulyk-plan` after recon: one round, 3-7 questions,
    `AskUserQuestion` one at a time, the recommended option first with a reason grounded in
    the recon, silence always a safe answer (`templates/grill.md`). It closes into `## Asks`
    in `brief.md` (the checklist the council judges) and `cycle.sh briefed --commit` writes
    `**Briefed:**` - the plan is shown in the terminal as a log, not asked as a question.
    Tier 1 gets the task phrase verbatim as its one ask and a single council round, no grill;
    `claude -p` answers its own questions and marks them `(assumed)`.
  - The Profile gains an optional **`Browser MCP: chrome-devtools | claude-in-chrome | none`**
    row, read only by `council-haiku`, for a client-path walk that needs a real browser on a
    separate test profile.
  - `tests/council.test.sh` drives the verdict table, the git-worktree rounds and the intake
    validation through fixtures in CI, alongside `tests/cycle.test.sh`.

### Changed
- Stage 05 is now the council's verdict, not a human's; `scripts/human-check.sh` stays, but
  as an override either direction can invoke (`ACCEPTED` over RED, `REJECTED` over GREEN)
  rather than a mandatory stop. `scripts/ship-check.sh` closes stage 02 on `**Briefed:**` or
  `**Approved:**` and stages 04+05 on the newest `memory/stats/council.jsonl` row (falling
  back to the old acceptance/human ledgers for specs recorded before v0.12.0).
  `scripts/state.sh` reports `04-council:<verdict>` and `paused`.
- **`/vulyk-ship` merges `vulyk/<slug>` into the default branch locally, updates CHANGELOG
  and version, and prints the publish command without waiting for it** - push, tag and
  deploy stay a human's to press, on their own schedule.
- `install.sh` now owns `.claude/workflows` like every other framework tree, wires the two
  `Bash(...)` allow rules the clerk needs into the target's `settings.json`, and pins the
  Queen's session with `scripts/top-model.sh --apply` on install and upgrade; the
  SessionStart brief reports whether the Workflow driver's CLI gate (`>= 2.1.154`) is met.
- `paperwork_only()`, `pack_fingerprint()` and `marker()` now live once, in `scripts/lib.sh`,
  sourced by `ship-check.sh`, `human-check.sh`, `acceptance-log.sh` and `release-check.sh` -
  one whitelist instead of four copies that could silently drift apart.

### Removed
- `.claude/agents/drone-acceptance.md` - superseded by the council seats.
- The mandatory owner look (stage 05) and the plan-approval stop in autonomous mode; a human
  who wants either back still has `/vulyk-pause` and `human-check.sh`, on their own
  initiative.

### Fixed
- **`install.sh` shipped the maintainer's own runtime files into every target.**
  `shippable()` had no exclusion for what VULYK's own `.gitignore` ignores, so
  `copy_tree ".claude"` carried `.claude/settings.local.json` (the pinned top model),
  `.claude/state.json`, `.claude/.vulyk-update-cache` and `.claude/handoff/*` into every
  install and upgrade - found while wiring this release's own session pin
  (`autonomous-cycle-07`). `shippable()` now refuses any path the framework's `.gitignore`
  ignores, and the `install-smoke` CI job plants dummies and asserts none survive a fresh
  install or an `--upgrade`.
- **The Workflow driver could not route a story to `worker-test`.** `status --json`'s
  `wave_stories` were bare file paths, and the driver may not open a story file to read its
  `worker:` line - so every build story dispatched to `worker-code` regardless. `wave_stories`
  now carries `{file, story, worker, repeat}` objects read from story frontmatter, and both
  drivers route from the object.
- **A fresh install's Profile had five rows where `CLAUDE.md` documents eight.** The
  `VULYK:PROFILE` reset placeholder in `install.sh` already omitted *Client path* and
  *Release / deploy* before this spec, and now the new *Browser MCP* row too - so
  `/vulyk-bootstrap` and the council's client-path lookup had no row to fill on a fresh hive.
  The placeholder now carries every row `CLAUDE.md` does, same order and hints, and
  `install-smoke` asserts the two blocks' row counts match so they cannot drift apart again.

### Notes
- The evidence the redesign rests on (`brief.md` `## Evidence`, 2026-09-12): the mandatory
  human gate returned **0 REJECTED across 10 rows in one week, three hives** - it stopped
  nothing; the existing blind gate it replaces caught real defects, **5 of 42 acceptance
  verdicts REJECTED, all substantive** (an interactive path dying after the first search, a
  brief requirement delivered nowhere, a central ask - `BANK_TARGETS` - left empty twice,
  once after a repair round). The rollback signal is `memory/stats/council.jsonl`: rounds to
  green, escalations, and escaped defects (a bug brief carrying `**Escaped from:** <slug>`
  against a `GREEN` row), printed weekly by `/vulyk-evolve`.
- **Cost, estimated, not yet measured** (`docs/token-economy.md` "The cost of the council"):
  roughly 2-3x the v0.11 gate (one `lead-review` + one `drone-acceptance`) per round at the
  target of <= 2 rounds to green - three cold-cache seats plus `lead-review` plus five Haiku
  clerk calls, one more `queen-planner` dispatch on a RED round. The session fallback (no
  Workflow) is the most expensive path: the same dispatches, plus roughly 120 lines of seat
  reports per round carried through the pinned top-model session itself.
- Design record: [ADR-001](docs/adr/001-cycle-state-contract.md) (proposed - the mechanics),
  the 13-question grill and its adversarial review, both linked from
  `docs/specs/autonomous-cycle/brief.md`.

### Upgrading
- `install.sh --upgrade` (or `/vulyk-update`) ships the council agents, `cycle.sh` and the
  Workflow script, adds the two `Bash(bash scripts/cycle.sh:*)` /
  `Bash(bash scripts/journal.sh:*)` allow rules to the target's `settings.json`, and pins
  the session via `top-model.sh --apply`. **`--upgrade` never deletes a file** - it iterates
  over the source tree, so a framework file this release drops upstream,
  `.claude/agents/drone-acceptance.md`, survives in every upgraded hive and has to be
  removed by hand; no removal mechanism ships with this release. Specs recorded under
  v0.11.0 keep shipping through the acceptance-ledger fallback in `ship-check.sh`; nothing
  is required of them.

## [0.11.0] - 2026-09-05

### Added
- **The cycle closes with a person.** VULYK had four of the six stages a delivery loop needs
  and stopped at *merge*: the request was verbatim, the plan was approved, the code was built
  and gated, and then a `PASS` said "propose a merge" and nothing on disk said who looked, on
  what, or whether anything was published. The pipeline is now the six-stage loop in
  [docs/cycle.md](docs/cycle.md) - **spec → plan → code → tests → human → ship** - and a stage
  is closed by a confirmation artifact on disk, never by a chat turn: `brief.md`,
  `**Approved:**`, `**Branch:**`, `acceptance.jsonl`, `**Checked:**`, `**Shipped:**`. The two
  stages that were missing are the two an agent cannot take.
  - **Stage 05, the owner's own look, is mandatory and recorded.** `/vulyk-review` no longer
    ends at `PASS`: it hands the owner a check card - the branch, where to look (the new
    *Client path* Profile row), one line per ask from the drone's `WORKS` lines - and waits.
    `scripts/human-check.sh <spec> ACCEPTED|REJECTED "<their words>"` then writes a
    `**Checked:**` line into plan.md beside `**Approved:**` and a row in
    `memory/stats/human.jsonl`, pinned to the commit and the pack fingerprint. It is a
    signature, not a judge: it has no cannot-run branch (if you could not look, you have not
    checked), and the Queen runs it only after the owner has answered. `--check` says whether
    the signature still describes what ships: `STALE (commit)` when code landed after the look,
    `STALE (pack)` when a story was cut. Committing the record itself does not stale it - a
    commit touching only the cycle's own ledgers is paperwork, and both scripts know the
    difference.
  - **Stage 06, `/vulyk-ship`.** Runs `scripts/ship-check.sh <spec>` first - all six
    confirmations at once, deterministic, free - and refuses on `NOT READY` the way
    `/vulyk-build` refuses without approval. Then one release-paperwork commit (version +
    CHANGELOG; story commits are never squashed), the merge as the *Release / deploy* row
    prescribes, and the publish step printed for **the human to press** - no agent deploys.
    `ship-check.sh --record <spec> <version> "<where>"` writes `**Shipped:**` and
    `memory/stats/ship.jsonl`. The docs refresh and the ADR harvest moved here from the review
    PASS path - after the human, not before - and the circle's leftovers (`UNASKED`,
    `## Descoped`, unfixed `CONCERNS`) are handed over verbatim as the draft of the next brief.
  - **Stage 03 has a branch.** `/vulyk-build` puts every spec on `vulyk/<slug>` (or the
    scheme the Profile names) before wave 1 and records it as `**Branch:**`; story commits
    never land on the default branch, and `ship-check.sh` reads the line.
  - **Stage 04 walks the client's path.** `drone-acceptance` receives the *Client path* row
    when it is filled and goes through the flow the way a client would - URL, CLI, or the
    browser runner's quiet command - before reading code; a green suite proves the parts, the
    path proves the whole. Its report gains a `PATH:` line.
  - **Stage 01 is confirmed before recon is spent.** `/vulyk-plan` shows the brief back and
    stops for one word at Tier 3-4 (shown-and-continue at Tier 2); a bug report is a spec too,
    error text and reproduction verbatim.
  - Two new Profile rows, `Client path` and `Release / deploy`, asked by the bootstrap
    interview (now 15 questions). `templates/plan.md` carries the four marker lines.
    `scripts/state.sh` derives a `stage` per spec for `/vulyk-status`. `tests/cycle.test.sh`
    drives both new gates through every stage in CI, including the paperwork-vs-code
    distinction and a pack that moves after the look.

### Changed
- `/vulyk-review` prefers the Profile's *Configurations that exist today* row by name, since it
  is no longer the block's last row. [docs/pipeline.md](docs/pipeline.md) lists nine checks and
  the two new invalidation rows; [docs/architecture.md](docs/architecture.md) draws the loop
  through stage 06.

## [0.10.1] - 2026-09-04

### Fixed
- **The handoff guard divided by the wrong window.** `context_limit` was a hardcoded `200000`
  with a comment telling you to raise it by hand on a 1M-context model, and the escalation
  thresholds were absolute tokens (`110000 / 140000 / 165000`) meant to be 55% / 70% / 82% of
  it. On `opus[1m]` that read 150k of a 1M window as **75% full** and injected exactly that
  into the model's context, which then repeated it to the owner and recommended a checkpoint
  at 15% used. Worse than the wrong number: level 2 fired at 14% of the window, so every
  session was nagged from its first turns, and a warning you have ignored all day is not a
  warning when the window really does run out.
  - The window is now detected per session and the thresholds are a share of it
    (`thresholds_pct`, default `[55, 70, 82]`), so one config is right on a 200k model and on
    a 1M one. Sources, strictest first: a `context_limit` pin; `CLAUDE_CODE_AUTO_COMPACT_WINDOW`
    and `CLAUDE_CODE_DISABLE_1M_CONTEXT`; the statusLine JSON `claude-statusbar` caches on disk;
    the window already seen this session; the measurement itself (past 200k tokens the window
    cannot be the stock one). Absolute `thresholds` and a pinned `context_limit` keep working.
  - Hook payloads carry no window size - the field exists only in statusLine input - hence the
    statusbar cache. Its global file is shared by every Claude Code window, so an entry is used
    only when it belongs to this session, the per-session copy is preferred, and the reading is
    remembered in the session state: one missed tick must not escalate a level that the
    anti-spam state would then keep silencing for the rest of the session.
  - Where the statusbar could answer but this tick could not, the hook stays quiet rather than
    divide by a guess. Machines without it keep the previous 200k behaviour unchanged.
  - `handoff.sh status` prints the resolved window and its source. CI covers the matrix in
    `tests/handoff-window.test.py`: both cache shapes, a foreign session, no statusbar, both env
    knobs, a config pin, legacy absolute thresholds, and the escalation floor.

## [0.10.0] - 2026-09-04

### Added
- **The top model follows the plan.** Fable 5.1 shipped, and whether it should be the king of
  planning is a question about the subscription, not about the model. Anthropic's plan terms
  draw the line in money: on Max 5x / 20x and on premium Team/Enterprise seats, up to half the
  weekly limit is Fable at no extra cost; on Pro and on standard seats Fable is not inside the
  plan at all - every token bills to usage credits on top of the subscription. So VULYK now
  resolves `TOP_MODEL` from the plan: **`fable` on Max and premium seats, `opus` on Pro,
  standard seats, API keys and anything unrecognised.**
  - `scripts/top-model.sh` does the reading, from the account profile Claude Code caches in
    `~/.claude.json` (`oauthAccount.organizationType`, `.organizationRateLimitTier`,
    `.seatTier`) - a cache of the signed-in account, not a credential; the credentials file is
    never opened. grep and sed only, so it runs where neither `jq` nor Python is installed.
    `--explain` shows the plan, the signal and the reason; `--apply` pins the alias as `"model"`
    in the gitignored `.claude/settings.local.json` so the Queen's own session starts on it;
    `--check` reports drift. Resolution order: `VULYK_TOP_MODEL`, then a non-`auto` pin in
    `CLAUDE.md`, then the plan, then `opus`. Every failure resolves to `opus` and says why.
  - `.claude/hooks/top-model-brief.sh` prints one `[VULYK] top model:` line at SessionStart -
    the alias, the plan, the Tier 4 second-reviewer pairing, and whether the session is pinned.
    It reads and never writes: pinning is a decision, and a hook that edits settings behind
    the owner's back is the failure mode the update check exists to prevent. Wired by
    `install.sh` on install and on `--upgrade`, through the same `wire_session_hook` the
    update check uses.
  - `/vulyk-plan` and `/vulyk-review` pass the resolved alias as the **per-invocation
    `model:`** when dispatching `queen-planner`, `lead-architect` and `lead-review`; the
    parameter takes precedence over frontmatter. `/vulyk-status` and `/vulyk-bootstrap` show
    the resolution; bootstrap runs `--apply`.
  - CI runs synthetic profiles for every plan shape - Max 20x, Max 5x, Pro, standard and
    premium seats, no profile, unparseable profile, env override, constitution pin - plus
    `--apply` into a file that already holds permissions, and the hook's silence without a
    resolver.

### Changed
- **`TOP_MODEL = auto`** in the constitution. An alias in its place overrules the plan
  (`opus` on a closed codebase to stay outside the 30-day retention Fable carries; `fable` on
  Pro for someone who has decided to spend credits). The three top-caste agent files keep
  `model: opus` as their floor: frontmatter cannot be conditional and ships to every install,
  so `fable` there would bill a Pro owner from the first plan without asking, and `inherit`
  would drag the planner down to the session default - Sonnet 5 on Pro. The native `best`
  alias was weighed and rejected for the same reason: it resolves to Fable wherever Fable is
  *available*, and on Pro it is available, for credits.
- The Tier 4 second reviewer is now named by the resolver rather than fixed to `claude-fable-5`:
  `opus` beside a Fable gate; beside an Opus gate, `fable` where the plan carries it and
  `sonnet` where it would bill to credits.
- The field names for Max were read off a real profile. The Pro and seat-tier spellings follow
  the same pattern and are matched loosely (`*pro*`, `*premium*`) - the honest amount of
  confidence to encode, and the first thing to check if a Pro owner's brief says `fable`.

### Upgrading
- `install.sh --upgrade` ships the resolver and wires the hook (verified from a real 0.9.5
  install: hook copied, `settings.json` gains one entry and stays valid, the constitution is
  untouched). **Untouched is the catch:** a pre-0.10.0 constitution pins `TOP_MODEL = opus`,
  and the resolver honours a pin over the plan, so an upgraded hive on Max keeps planning on
  Opus until you change that line to `TOP_MODEL = auto`. The installer says so when it sees
  the old pin; the session brief reports `by constitution` until it changes.

## [0.9.5] - 2026-08-18

### Fixed
- **`--check` was advertised as a dry run and created seven directories.** One unguarded
  `mkdir -p` seeded `memory/learnings`, `memory/snapshots`, `docs/wiki`, `docs/specs` and
  `docs/adr` in the target whether or not the run was meant to touch it - so the one command
  offered to someone who only wants to know what VULYK *would* do to their repository was the
  command that quietly changed it. The line next to it had carried the `--check` guard all
  along; this one never did. It now prints `would create` and writes nothing, and the fix was
  verified by result rather than by report: a dry run against an empty target leaves **0**
  objects, and a real install still produces the full hive (22 directories, 56 files,
  constitution + wired hook + seeded `skills.json`). Every other writer on that path
  (`ensure_gitignore`, `wire_session_hook`) was already guarded and was re-checked here - a
  dry run against a populated target leaves `.gitignore` and `.claude/settings.json`
  byte-identical.

  **Found by [@chizhseo](https://github.com/chizhseo) in [PR #1](https://github.com/Black-coffe/vulyk/pull/1)**
  (2026-06-15), while writing an installer smoke test - which is the whole point: the defect
  was invisible to reading the code and obvious to anyone who checked the result. It survived
  nine releases because nothing in this repository ran the installer and then looked at what it
  had done. That is the same gap the framework spends its gates on, and it existed at home.

## [0.9.4] - 2026-08-18

### Fixed
- **The installer shipped runtime artifacts and no rule for ignoring them.** Handoffs,
  snapshots, the update-check cache, the derived state view, the installer's own settings
  backup - VULYK creates all of them inside your repository, and `.gitignore` is not in any
  tree `install.sh` copies, because it is the project's file and must never be replaced. The
  result: an installed project committed whatever the framework left lying around, or did
  not, by luck. Found by watching `.claude/state.json` turn up untracked in a real project one
  release after v0.9.1 declared it gitignored - true of this repository, and of nowhere else.
  `ensure_gitignore` now appends only the missing entries, in a marked block, and says how
  many it added. Idempotent, never rewrites what is already there, and honest under `--check`.
  Same doctrine as the hook wiring in v0.8.0: a rule that does not reach existing installs is
  a rule the framework only believes about itself.

## [0.9.3] - 2026-08-18

Three specs went through the blind gate in one sitting - the first time the acceptance series
had more than one entry - and the sitting found three defects in the machinery that produced
it. None were in the code under test.

### Fixed
- **`drift` could not fire on a spec whose stories predate the status convention.** It asks
  "does every story say done while the gate did not accept", and a status outside
  `todo|in-progress|done|blocked` is neither done nor not-done - so a fully merged
  twelve-story spec scored `done: 0`, the comparison never held, and the record said
  `drift: false`. The reassuring answer, not the true one: the one metric built to contradict
  the hive, switched off by a spelling. It now records `"unknown"` with the count of
  unrecognised statuses and says out loud why the comparison was unavailable.
- **The milestone-ledger exception leaked the framework's own account.** `drone-acceptance`
  is handed a configuration statement so it does not demand guarantees for deployments nobody
  has. Where that statement is a section of a milestone plan, the rest of that file is exactly
  what the gate must never read - and handing over the whole file invites reading past it.
  Observed once, and disclosed by the drone itself, which then re-verified independently: the
  disclosure rule worked and the dispatch that made it necessary should not be repeated.
  `/vulyk-review` now prefers the `## Profile` block, which holds configuration and nothing
  else, and falls back to a ledger only by **naming the section, not the file**; the caste is
  told to stop at that boundary and to report a breach rather than absorb it.
- **Concurrent acceptance gates collide on fixed test ports.** `lead-review` and
  `drone-acceptance` are dispatched together because they are independent *in information*,
  and that pairing is safe - only acceptance runs anything. Several acceptance gates at once
  are not: two of three lost their first runs to `EADDRINUSE`, which reads exactly like a
  defect in the code under test. Documented in `docs/pipeline.md` and in the dispatch step.

## [0.9.2] - 2026-08-18

The 1.0.0 bar stops being a thing anyone remembers.

### Added
- **`scripts/release-check.sh`** - counts criterion (1) instead of recalling it. A spec counts
  only when all three series exist for it: a `brief.md` for trace-check to walk, at least one
  `scope.jsonl` entry, and an `acceptance.jsonl` verdict whose `pack` fingerprint still matches
  the spec as it stands. Criteria (2)-(5) are audits rather than counts, and the script says so
  rather than guessing at them - including refusing to count version tags for (2), which is a
  fact about VULYK's releases and not about the project being measured.
  It was written because the bar had been answered from memory, wrongly, more than once. On its
  first run against a real repository the true figure was **0 of 10**, against an estimate of
  five: three specs carry brief and scope but have never been put in front of the blind gate,
  and the one acceptance record that exists predates v0.8.2's pinning, so it cannot be shown to
  describe the pack that shipped.

### Fixed
- **Two of the four deterministic records could not be joined.** A story file carries
  `story: s265a-08`; `scope-check.sh` writes the basename it was invoked with,
  `s265a-08-abandon-is-one-guarded-write`. Neither is wrong and nothing had ever needed both at
  once, so the mismatch sat unnoticed until something tried to count across them - and the
  first version of this script silently reported `scope: no` for every spec in a repository
  with thirty-seven scope entries. It now matches on both spellings. A silent `no` from a meter
  is the same defect class as a silent green from a gate.

## [0.9.1] - 2026-08-18

The last instrument v0.9.x owed, built to the constraint the judge panel set for it when
Autopilot's version was rejected: derive a view, never duplicate the truth.

### Added
- **`scripts/state.sh` -> `.claude/state.json`.** A derived view of every spec's story
  frontmatter: per-status counts, per-story rows, and a `stale` flag set when a story file is
  newer than the snapshot. Deterministic, model-free, free. `/vulyk-status` regenerates it
  before reading it and `/vulyk-handoff` regenerates it before dumping, so neither ever reads
  a snapshot from an unknown moment.
  **It is gitignored, deliberately.** A derived artifact committed beside its source becomes a
  second account of the same fact and the two diverge the first time someone edits one - which
  is this framework's fourth failure mode, built by hand. Regenerating costs nothing, so a
  stale copy has no reason to exist. If a number disagrees with a story file, the story file
  wins.
- **`unrecognised` is its own count.** Statuses outside `todo|in-progress|done|blocked` are
  reported as themselves rather than folded into `todo`. Found on the first real run: a
  repository whose older specs predate the convention - `status: DONE + merged to main ...`,
  `status: ready-for-dispatch` - was reported as 0 of 28 done. A derived view that miscounts
  quietly is worse than no view, and the bucket that made it quiet was the default one.

## [0.9.0] - 2026-08-18

Memory hardening. Three of the four records this framework keeps were written by parties
with an interest in them, and this release moves each one onto evidence.

### Added
- **`docs/pipeline.md` - the gates reference.** Deliberately not a second drawing of the
  pipeline; `architecture.md` has one. It answers the two questions documented nowhere: what
  each of the seven gates *structurally cannot see*, and what invalidates it. Acceptance
  cannot see whether the proof is real. `lead-review` cannot see the human's ask
  independently, because it reads the plan. Coverage and acceptance both sit outside the
  build, so neither observes one. Plus the staleness table and the sentence underneath every
  row of it: **when the pack moves, whatever judged it is re-run.**
- **A `## Profile` block in `CLAUDE.md`, between `VULYK:PROFILE` markers.** Stack, runner,
  source layout, test framework, commit convention - and the row that pays for itself:
  *which configurations exist today*, and what is deferred until when. A reviewer without
  that demands guarantees for deployments nobody has, and the blind acceptance gate cannot
  state the shape it judged against; both have cost real review rounds. It ships blank,
  because a profile copied from another repository is a confident lie. `/vulyk-bootstrap`
  fills it from what it verified, and `/vulyk-review` hands it to `drone-acceptance`.
- **ADR harvest, dispatched to `librarian` on the review PASS path.** A build makes decisions
  the plan did not anticipate and writes them down exactly once, in `## Plan deltas`, inside
  a directory nobody opens again. The librarian reads only those deltas and `docs/adr/`, and
  proposes an ADR for each decision that meets all three tests: a future story would have to
  re-decide it, it constrains code that does not exist yet, and its reason was recorded.
  Status is **`proposed`, always** - `accepted` is a word only the human writes. The delta is
  quoted verbatim, the same discipline `## Requirements` obey. And it may **not invent the
  options**: where a delta records no alternatives, `## Options` says "none recorded" rather
  than manufacturing a comparison nobody made - which is the defect `lead-review` calls an
  invented fact.

### Changed
- **`drone-docs` now sources from the diff; an implementation note is a lead, never a fact.**
  A worker's `## Implementation notes` is that worker's account, written by the party with an
  interest - the same reason `drone-acceptance` is kept away from the specs. A map built from
  prose inherits the prose's errors and then outlives them, and a wrong map is worse than an
  absent one because it is consulted with confidence. It gains a **verify-before-write
  checklist** (the path exists, the symbol is exported, the enforcing line is found rather
  than a mentioning one, a test claim's assertion would fail without the rule, every number
  re-derived) and an obligation to **retire what the change falsified** - the defect that
  produced both critical findings on the S2.6.5a pack that motivated this release.
- **README names a fourth failure mode.** Gates go stale where nobody looks: a check runs,
  reports green, the thing it checked moves, and nothing re-runs it. Not a bug in any gate -
  the gap between *a check ran* and *a check ran against this*. Hit twice in one day of real
  use.

### Fixed
- **A constitution block could only be reset once.** `install.sh` deleted the `VULYK:COMMANDS`
  markers while resetting the table they delimited, so a later `--upgrade` found no markers,
  warned, and left whatever was there. Both blocks now go through one `reset_marked_block`
  helper that keeps `:START` and `:END`, making the reset repeatable - which is the only way
  a framework can change its own placeholders after the first install.

## [0.8.3] - 2026-08-18

The second v0.8.x battle-test question came back and indicted the caste rather than the
gate. Plus two silent-loss paths and one stale claim, found by auditing 1.0.0 criteria (3)
and (4) against the repository rather than against the roadmap's memory of it.

### Fixed
- **`drone-acceptance` was told a library cannot be run.** Its cannot-run branch listed
  "a library" as an example of work with no runnable surface. That is false: a library's
  surface is a caller, and writing one is the gate's job. The sentence licensed a lazy
  `CANNOT_RUN`, which is the exact mirror of the false green the branch exists to prevent -
  both are a verdict the gate did not earn. Found by running the battle test that question
  was waiting on: given a genuinely library-only spec (`@skervik/core`'s adaptive-duration
  calculator, seven asks, no user-reachable surface), the drone ignored the instruction,
  wrote a caller against the built package, mapped every ask to an executable observable and
  ran them - negatives included. It was better than its own definition. The branch is now
  reserved for behaviour with no entry point or an environment missing what reaching it
  needs, a library / CLI flag / schema / pure function are named as reachable, and a decline
  must state what was tried - so one that made no attempt is visible as such.
- **The acceptance note reaches git unredacted.** `scripts/redact.sh` was wired into the
  three writers that persist free text - `session-end-learnings.sh`, `handoff.py`, and
  `brief.md` via `/vulyk-plan` - but not into `acceptance-log.sh`, whose `note` is free text
  a model wrote while summarising a drone's report and whose output file,
  `memory/stats/acceptance.jsonl`, is committed. A drone that quotes a command line with a
  token in it put that token in the repository. The note now goes through the same filter,
  degrading to unfiltered text only where `redact.sh` is absent, exactly as the other writers
  do. Verified: `ghp_...` and `sk-ant-api03-...` in a note now land as `[VULYK:REDACTED]`.
- **A repair round is dispatched against a wave-check nobody re-ran.** `/vulyk-build` runs
  the story gate at step 2, against the pack as approved - and then a repair round changes
  that pack. The rule for ad-hoc repairs said to intersect file sets *by hand*, which is the
  one job this repo already has a deterministic script for. It now says to re-run
  `wave-check.sh` on the spec, because when the pack moves, whatever judged it is re-run -
  the same rule v0.8.2 gave the acceptance verdict, for the same reason.

### Changed
- **README no longer says the acceptance series "starts empty, as it should".** It did when
  that sentence was written; the first real entries are in, and the sentence now says which
  claim it is making about a fresh install and points at what the first run showed. Criterion
  (3) is that no documented claim goes unverified on the current client - `effort` and the
  ten agents' models were re-checked against the files this release and both hold.

## [0.8.2] - 2026-08-18

The first v0.8.x battle test came back, and the thing it broke was the metric.

### Fixed
- **An acceptance verdict now names the pack it judged.** `scripts/acceptance-log.sh` recorded
  the pack's *size* and not its *identity*, so the one series built to contradict the hive is
  falsifiable by ordinary process: run the gate, let review carve out repair stories, ship.
  The record then reads `ACCEPTED`, `drift: false` about a pack the drone never saw. That is
  not hypothetical - it is what the first real run did (katan `S2.6.5a`: accepted at six
  stories, shipped at nine, gate never re-run). Every entry now carries `head` (the commit)
  and `pack` (a fingerprint over the story filenames; adding, removing or renaming a story
  changes it, editing a story's body does not - a verdict is about which work was judged).
  New `--check <spec-dir>` recomputes it and answers `CURRENT`, `STALE` or
  `NO VERDICT RECORDED`, report-only and exit 0 like every other deterministic check.
  Degrades to the plain story count where no `sha256sum`/`shasum` exists, which still catches
  the case that actually happened.
- **`/vulyk-review` closes the hole on both sides.** Step 5: cutting a repair story invalidates
  the verdict, and the gate is re-dispatched when that repair round closes - a verdict
  inherited across a changed pack is the drift number quietly lying, which is worse than no
  number. New step 6: no merge is proposed until `--check` says the accepted pack is the
  shipped pack, and `NO VERDICT RECORDED` is reported out loud rather than passed over.

### Changed
- **`acceptance-log.sh` stops overselling its own series.** Its header called a long run of
  `drift: false` "the closest thing to proof that the pipeline delivers what was asked". The
  same battle test showed why that reads too far: the blind gate accepted a pack `lead-review`
  then blocked twice, on coverage holes that were entirely real - the e2e no longer proved the
  GDPR route abandoned a paused match, and nothing failed if the erasure handler reverted to a
  read-then-write. Both gates were right at once, because one asks whether the asks got built
  and the other asks whether the proof is real. `drift` is evidence about delivery and never
  about proof, and the header now says so.

## [0.8.1] - 2026-08-18

A one-line release, and the line matters: in 0.8.0 the update check wired itself into
Windows projects in a form that never runs.

### Fixed
- **`install.sh` now mirrors the project's own hook-launcher convention when wiring.**
  Claude Code executes a hook command through the system shell, so a Windows install wraps
  every hook as `"C:\Program Files\Git\usr\bin\bash.exe" "$CLAUDE_PROJECT_DIR/.claude/hooks/x.sh"` - a bare `.sh` path there is not executable and silently
  does nothing. 0.8.0's `wire_session_hook` always wrote the bare path, so on exactly the
  platform the author runs, the update notice was installed and then never fired. The wiring
  now reads how the sibling hooks in that file are invoked and reproduces it, prefix and
  quoting alike, falling back to the bare path when the siblings use one. Idempotence matches
  on script name under any spelling, so a project wired by 0.8.0 is not given a second entry.
  Found by reading the settings file after a real upgrade rather than the installer's own
  report of success - the report said `wire`, truthfully, and was useless.

## [0.8.0] - 2026-08-18

Independence gates — the v0.8.0 slice of the Autopilot merge. Two checks that are useful
precisely because of what they are not allowed to read, plus the deterministic checks the
v0.7.0 battle tests earned. Every mechanism here answers one question: can this framework
be contradicted by something other than itself?

### Added
- **`.claude/agents/drone-coverage.md`** (sonnet, `Read`, `maxTurns: 5`) — receives exactly
  `brief.md` and `plan.md`, never a story file, and reports which of the human's asks the
  plan does not visibly carry: absent, partial, plan work with no ask behind it, and asks
  the plan answers by assuming them away. Dispatched at `/vulyk-plan` step 8, *before* the
  approval stop — after it the check is theatre. Quotes the brief verbatim so its fragments
  reconcile with `trace-check.sh`; one-line `CANNOT RUN` when there is no brief.
- **`.claude/agents/drone-acceptance.md`** (sonnet, `Read/Grep/Glob/Bash`) — receives the
  brief, the repository, one run command and the project's milestone ledger, and is
  forbidden everything else under `docs/specs/`. It judges the software against the request,
  not against the framework's account of what it built, and it can only do that while it has
  not read that account. Verdict `ACCEPTED | REJECTED | CANNOT_RUN`, one line per ask with
  the evidence, plus `UNASKED` for behaviour nobody requested. The `CANNOT RUN HERE` branch
  is loud and is a respectable outcome: a gate that quietly says "looks fine" without running
  anything is the failure this caste exists to prevent.
- **`scripts/acceptance-log.sh`** — fourth deterministic record, beside scope/wave/trace.
  Reads the story statuses itself, takes the verdict from the caller, appends to
  `memory/stats/acceptance.jsonl`, and computes **drift**: every story `done` while the blind
  gate did not accept. That series is the only one in VULYK capable of contradicting VULYK.
- **Story-gate checks in `scripts/wave-check.sh`** (candidates 1–3 from the v0.7.0 battle
  tests, pulled into this release rather than a v0.7.1): `missing` — a declared path whose
  parent directory does not exist; `empty-glob` — a declared glob matching nothing;
  `no-verify` — a story with no verification command, whose green cannot mean anything;
  `verify-gap` — a verification command whose named paths do not intersect the story's
  `## Files`, the shape that made one battle-test story's green vacuous; `repeat` — a
  malformed repeat count. A command token counts as a path only when the tree agrees - it
  exists, or it is a glob - so `@scope/package`, a branch name or a URL is not mistaken for
  one (caught by this release's own battle test, which otherwise flagged every story in a
  pnpm monorepo). The script's own limits are stated in its header instead of being
  discovered later: a whole-suite command that names no path cannot be judged, and a path
  that resolves but is the wrong file passes.
- **Optional `repeat: N` under a story's `## Verification`** — for a surface with a measured
  flake rate, honoured by both workers and by the build loop. The template carries the
  arithmetic that makes the number honest: five runs catch a 1-in-5 flake about two times in
  three and a 1-in-25 flake fewer than one time in five.
- **`.claude/hooks/vulyk-update-check.sh` + `scripts/vulyk-update.sh` + `/vulyk-update`** — a
  colony that can be told a newer version of itself exists. The hook compares the installed
  stamp in `.claude/vulyk-version` against the newest `v*` tag on the origin at most once a
  day (cached in a gitignored `.claude/.vulyk-update-cache`), and on a genuine difference
  prints one line whose entire content is an instruction to **ask the owner** — it applies
  nothing, and it says so to the model in as many words, because a hook's output is not
  consent. It fails open on every axis that could otherwise cost a session: no stamp, no
  `curl`, no network, a rate-limited API, an unparseable cache, or an owner running ahead of
  the tags all exit silently. `scripts/vulyk-update.sh` is the applier, and it deliberately
  contains **no copying logic of its own**: it fetches the requested tag into a cache outside
  your project and hands the work to *that release's* `install.sh --upgrade`, so an upgrade
  can never mean something the release did not document. `/vulyk-update` puts the decision
  where it belongs — dry run first, CHANGELOG summarised, then one question — and names the
  constitution edits that did NOT land, since `CLAUDE.md` is yours and stays a manual merge.
  Forks point it elsewhere with `VULYK_REPO` or a `.claude/vulyk-origin` file; `VULYK_UPDATE_CHECK=0`
  switches the whole thing off.
- **`install.sh` now wires a shipped hook into an existing `.claude/settings.json`** —
  `wire_session_hook`. Found while testing the above, and it is the difference between the
  feature working and appearing to: `settings.json` is deliberately NOT framework-owned (it
  holds the owner's permissions and their own hooks), so `--upgrade` skipped it and every
  existing install would have received the update-check script without ever running it — the
  notice failing to reach precisely the people furthest behind. The installer now appends the
  single missing entry in place, after writing `.claude/settings.json.vulyk-bak`, and prints
  what it did including that the edit re-indents the file. Idempotent (the entry is matched by
  script name, so a second upgrade is a no-op), honest under `--check` (`would wire`), and it
  refuses rather than guesses when there is no python on PATH or the JSON does not parse — in
  both cases printing the exact line to paste. Nothing else in `settings.json` is read or moved.

### Changed
- **`lead-review`** gains three categories — **Reinvention** (the repo already has this),
  **Silent narrowing** (delivered less than asked, with nothing in `## Descoped` or
  `## Plan deltas`), **Invented fact** (a claim about the repo, a library or an interface
  that nobody verified) — plus three rules: a coverage claim must hold for *each* thing it
  names rather than the set; a severity resting on a deployment shape must name the
  configuration it assumes, because the Queen holds the milestone context and the reviewer
  does not; and every finding carries a routing word, `plan` or `worker`, answering "could a
  worker holding only its story have known?". Findings are written as one-sentence
  conditions, since the repair goes to a fresh worker that never saw the review.
- **`worker-code` / `worker-test`** — a claim in the return report must be true of each thing
  it names, not of the pair; both honour `repeat: N`.
- **`/vulyk-plan`** is now 9 steps (coverage check inserted before the approval stop, which
  now presents three verdicts). **`/vulyk-review`** dispatches `lead-review` and
  `drone-acceptance` in one message — independent, so concurrent — and records the verdict
  through `acceptance-log.sh`; an acceptance `BROKEN` outranks a review minor, because it is
  the human's own request failing while being run.
- **`/vulyk-build`** re-runs the story gate after approval (the tree moved since planning),
  applies the wave file-intersection rule to ad-hoc **repair** dispatches, and bans
  `git checkout <path>` / `git restore` / `git stash` during a build: uncommitted worker
  output is the normal state of the tree and there is no diff to recover it from. Mutation
  testing waits for the story's commit as its restore point. Same ban stated in `lead-review`.
- README, architecture flow, model cascade, command reference and getting-started updated for
  the two new castes; `memory/stats/acceptance.jsonl` named in the measured section, where it
  starts empty as it should.

## [0.7.0] - 2026-08-17

Traceability spine — the v0.7.0 slice of the Autopilot merge: the discipline that a
human's request survives, verbatim and traceable, from idea to approved plan.

### Added
- **`docs/specs/<slug>/brief.md`** — `/vulyk-plan` now opens by writing the request
  VERBATIM as a blockquote, piped through `redact.sh` (briefs are committed; secrets are
  not), plus an `## Answers` section for briefing answers, also verbatim.
- **Briefing discipline** as a `/vulyk-plan` step: look facts up first; only
  irreversible / costly / vendor-choice / business-rule questions reach the human, one at
  a time, each with a recommended default so silence has a safe meaning.
- **`## Requirements` in `templates/story.md`** — verbatim quotes from brief.md, one `> `
  line per fragment, explicitly EXEMPT from the ~1500-token story budget (user words are
  never trimmed to fit). Tier 2+ only, per the ceremony floor.
- **`templates/plan.md`** — the plan file gets a template at last: assumptions,
  story-by-wave index, `## Contracts` (interfaces crossing story boundaries, pinned at
  plan time by the one context that saw the whole plan), integration gate, `## Descoped`,
  `## Plan deltas`, and the approval line `/vulyk-build` refuses without.
- **`scripts/trace-check.sh`** — third deterministic gate, beside scope-check and
  wave-check; report-only, exit 0, zero tokens. Backward: every story quote must appear
  verbatim (whitespace-normalized) in brief.md — or in plan.md's `## Plan deltas` for
  stories cut after approval, reported as `~` — so an invented or paraphrased requirement
  and a quoteless story are both caught before the human approves. Forward: brief lines
  no story quotes are listed; deciding "context, not requirement" belongs to the human.
  Loud cannot-run branch on specs that predate the brief.
- **Merge pass in `queen-planner`** — after decomposition, every story faces the
  *payback test* (a story that will not pay back its own dispatch overhead folds into its
  neighbour) and the *neighbour test* (if the adjacent story's worker would do this work
  at marginal cost, the boundary is imaginary). Shipped as heuristics by name — the
  analysis's re-orientation token figure was an estimate nobody measured, so per the
  judges' verdict the number is not shipped as if it were.

### Changed
- `/vulyk-plan` is now 8 steps: tier → brief → briefing questions → recon → plan →
  stories → wave-check + trace-check → approval stop (which now also presents uncovered
  brief lines and both gate verdicts).
- Routing matrix in CLAUDE.md gains a **Stories** column (0: —, 1: 1, 2: 2–4, 3: 4–8,
  4: 9–16; past 16 = split into separate specs) and states the **ceremony floor**:
  brief.md + requirement quotes at Tier 2+, trace-check whenever stories exist, Tier 0–1
  exempt from all of it.
- `queen-planner` receives the brief as a first-class input and must tie every story to
  a verbatim quote — a story it cannot tie is speculative and gets cut or surfaced as an
  assumption.
- README, architecture flow, command reference updated; battle-test of the backward
  trace (invented story, delta-sourced story, quoteless story, uncovered brief line —
  all caught) ran against a synthetic spec; the two real Tier-3 plans the roadmap asks
  for accrue on the next planning sessions.

## [0.6.0] - 2026-08-17

Secrets & claims hygiene — the v0.6.0 slice of the Autopilot merge
(`docs/specs/autopilot-merge/plan.md` §4). Distribution (`--upgrade` + version stamp) was
pulled forward into v0.5.0/0.5.1 and battle-tested there; the effort claim was re-measured
and restated back in v0.4.0. What remained ships here.

### Added
- **`scripts/redact.sh`** — deterministic stdin→stdout secret mask (AWS/GitHub/Slack/
  Google/`sk-*` tokens, JWTs, Bearer headers, URL credentials, PEM private-key blocks,
  `password=`/`api_key:`-style assignments). The only VULYK script that transforms instead
  of reports; still never blocks — if the sed dialect rejects the expressions it degrades
  to `cat`, because eating a handoff would be a silent-loss path of its own.
- **`CLAUDE.md` `## Secrets`** — secrets never enter the paperwork (env-var names, not
  values); redaction is a seatbelt, not permission; a secret that reaches git is rotated,
  not deleted.

### Changed
- `session-end-learnings.sh` pipes distilled learnings through `redact.sh` —
  `memory/learnings/` is committed to git.
- `handoff.py` passes the whole dump through `redact.sh` before writing (subprocess with a
  minimal built-in regex fallback for bash-less environments) — handoffs are gitignored
  but re-injected into future sessions and routinely shared.
- Irreversible-action rule now stated in **every** Bash-holding agent: `worker-code`
  already had it (v0.5.0); `worker-test` and `lead-review` (which gained Bash later) now
  carry it too — the plan's "both Bash-holding agents" predates lead-review holding Bash.
- Haiku→Sonnet drift fixed where docs still claimed drones run on Haiku:
  `docs/architecture.md` (caste table + flow diagram), `docs/command-reference.md`,
  `docs/getting-started.md`, `/vulyk-map`'s description, and CLAUDE.md's own Bookend rule.
  Frontmatter (`model: sonnet` since v0.2.0) is the truth; the honest "not measured"
  caveat stays in `docs/model-cascade.md`. Remaining Haiku mentions (autolearn distiller,
  alias examples) are accurate and stand.

### Removed
- `.claude/workflows/` (experimental README + example JS). VULYK's pipelines ship as slash
  commands; the sketch referenced a roadmap line that no longer exists. Existing installs
  keep their copy — `--upgrade` never deletes; remove it by hand if you never enabled it.

## [0.5.2] - 2026-08-17

First battle-test of the v0.5.x build loop on a real Tier-3 pack (8 stories, 4 waves,
katan/skervik S2.1.7b) passed: waves dispatched with no file collisions, one commit per
story, NEEDS_CONTEXT and Law 5 both fired and held. The test surfaced one metric leak:

### Fixed
- `scope-check.sh` counted the story file itself as out-of-scope. The build loop commits
  the story alongside its code (the `status:` line changes, one commit per story), so every
  scope.jsonl entry carried a constant `out_of_scope: 1` of noise and a clean scope report
  was unreachable by construction. The story file is now dropped from the measurement
  (both `changed` and `out_of_scope`); paths are normalized against a leading `./`.

## [0.5.1] - 2026-08-16

First battle-test of `--upgrade` (a real pre-0.5.0 install) caught three leaks in the
installer - all three are VULYK's own working content shipped into the user's project.

### Fixed
- `install.sh` no longer ships: `__pycache__/`/`*.pyc` (the installer copies from disk,
  not from git, so the maintainer's compiled Python rode along), VULYK's own session
  learnings (`memory/learnings/*` except `README.md`), and VULYK's own dev specs
  (`docs/specs/*`; the directory itself is still created). New `shippable()` filter with
  the rule stated: the skeleton ships, the hive's own honey does not.

## [0.5.0] - 2026-08-16

First release of the Autopilot merge: parallel build made safe and cheap. Design decisions,
resolved conflicts and the roadmap to 1.0.0 are in `docs/specs/autopilot-merge/plan.md` — the
synthesis of a 40-agent analysis (9 lenses × opus/sonnet/haiku panel + 3 adversarial judges)
of VULYK v0.4.2 against [Autopilot](https://github.com/nick-vels/skills) (MIT, © Nick Vels).

### Added
- **Waves.** `templates/story.md` frontmatter gains `wave:` and `blocked_by:`. Stories in one
  wave are dispatched concurrently and must declare disjoint `## Files` — the file list is now
  also the collision key. `queen-planner` decides the boundaries at plan time, in the one
  context that has seen the whole plan.
- **`scripts/wave-check.sh`** — second deterministic gate alongside scope-check: reports file
  collisions within a wave, blocker-order violations, dangling `blocked_by` ids and empty
  `## Files` blocks. Model-free, token-free, always exits 0; `/vulyk-plan` runs it before the
  approval stop and `/vulyk-build` re-runs it before dispatching.
- **Bounded worker returns.** `worker-code` and `worker-test` end with a ≤25-line report
  (`STATUS`/`FILES`/`TESTS`/`INTERFACES`/`CONCERNS`/`BLOCKERS`) — never diffs or raw logs.
  New `NEEDS_CONTEXT` status separates a defective story (a plan bug) from a worker failure.
- **Law 5 — the Queen's hands stay off story code.** From the moment a story file exists,
  every edit to its files travels through a worker; at every tier, a returned worker's story
  is never finished by hand. Tier 0–1 direct work is explicitly untouched.
- **`install.sh --upgrade`** (pulled forward from the v0.6.0 plan): syncs framework-owned
  files (agents, commands, hooks, meta-skills, bootstrap, templates, scripts) to the new
  version, never touches the constitution, memory, specs, ADRs or wiki, and points out
  constitution changes to merge by hand. `.claude/vulyk-version` stamp records the installed
  version; a `VERSION` file at the repo root is its source. An installed (marker-eaten,
  possibly edited) constitution is recognized by its title, so an upgrade no longer offers a
  second, conflicting `CLAUDE.vulyk.md`.

### Changed
- **`/vulyk-build` rewritten around the wave loop.** One message per wave (that is what makes
  workers actually concurrent); each returning story closed individually: scope-check → quiet
  verification → **one commit per story** (`story(<slug>-NN): <title>`) → status. Repair is
  capped at two rounds, findings attached as conditions, third attempt = `blocked` + re-plan.
  Mid-build narrowing is recorded in `## Descoped` in plan.md, never silent. The final full
  verification runs outside the main context (subagent or `tail -30`).
- **`scope-check.sh` measures per story now.** With per-story commits, the default
  working-tree range at close time is exactly the closing story's diff — the numbers in
  `memory/stats/scope.jsonl` stop being contaminated by earlier stories in the same build.
- `/vulyk-review` on `BLOCK` converts every finding worth acting on — not only criticals —
  into fix stories routed through the cascade (Law 5: no hand-patching).
- `queen-planner` right-sizing table extended: Tier 3 ≈ 4–8 stories, Tier 4 up to ~16,
  past that the goal splits into separate specs. Calibration, not targets.

### Notes
- Adopted from Autopilot by decision of the panel: waves, bounded returns, repair ceiling,
  per-story commits, the orchestrator-keyboard law, descope records. Explicitly refused, with
  reasons recorded in the plan: modes/depth/polish dials, the R##/A##/D## manifest ledger,
  `.autopilot/` as a second storage root, persistent reviewers (experimental-flag-bound),
  per-story model review, the dashboard as a source of truth.
- `wave-check.sh` verified against synthetic specs covering all four defect classes plus
  glob-vs-path and directory-prefix collisions; `install.sh` fresh/reinstall/upgrade paths
  verified on throwaway projects, including user-file immunity and the no-duplicate-
  constitution case.

## [0.4.2] - 2026-08-16

Stops v0.4.1's filled-in `## Commands` table from reaching other people's projects.

### Added
- `install.sh` now blanks the `## Commands` table back to placeholders when it copies the
  constitution (into `CLAUDE.md` or `CLAUDE.vulyk.md` alike). Those rows are VULYK's own shell and
  Python syntax checks: harmless-looking, and they exit 0 on any repository, which is exactly what
  makes them dangerous elsewhere — a false green is worse than a visible placeholder.
- `VULYK:COMMANDS:START` / `VULYK:COMMANDS:END` markers in `CLAUDE.md` for the installer to anchor
  to. When they are missing — an edited constitution, an older copy — the installer prints a
  **warning** and leaves the table alone rather than quietly matching nothing. A silent no-op is
  the failure mode the whole mechanism exists to prevent, so it is the one outcome ruled out.
  `CONTRIBUTING.md` now tells contributors to keep the markers.

### Notes
- Verified with a 20-check suite over real installs: fresh directory, directory with an existing
  `CLAUDE.md` (untouched, byte for byte), `--check` dry run (announces, writes nothing), a source
  with the markers stripped (warns, still exits 0), and two installs producing byte-identical
  output. The surrounding constitution survives intact — heading, following section, and file tail.
- `CONTRIBUTING.md` gains the real dev-verification block, replacing a stale one-liner.

## [0.4.1] - 2026-08-16

Fills in the `## Commands` table v0.4.0 shipped empty — for VULYK itself.

### Changed
- `## Commands` in `CLAUDE.md` now carries this repository's real verification commands: `bash -n`
  over every tracked shell script, `py_compile` over the hooks, `jq -e` over every tracked JSON
  file, the `handoff.sh status` self-diagnosis, and the per-story scope gate. Each was run in both
  directions before being written down — silent and zero on success, non-zero on a deliberately
  broken input. The "full suite / build" row says **none exists** rather than naming a plausible
  command: VULYK has no test runner and no compiler, and a verification that always exits 0 is
  worse than an admitted gap.
- Because `install.sh` copies `CLAUDE.md` verbatim, the table now carries a blockquote saying in
  as many words that these rows are VULYK's own and wrong for any other project. `/vulyk-bootstrap`
  is correspondingly stricter: **replace every row** (and delete the blockquote), verify each
  command actually runs, and write "none" where the project genuinely lacks one.

## [0.4.0] - 2026-08-16

The price list behind the rules. VULYK's token economy was a set of good habits with no stated
mechanism; this release writes the mechanism down and closes the gaps it exposes. **Additive:
nothing was removed.** Grounded in Anthropic's
[Maximizing the value of your Claude Code sessions](https://claude.com/blog/maximizing-the-value-of-your-claude-code-sessions).

### Added
- `docs/token-economy.md` — what actually decides the price of a token: which model burns it, input
  vs output (decode is priced at roughly 5× prefill, and thinking tokens are output tokens), and
  cache state (a hit costs ~0.1× input, a write up to 2×). Then the cache key and everything that
  invalidates it — `/model`, `/effort`, fast mode, `/compact`, the TTL, resuming an old session —
  and the four levers ranked by what they actually cost: session length, context size, model and
  effort, cache breaks.
- `## Commands` in `CLAUDE.md` — a table of the project's verification commands **in quiet form**.
  Command output under 30 000 characters is appended to the transcript verbatim and re-sent on
  every subsequent turn, so a chatty test reporter can outweigh the code it verifies.
  `/vulyk-bootstrap` now fills this table in, and `templates/story.md` requires `## Verification` to
  name one of its entries.
- `## Compact instructions` in `CLAUDE.md` — what a compaction of a hive session must preserve
  (tier, story statuses, decisions *with reasons*, walls, open pointers) and what it should drop
  (file contents, diffs, command output, scout reports — all of it re-readable from disk). Claude
  Code honours this section; it is the model-side counterpart to what `context-guard.sh` snapshots
  to disk.
- Cache-warmth awareness in `handoff.py`. The transcript entry that yields the token count also
  carries its `timestamp`, so the age of the cached prefix is free to compute — and it decides the
  *price* of acting on the warning, since compacting and checkpointing both re-read the
  conversation. From level 2 the banner and the prompt injection now close with "warm for ~55 more
  min", "expires in ~5 min — checkpoint now", or "expired anyway — no reason to delay". New
  `cache_ttl_minutes` config key, default 60 (subscription); set `5` on an API key without
  `ENABLE_PROMPT_CACHING_1H=1`. Transcripts without a parseable timestamp drop the clause silently.

### Changed
- `## Token economy` in `CLAUDE.md` gains three rules that were previously only implied: route
  models with agent frontmatter and never `/model` (a subagent has its own context *and its own
  cache*, while a session-level switch re-prefills the whole conversation at full price — which is
  also what makes the Tier 4 second reviewer affordable); name paths instead of describing
  symptoms, since a vague request buys a grep and a dozen file opens that stay in context for the
  rest of the session; and prefer `/rewind` over `/compact` when undoing the last few turns,
  because it cuts only the end and leaves the cached prefix intact.
- `/vulyk-status` gains a context-hygiene step — `/context` and `/mcp` — that fires only on a fresh
  session, where the advice can still be acted on.
- Docs: new "Route with frontmatter, never with `/model`" section in `model-cascade.md`; a
  context-hygiene section in `getting-started.md`; cache-warmth details in `hooks-reference.md`;
  `command-reference.md` and README updated.

### Notes
- No behaviour change for anyone who never hits a warning threshold: the hook's contract (never
  crash, never block, one warning per level per session) is untouched, and the new clause is
  additive text on warnings that already fired.
- The `## Commands` table ships with placeholders. Existing projects should fill it in — or re-run
  the relevant part of `/vulyk-bootstrap` — otherwise story templates point at an empty table.

## [0.3.0] - 2026-08-16

Session continuity. The token economy already mandates `/clear` between tiers — this release makes
that hygiene cheap by adding the layer that survives it. **Additive: nothing was removed.** Ported
from a battle-tested private Windows setup (in daily use since 2026-07-27), translated and
re-rooted into the project.

### Added
- `.claude/hooks/handoff.py` — context-budget guard + session handoff. The key mechanism: Claude
  Code hooks receive **no token counter**, but every hook gets `transcript_path`, and the
  `message.usage` block of the last *non-sidechain* assistant entry in that JSONL (input +
  cache_read + cache_creation + output) is the true current context size. Everything else hangs off
  that measurement:
  - escalating warnings at 110k / 140k / 165k tokens (Stop banner to the human, UserPromptSubmit
    injection to the model), each level firing **once per session** — a noisy hook is worse than no
    hook;
  - mechanical auto-dump (git state, last TodoWrite, touched files, recent prompts, last reply) to
    `.claude/handoff/` on SessionEnd (`/clear`, exit) and PreCompact; sessions under 25k tokens are
    skipped as not worth dumping;
  - restore on SessionStart: always after `clear`/`compact`, on plain `startup` only if younger
    than 12 h and not already consumed, never on `resume`/`fork`. The injected preamble instructs
    the model to confirm the resume point with the user before doing any work;
  - contract: **never crash, never block** — any failure is `exit 0` with no stdout.
- `.claude/hooks/handoff.sh` — fail-open wrapper: tries `python3`/`python`/`py`, silently no-ops
  when no Python 3 is on PATH, per the same contract the other hooks follow for `jq`.
- `/vulyk-handoff` — two-phase checkpoint: the script writes the mechanical skeleton, the model
  rewrites its `## Summary` (goal, current state, next step, decisions *with reasons*, dead ends,
  needed resources) and flips `enriched: true`. The reasoning behind decisions is the part no
  mechanical dump can recover — that is why the command exists on top of the auto-dumps.
- Hook wiring in `.claude/settings.json` (Stop and UserPromptSubmit are new events for VULYK;
  handoff entries appended to the existing SessionStart / SessionEnd / PreCompact groups).
- `.claude/handoff/` gitignored — handoffs, their index and anti-spam state are per-machine session
  state, deliberately outside the git-tracked memory plane.
- Optional `.claude/handoff.config.json` for overrides (`thresholds`, `context_limit` — set
  `1000000` on a 1M-context model, `enabled`, dump limits).
- Docs: session-handoff sections in `hooks-reference.md`, `command-reference.md`,
  `memory-system.md`, README hook/command tables.

### Notes
- Requires Python 3 for the handoff feature only; without it every handoff hook exits silently and
  the rest of VULYK is unaffected.
- The `/vulyk-evolve` rebuild around the scope metric, previously earmarked for v0.3.0, moves to a
  later release — it is still blocked on real `scope.jsonl` data.

## [0.2.0] - 2026-07-27

Recalibration for Claude Opus 5 (released 2026-07-24). **Additive: nothing was removed.** The
roster, the commands and the memory plane are untouched — what changes is model routing, three
prompt rules aimed at a frontier model's failure mode, and the framework's first objective metric.

### Added
- `scripts/scope-check.sh` — the scope gate, and VULYK's only objective metric. Compares a story's
  `## Files` block against the real diff and appends two numbers to `memory/stats/scope.jsonl`:
  files declared, and files touched that were never named. Deterministic, no model, zero tokens.
  Wired into `/vulyk-review` as its first step, because that is an event that actually happens —
  the build loop neither commits nor merges, so a post-merge hook would never have fired.
- `## Non-goals` in `templates/story.md` — an explicit stop-list of what this story invites and
  must not do. Aimed directly at scope expansion, which the Opus 5 system card names as the cause
  of its own dip in coding scores at high effort.
- `## Tracer` and a `tracer:` flag — the first story of an epic cuts the thinnest possible slice
  through every layer before the rest add breadth.
- A `~1500 token` budget on story files, and an artifact-length rule in `CLAUDE.md`. Written
  artifacts from current models run long by default.
- "Working with a frontier model" in `CLAUDE.md`: scope discipline, delegation restraint, artifact
  length — the three rules Anthropic's Opus 5 prompting guide recommends.
- "What is measured, and what is not" in `README.md`.
- `"effortLevel": "medium"` in `.claude/settings.json`.

### Changed
- `TOP_MODEL` is now the `opus` alias rather than a pinned ID, and the cascade documents aliases as
  policy. `opus` and `sonnet` already resolved to Opus 5 and Sonnet 5, which is why this migration
  cost three lines instead of a rewrite.
- `drone-scout`, `drone-docs`, `librarian` moved from `haiku` to `sonnet`. **This one is a judgment
  call, not a measurement** — Anthropic's own effort routing puts recon at "Sonnet or cheaper", and
  the counter-argument is only that Haiku 4.5 is the sole tier without a fifth-generation upgrade
  while scout reports feed planning. First in line to be measured; reverting is three lines.
- `lead-review` now reports every finding ranked by severity instead of capping at three nits on a
  PASS. A reviewer told to report only what matters reliably finds less — and Opus 5's review recall
  is already lower than its predecessor's (61.1% → 55.2% on CodeRabbit's production benchmark) even
  as precision rose.
- The Tier 4 second reviewer must now run on a *different* model. Two copies of one model are blind
  in the same places. `claude-fable-5` is the intended pairing, off by default: it costs about twice
  as much, and unlike Opus it is subject to 30-day data retention while seeing the entire diff.
- "Max effort on planning" removed from Tier 4. The step from `high` to `max` costs roughly +94%
  for about two points of benchmark index.

### Fixed
- Documented that `effort:` in `.claude/agents/*.md` frontmatter is **silently ignored** — an
  invalid value raises no error. Effort is a session-level setting (`--effort`, `/effort`, or
  `effortLevel` in settings). Both behaviours were measured; numbers in `docs/model-cascade.md`.

### Notes
- v0.1.0 is tagged. Nothing in this release breaks an existing install.
- `/vulyk-evolve` is unchanged but still unproven. It is being rebuilt around the scope metric for
  v0.3.0, once `scope.jsonl` has real data — changing configuration without feedback is exactly
  what it exists to prevent.
- The reasoning behind every decision here, including a plan that was overturned by adversarial
  review before shipping, is in `docs/grill/2026-07-27-vulyk-v0-2-0-opus-5.md`.

## [0.1.0] - 2026-06-12

### Added
- Hive roster: 8 cascade-routed agents (queen-planner, lead-architect, lead-review, worker-code, worker-test, drone-scout, drone-docs, librarian).
- Orchestration commands: /vulyk-bootstrap, -plan, -build, -review, -map, -evolve, -gc, -status.
- Memory plane: pointer index, codebase map, LLM wiki conventions, learnings buffer, snapshots.
- Self-evolution cycle with insight-harvester and skill-gardener meta-skills, usage counters, and graveyard retirement.
- Hooks: session brief (SessionStart), learnings capture (SessionEnd, optional Haiku auto-distill), skill usage counter (PostToolUse), compaction guard (PreCompact); post-merge git-hook sample.
- Bootstrap interview, story/ADR/wiki-note templates, non-destructive installer, full documentation set.
