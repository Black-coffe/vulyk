---
story: mass-audit-fixes-11
spec: mass-audit-fixes
status: done
returned: DONE
tier: 4
worker: worker-code
wave: 3
blocked_by: [mass-audit-fixes-09]
red: required
red_reason: skip (bad path)
red_verified_at: 2026-11-09T14:23:49Z e6a8f511a3d1cd697b9594367322efca2b6c981aea16b629d74b8475571ee08c
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
- install.sh: `bad_path` (leading `/`, a backslash, a `..` segment) is one rule; `owned()` refuses it, the removal loop logs `skip (bad path) <line>` before any lookup, and the `kept deleted` lookup reads `$OLD_LISTED`, the old manifest read once with CR and bad paths dropped.
- install.sh: `copy_tree` collects `find` output into a file, decides each path in the main shell (fd 3, so a git call cannot eat the list), copies the new files in one `tar -c | tar -xp` pass (mode and mtime kept as cp -p did) and prints copy/skip/would-skip lines from one awk, after any update/merge line of that tree.
- install.sh: `shipped_blobs` is called by the first `release_copy`, no longer eagerly; the no-history NOTE now prints only when a changed owned file is met.
- install.sh: on `--upgrade` a `"model"` already in settings.local.json is printed `kept: model = <x> (yours)` and `top-model.sh --apply` is skipped (an opus pin is printed too).
- install.sh: `install_mod` reads the user-scope `Version:` under the id in `claude plugin list`; equal to VERSION -> `current ...`, no marketplace/plugin update. `claude plugin update --help` (local CLI) offers no ref option, so no pin branch was written: each update logs `mod: marketplace head, not pinned`.
- install.sh: `shippable` drops `memory/map/*` but its README (`.stale` keeps its runtime code by a rule placed first).
- tests/telemetry.test.sh: install part gains the map, copy/skip fixture diffs, git-shim count, mod version cases and a `scripts/../CLAUDE.md` bad line (the red receipt showed the old loop deleting the constitution); install-xp gains the three bad lines + retired path, the sonnet pin, and the no-pin pin on the A9 upgrade.
- Surprise: the verification line is one `&&` chain, so the red reason had to appear in the install part too.

## Findings

## Red receipt
- command: bash tests/telemetry.test.sh --part install && bash tests/telemetry.test.sh --part install-xp
- exit: 1
- tests: e6a8f511a3d1cd697b9594367322efca2b6c981aea16b629d74b8475571ee08c (tests/telemetry.test.sh)
- impl: c5c5937e9386d7e36ab52feda3892dd4a08b20eea21847a34da48275f660505e
- stamped: 2026-11-09T14:23:49Z

```
::error::a dot-dot manifest line on a plain --upgrade: skip (bad path), the constitution stays - expected 'skip (bad path) scripts/../CLAUDE.md' in:
          Every story '## Verification' line also runs under a 300 s cap (VULYK_VERIFY_TIMEOUT above 300 acts as 300):
          cut any row over ~210 s into --part rows before this hive takes this release. Your constitution is not edited.
          profile row    CLAUDE.md: Telemetry = off
          stamp          .claude/vulyk-version = 0.49.0
          write          .claude/vulyk-manifest (102 paths)
        
        Done. Upgraded framework files only; your CLAUDE.md, memory/, specs, ADRs and wiki were not touched.
        If the constitution changed this release, the note above says by how much and how to migrate.
  skip  bare-install terminal case: no util-linux `script` on PATH to drive a pseudo-terminal
telemetry.test.sh: 42 checks, 8 failed
```
