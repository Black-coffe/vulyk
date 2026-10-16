---
id: work-handed-back-to-owner
title: Work an agent can do is handed back to the owner as a to-do list
status: text
check:
fixtures: []
keys: [сам можешь, бери и делай, постоянно просишь меня]
paths: [".claude/commands/vulyk-ship.md", ".claude/commands/vulyk-update.md", ".claude/commands/vulyk-build.md", "docs/specs/*/report.md"]
---

# Work an agent can do is handed back to the owner as a to-do list
A report ends with steps for the owner: commands to run, windows to open, a publish to press, an account action in a
browser where he is already logged in. The agent could take every one of them with the tools it has. The owner pays
his time for work he delegated, and each hand-copied step is a new chance of error.

## Owner quotes

## Seen in hives
Not counted as owner quotes: they corrected hive work, not VULYK's (README, *Promoted from hives*). Verbatim, with
people, clients and hives masked.
- 2026-09-12 · a video hive · a shoot sheet's off-camera preparation left to the owner — «если мы этого не пишем, тогда ты подключайся, самостоятельно всё исправь… зачем мне это всё дублировать, если ты сам можешь всё это сделать»
- 2026-09-28 · a site hive · a search-console reindex handed back as manual steps — «индексацию Google Search Console нужно делать через Google MCP Browser, зайдя в Google Search Console под моей учёткой»

## Cause
A procedure's "print, never run" default (in `/vulyk-ship`, protecting other owners of the public framework) and a
tool that looked unavailable at first try are read as "the owner does it". Nobody asked whether the agent could.

## Check
None, and code cannot add one generically: whether a step needs a person depends on the tools and logins at hand.

## Never
- End a report with steps the agent can run itself (git push, tag, release, a hive upgrade, a browser action under the
  owner's logged-in profile): run them, then report what was done.
- Give up on a tool after one failed attempt and hand the step back: try the other route first.

## Allowed
- Asking for a real decision (approving a plan, a design fork), or a step only a person can take, stated once with
  what was already done.
- The framework default for owners who have not overridden it: `/vulyk-ship` prints the publish step.
