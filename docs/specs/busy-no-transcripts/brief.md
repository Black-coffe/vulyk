# A hive with no session transcripts is idle, not unknown (brief)

**Date:** 2026-11-12 · **Owner:** Andrei · **Escaped from:** post-052-tails

## Request (verbatim)

> с формулировкой своими словами, и сделать её лучше до 19.11, пока паузы 12 ульев не истекли.

## Context
- "её" is the task the owner picked a moment earlier, after a side agent's note that two hives with no Claude Code
  session ever (one of them a canary) are held on every ship: option «Поправить правило, новая задача (Рекомендую)»
  (2026-11-12; option text is the agent's, cross-checked with Sonnet, which agreed and asked for a separate reason
  line and tests for both cases). The option read: no transcript folder means no session ever ran there, so the hive
  is idle, with its own reason; but when no registered hive resolves to a transcript folder in the run, Claude Code's
  naming scheme has changed and every hive is busy; the DRIVER and clean-tree checks stay; tests for both cases.
- Recon: `scripts/hives-behind.sh` `busy()` prints `unknown no session transcripts ...` (exit 1) when no root holds
  `<root>/projects/<slug>/`; the 2026-11-12 rollout held two registered hives on exactly that line.

## Asks
1. `hives-behind.sh --busy <hive>`: a hive with no transcript folder under any root is `idle`, with a reason that says no session has run there, as long as at least one hive in the registry resolves to a transcript folder; when none does (or there is no registry), it stays `unknown` (exit 1). DRIVER, fresh-transcript and subfolder checks are unchanged. Tests cover both cases.
