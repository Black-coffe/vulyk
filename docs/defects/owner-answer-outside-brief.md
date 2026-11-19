---
id: owner-answer-outside-brief
title: An owner's answer that changes an ask is kept out of the brief
status: text
check:
fixtures: []
keys: [не попало в бриф, answer missing from the brief]
paths: ["docs/specs/*/brief.md", "cmd:cycle\\.sh +(reopen|revise)"]
---

# An owner's answer that changes an ask is kept out of the brief
The owner answers a question at the grill, at approval or mid-build in a way that narrows or widens an ask, and the
answer reaches a story or the plan but not `brief.md`. The blind council seat reads only the brief, so it judges a
different requirement than the one built and goes red on work that matches the owner's answer.

## Cause
The answer was applied where the builder looked (the story, the plan) and the brief was treated as written once.
Ordering makes it worse: narrowing the asks before reopening an escalated round turns the reopen into a full round.

## Never
- Apply an owner's answer that narrows or widens an ask to the stories or the plan without writing it into
  `brief.md` `## Answers` verbatim and editing the ask to match (then trace-check, and `revise` the stories quoting it).
- Drop an extra point a second-opinion model raised without relaying it to the owner.

## How-to
- After an ESCALATE, run `cycle.sh reopen` first and let it cut the repair, then narrow the asks in `brief.md` and
  `revise` the stories: a brief edit before the reopen stales the round and buys a full round instead of a repair.

## Source
- 2026-11-18 · auto memory vulyk-feedback-narrowing-answer-into-brief.md · retold, not a quote
- 2026-11-18 · auto memory vulyk-reopen-before-narrowing-asks.md · retold, not a quote
