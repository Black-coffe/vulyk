---
id: framework-fix-skips-live-hives
title: A framework fix ships in VULYK while a live hive keeps the defect
status: text
check:
fixtures: []
keys: [само не дойдёт, не дойдёт до, так и останется]
paths: [".claude/commands/vulyk-ship.md", "CHANGELOG.md", "docs/specs/*/plan.md"]
---

# A framework fix ships in VULYK while a live hive keeps the defect
A defect found in a hive is fixed in VULYK's own files and released, and the work is called done. A hive installed
from an older release keeps running the broken code (or keeps the project line that triggers it) until someone
upgrades it, which for a hive mid-build or on a much older version may be weeks. The owner sees the bug still live.

## Owner quotes
- 2026-10-14 · spec `top-model-pin` · the gate-model resolver in a hive on 0.17 — «Исправление выбора модели в VULYK до <hive> само не дойдёт: модель для самых важных проверок там так и останется старой claude-opus-4-8.»

## Cause
The fix was sized to the framework (Law 6, "fix the root") and the survey of hives that showed which one was affected
was read as impact analysis, not as a to-do. Nothing in planning or shipping asks "which live hive carries this
defect today, and what removes it there now".

## Never
- Close a framework fix found in a hive without also removing the defect in every live hive the survey shows it in
  (the smallest local change: the one triggering line, or the release delta), or naming why a hive is left.
- Count on `/vulyk-update` to carry a fix to a hive that is on an old version or in the middle of a build.

## Allowed
- Leaving a hive alone when the owner says so, or when the defect cannot fire there; say which and why.
