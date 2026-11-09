---
id: framework-defect-deferred-mid-build
title: A framework defect met during a build is put off until after the build
status: text
check:
fixtures: []
keys: [не жди конца сборки, почини сразу, сразу почини]
paths: [".claude/commands/vulyk-build.md", "docs/specs/*/plan.md", "docs/specs/*/journal.md"]
---

# A framework defect met during a build is put off until after the build
A VULYK defect stops or degrades the running build (the driver, a clerk, a gate). The Queen works around it for
this run and promises a fix "after the release". Meanwhile the defect keeps firing in this build, and in every
hive that hits it before the next release.

## Owner quotes
- 2026-11-09 · spec `mass-audit-fixes` · the Workflow driver stopped twice on a clerk-garbled `--claim` line; the Queen switched to the in-session loop and offered a driver fix after the build — «Почини драйвер сразу, не жди конца сборки»

## Cause
Law 3 (no out-of-scope edits) and Law 5 (the Queen edits no story file at Tier 3-4) were read as "not in this
build". Both allow a new ask and a new story in the running spec, built by a worker in a wave whose files do not
collide.

## Check
None: whether a defect blocks the build is a judgement about the run, not a pattern in a file.

## Never
- Defer a framework defect that has already stopped or degraded the running build to "after the release" without
  asking the owner: add it as an ask and a story to the running spec, in the earliest wave whose files do not
  collide, and build it now.

## Allowed
- Deferring a defect that does not touch the running build, or that the owner chose to defer; say which.
