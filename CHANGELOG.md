# Changelog

All notable changes to VULYK are documented here. `/vulyk-evolve` changesets append entries automatically (one line per change, with rationale).

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
