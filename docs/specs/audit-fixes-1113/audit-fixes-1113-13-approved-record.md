---
story: audit-fixes-1113-13
spec: audit-fixes-1113
status: todo
returned:
tier: 3
worker: worker-code
model: opus
wave: 5
blocked_by: [audit-fixes-1113-09]
red: required
red_reason: a story change committed outside cycle.sh is not approved
---

# A story's approved version is a commit cycle.sh made

## Goal
**A1** (plan.md `## Contracts`). The approved version of a story is the story file in a commit `cycle.sh`
itself made and recorded: at `branch`, at the new verb `revise <story-file>`, at `repair`. `close-story` and
`stamp-red` compare `## Verification`, `## Files` and `red:` with that commit and read no commit subject. The
subject walk survives only as the one-time seeding that `claim` and `branch` do for a spec built before this
release. `/vulyk-build` and `/vulyk-plan` tell the Queen to run `cycle.sh revise` where they told her to
commit by hand. Add the new part `approved` to `tests/cycle.test.sh` (`PARTS`).

`model: opus`: a gate in the script that closes this very story, with the
fixtures of several suites moving with it. Cut from story 09 by lead-architect (plan delta 2026-11-14).
Patch ranges for this story: patch lines 34-56, 92-225, 374-389, 402-474, 487-512, 916-1029.

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
> 9. A story's approved version is bound to a commit that `cycle.sh` itself made, not to a commit subject.

## Files
- scripts/cycle.sh
- .claude/commands/vulyk-build.md
- .claude/commands/vulyk-plan.md
- docs/cycle.md
- docs/adr/032-*.md
- tests/cycle.test.sh
- tests/council.test.sh
- tests/solo.test.sh
- tests/e2e.test.sh

## Non-goals
- Do not touch `git-guard.sh`, `install.sh`, `settings.json`, `human-check.sh`, `ship-check.sh` or the driver.
- Fix a fixture, never the gate. In `tests/solo.test.sh` and `tests/e2e.test.sh` change fixture lines only (a helper that makes a Tier 3-4 fixture claim or branch first).
- Finish every test-file edit before `stamp-red`: the sealed tests are not edited after the receipt.
- No ledger of commits, no trailer, no new committed file: the records live in the cycle's run state beside the verify records.
- `close-story` and `stamp-red` never seed a record and never read a commit subject: a missing record at Tier 3-4 is exit 2.
- In the two commands change only the sentences about committing a revised story or plan.

## Acceptance criteria
- [ ] Original case: after `branch` recorded a story, a commit not made by `cycle.sh` that changes the story's `## Verification`, `## Files` or `red:`, whatever its subject, leaves the approved version where it was: the close exits 4 `story blocks differ from the approved version`. Neighbour: the same change through `cycle.sh revise <story>` is approved and closes.
- [ ] `branch` on a spec with an untracked or modified story exits 2 `commit the plan first`; `repair` records its story; a Tier 3 story with no record exits 2 `no approved record for <story>` in `close-story` and `stamp-red`.
- [ ] Seeding: a spec with stories committed before this release and no record gets one from `claim`, with a journal line; a record missing after that line makes `claim` exit 2 naming `cycle.sh revise`.
- [ ] `docs/cycle.md` describes the record and `revise`; ADR-032 has a dated amendment stating the rule. `bash scripts/prompt-check.sh --touched scripts/cycle.sh .claude/commands/vulyk-build.md .claude/commands/vulyk-plan.md` has no error.

## Verification
`bash tests/cycle.test.sh --part approved`
`bash tests/cycle.test.sh --part close`
`bash tests/cycle.test.sh --part close2`
`bash tests/council.test.sh --part verbs`
`bash tests/council.test.sh --part close`
`bash tests/solo.test.sh`
`bash tests/e2e.test.sh`

## Implementation notes
<!-- files changed, decisions, surprises - 1-2 lines each; end with one `CHANGELOG:` line for the ask. -->
