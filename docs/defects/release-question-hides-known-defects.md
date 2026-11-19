---
id: release-question-hides-known-defects
title: A release or plan question that leaves out what the builder already knows
status: text
check:
fixtures: []
keys: [почему ты про это молчишь, known defects left out]
paths: [".claude/commands/vulyk-ship.md", ".claude/commands/vulyk-plan.md", "cmd:human-check\\.sh"]
---

# A release or plan question that leaves out what the builder already knows
The owner is asked to ship, accept or approve, and the question omits something the builder met or decided on its
own: a defect hit in the code being shipped, an ask the council marked N/A, the open critical tails, or items a broad
request ("all known") quietly excluded. The owner's yes is given on a list he never saw in full.

## Cause
A GREEN council judges the asks, not what the session saw while driving; open debt sat in per-ship notes and was
never added up; excluding part of a broad request was taken as a routine call.

## Never
- Ask the release or acceptance question without listing every defect this session met in the code being shipped,
  with whether it ships, and the asks the seats marked N/A, with counts.
- Leave items out of a request that says "all" or "every known" without listing them in a question first, above all
  items the owner ordered or chose earlier.

## How-to
- Before planning new work and at every ship, show the open critical tails (security, data loss, broken gates,
  hives not upgraded) in one short block checked against disk and git, with what each blocks.

## Source
- 2026-11-18 · auto memory vulyk-feedback-ship-question-names-known-defects.md · retold, not a quote
- 2026-11-18 · auto memory vulyk-feedback-surface-open-critical-tails.md · retold, not a quote
- 2026-11-18 · auto memory vulyk-feedback-all-known-means-ask-before-excluding.md · retold, not a quote
