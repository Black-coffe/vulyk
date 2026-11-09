---
story: mass-audit-fixes-11
spec: mass-audit-fixes
status: todo
returned:
tier: 4
worker: worker-code
wave: 3
blocked_by: [mass-audit-fixes-09]
red: required
red_reason: skip (bad path)
---

# install.sh trusts no manifest path, keeps the owner's choices, ships no VULYK map, and copies in one pass

## Goal
`install.sh` (private audit 2026-11-08, shell lens): the upgrade removal loop and `owned()` skip any manifest
line holding a `..` segment, a leading `/` or a backslash, logging `skip (bad path) <line>`, and the `kept
deleted` lookup applies the same rule (S1-shell); `top-model.sh --apply` is called only on a fresh install or
when no `model` pin exists, so an owner's deliberate session model survives `--upgrade` (`kept: model = <x>
(yours)`) (S4-shell); the mod step skips `plugin update` when the installed plugin version already equals the
release, and pins a ref only if the CLI offers one, else logs `mod: marketplace head, not pinned` (S6-shell);
`shippable()` excludes `memory/map/*` except its `README.md` (S7-shell); `copy_tree` collects the shippable
paths first and copies them in one pass, printing the `copy`/`skip` lines from one awk (O1); `shipped_blobs`
is built lazily, in the main shell, on the first `release_copy` (O5). Ask 11. Marked red: a path-validation
branch on a file-deleting loop.

## Requirements
> 11. Every finding of our private audit that the merged branch does not close (Scope E) is fixed, with a regression test wherever code can check it.

## Files
- install.sh
- tests/telemetry.test.sh

## Non-goals
- Do not touch hook wiring, `py_wire`, the `REL`/`by_hand` templates or the JSON writer (story 04, landed).
- Do not change what `OWNED` contains or how `retired_edited` decides; only reject bad paths before acting.
- Do not add `memory/map/*` to the upgrade's removal set: `memory` is not OWNED, a hive's own map stays.
- Do not edit `tests/telemetry.test.sh` outside the `install` and `install-xp` parts.
- Mind the CR-byte trap: edit `install.sh` with Edit, never through a Python text-mode rewrite; run the gate
  after every edit (bash 3.2, BSD userland).

## Map slice
`memory/map/scripts.md` → install.sh - the upgrade contract, Gotchas (BSD, CR bytes).

## Acceptance criteria
- [ ] `--part install-xp`: a hive manifest with `scripts/../VICTIM.md`, `/etc/x`, `a\b.sh` lines upgrades
  with three `skip (bad path)` lines and every named file still present (label contains `skip (bad path)`); a
  normal retired path is still removed.
- [ ] `--part install-xp`: a hive `settings.local.json` with `"model": "sonnet"` keeps it through `--upgrade`
  and the log says `kept`; a hive with no `model` gets the pin as today.
- [ ] `--part install`: a fresh install's `.claude/vulyk-manifest` has no `memory/map/` entry but
  `memory/map/README.md`; `ls memory/map` in the hive shows the README alone.
- [ ] `--part install`: the set of copied paths and the `copy`/`skip` log lines are identical before and after
  the one-pass change (fixture diff); an up-to-date `--upgrade` runs `git log --all` zero times (counting `git`
  shim).
- [ ] `--part install`: with a stub `claude` whose installed plugin version equals the release, no `plugin
  update` call is made; with an older version it is.
- [ ] `bash scripts/portability-check.sh install.sh` is clean.

## Verification
`bash tests/telemetry.test.sh --part install && bash tests/telemetry.test.sh --part install-xp`

## Implementation notes

## Findings
