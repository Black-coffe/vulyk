---
id: full-round-for-a-narrow-fix
title: A repair of one narrow finding re-runs a full council round and every inherited suite
status: text
check:
fixtures: []
keys: [одну строку поправили, зачем эти циклы гонять, дурной подход]
paths: ["scripts/cycle.sh", ".claude/workflows/vulyk-cycle.js", ".claude/commands/vulyk-build.md"]
---

# A repair of one narrow finding re-runs a full council round and every inherited suite
A round ends with every ask green and one reviewer finding, a one-line fix. The loop cuts a repair story that inherits
the `## Verification` of every story before it (including suites that take minutes and do not touch the fixed file),
relaunches the hive, closes the story through those suites and then opens a whole new round: every seat dispatched
again, the full integration gate again. The owner pays a full round for what a re-run of the finding's own repro and a
look at the one-file diff would settle.

## Owner quotes
- 2026-10-16 · spec `vulyk-watcher` · round 3 (opus GREEN, review BLOCK with one finding in `scripts/lib.sh`) — «Зачем перезапускать цикл, если всего лишь одну строку поправил и всё? Если всё остальное нормально было, green, и не было никаких проблем, то мы одну строку поправили, перепроверили эту строку и всё. Зачем эти циклы гонять? Что за дурной подход?»

## Cause
`cycle.sh repair` cuts a repair story with the union of earlier stories' verification and `advance` always follows a
repair with `open-round`; nothing sizes the re-check to the finding. The narrow path exists only as the owner's
override (`human-check.sh ACCEPTED`), which the Queen did not offer before relaunching.

## Never
- Relaunch the hive and open a new full round when the last round's asks are all green and the findings are narrow
  (a line or two, one file): fix, re-run each finding's repro and the fixed file's own tests, show the diff, and offer
  the owner `human-check.sh ACCEPTED` - or a review-only re-check of the diff.
- Give a repair story verification it does not touch: keep the suites that cover its `## Files`, drop the rest.

## Allowed
- A full round when an ask was red, the fix spans modules, or the finding was a design fault.
