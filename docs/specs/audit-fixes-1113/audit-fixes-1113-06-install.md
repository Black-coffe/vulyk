---
story: audit-fixes-1113-06
spec: audit-fixes-1113
status: done
returned: DONE
tier: 3
worker: worker-code
model: opus
wave: 2
blocked_by: [audit-fixes-1113-01, audit-fixes-1113-03, audit-fixes-1113-04]
red: required
red_reason: an edit equal to an older release is merged, not replaced
red_verified_at: 2026-11-13T22:51:09Z c34805f8fb478af0b6b11c76983a249557ad0eef0af0ecc194a6044dc49bb474
---

# install.sh: the upgrade base is the installed tag, a fresh hive gets the memory skeleton, CI actions are pinned

## Goal
Five changes, all in or beside `install.sh`.
1. `--upgrade` follows plan.md `## Contracts` U1: a hive file is a release copy only when it equals the blob of
   that path in the tag of the hive's installed version; everything else is merged three-way with that blob as the
   base, and a conflict keeps the hive's file with `<file>.vulyk-new` beside it. No other tag and no branch is
   consulted. When that tag is missing from the source, no file counts as a release copy. Card
   `upgrade-overwrites-host-edits` gets a `check:` (`bash scripts/upgrade-base-check.sh <arg>`, `<arg>` an
   installer to judge), two fixtures and `status: block`.
2. A fresh install writes `memory/memory.md` from `templates/memory.md`; VULYK's own index does not ship. CI's
   `install-smoke` job checks that the installed index names no `memory/map/` and no `tests/` path.
3. `.github/workflows/ci.yml` pins every action whose owner is not `actions` by full commit SHA, with the tag in
   a trailing comment. Resolve each SHA from the action's repository (`git ls-remote <url> refs/tags/<tag>`),
   never from memory.
4. `memory/stats/skills.json` does not ship; `ensure_gitignore` adds it; `--upgrade` on a hive that tracks it
   prints one line with the command that untracks it and runs nothing in the hive's index.
5. The installer's matcher for `defects-inject.sh` is the one of contract M1, and `--upgrade` moves a hive entry
   that still has the old shipped matcher.

`model: opus`: long-horizon and judgment-heavy, five asks in one 1900-line installer, one of them data-loss
handling. Marked red: the branch that decides whether a hive's file is replaced.

## Requirements
> 19. `install.sh --upgrade` takes as a release copy only the blob in the tag of the hive's installed version and merges anything else three-way. Card `upgrade-overwrites-host-edits` gets a `check:` and two fixtures and becomes `block`.
> 17. A fresh install ships the memory skeleton from `templates/memory.md`, not VULYK's own memory index, and CI checks that the installed index names no `memory/map/` or `tests/` path.
> 15. CI pins third-party actions by full commit SHA.
> 2. `memory/stats/skills.json` is no longer tracked (`git rm --cached`, gitignored) and public history is not rewritten. It counts only VULYK's own skills and `vulyk-*` commands and lives locally. `install.sh` does not ship it, no ship step commits it, and the clean-tree exceptions made for it are gone.
> 12. Defect cards reach PowerShell commands as they reach Bash ones.

## Files
- install.sh
- scripts/upgrade-base-check.sh
- templates/memory.md
- .github/workflows/ci.yml
- .claude/commands/vulyk-update.md
- docs/defects/upgrade-overwrites-host-edits.md
- docs/defects/upgrade-overwrites-host-edits.original.fixture
- docs/defects/upgrade-overwrites-host-edits.neighbour.fixture
- docs/defects/INDEX.md
- tests/telemetry.test.sh
- tests/intake.test.sh
- scripts/defects-check.sh
- docs/defects/.scrub-revs
- tests/defects.test.sh

## Non-goals
- Do not touch the allow list or the wiring of any other hook: story 10 owns those parts of `install.sh` in wave 3.
- Do not overwrite, merge or delete a hive's existing `memory/memory.md` on `--upgrade`; `memory/` is not owned.
- Do not put back a file the hive deleted, and keep the frontmatter merge per key and the bad-path rule as they are.
- Do not add a Windows CI job or change the CRLF step: the later installer spec.
- Do not edit `tests/telemetry.test.sh` outside the `install`, `install-xp` and `wiring` parts.
- CR-byte trap: edit `install.sh` with Edit, never through a Python text-mode rewrite; awk values go through
  `ENVIRON`. Run `bash scripts/portability-check.sh install.sh scripts/upgrade-base-check.sh` after every edit.
- `vulyk-update.md` changes only where it reads the dry-run lines to the owner (a renamed or new line).
- Run `bash scripts/defects-index.sh` after the card edit; never edit `INDEX.md` by hand.

## Map slice
`memory/map/scripts-install.md` → install.sh - the upgrade contract, Gotchas; `memory/map/scripts.md` → Gotchas
(bash 3.2 / BSD); `docs/defects/README.md` (Statuses, Fixtures).

## Acceptance criteria
- [ ] `--part install-xp`: source tags `v0.1.0`, `v0.2.0`, `v0.3.0`; the hive is installed at `0.2.0` and one
  owned file holds the `v0.1.0` text. `--upgrade` to `0.3.0` does not replace it: a clean merge keeps the hive's
  change, a conflict keeps the file and writes `.vulyk-new`. The label contains `an edit equal to an older release
  is merged, not replaced`. A file equal to the `v0.2.0` blob is replaced as today.
- [ ] Neighbour: a hive file equal to a blob that exists only on an unmerged branch of the source is treated as
  an edit. With tag `v0.2.0` absent from the source, every differing file is kept with `.vulyk-new` and one NOTE
  line says why. An up-to-date `--upgrade` still runs no history walk (counting `git` shim).
- [ ] `bash scripts/upgrade-base-check.sh install.sh` exits 0 in a few seconds; it exits non-zero on both
  fixtures (the original form and the neighbour form), and `bash scripts/defects-check.sh` is green with the card
  shown as `block`. The card's `## Cause` says what the base is now; its "Still open" paragraph is gone.
- [ ] `--part install`: a fresh hive's `memory/memory.md` equals `templates/memory.md` and names no `memory/map/`
  and no `tests/` path; `ci.yml` asserts the same in `install-smoke` and no longer requires VULYK's index.
- [ ] `--part install`: a fresh hive has no `memory/stats/skills.json` copied from the source and its
  `.gitignore` holds the path; `--upgrade` (and `--check`) on a hive that tracks the file prints the untrack line.
- [ ] `--part wiring`: a fresh install and an upgraded hive carry the M1 matcher on the `defects-inject.sh`
  entry; a matcher the hive changed itself is left alone and named.
- [ ] Every `uses:` in `ci.yml` with an owner other than `actions` ends in a 40-hex SHA and a `# <tag>` comment.

- [ ] `--part edits`: the two assertions that held the old base (an untagged-commit copy replaced; a source with no
  `v*` tag replaced) now expect U1: the file kept with `.vulyk-new` and one NOTE line saying why (Queen's ruling,
  plan delta 2026-11-13).

- [ ] `PRE_M` in the shared header of `tests/telemetry.test.sh` is the M1 matcher (story 04 already ships it in
  `.claude/settings.json`), and `tests/intake.test.sh` expects M1 on an upgraded hive (Queen's ruling).

- [ ] `defects-check.sh` dates quote lines with `git blame --ignore-revs-file docs/defects/.scrub-revs` when that
  file exists. `.scrub-revs` lists, one full SHA per line with a `#` comment, the commits that only masked paths or
  names in card text: today `d7bc24899ef274ece4c39da6252d6921fd15553a` (story 04's scrub). A quote line changed only by a listed commit keeps its
  older date, so it is no new quote, no ESCAPE and no new debt; the same change by an unlisted commit is still an
  ESCAPE. `tests/defects.test.sh` holds both cases (original: the masked quote of 2026-11-13; neighbour: an
  unlisted edit). Queen's ruling, plan delta 2026-11-14.

## Verification
`bash tests/telemetry.test.sh --part install-xp`
`bash tests/telemetry.test.sh --part install`
`bash tests/telemetry.test.sh --part wiring`
`bash scripts/defects-check.sh`
`bash tests/telemetry.test.sh --part edits`
`bash tests/telemetry.test.sh --part install-xp2`
`bash tests/telemetry.test.sh --part library`
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each. End with one `CHANGELOG:` line
per ask (19, 17, 15, 2, 12). -->
- install.sh: `shipped_blobs` (every tag + `git log --all` walk) replaced by `prev_tag`/`release_copy` comparing to `v$PREV:<rel>` only; no tag -> one NOTE, nothing is a release copy.
- install.sh: `memory/memory.md` no longer ships; a fresh install (not `--upgrade`) seeds it from `templates/memory.md`; `skills.json` is runtime (not shipped), gitignored, and a tracked one gets one `rm --cached` line (read-only `ls-files`).
- install.sh: INJECT_MATCHER is M1; any of the three earlier shipped matchers is moved, a hive's own matcher is kept and named (`kept (yours)`); reading the groups goes through `vulyk_python`, grep fallback without it.
- scripts/upgrade-base-check.sh + two fixtures (any-blob rule; closest-tag/branch base): the card's `check:`, card set to `block`, INDEX regenerated by defects-index.sh.
- ci.yml: ludeeus/action-shellcheck pinned to 00cae500 (resolved by `git ls-remote`, tag 2.0.0); install-smoke compares the index with the template, `--check` no longer requires memory/memory.md.
- tests: PRE_M and intake's two matchers set to M1; part `edits` two assertions moved to U1 (Queen's ruling).
- scripts/defects-check.sh: `blame()` passes `--ignore-revs-file <library>/.scrub-revs` when the file exists; header and `--help` range updated. `docs/defects/.scrub-revs` lists d7bc248; the story 04 ESCAPE is gone, audit GREEN.
- tests/defects.test.sh: new "scrub" block, unlisted masking commit -> ESCAPE (neighbour), the same commit listed -> green (original).
- CHANGELOG: (19) `--upgrade` treats a file as a release copy only when it equals the installed tag's blob; anything else, older-release text included, is merged.
- CHANGELOG: (17) a fresh hive gets the memory skeleton from templates/memory.md, not VULYK's own index.
- CHANGELOG: (15) CI pins third-party actions by commit SHA.
- CHANGELOG: (2) memory/stats/skills.json no longer ships and is gitignored; an upgrade prints the untrack command for a hive that tracks it.
- CHANGELOG: (12) defects-inject.sh's matcher includes PowerShell; an upgrade moves the old shipped matcher.

## Findings
- 2026-11-13, worker, before any edit: ask 19 (U1) turns two assertions of `tests/telemetry.test.sh` part `edits`
  (case 21) red. Non-goals allow edits only in parts `install`, `install-xp`, `wiring`.
  1. Line ~3093, `a copy from an untagged commit is a release copy (update)`: the hive holds a commit's copy (the
     `hotfix` commit, untagged). U1 consults no other tag and no branch, so it becomes an edit. Its line 3 conflicts
     with v9.0.1's line 3, so the result is `kept + new`, not `update`.
  2. Line ~3131-3138, `a source with no v* tag says so and replaces as before`: U1 says that with tag `v$PREV`
     missing, no file is a release copy, so the ZIP source keeps `lead-review.md` with `.vulyk-new` and does not
     replace it. The NOTE text changes too.
  Question: may this story rewrite those two assertions in part `edits` to the U1 behaviour (keep + `.vulyk-new`,
  one NOTE line), and add `edits` to `## Verification`? Otherwise `close-story` passes, because `edits` is not in
  `## Verification`, but the integration gate (`tests/full-suite.sh`) goes red. No implementation, test or red
  receipt has been made yet.
- 2026-11-13, worker, relaunch after the wave 2 rulings, before any edit: ask 12 (M1 in the installer) needs two
  test paths this story may not touch.
  1. `tests/telemetry.test.sh:150`, `PRE_M` (shared header, outside the parts `install`, `install-xp`, `wiring`,
     `edits`): it still holds the matcher without `PowerShell`. Parts `wiring` (space_run, the 17-entry signature),
     `install-xp2` (line ~1715-1720), `library` (line ~2278-2286, ~2562) and `wrapper` (line ~2620) select on it.
     Measured on HEAD c3c5471f, before this story: `wiring` 2 failed, `install-xp2` 1 failed, `library` 2 failed,
     because story 04's `.claude/settings.json` (copied whole into a fresh hive) already carries M1. `--part wiring`
     is in this story's `## Verification`, so it cannot close green without changing `PRE_M` (or shadowing it
     inside `wiring` only, which leaves `install-xp2` and `library` red at the integration gate).
  2. `tests/intake.test.sh` lines ~372-374 and ~387-389 expect an upgraded hive's inject matcher to be the 0.41
     one (`...|Read|Bash|WebFetch|...`, no `PowerShell`). Green today (119/0); with M1 in `install.sh`
     (`INJECT_MATCHER`, `SHIPPED_HOOKS`) both turn red. No open story names this file.
  Question: may this story (a) set `PRE_M` at `tests/telemetry.test.sh:150` to M1, which also turns `install-xp2`
  and `library` green, and (b) take `tests/intake.test.sh` into `## Files` to change those two expected matchers to
  M1? No implementation, test or red receipt has been made yet.

- 2026-11-14, worker, implementation done: close-story ran `--part install-xp`, `install`, `wiring` green, then
  `bash scripts/defects-check.sh` is RED with one escape not from this story:
  `ESCAPE  command-injection-follows-cwd: quote d7bc248 2026-11-13 23:18 came after the block check, no fixture or
  check change since - add the new form as a fixture and make the check fail on it`. Commit d7bc248 is story 04's
  (a quote added to `docs/defects/command-injection-follows-cwd.md`). Fixing it needs a fixture/check for that card,
  outside this story's `## Files`. This story's own card (`upgrade-overwrites-host-edits`) passes: both fixtures fail
  the check, `install.sh` passes it. Question: who adds the fixture for story 04's quote (or rules the escape out),
  so this story's `defects-check.sh` line can go green?

- 2026-11-14, worker, after the `.scrub-revs` delta: implemented (`defects-check.sh` honours `docs/defects/.scrub-revs`,
  listing d7bc248; audit GREEN: 9 blocking checks; `tests/defects.test.sh` all passed with the two new scrub cases).
  `close-story` exit 4: `test changed after red receipt: re-run stamp-red`. The receipt (2026-11-13T22:13:57Z) sealed
  `tests/intake.test.sh` and `tests/telemetry.test.sh`; the delta added `tests/defects.test.sh` to `## Files` and
  `## Verification`, so it is now sealed too, and I edited it (new block "a masking commit listed in .scrub-revs keeps
  the quote's date"). The implementation is already green, so per protocol I do not re-stamp. Question: the Queen's
  re-stamp (revert impl, stamp-red, re-apply), or a ruling that the receipt may be re-stamped over the green impl?

## Red receipt
- command: bash tests/telemetry.test.sh --part install-xp
- exit: 1
- tests: c34805f8fb478af0b6b11c76983a249557ad0eef0af0ecc194a6044dc49bb474 (scripts/defects-check.sh, tests/defects.test.sh, tests/intake.test.sh, tests/telemetry.test.sh)
- impl: 8ca60e24a853d13457c04d22e8a3d5319f0a0c0b559d4f527bc1cfe41c30c667
- stamped: 2026-11-13T22:51:09Z

```
::error::an edit equal to an older release is merged, not replaced:
  update         .claude/agents/u1-clash.md
  ok    a file equal to the installed tag's blob is replaced (update)
::error::a blob found only on an unmerged branch of the source is an edit, merged:
  update         .claude/agents/u1-branch.md
::error::an upgrade with edits walks no history: git log --all / rev-list zero times (counting git shim) - expected [0 0], got [1 0]
::error::tag v0.2.0 absent: each of the four differing files is kept with .vulyk-new - expected [4], got [0]
::error::... nothing is replaced or merged - expected [0], got [4]
::error::... the release copy too stays byte for byte - expected [tail one], got [tail three]
::error::... and one NOTE line says why - expected [1], got [0]
telemetry.test.sh: 87 checks, 8 failed
```
