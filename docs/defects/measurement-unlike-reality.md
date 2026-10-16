---
id: measurement-unlike-reality
title: A test or measurement that does not represent the reality it is used to judge
status: text
check:
fixtures: []
keys: [не ту игру, не насколько они верны, только на смешанных, сравнивать нельзя]
paths: ["tests/**", "docs/specs/*/report.md", "docs/specs/*/plan.md", "scripts/token-report.py", "scripts/telemetry.sh"]
---

# A test or measurement that does not represent the reality it is used to judge
A number or a green run is offered as evidence about the real thing, but the setup measured something else: the A/B
arms differ in more than the compared layer, the exam's answers were written by the model it grades, the sample holds
only the case the feature was built for, the test environment runs with the live flags off, two figures are
compared under different conditions. The result is honest about its setup and wrong about the claim.

## Owner quotes

## Seen in hives
Not counted as owner quotes: they corrected hive work, not VULYK's (README, *Promoted from hives*). Verbatim, with
people, clients and hives masked.
- 2026-10-14 · a consulting hive · a blind exam of the knowledge base, reference answers by our own model — «Правильные ответы для слепого экзамена напишет наша же модель по SQL и выгрузке, без проверки <name>. Цифра покажет, насколько ответы совпадают с нашими моделями, а не насколько они верны. […]»
- 2026-10-11 · a game hive · preprod smoke before a production tag, ~60 live feature flags off on preprod — «На preprod были выключены около 60 фич, которые на проде включены. Поэтому прежние «зелёные» смоуки на preprod, после которых ставился прод-тег, проверяли не ту игру.»
- 2026-10-08 · a local-RAG hive · a default switched on from a blind A/B that sampled only mixed-language calls — «После рестарта <hive> сам определяет язык примерно каждые 30 секунд, даже если вы выбрали «uk». Проверяли это только на смешанных звонках. как будет далее?»
- 2026-10-15 · a video hive · a stats summary ranking a video under a thumbnail test against videos without one — «Ролик 6 сразу вышел с A/B/C-тестом значков, поэтому его CTR 2,45 % — это смесь трёх значков. Напрямую с первыми часами роликов 1–5 его сравнивать нельзя.»

## Cause
The setup was judged by the property that was easy to see (same questions, same age, a green smoke) and not by
whether it holds everything equal except what is being judged. The same consulting hive also ran an A/B whose arms
had different raw inputs; VULYK's rule that the family that builds never judges is this class at the council level.

## Check
None, and code cannot add one generically: equal arms, an independent reference and a representative sample are
properties of each experiment's design, not of any file it leaves behind.

## Never
- Report a number or a green run as evidence about the real thing before naming what differs between the test setup
  and reality (inputs, flags, sample, who wrote the reference), and why that difference does not decide the result.
- Let the model or the builder whose work is measured write the reference it is measured against.
- Switch a behaviour on for every input from a sample of only the inputs it was built to improve.

## Allowed
- A measurement with a known gap, when the gap is stated next to the number and the claim is narrowed to match.
