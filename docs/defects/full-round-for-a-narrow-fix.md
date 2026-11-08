---
id: full-round-for-a-narrow-fix
title: A repair of one narrow finding re-runs a full council round and every inherited suite
status: block
check: bash -c 'f="$1"; [ -f "$f" ] || exit 0; ! grep -qx "narrow=1" "$f" || ! grep -qE "^seats=.*(haiku|sonnet|opus)|^second=risk|^STEP [0-9]" "$f"' _ <arg>
fixtures: [docs/defects/full-round-for-a-narrow-fix.original.fixture, docs/defects/full-round-for-a-narrow-fix.neighbour.fixture]
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
`cycle.sh repair` cut a repair story with the union of earlier stories' verification and `advance` always followed a
repair with `open-round`; nothing sized the re-check to the finding. The narrow path existed only as the owner's
override (`human-check.sh ACCEPTED`), which the Queen did not offer before relaunching.

Since ab-run-fixes (C5) a RED round with one item in one non-test file gets a `narrow: true` repair story (that file,
its exact tests, `docs/defects/*`, the verification of the stories that named the file), and the next round freezes
`seats=review` and `narrow=1` in its `ROUND`: no blind seat, no second reviewer, and `cycle.sh suite` writes
`SUITE: none - narrow repair round` without running a step. The `check:` reads a round's `ROUND` (and `suite.log`)
text: a narrow round that still names a blind seat, `second=risk`, or a run `STEP` fails it.

## Never
- Relaunch the hive and open a new full round when the last round's asks are all green and the findings are narrow
  (a line or two, one file): fix, re-run each finding's repro and the fixed file's own tests, show the diff, and offer
  the owner `human-check.sh ACCEPTED` - or a review-only re-check of the diff.
- Give a repair story verification it does not touch: keep the suites that cover its `## Files`, drop the rest.

## Allowed
- A full round when an ask was red, the fix spans modules, or the finding was a design fault.
