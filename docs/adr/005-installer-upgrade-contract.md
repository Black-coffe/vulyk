# ADR-005: The installer's upgrade contract - ship set, manifest, constitution blocks

- Status: proposed
- Date: 2026-09-13
- Spec: docs/specs/v0-12-0-remainders (asks 5, 6, 7)

## Context

Three installer defects were reproduced on 2026-09-13 against a real hive (`brief.md`
`### The three installer tails`), all in `install.sh` at `3e200bb`:

1. **ADR leak.** The tree loop at `install.sh:347` copies `docs/adr` and `docs/wiki`, and
   `shippable()` (`:49-65`) has no deny arm for either, so VULYK's own ADR-001..004 land in
   every hive that lacks them. The header at `:10` and the closing line at `:452` promise the
   opposite.
2. **Nothing is ever removed.** `copy_tree` (`:67-87`) adds or replaces; no path in the file
   deletes a target file. A framework file retired in a release (`.claude/agents/drone-acceptance.md`,
   removed in `7d243a9`) survives every upgrade, and `--check` cannot show it.
3. **The constitution is never carried forward.** The "already a VULYK constitution" branch
   (`:362-386`) prints a `diff` hint and touches nothing. Nine of eleven installed hives have no
   `## Profile` section, so the `Client path` and `## Commands` rows the v0.12.0 council is
   contractually given (ADR-001 D5, C5) do not exist there, and the installer reports success.

The owner fixed the shape of all three in the grill (`brief.md` `## Answers`): deny `docs/adr/*`
and `docs/wiki/*`; a manifest `.claude/vulyk-manifest` beside the version stamp with removal on
`--upgrade` and a report-only first pass; insertion of missing `VULYK:PROFILE` /
`VULYK:COMMANDS` placeholder blocks at the source's position, filled blocks untouched. This ADR
makes those shapes precise, records the rejected alternatives, and names the invariants.

Two facts about the existing code constrain the details. `OWNED` (`:34-35`) is already the
installer's only definition of "the framework may replace this"; and `reset_marked_block`
(`:103-125`) already establishes the marker discipline: `:START`/`:END` survive every pass, and
a block whose markers are gone is warned about, never rewritten.

## Options

### A. What ships from `docs/`

1. **Deny arm in `shippable()`: `docs/adr/*` and `docs/wiki/*` return 1, `*/README.md` under
   them returns 0** - one case arm, same pattern as the `memory/learnings/*` arm at `:55`; the
   directories are still created at `:358`. *Chosen.*
2. **Drop `docs/adr` and `docs/wiki` from the tree loop at `:347`.** Rejected: it also drops
   any skeleton README a future release puts there, and it hides the decision in a loop list
   rather than in the function whose whole job is the ship/deny rule.

### B. How retired framework files leave a hive

1. **A manifest beside the stamp.** `install.sh` writes `.claude/vulyk-manifest`, the list of
   every path the release ships; on `--upgrade`, paths in the old manifest that the new release
   does not ship are removed. *Chosen (the grill's answer).*
2. **A `RETIRED` list shipped with each release** (a file naming paths retired since version X).
   Rejected in the grill: the maintainer must remember to write an entry per retirement, the
   list must be cumulative to serve a hive that skipped releases, and a forgotten entry is
   invisible - nothing on the hive side can detect the omission. The manifest is derived from the
   tree, so it cannot be forgotten.
3. **Sync `OWNED` trees without a manifest** (delete anything under `OWNED` that the release does
   not ship). Rejected in the grill: `.claude/agents` and `.claude/commands` are `OWNED` and are
   exactly where owners add their own agents and commands; a sync deletes them. A manifest lists
   only what the installer itself wrote, so an owner's file is never a removal candidate.

### C. How a constitution gains the blocks the council needs

1. **Insert the missing marker block as a placeholder, at the source's position; never touch a
   block whose markers exist.** *Chosen (the grill's answer).*
2. **Framework-owned `CLAUDE.md`** (overwrite on `--upgrade`, owner content lives only inside
   the marked blocks). Rejected in the grill: it inverts the ownership model at `:362-364`
   ("a bootstrapped constitution is the user's tailored law") after owners have already edited
   outside the blocks; the undo is a hand merge on every hive.
3. **Status quo: the `diff` hint.** Rejected: measured, it leaves nine of eleven hives unable to
   run the council as specified.

### D. Where "the source's position" is (the open detail under C1)

1. **Anchor on the source heading that precedes the block, and insert before the first later
   source heading that exists in the target; append at EOF if none does.** *Chosen.* Undo is
   deleting one contiguous region from the inserted `## <heading>` line to the `:END` marker.
2. **Anchor on the preceding `## <heading>` in the target.** Rejected: in the common case (nine
   hives) the heading is absent too, so the anchor does not exist.
3. **Append at EOF always.** Cheapest to write, but the constitution's Profile then sits after
   `## Evolution`, and a later `--upgrade` cannot move it without becoming a rewrite. Rejected
   because option 1 degrades to it anyway when no anchor is found.

## Decision

Options A1, B1, C1, D1. The deciding factor throughout is that every new action of the installer
is derived from a list the installer itself wrote or from a marker it itself placed, so nothing
an owner authored is ever a candidate for deletion or rewrite.

### D1. Ship set

`shippable()` gains one arm before the fallthrough:

```
docs/adr/*|docs/wiki/*)  case "$f" in */README.md) return 0 ;; esac; return 1 ;;
```

`.claude/vulyk-manifest` joins the `.claude/vulyk-version` arm (`:58`, return 2): the
maintainer's own manifest never ships, for the same reason the stamp does not. The wording at
`:10` and `:452` is then true as written and is left as is.

### D2. Manifest

| Property | Decision |
|---|---|
| Path | `.claude/vulyk-manifest`, written in the same guarded block as the stamp (`:418-425`), on every non-`--check` run (install and upgrade). `--check` prints `would write    .claude/vulyk-manifest (<n> paths)`. |
| Format | One path per line, LF, `LC_ALL=C sort`, relative to the hive root, forward slashes, no leading `./`, no blank lines, no comments. A hive commits it, as it commits the stamp; it is not added to `ensure_gitignore`. |
| Content | Exactly the paths `copy_tree` found shippable (`shippable` returned 0) in this run, whether it copied, updated, or skipped them as existing. Paths that returned 1 or 2 are not listed. The manifest and the stamp are not listed: they are installer state, not shipped content. `CLAUDE.md`, `CLAUDE.vulyk.md` and `AGENTS.md` are not listed: they are not written by `copy_tree` and are never removal candidates. |
| Removal rule | After the copy loop and before writing the new manifest: for each path in the old manifest that is not in the new ship set **and** for which `owned()` is true, delete the file if it exists and print `remove         <path>` (`--check`: `would remove   <path>`, nothing deleted). A path outside `OWNED` that dropped out is printed once as `leave (yours)  <path>` and simply falls out of the manifest. Empty parent directories are left in place. |
| Modified-by-owner file | Removed regardless of content. No comparison is made because there is nothing to compare against: the retired file has no source. This is the same rule `OWNED` already applies to replacement at `:76`, where an owner's edit to a framework-owned file is overwritten on upgrade. The tradeoff is accepted openly: `--check` shows every `would remove` first, and a committed hive keeps the file in its history. Owners who want to keep a retired framework file copy it out of `OWNED` (a `.claude/agents/` file cannot be kept in place, by the definition of `OWNED`). |
| No manifest yet | On `--upgrade` with no `.claude/vulyk-manifest`: delete nothing; for each file present under an `OWNED` tree in the target but absent from the new ship set, print `unlisted (kept) <path>`; then write the manifest. The next upgrade has a manifest and never sees those files again, because a manifest lists only shipped paths. |
| Idempotence | A crash between removal and manifest write is harmless: the next run recomputes from the old manifest, and removing a missing file is a silent no-op. |

The manifest deliberately lists the whole ship set, not only `OWNED` paths, so that `OWNED` is
consulted in exactly one place (the removal filter) and a later decision to widen or narrow
removal is a filter change, not a format change.

### D3. Constitution blocks on `--upgrade`

A new `ensure_marked_block <file> <MARKER> <human label>` (placeholder on stdin, like
`reset_marked_block`) runs in both "already a constitution" branches: `CLAUDE.md` (`:365-386`)
and the sidecar `CLAUDE.vulyk.md` (`:387-394`). The sidecar gets identical treatment because it
is the same constitution under a different filename, and the council reads the same blocks from
it. The foreign `CLAUDE.md` beside a sidecar is never opened.

| Target state | Action |
|---|---|
| Both `<MARKER>:START` and `:END` present, any content | Nothing. Filled or placeholder makes no difference; the markers are the ownership boundary. |
| Exactly one marker present | `WARNING`, same voice as `:108-112`; nothing written. |
| Neither marker, but the source's preceding heading (`## Profile` / `## Commands`) exists in the target | `WARNING: ## Profile exists without VULYK:PROFILE markers - left as-is`; nothing written. An owner wrote that section by hand; the installer does not know which rows are theirs. |
| Neither marker, heading absent | Insert the source's whole section for that block - from its preceding `## <heading>` line up to and including `<MARKER>:END`, with the block body replaced by the placeholder - immediately before the first later `## ` heading of the source that exists verbatim in the target; if none does, append at EOF. Print `insert         CLAUDE.md '## Profile block' (placeholders)` (`--check`: `would insert   ...`). |

After the block pass, for each block the installer prints the rows that still hold `<fill in`,
by row label: `  profile: 9 rows still hold <fill in: Stack, Package manager / runner, ...`, or
`  profile: filled`. This is printed on every `--upgrade`, whether or not anything was inserted,
because it is the one line that tells an owner whether the council can run in this hive.

The placeholder text for each block moves out of `reset_commands_table` (`:128-152`) into two
functions that print it, so that reset and insert share one source and the CI row-count check at
`ci.yml:170-173` covers both.

### D4. Install-smoke assertions the decision implies

Added to `.github/workflows/ci.yml` `install-smoke`; existing steps stay, including
`--upgrade never touches an already-filled Profile block` (`:206-214`).

1. `--check` output has no `would copy docs/adr/` or `would copy docs/wiki/` line; after a real
   install, `docs/adr/` and `docs/wiki/` exist and hold no file from the source (`001-*.md` absent).
2. After a real install, `.claude/vulyk-manifest` exists, passes `LC_ALL=C sort -c`, every line
   names an existing file in the target, contains `.claude/agents/worker-code.md`, and contains
   no line matching `vulyk-version`, `vulyk-manifest`, `docs/specs/`, `docs/adr/0`, or `CLAUDE`.
3. **Retire:** install; append `.claude/agents/retired-smoke.md` to the manifest and create that
   file; `--upgrade --check` prints `would remove   .claude/agents/retired-smoke.md` and the file
   and manifest are unchanged; real `--upgrade` deletes it and the manifest no longer lists it.
4. **Never outside OWNED:** same as 3 with `memory/retired-smoke.md`: the file survives
   `--upgrade`, the output has no `would remove`/`remove` line for it, the manifest drops it.
5. **Owner's own file:** create `.claude/agents/mine.md` after install; `--upgrade` leaves it and
   the manifest never lists it.
6. **No manifest:** install, delete the manifest, create `.claude/agents/stale-smoke.md`;
   `--upgrade` prints `unlisted (kept) .claude/agents/stale-smoke.md`, the file exists afterwards,
   the manifest exists afterwards and does not list it.
7. **Missing Profile block:** install, delete from the `## Profile` line through
   `VULYK:PROFILE:END` in the target; `--upgrade`; both markers are back, the Profile row count
   equals the source's, the `## Profile` line number is smaller than the `## Commands` line
   number, and the output names `Client path` among the `<fill in` rows.
8. **Missing Commands block:** as 7 for `VULYK:COMMANDS`, asserting it lands before
   `## Compact instructions`.
9. **Hand-written section:** install, delete the markers only (keep the `## Profile` heading and
   rows); `--upgrade` prints `WARNING` and the file is byte-identical.
10. **Sidecar:** foreign `CLAUDE.md` plus `CLAUDE.vulyk.md`; delete the Profile section from the
    sidecar; `--upgrade` restores it in the sidecar and `CLAUDE.md` is byte-identical.
11. **Dry run stays dry:** `--upgrade --check` after 3 and 7 writes nothing (target tree
    checksum unchanged).

## Consequences

- **Easier:** a retired framework file leaves every hive on its next upgrade, visibly in
  `--check` first. The council's two contractual inputs exist in every upgraded hive after one
  run, and the installer says which rows are still placeholders. The sentences at `:10` and
  `:452` stop being false.
- **Harder / accepted debt:** the first upgrade of each of today's eleven hives prints an
  `unlisted (kept)` report that will name every owner-added agent and command as well as every
  truly stale file; the owner reads it once. An owner's edit to a file the framework later
  retires is lost on upgrade, with `--check` as the only warning. A hive whose `CLAUDE.md` has a
  hand-written `## Profile` without markers is warned, not fixed; that hive's owner adds the two
  marker comments by hand.
- **Migration:** none for the ship set. The manifest appears on the first run of the new
  installer; `scripts/vulyk-update.sh` needs no change because it delegates to the release's own
  `install.sh`. ADR-001's Consequences `Migration` line ("`install.sh` adds the two `Bash(...)`
  allow rules") is unaffected.
- **Docs:** `docs/wiki/` receives the invariants below; the `--check` line vocabulary in
  `recon/install-and-update.md` gains `would write`, `would remove`, `would insert`,
  `leave (yours)`, `unlisted (kept)`.

## Invariants created

- `shippable()` is the only place that decides what the installer ships; `docs/adr/*` and
  `docs/wiki/*` are denied there, `README.md` files under them allowed.
- `.claude/vulyk-manifest` lists exactly the paths `copy_tree` found shippable on the last
  run: one per line, `LC_ALL=C` sorted, root-relative, forward slashes, never the manifest or
  stamp, never `CLAUDE*.md` or `AGENTS.md`.
- The installer deletes a file only if all three hold: it is in the previous manifest, it is
  not in the current ship set, and `owned()` is true for it. An owner-authored file is never in
  a manifest and is therefore never deleted.
- With no previous manifest, `--upgrade` deletes nothing; it reports and writes the manifest.
- `--check` performs no write and no delete; every mutating action has a `would ...` line.
- `VULYK:PROFILE` and `VULYK:COMMANDS` markers are the ownership boundary of the constitution:
  the installer never writes between existing markers on `--upgrade`, and inserts a block only
  where neither marker nor the block's heading exists.
- A `--upgrade` prints, for each block, which rows still hold `<fill in`.
- `CLAUDE.vulyk.md` is treated exactly as `CLAUDE.md` for block insertion; the foreign
  `CLAUDE.md` beside it is never opened.

## Revisit when

- A release needs to ship a file into `docs/wiki/` or `docs/adr/` other than a README: the deny
  arm then needs a named allow list, or the file belongs elsewhere.
- `unlisted (kept)` reports across the eleven hives show that owners routinely keep edited
  copies of retired framework files: the "remove regardless of content" rule should then gain
  a `cmp` against the previous release's copy, which requires the manifest to carry hashes.
- A third constitution shape appears (a hive that imports the constitution from a path other
  than `CLAUDE.md` / `CLAUDE.vulyk.md`), or a third marker family is added: the block pass
  should then iterate a marker list instead of two calls.
- An owner asks for a retired file to be preserved in place: that is a request to move it out
  of `OWNED`, not to weaken the removal rule.
