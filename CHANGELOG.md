# Changelog

All notable changes to VULYK are documented here. `/vulyk-evolve` changesets append entries automatically (one line per change, with rationale).

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
