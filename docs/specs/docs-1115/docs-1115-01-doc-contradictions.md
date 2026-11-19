---
story: docs-1115-01
spec: docs-1115
status: done
returned: DONE
tier: 1
worker: worker-code
wave: 1
blocked_by: []
---

# Docs match the code: the inventory's doc items and the handed-on doc lines

## Goal
Correct each doc sentence the brief's asks name so it says what the code does at HEAD; apply the doc lines
`tails-1115` handed on. Read each item in `~/.vulyk/audits/known-defects-2026-11-15/tails.md` and the code it names
before writing. Docs only.

## Requirements
> 1. Every doc sentence the inventory items T18, T19, T21, T60, T66, T79, T81, T82, T83, T84, T86, T88 (A10), T89, T91, T99 (A11, README only) and the doc halves of T65, T80, T90 name says what the code does at HEAD; nothing else in those pages changes.
> 2. The doc lines `tails-1115` handed on are applied: the `memory/map/` lines of its stories 01, 02, 05 (listed under story 11's `## Findings`), and `.claude/commands/vulyk-bootstrap.md:23` (one blind seat, swapped for `haiku` when *Client path* is filled); `docs/hooks-reference.md` describes the 0.54 guard hooks in the general words of their headers; `docs/token-economy.md:144` matches the code.
> 3. No code, test or hook changes; the docs tests that pin sentences stay green.

## Files
- README.md
- CONTRIBUTING.md
- docs/architecture.md
- docs/command-reference.md
- docs/cycle.md
- docs/faq.md
- docs/getting-started.md
- docs/hooks-reference.md
- docs/model-cascade.md
- docs/pipeline.md
- docs/token-economy.md
- docs/wiki/rules-tree.md
- docs/defects/README.md
- docs/adr/013-light-vulyk.md
- docs/specs/self-learning/plan.md
- .claude/commands/vulyk-bootstrap.md
- memory/map/cycle.md
- memory/map/scripts-checks.md
- memory/map/scripts-hives.md
- memory/map/scripts-install.md
- memory/map/scripts.md
- memory/memory.md

## Non-goals
- No code, tests, hooks, cards' `check:` lines or `CLAUDE.md`.
- No concrete gate-bypass spelling or secret shape in any public doc: the guard hooks are described in their headers'
  general words.
- `memory/` only through `drone-docs` (`model: opus`).

## Acceptance criteria
- [ ] Each named item is fixed or closed as already fixed, with one implementation-notes line per item.
- [ ] `bash tests/maintenance.test.sh --part upkeep` and `bash scripts/defects-check.sh` pass.

## Verification
`bash tests/maintenance.test.sh --part upkeep`
`bash scripts/defects-check.sh`

## Implementation notes
- T18: hooks-reference line 3 names the three PreToolUse guards as the fail-closed exception; the defect-intake row
  carries the quote rule from its header.
- T19: hooks-reference "From level 1": `cache_note` rides every level's banner and prompt (handoff.py `banner`, `mode_prompt`).
- T21: blank line before `**Shipped:**` in docs/specs/self-learning/plan.md.
- T60: `ysk-offer.sh` row in hooks-reference (counter in the Claude config folder) and in the README hook table.
- T65 (doc half): architecture, faq, README say Claude Code allows nested subagents (`Agent`, `Task` before 2.1.63)
  and VULYK does not use it (prompt-check refuses the tool); the `lead-build` question reworded (tails-1115 cc-facts F4).
- T66: the `~/.claude/.env` Agent Teams advice dropped from README and getting-started; faq, README and architecture
  say: not needed, off by default, `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in the shell or settings `env`, not during
  a build (cc-facts F5).
- T79: architecture, cycle, token-economy, README say 300 s per line inside a 540 s call that pauses and resumes;
  pipeline.md no longer carries the number; ADR-013 gets an "Amended by gate-split (0.45.0)" bullet.
- T80: already fixed at HEAD by tails-1115 (pipeline.md, council-opus.md); pipeline.md loses its private "(T80)" tag.
- T81: command-reference: solo review dispatch carries the suite gate and the profile's review model; the hive call
  names `launched_at` and the profile models; the GREEN step asks «Выпускаем?»; `bash scripts/py.sh` twice.
  `--quick` and `/vulyk-models` already matched the commands.
- T82: token-economy: warnings at 70/80/90 % of the real window.
- T83: `drone-horizon` joins the omitClaudeMd list; the effort/cache sentences in model-cascade say Fable 5.1 and
  later, Opus 5.5, Sonnet 5.5, Haiku 5.5, API key or subscription, not Bedrock / Agent Platform / apps gateway
  (code.claude.com/docs/en/prompt-caching "Changing effort level", read 2026-11-18; anthropics/claude-code
  CHANGELOG "changing effort mid-session no longer invalidates the prompt cache" on Fable 5.1).
- T84: architecture: scouts sonnet, workers sonnet (the profile may name opus), grill in batches of up to 4;
  getting-started grill line the same.
- T86: README hook table gains ysk-offer, defect-intake, defects-inject and the three guards, the counter's
  UserPromptExpansion; telemetry codes list all 12 of `telemetry.sh enum`; drone-acceptance named retired; the
  roadmap points at CHANGELOG for v0.22.0 onward. No table test (story names no test file).
- T88 (A10): defects README: an Allowed line is one allowed form, may carry a date, is not a quote; quotes live under
  `## Owner quotes`; only dated Allowed lines count as repeats (defects-check.sh:302-306).
- T89: rules-tree wiki: every card but a revoked one is injected, a block card included.
- T90 (doc half): CONTRIBUTING uses `bash scripts/py.sh`; vulyk-evolve's `sort -rV` is already gone at HEAD.
- T91: README memory plane: `memory/memory.md` read at task start, a hint to verify (not "always loaded"); its header
  says the same and the file is cut from 79 to 56 lines under its cap of 60 (drone-docs, model opus). Not done:
  `templates/memory.md:3` still says "always loaded" (outside `## Files`).
- T99 (A11): README 1.0 bar says 0 of 10, as `release-check.sh` counts, and why it cannot rise; code untouched.
- Handed on: memory/map cycle, scripts-install, scripts-checks, scripts-hives, scripts lines (drone-docs, opus);
  vulyk-bootstrap.md:23 "swaps the blind seat opus for haiku"; hooks-reference guard rows in their headers' general
  words (run state, history moves under a DRIVER, forced tag/push, court per round, git allowlist); token-economy
  narrow-round paragraph matches the 0.54 repair rule.

## Findings
