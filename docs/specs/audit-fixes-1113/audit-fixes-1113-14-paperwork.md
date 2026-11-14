---
story: audit-fixes-1113-14
spec: audit-fixes-1113
status: todo
returned:
tier: 3
worker: worker-code
model: opus
wave: 6
blocked_by: [audit-fixes-1113-13]
red: required
red_reason: a hand edit of the brief asks stales the round
---

# Paperwork is only what a cycle script writes

## Goal
**P1** (plan.md `## Contracts`). `brief.md` and `plan.md` are paperwork only in the lines a cycle script
writes. Any other change is a hand edit: it refuses a close, stales an open round and is named by `status`.
Every cycle commit stages its named files, never the whole spec folder. Fix while porting: the hand-edit
base is `git rev-list "$SINCE..HEAD" -- <file>` (a later `repair`/`branch` record commit must not hide an
earlier hand edit); the `status` note does not call a `revise` commit hand-edited; the list of spec-folder
kinds is checked against what the cycle scripts write. Add the new part `paperwork` to
`tests/cycle.test.sh` (`PARTS`).

`model: opus`: a gate in the script that closes this very story, with the
fixtures of several suites moving with it. Cut from story 09 by lead-architect (plan delta 2026-11-14).
Patch ranges for this story: patch lines 3-33, 61-91, 120-121, 285-343, 502, 518-610, 620, 676-707, 763-831, 1041-1051.

How to work (lead-architect, 2026-11-14; two earlier attempts died at the turn cap in a scratchpad copy):
1. Build in the tree, never in a copy: the suites build their own fixture repo from `$SRC`, and this story runs
   alone in its wave.
2. A head start: `.vulyk/reports/audit-fixes-1113/story-09-partial.patch` holds an untested diff from those attempts. Read only the line ranges named above and
   port them by hand (the hunks interleave three asks, so no `git apply`). Fix while porting: guard every array
   expansion as `${A[@]+"${A[@]}"}` (card `shell-needs-gnu-or-bash4`).
3. Write the new test part first, run `stamp-red`, then port the code. Loop on that one part only.
4. Run the inherited `## Verification` rows once at the end, each to a log, and read only the `::error::` lines. A
   part or suite outside `## Verification` that trips is `NEEDS_CONTEXT`.

Private input: the matching section of `~/.vulyk/audits/framework-audit-2026-11-13/FINAL.md`. Comments, test labels
and the ADR say what the gate does now, never what used to pass.

Expected on this spec only: the wave may have been claimed by the old script, so your own `close-story` can exit 2
with `no claim head recorded` or `no approved record`. That is the gate working. Return `NEEDS_CONTEXT` with that
line; the Queen relaunches the driver and its `advance --claim` writes the records. Do not write a record by hand.

## Requirements
> 10. Only files `cycle.sh` writes count as paperwork. A hand edit of `brief.md` or `plan.md` stales the round and is reported, and paperwork commits stage the named files, not the spec folder.

## Files
- scripts/cycle.sh
- scripts/lib.sh
- scripts/scope-check.sh
- docs/cycle.md
- tests/cycle.test.sh
- tests/council.test.sh

## Non-goals
- Do not touch `git-guard.sh`, `install.sh`, `settings.json`, `human-check.sh`, `ship-check.sh` or the driver.
- Fix a fixture, never the gate. In `tests/solo.test.sh` and `tests/e2e.test.sh` change fixture lines only (a helper that makes a Tier 3-4 fixture claim or branch first).
- Finish every test-file edit before `stamp-red`: the sealed tests are not edited after the receipt.
- `VERSION`, `CHANGELOG.md`, `CITATION.cff`, `memory/stats/*.jsonl`, `journal.md` and `council/` stay paperwork.

## Acceptance criteria
- [ ] Original case: a `## Asks` line of `brief.md` or the `**Tier:**` line of `plan.md` changed by hand: dirty at close is exit 4 naming the file; committed after `ROUND.head` makes the round stale, and `status` names the file and the commit. Neighbour: a `## Stories` line of `plan.md`. A commit holding only marker lines or `reopen`'s `## Answers` lines keeps the round current; a `revise` commit of `plan.md` before the round is accepted by the wave's closes.
- [ ] A `--commit` verb run with a stray file inside the spec folder commits its named files and leaves the stray one out.
- [ ] `docs/cycle.md` describes the paperwork rule.

## Verification
`bash tests/cycle.test.sh --part paperwork`
`bash tests/cycle.test.sh --part hooklog`
`bash tests/cycle.test.sh --part gates`
`bash tests/cycle.test.sh --part close`
`bash tests/cycle.test.sh --part ship`
`bash tests/council.test.sh --part verbs`
`bash tests/council.test.sh --part close`

## Implementation notes
<!-- files changed, decisions, surprises - 1-2 lines each; end with one `CHANGELOG:` line for the ask. -->
