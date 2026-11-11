# Study: an automation recommender inside VULYK

**Date:** 2026-11-11 · **Deliverable:** study (no code) · **Brief:** `brief.md`
**Validation:** three-model cross-review (Fable, Opus, Sonnet; two rounds, anonymized round 2). Same provider, so shared blind spots are possible.

## Bottom line

Take the idea, not the file. Build only after a measurement shows that the recommendations do not
simply repeat what VULYK already ships. The measurement comes first and costs no code: run Anthropic's
own skill on 3-5 hives of different stacks and subtract what VULYK covers. If at least one recommendation
per hive survives and the owner accepts it, ship a small VULYK-aware skill that the owner calls on
demand. Its description is not loaded into every session, so it costs nothing until it is used. If
nothing survives, ship one line in the docs that points to the official plugin.

## Findings

1. **The source is real and read-only.** Anthropic plugin `claude-code-setup` v1.0.0, skill
   `claude-automation-recommender`, Apache-2.0, in `anthropics/claude-plugins-official`
   (`plugins/claude-code-setup/.claude-plugin/plugin.json`, `LICENSE`). Its `SKILL.md:11`: "This skill is
   read-only ... It does NOT create or modify any files." SKILL.md is 289 lines and its five reference files
   are 1188 more, 1477 in total. The plugin page (claude.com/plugins/claude-code-setup, read 2026-11-11)
   says "Anthropic verified", read-only, 195,067 installs.
2. **Its signal tables collide with VULYK.** `SKILL.md:135` recommends a `code-reviewer` subagent for
   repos over 500 files, and `:140` a `test-writer`. VULYK already has `lead-review`, the council and
   `worker-test`. `SKILL.md:121-124` adds PostToolUse auto-format, lint, type-check and run-related-tests
   hooks on every edit. A formatter touches files outside a story's `## Files` (Law 3, `scope-check.sh`),
   and running tests on every edit breaks the one-suite-per-round budget (ADR-023). `SKILL.md:286` puts
   `Bash(git commit:*)` in the permissions allow list, and `:273` uses headless `claude -p` in pre-commit;
   both cut across VULYK's commit path. `SKILL.md:84` recommends a Memory MCP, which VULYK's own memory
   already covers (ADR-019).
3. **Not every recommendation is a duplicate.** `git-guard.sh` blocks only git verbs that discard work
   (`.claude/hooks/git-guard.sh:2-8`), and `.claude/settings.json` has no `.env` deny rule. A "block
   `.env` edits" hook is therefore a real gap a recommender could fill, and so are stack MCP servers
   (database, docs lookup).
4. **The fit inside VULYK.** `/vulyk-bootstrap` already reads manifests and CI
   (`.claude/commands/vulyk-bootstrap.md:11`) but ends with "no feature work" (`:70`). A recommender
   belongs in its summary as an offer, not as a step. `skill-gardener` already drafts project skills from
   patterns repeated 3+ times (`.claude/skills/_meta/skill-gardener/SKILL.md`), so the recommender's
   "skills to create" table overlaps it.
5. **The cost of the form.** By default a skill's description is loaded into every session. With
   `disable-model-invocation: true` it is not ("Description not in context, full skill loads when invoked",
   code.claude.com/docs/en/skills, read 2026-11-11). This session confirms it: `recall-record-stop`
   carries the flag and is missing from the loaded skill list. Skills nested under `.claude/skills/_meta/`
   are not discovered at all: the docs do not list that layout, and `insight-harvester` and
   `skill-gardener` are absent from the session list.

## Options

1. **Recommended. Measure first, then build a VULYK-aware skill the owner calls on demand.** It is
   read-only and called by `/name`, with `disable-model-invocation: true`, so it adds zero always-loaded
   text. It reads the hive's live inventory (the Profile, `## Commands`, agents, hooks, settings,
   `.mcp.json`), subtracts what exists, applies the never-list, and prints candidate lines phrased for
   `/vulyk-plan`. `/vulyk-bootstrap` gets one offer line in its summary. Why first: it is the only option
   that is both free when unused and callable when the stack changes, and the measurement guards against
   shipping a filter that leaves nothing.
2. **Reference file under `_meta`, read only by bootstrap and evolve** (2 of 3 reviewers in round 2).
   It is also free, but the owner cannot call it on demand. Option 1 meets the same zero-cost requirement
   without that loss. The reviewers did not know the flag before the caller checked it.
3. **Docs line only (B).** Point to the official plugin. This is the fallback if the measurement fails.
   It is generic and carries the collisions from finding 2.
4. **Rejected.** Vendoring the 1477 lines (C): the catalogue goes stale, and the bodies break the
   ~150-line skill rule. A new `/vulyk-*` command (D): its description is always loaded and gives nothing
   that option 1 lacks. A re-run in `/vulyk-evolve` on a manifest change: 2 of 3 reviewers say no until
   data shows that hive stacks actually change. The measurement below collects that data.

## Never recommend in a hive (the never-list, 3/3)

- Reviewer or test-writer subagents (the council, `lead-review` and `worker-test` exist).
- PostToolUse format, lint, type-check or test hooks that run on every edit.
- A Memory MCP.
- `commit`, `feature-dev`, `pr-check` or `release-notes` skills.
- `Bash(git commit:*)` in the permissions allow list; headless `claude -p` in pre-commit.
- Hooks that write `memory/`, the constitution or other always-loaded text.
- Auto-install of anything.
- A personal tool on the default path.
- Duplicates of `git-guard` or the defect hooks.

## Not read or run

- The official skill has not been run on any hive yet.
- No hive's stack-change frequency was measured.
- Not confirmed: whether the official marketplace is present for every Claude Code user by default.
- The last 19 KB of the skills docs page were not read.

## Candidate stories (for a later `/vulyk-plan`, in the owner's words)

1. **Measurement (study, no code).** Run the official skill, asking for the full list, on 3-5 local
   hives of different stacks. Subtract by inventory and the never-list. The owner marks each surviving
   line accepted or not. Pass: at least 1 accepted per hive, reported as counts. Also run
   `git log --since=90.days` on each hive's manifests to measure stack change. Per-hive results stay
   private; only counts come here.
2. **Skill (Tier 1-2, only if 1 passes).** A new skill under `.claude/skills/<name>/SKILL.md`, at most
   150 lines, with `disable-model-invocation: true` and read-only tools. Its signal table is rewritten in
   VULYK's own words, with one credit line to the Apache-2.0 original. Its path joins the owned paths in
   `install.sh`. `.claude/skills/README.md` changes from "ships only the two `_meta` skills". One offer
   line goes into the `/vulyk-bootstrap` summary. Add a `tests/maintenance.test.sh` check that the flag
   stays, since the flag is what makes it free.
3. **Evolve re-run (only if 1 shows stacks change).** A manifest or CI change since the last run puts
   candidates into the evolve changeset.
4. **Fallback (if 1 fails).** One line in `docs/getting-started.md` pointing to `claude-code-setup`, with
   the never-list beside it.

## Measurement (2026-11-11, candidate story 1 run)

The official skill (full list, no web search) ran read-only on five local hives: a web app (TypeScript +
Python), a Python desktop app, a TypeScript monorepo, a small Python service, a media pipeline. Per-hive
lists stay private; counts only here.

| | Count |
|---|---|
| Raw recommendations | 121 |
| Already present in the hive or the account (MCP, plugins, `gh`, own skills) | 36 |
| Never-list conflicts | 39 |
| VULYK already does it | 9 |
| No signal in the code | 5 |
| Survivors shown to the owner | 32 |
| Accepted by the owner | 9 (per hive: 2, 3, 2, 0, 2) |

- **Pass rule (set before the run): at least 1 accepted per hive. Result: 4 of 5 hives, so by the rule
  as written it is not passed.** The small Python service got 0 of 5.
- What the owner accepted: performance and cost analyst subagents (4 of 5 offered), LSP plugins
  (2 of 2), two project scaffold skills (2 of 9), one research MCP (1 of 1).
- What the owner rejected: every hook that blocks edits to secrets, live data or lockfiles (0 of 9),
  every read-only database MCP (0 of 4), every migration and deploy skill.
- Stack change: dependency manifests changed on 2-8 distinct days in 90 days in every hive. A manifest
  edit is not always a new library.
- Gaps: the owner judged only the survivors, so it is unknown whether a subtracted item would have been
  accepted. The Queen did the subtraction (rules above, applied the same way to every hive); the
  reference is the owner's acceptance, not the Queen's labels.
