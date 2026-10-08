# An upgrade merges the release into the hive's constitution, and never drops a project rule (plan)

**Tier:** 2 · **Spec slug:** `constitution-merge` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-005 (installer upgrade contract; D3 constitution blocks; the 2026-09-26 replace amendment this spec
removes), ADR-013 D7 (where replace came from), Law 6 (the owner's correction becomes a defect card with a check)
**Depends on:** v0.26.0 (48a1350)

## Goal
`/vulyk-update` stops offering to replace a hive's constitution. When the release's constitution changed, the Queen
studies the hive's own CLAUDE.md (or `CLAUDE.vulyk.md`), and a script drafts a three-way merge: the release the hive was
installed from is the base, the hive's file is "ours", the new release is "theirs". Framework edits land; every project
rule keeps its place. Where the hive and the release changed the same passage, the owner sees both in plain words and
the project's version is the default. A `CLAUDE.pre-*.md` backup left by an old replace is read, and the project rules
it holds that the current file lacks are offered back. Nothing is written without the owner's yes, and after the write
a deterministic check proves that no project line vanished unless the owner saw it listed as superseded. The project's
own lines are defined mechanically: non-blank lines that appear in no released VULYK constitution.

## Assumptions
- The merge needs the release history: `scripts/vulyk-update.sh` already keeps a clone with every `v*` tag
  (`~/.vulyk/src`). The base is `v<.claude/vulyk-version>:CLAUDE.md`; with no recorded version the draft is two-way and
  every difference surfaces for the Queen and the owner.
- Plain `install.sh --upgrade` (no model in the loop) still never writes the constitution; it now points at
  `/vulyk-update`'s merge instead of at `--constitution replace`. `--constitution replace` is removed; passing it is an
  error that names the merge.
- A sidecar hive merges its `CLAUDE.vulyk.md`; the foreign `CLAUDE.md` beside it is never opened (ADR-005 unchanged).
- The `.pre-<version>.md` backup is still written before a merge lands: cheap, and the check compares against it.
- Fixtures are synthetic. Hive constitutions are private and VULYK is public, so the original case (`E:/Projects/AI`,
  0.19) is reproduced in shape - a project section dropped by a replace - not copied.
- Released together with 0.26.0, on the owner's word; this spec ships as 0.27.0.

## Stories

**Wave 1**
- `constitution-merge-01` — `scripts/constitution-merge.sh` (`host-lines`, `draft`, `check`, `check-fixture`), its fast
  suite `tests/constitution.test.sh`, the Law 6 card `docs/defects/upgrade-drops-host-constitution.md` with two
  single-file fixtures, and a CI step (the `## Commands` row "Merge tests" was added at plan time, so `close-story`
  can run it)

**Wave 2**
- `constitution-merge-02` — `install.sh` / `scripts/vulyk-update.sh`: `--constitution replace` removed, the plain-upgrade
  hint names the merge; replace cases in `tests/telemetry.test.sh` become "refused" cases; ADR-005 amendment

**Wave 3**
- `constitution-merge-03` — `/vulyk-update` runs the merge (study, draft, conflicts to the owner with the project as the
  default, backup rules offered back, one plain summary, write on yes, check after); README, getting-started,
  command-reference, faq, token-economy and ADR-013 stop naming replace

## Contracts
- `constitution-merge.sh host-lines <file> [--releases <dir>]` -> the file's non-blank, whitespace-normalised lines that
  no released constitution contains (releases: every `v*` tag's `CLAUDE.md` in `${VULYK_SRC:-~/.vulyk/src}`, or the
  `*.md` files in `<dir>`).
- `draft <constitution> --to <new> [--from <old>] --out <file>` -> exit 0 clean, 1 with conflicts (`git merge-file`
  markers in `<file>`, count on stderr), 2 on usage; prints `restore: <line>` for each project line of a sibling
  `CLAUDE.pre-*.md` the constitution lacks.
- `check <before> <after> [--superseded <file>] [--releases <dir>]` -> exit 1 naming each project line of `<before>`
  missing from `<after>` and not in `<superseded>`; `check-fixture <file>` runs it on one fixture file whose
  `=== before ===`, `=== after ===` and `=== release <v> ===` sections hold the inputs (the defect card's `check:`;
  one file per fixture, because the gate passes a single path).

## Integration gate
`bash tests/constitution.test.sh` · `bash tests/telemetry.test.sh` · `bash scripts/defects-check.sh` ·
`git ls-files '*.sh' | xargs -n1 bash -n`

## Descoped

*(empty)*

## Plan deltas

**Approved:** Andrei, 2026-10-08
**Briefed:** <written by scripts/cycle.sh briefed>
**Branch:** <written by /vulyk-build before wave 1>
**Checked:** <written by scripts/human-check.sh after the owner has looked>
**Council:** <written by scripts/cycle.sh judge/escalate>
**Shipped:** <written by scripts/ship-check.sh --record>
