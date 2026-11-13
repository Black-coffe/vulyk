---
story: audit-fixes-1113-06
spec: audit-fixes-1113
status: todo
returned: NEEDS_CONTEXT
tier: 3
worker: worker-code
model: opus
wave: 2
blocked_by: [audit-fixes-1113-01, audit-fixes-1113-03, audit-fixes-1113-04]
red: required
red_reason: an edit equal to an older release is merged, not replaced
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

## Verification
`bash tests/telemetry.test.sh --part install-xp`
`bash tests/telemetry.test.sh --part install`
`bash tests/telemetry.test.sh --part wiring`
`bash scripts/defects-check.sh`
`bash tests/telemetry.test.sh --part edits`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each. End with one `CHANGELOG:` line
per ask (19, 17, 15, 2, 12). -->

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
