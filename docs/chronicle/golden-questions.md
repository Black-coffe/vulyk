# Golden questions - VULYK

<!-- written 2026-09-21, before any distillation; sources: git log, CHANGELOG.md, docs/adr, docs/grill, docs/specs (all in E:/Projects/vulyk) -->

## Q1 · Что было в релизе до 0.1, как брейнштормили, что устарело?
- answer: v0.1.0 | subtraction | additive
- refs: 1a55780; docs/grill/2026-07-27-vulyk-v0-2-0-opus-5.md
- source: `git tag | sort -V | head -1` and `git show 21760d6 --stat` show v0.1.0 is the repo's root commit (no earlier release exists); the grill (`docs/grill/2026-07-27-vulyk-v0-2-0-opus-5.md`) proposed a breaking «вычитание» release (cut a third of agents, a quarter of commands, half the hooks) - the English word "subtraction" itself occurs only in the `1a55780` commit message (found via `git log -S` + the literal word, "The original plan for this release was a breaking subtraction ..."); `git show 1a55780` (CHANGELOG's `[0.2.0]` section) opens "Additive release: nothing removed" - the grill's own subtraction plan was the thing superseded before it shipped.

## Q2 · What did v0.7.0 add to the planning stage, and what enforces it?
- answer: trace-check.sh | Traceability spine
- refs: 86ee548; scripts/trace-check.sh
- source: CHANGELOG.md's `[0.7.0]` section is titled "Traceability spine"; `git show 86ee548 --stat` confirms `scripts/trace-check.sh` and `docs/specs/<slug>/brief.md` (verbatim request, piped through `redact.sh`) were both added in this release; `scripts/trace-check.sh` exists on disk today.

## Q3 · What does ADR-001 decide about where the cycle's state lives, and why?
- answer: one truth on disk | Workflow runtime
- refs: docs/adr/001-cycle-state-contract.md
- source: `docs/adr/001-cycle-state-contract.md` decides "one truth on disk, two thin drivers" because the Workflow runtime "has no filesystem, no shell, no Node API and no clock", so it cannot hold a round counter or write a ledger; `cycle.sh` on disk is the one truth both drivers read.

## Q4 · What did the adversarial grill on the autonomous-cycle council brief conclude about stage 05?
- answer: no owner response by | мини-гриль
- refs: docs/grill/2026-09-12-autonomous-cycle-council-adversarial.md
- source: `docs/grill/2026-09-12-autonomous-cycle-council-adversarial.md` section 3.1 - it argues the brief's blind council does not replace the human stage 05 review, it triples `drone-acceptance` instead, and proposes giving `human-check.sh` a deadline: «Первое: `human-check.sh` получает дедлайн ... если владелец не записал ACCEPTED/REJECTED за N часов, `ship-check.sh` принимает `**Checked:** auto, no owner response by <ts>`», keeping only the existing "мини-гриль" (mini-grill, decision 9) as the honest compensation for removing the human gate.

## Q5 · Which agent was retired in favour of drone-coverage judging by ask?
- answer: drone-acceptance.md | autonomous-cycle-05
- refs: 7d243a9; docs/specs/autonomous-cycle/autonomous-cycle-05-council-agents.md
- source: `git show 7d243a9 --stat` shows `.claude/agents/drone-acceptance.md` deleted (82 lines removed) in the commit titled «drone-acceptance retired; drone-coverage judges by ask», story slug `autonomous-cycle-05` (`docs/specs/autonomous-cycle/autonomous-cycle-05-council-agents.md`), which also adds three new council seats.
