---
id: test-gate-one-long-limit
title: A test gate runs as one long job under one big time limit and keeps hitting it
status: text
check:
fixtures: []
keys: [упираться в лимиты, дробными лимитами, гонять по 20-30 мин]
paths: ["tests/full-suite.sh", "tests/*.test.sh", "scripts/cycle.sh", "scripts/lib.sh", ".claude/agents/lead-review.md", ".claude/agents/worker-*.md", "cmd:full-suite\\.sh", "cmd:VULYK_SUITE_TIMEOUT"]
---

# A test gate runs as one long job under one big time limit and keeps hitting it
The council's integration gate runs every suite at once under one wall-clock budget. As suites grow, the run reaches
the budget, the jobs still running are killed as TIMEOUT, and the round escalates on the timeout instead of on the
code. The builder's answer was to raise the one budget (590 s, then 900 s), and the run grew into it again: round 1
of `weekly-budget` stopped at 593 of 595 s, round 2 at 904 of 905 s, both ESCALATE for `suite-timeout`. Each round
costs the owner a 15-30 minute run, two reviewers and a human decision, and says nothing about the code it timed out on.

## Owner quotes
- 2026-11-02 · spec `weekly-budget` · round 2 ESCALATE (suite 904 s of 905 s) — «Давай запомни, построй запрет, разрешение, правила раз и навсегда. Любые тесты, которые имеют лимиты и могут теоретически впереться в эти лимиты, переоткрываем с супердробными частями. Лучше разбить на 10 шагов гейтов дробными лимитами по 300, по 100, по 200 секунд, нежели гонять по 20-30 мин. и постоянно упираться в лимиты. Ты уже достал это дерьмо делать. Давай наводи порядок в своей технической части, экспертности, запускай тройное кросс-валидирование агентами и сделайте раз и навсегда нормальные тесты без вот этих лимитов.»

## Cause
`tests/full-suite.sh` puts 51 jobs under one `VULYK_SUITE_TIMEOUT` (default 590 s); `cycle.sh` turns a `SUITE: TIMEOUT`
line into the `suite-timeout` escalation and its message advises raising the budget. Nothing caps a single part, so a
part that grows is noticed only when the whole run reaches the one limit, and the fix offered is the bigger limit.

## Never
- Run a test gate as one job, or one batch of jobs, under one long time limit that the run can reach: cut it into
  parts, each with its own small cap (100, 200 or 300 s, as the owner set).
- Answer a gate that reached its time limit by raising the limit (`VULYK_SUITE_TIMEOUT` 590 -> 900 -> 1800): split the
  part that ran long, in the same work.
- Let a part's timeout stand in for a verdict on the code: a timeout names the part that ran long and is fixed as such.

## Allowed
- 2026-11-02 · «Лучше разбить на 10 шагов гейтов дробными лимитами по 300, по 100, по 200 секунд, нежели гонять по 20-30 мин.»

## How-to
- A test gate is a list of parts, each with its own cap of at most 300 s and a measured run time well under that cap;
  a part that grows toward its cap is split before it reaches it, and the gate is green only when every part ran to
  its end.
