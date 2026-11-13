---
story: beta-fixes-1113-01
spec: beta-fixes-1113
status: done
returned: DONE
tier: 3
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: a numbered finding names its file, not its number
red_verified_at: 2026-11-13T08:21:03Z 2d2775670fb3df6b705c73753fc0b508996cfdcca75dbc1a1b28497524aad8d3
---

# Two parsers: a numbered finding gives its file, a quoted `red_reason` matches

## Goal
`scripts/cycle.sh`, two small fixes. **Ask 1.** `finding_paths` drops a leading item number (`N. `, digits, a
dot, a space) beside the `- ` and `[tag] ` it already strips, so a finding written the way `lead-review` numbers
them (see its report format) yields its `path:line`, never `1.`. Both callers get it through the function: the
repair story's `## Files` / `## Verification` (`repair_verification`) and the narrow decision (`narrow_file`,
re-checked by `narrow_round_holds`). The narrow decision also asks for a real path: a round is narrow only when
its one RED item's findings name exactly one path that exists in the tree and is not a test. Findings that name
no such path (no path, or a dotted word such as `e.g.`) give a full round: no `narrow: true`, no
`narrow.round-<n+1>` record, the tier's full seats, and `suite` runs. **Ask 7.** Where `red_reason` is read
(stamp-red's compare with the failing output, and any other site that reads it), one layer of matching YAML
quotes, single or double, is removed first.

## Requirements
> 1. Repair parser: `finding_paths` drops a leading `N. ` item number, so a reviewer's numbered finding never yields `1.` as a path; a repair whose findings name no real path is not a narrow round and keeps the round's suite.
> 7. A quoted `red_reason:` (YAML single or double quotes) matches the same as an unquoted one.

## Files
- scripts/cycle.sh
- tests/council.test.sh
- tests/cycle.test.sh

## Non-goals
- Do not filter `finding_paths` itself by existence: a finding may name a file the repair must create. The
  existence test belongs to the narrow decision only.
- Do not change what else counts as narrow (one RED item, one non-test file), the repair story's shape, `model:
  opus`, the roster, the verdict rule, or the narrow record's keys.
- Do not change what `fm_raw` returns to its other callers, and do not touch `scripts/lib.sh` (`fm_field` already
  unquotes); unquote at the `red_reason` reads.
- Do not touch `advance`, `cmd_resume`, `branch_guard` or the close-story segment check (story 04, wave 2), nor
  the driver.
- Edit `tests/council.test.sh` only in part `verbs` and `tests/cycle.test.sh` only in part `red`. One exception:
  an existing case that asserts a narrow round from a finding with no path is updated to the new rule and named
  in `## Implementation notes`.
- Fixtures use stand-ins (`app/acme.sh`, `Acme`); nothing copied from a hive.

## Map slice
`memory/map/cycle.md` → Repair (ADR-013 D4), Verbs (Red receipt; Cycle-owned run state: the narrow record;
`open-round`), Seats and the verdict (narrow round); `memory/map/scripts.md` → Gotchas (bash 3.2 / BSD).

## Acceptance criteria
- [ ] `--part verbs`: a RED round whose review has one finding in `lead-review`'s numbered form naming one
  existing non-test file (`app/acme.sh:12`): the repair story's `## Files` holds `app/acme.sh` and no line that
  is a number; its `## Verification` is not empty (the lines of the story that named the file). The failing label
  contains `a numbered finding names its file, not its number`.
- [ ] `--part verbs`, neighbours: item `10. ` is stripped the same way; a path that itself starts with digits and
  a dot (`2.0/notes.md`, existing in the fixture) is kept whole, because no space follows the dot.
- [ ] `--part verbs`: one RED item whose finding names no existing file (a dotted word as first token; a path
  absent from the tree; no path at all): the repair story has no `narrow: true`, no `narrow.round-<n+1>` record
  is written, the next `open-round` freezes the tier's full seats, and `suite` runs its step: the log does not
  read `SUITE: none - narrow repair round`.
- [ ] `--part verbs`: a one-item round whose finding names one existing non-test file is narrow, as before.
- [ ] `--part red`: with `red_reason: "acme: boom"` and with `red_reason: 'acme: boom'`, `stamp-red` writes the
  receipt when a failing line holds `acme: boom`; the unquoted form behaves as before. A value with an inner or
  unmatched quote (`it's red`, `"half`) is compared as written.
- [ ] Every new case fails on HEAD before the implementation; `## Implementation notes` says so.
- [ ] `bash scripts/portability-check.sh scripts/cycle.sh` is clean (no arrays, awk values through `ENVIRON`).
- [ ] `## Implementation notes` ends with two `CHANGELOG:` lines, one per ask.

## Verification
`bash tests/council.test.sh --part verbs`
`bash tests/cycle.test.sh --part red`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each -->
- scripts/cycle.sh `finding_paths`: drops a leading `N. ` (all digits, then `. `) after `- `; `2.0/x.md` stays whole (no space after its dot).
- scripts/cycle.sh `narrow_file`: no fallback to the ## Files union; narrow only when the findings' deduped paths are exactly one, it is a file under `$ROOT` and not a test. Decision: a second unresolvable token (e.g. `e.g.` beside a real path) makes the round full, the conservative reading. `<files>` arg kept so callers stay unchanged.
- scripts/cycle.sh stamp-red: one matching layer of `"..."` or `'...'` stripped from `red_reason` before the compare (the only `red_reason` read in cycle.sh); `""` becomes empty and refuses as empty.
- tests/council.test.sh part verbs: `nb_*` fixture (one story on `app/acme.sh`, `2.0/notes.md` in the tree, a temporary Full suite row `true`, removed at the end); cases `1.`, `10.`, `1. 2.0/notes.md`, `e.g.`, absent path, no path.
- tests/cycle.test.sh part red: `red_q` cases 40-44 on `tests/red-acme.sh` with its own `src/red-acme.txt` (src/red.txt is already `done` by then).
- Updated existing case (Non-goals exception): part red `redrq` asserted `narrow: true` from the finding `- [ask 1] ask 1 broke: ...` (no path); now asserts the frontmatter without `narrow: true`.
- Red on HEAD: every new numbered/no-path case and both quoted red_reason cases failed before the implementation. The guards that pin old behaviour pass on HEAD by design: round 2 of `nbn` opening narrow (HEAD recorded `1.` and re-checked it), the `## Verification` line check, and red_q 42 (unquoted), 43 (`it's red`), 44 (`"half` refused).
CHANGELOG: Repair: a reviewer's numbered finding (`1. path:line`) now yields its path, never `1.`; a repair whose findings name no existing non-test file is a full round with the suite, not a narrow one.
CHANGELOG: stamp-red: a `red_reason:` in YAML single or double quotes matches the failing output the same as an unquoted one.

## Findings

## Red receipt
- command: bash tests/council.test.sh --part verbs
- exit: 1
- tests: 2d2775670fb3df6b705c73753fc0b508996cfdcca75dbc1a1b28497524aad8d3 (tests/council.test.sh, tests/cycle.test.sh)
- impl: cca74342007f0c8d7ef0cc03ab1c00725b207fbe8078a1a05b488bda8b495573
- stamped: 2026-11-13T08:21:03Z

```
beta-fixes-1113 (ask 1): a numbered finding names its file, not its number; a finding with no real path is a full round
::error::a numbered finding names its file, not its number - 1. app/acme.sh:12: narrow on app/acme.sh, ## Files holds no number, ## Verification not empty: story=---
::error::a numbered finding names its file, not its number - 10. app/acme.sh:12: the two-digit number is stripped the same way: story=---
from=1 ROUND=head=b40f5a6
pack=508e4cd3d87d
opened=2026-11-13T08:18:01Z
court=
ceiling=3
tier=3
seats=review
since=4cfe024
narrow=1 log=head=b40f5a6 steps=0
SUITE: none - narrow repair round
```
