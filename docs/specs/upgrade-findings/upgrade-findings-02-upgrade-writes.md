---
story: upgrade-findings-02
spec: upgrade-findings
status: todo
returned:
tier: 3
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: a frontmatter-only edit lands the release body
---

# What the upgrade writes: a frontmatter edit merged by key, CRLF pinned, `settings.json` indent kept

## Goal
Three changes to what `install.sh --upgrade` writes into a hive. **E1:** when `upgrade_edited`'s
`git merge-file` conflicts and the hive's edit is frontmatter-only (its body equals the body the installed
release shipped, CR stripped), the upgrade writes the new release's body under a frontmatter merged key by
key and prints the lines of plan.md `## Contracts` E1 (`merge frontmatter <file>`, `kept <key> (yours)`,
`dropped <key> (removed by the release)`); a key both sides changed prints `frontmatter conflict on <key>` and
the file is parked as `keep + new`, exactly as today. `--check` prints the `would ...` form and writes
nothing. **E2:** a test pins that a CRLF-only checkout of a release copy is classified as a release copy, not
as a local edit; `install.sh` changes for it only if that test is red. **E3:** every installer writer that
rewrites an existing JSON file reads the file's indent unit (N spaces or a tab, from its first indented line)
and writes with it; a new file gets 2 spaces; the upgrade's note about `settings.json` no longer claims a
re-indent when the unit was kept, and `.claude/settings.json.vulyk-bak` is still written.

## Requirements
> 12. E1: when a hive's edit of a framework file touches only its frontmatter and the release changed the file, the upgrade lands the release's body with the hive's frontmatter keys merged in, and names each key kept or dropped, instead of parking the whole file as `.vulyk-new`.
> 13. E2: a test shows that a CRLF-only checkout of a release copy is not classified as a local edit (code changes only if that test fails).
> 14. E3: the upgrade keeps `.claude/settings.json`'s existing indent when it rewrites the file.
> 16. Out of scope: no hive-side file changes, no change to the A/B measurement study or model profiles, and `install.sh --upgrade` widened no further than asks 7, 8, 12, 14 and 15 describe.

## Files
- install.sh
- tests/telemetry.test.sh

## Non-goals
- No YAML parser: a key is a top-level `name:` line plus its indented lines, compared as text.
- Do not change the outcome of a clean `git merge-file` (`merge edit`), of a body edit (`keep + new`), of
  `keep (edited)` or `keep deleted`; the key merge is tried only after a conflict.
- Never let the release win a key the hive also changed (card `upgrade-overwrites-host-edits`).
- Do not add the commands lint, the measured-suite lines or the backup-only constitution lines (story 04),
  and do not edit `.claude/commands/vulyk-update.md` (story 04 documents the E1 lines).
- Do not touch hook wiring, `ensure_gitignore`, manifest handling or the telemetry row.
- Do not edit `tests/telemetry.test.sh` outside parts `edits`, `crlf` and `wiring`.
- CR-byte trap: edit `install.sh` with Edit, never through a Python text-mode rewrite.

## Map slice
`memory/map/scripts.md` → install.sh - the upgrade contract, Gotchas (bash 3.2 / BSD, awk through `ENVIRON`).
Unmapped, read in place: `release_copy`, `upgrade_edited`, the five `json.dump(..., indent=2)` writers.

## Acceptance criteria
- [ ] `--part edits`: a synthetic agent file (frontmatter `name`, `model`, `maxTurns: 40`, a two-line nested
  key; a body) installed at release A; the hive sets `maxTurns: 140`; release B changes the body and removes
  the nested key. `--upgrade` leaves the file with B's body, `maxTurns: 140`, no nested key, no `.vulyk-new`,
  and prints `merge frontmatter`, `kept maxTurns (yours)`, `dropped <nested key> (removed by the release)`.
  The failing label contains `a frontmatter-only edit lands the release body`.
- [ ] `--part edits`: the same with release B also changing `maxTurns` prints `frontmatter conflict on
  maxTurns`, keeps the hive file byte for byte and parks `.vulyk-new`; a hive edit that also touches the body
  is parked as today; a key the hive added and one it deleted both survive a release that left them alone.
- [ ] `--part edits`: `--upgrade --check` on the first case prints `would merge frontmatter` with the same
  key lines and changes no file.
- [ ] `--part crlf`: a hive whose framework file is the installed release's copy with CRLF endings is
  replaced as a release copy (no `keep (edited)`, no `.vulyk-new`), and the E1 case passes with a CRLF hive
  file. If this was green before any `install.sh` edit, `## Implementation notes` says so.
- [ ] `--part wiring`: a `settings.json` indented with 4 spaces, and one with tabs, come out of an upgrade
  that adds a hook with the same unit on every line (a diff against the old file shows only the added
  entries); a 2-space file and a fresh install are unchanged in shape; the output is LF with a trailing newline.
- [ ] `bash scripts/portability-check.sh install.sh` is clean; fixtures name no hive or client.

## Verification
`bash tests/telemetry.test.sh --part edits`
`bash tests/telemetry.test.sh --part crlf`
`bash tests/telemetry.test.sh --part wiring`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each -->

## Findings
