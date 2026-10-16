---
id: owner-words-by-builder
title: The owner's words or decision written by the builder
status: text
check:
fixtures: []
keys: [в любое время я не могу, waived, не называл]
paths: ["docs/defects/*.md", "docs/specs/*/plan.md", "scripts/human-check.sh", "scripts/acceptance-log.sh", ".claude/hooks/defect-intake.sh"]
---

# The owner's words or decision written by the builder
A line that only the owner may write - his decision, his waiver, his acceptance, a message in his name, a quote on a
defect card - is written by the agent doing the work. It may paraphrase him generously or invent him outright; either
way the record now says the owner decided what he did not, and the gate that waited for him opens on the builder's
word.

## Owner quotes

## Seen in hives
Not counted as owner quotes: they corrected hive work, not VULYK's (README, *Promoted from hives*). Verbatim, with
people, clients and hives masked.
- 2026-10-15 · a video hive · the owner's real choice, after a builder-written `waived` line had passed a script gate as his decision — «Ваша фраза + голоса из кейсов»
- 2026-10-07 · a consulting hive · a client reply drafted in the owner's name that widened his availability — «Завтра в любое время я не могу. Завтра с 12:00 созвон по фонду, по основной работе, поэтому либо завтра после двух часов.»

## Cause
The builder holds the pen for every file, including the lines that record the owner. A gate that accepts any text in
an owner field (`waived`, **Approved:**, ACCEPTED, a quote) is held only by the honesty of the one it holds. In VULYK
the same risk was caught in planning on 2026-10-15: a mod's button would have filed a model's note as an owner quote.

## Check
None, and code cannot add one generically: a file cannot show who typed a line. Where a hive can bind the line to a
source (the video hive's waiver check demands one), that check is per hive.

## Never
- Write a line that records the owner (a decision, a waiver, **Approved:**, `human-check.sh ACCEPTED`, a quote under
  `## Owner quotes`, a message in his name) from anything but his own words this session, verbatim.
- Widen what the owner said (time, scope, a promise) when writing in his name: leave a placeholder or ask.
- File model-written text (a relayed note, a filled prompt) as the owner's words.

## Allowed
- A draft in his name marked as a draft, with the open points left as `[ ]` for him.
