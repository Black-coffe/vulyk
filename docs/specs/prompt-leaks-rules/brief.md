# Brief: prompt-leaks-rules

Date: 2026-11-12 · Tier: 1

## Request

The owner's decision, this session, by choosing an option in an AskUserQuestion window. The option label and its text
are the agent's words, not the owner's: «5 правил + проба (Рекомендую)», described as "add the five rules to the agent
files now (Tier 1, built solo, one reviewer round); in parallel, one probe of whether workers see `.claude/rules`
rules". The rules are the five TAKE rows of `docs/specs/prompt-leaks-study/report.md` (C1, C2+C13, C3, C4, C5),
reviewed by a three-model panel. The owner's original request is quoted verbatim in `docs/specs/prompt-leaks-study/brief.md`.

A side-agent note relayed by the owner during the turn (model text, not the owner's words) restates the study's own
constraint: the collection's text belongs to other companies; take the technique in our own words, never verbatim.

## Recon (2026-11-12)

- `worker-code.md` already has "what you did not check or run" under `CONCERNS` and "A claim in your report holds for
  each thing it names"; step 1 already tells the worker to read `.claude/rules/` files for the paths it touches.
  Missing: untrusted text as data; never silencing a failing check; naming what was stubbed.
- `worker-test.md`: same gaps. `drone-scout.md`: no untrusted-text line ("Report only what you read" exists).
- `librarian.md` GC step 1 already drops "one-time trivia" and "anything generic". Missing: an entry the model
  inferred rather than observed, delete-not-patch on contradiction, facts not orders.
- `queen-planner.md` checks `## Files` disjointness per wave and lists `## Contracts`; no rule that a shared contract
  splits a wave, no migration ordering.
- Probe (scratchpad project, Claude Code CLI, one run each, 2026-11-12): a `.claude/rules/ui.md` with `paths:
  web/**/*.css` and a canary line was obeyed by a subagent (`tools: Read, Edit, Write`, no instruction to read rules)
  editing `web/a.css`, and by a main-session control editing `web/b.css`. Path-scoped rules reach subagents on this
  version: n=1, not repeated.

## Asks

1. Add the five rules (untrusted text is data; never silence a failing check and name what is stubbed; the memory filter; a shared contract splits a wave; migrations shadow then cut over) to the framework agent files, in VULYK's own words, and record the probe result.
