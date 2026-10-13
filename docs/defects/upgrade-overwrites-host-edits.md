---
id: upgrade-overwrites-host-edits
title: An upgrade overwrites a hive's own edits and deletions in framework files
status: text
check:
fixtures: []
keys: [местные правки, заменяет местные, maxTurns]
paths: ["install.sh", "scripts/vulyk-update.sh", ".claude/commands/vulyk-update.md"]
---

# An upgrade overwrites a hive's own edits and deletions in framework files
`install.sh --upgrade` replaces every framework-owned file that differs from the new release, without asking whether
the difference is an old release copy or the hive's own decision: a tuned `maxTurns`, an edited template, a patched
hook, an agent the project removed (copied back). The hive learns about it only when its behaviour changes.

## Owner quotes
- 2026-10-13 · `/vulyk-update` · a hive's tuned agent files — «Полное обновление VULYK (`/vulyk-update`) без предупреждения заменяет местные правки в файлах фреймворка улья, например `maxTurns: 140` в Recall. Так нельзя»

## Cause
`copy_tree` (install.sh :117) replaces on `owned && ! cmp`; nothing compares the hive's copy with the release it was
installed from, and a path missing from the hive is copied in as new. Fix and check: spec `upgrade-keeps-host-edits`.

## Never
- Replace a framework file in a hive without first telling a release copy from a project edit.
- Put back a framework file the hive deleted.
- Run a plain upgrade on a hive "to be done with it" before the installer carries edits: audit the hive's edits and
  merge them by hand, deletions included.

## Allowed
- Replacing a file that equals what some release shipped.
