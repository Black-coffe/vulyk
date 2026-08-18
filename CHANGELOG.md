# Changelog

All notable changes to VULYK are documented here. `/vulyk-evolve` changesets append entries automatically (one line per change, with rationale).

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
