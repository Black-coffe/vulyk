---
story: audit-fixes-1113-09
spec: audit-fixes-1113
status: todo
returned:
tier: 3
worker: worker-code
model: opus
wave: 3
blocked_by: [audit-fixes-1113-03]
red: required
red_reason: an edit committed before the close is out of scope
---

# Scope is counted from the claim head

## Goal
**S1** (plan.md `## Contracts`). `claim` records the wave's head once. `close-story` at Tier 3-4 hands it to
`scope-check.sh`, which counts every file changed between that head and the working tree, committed or not,
plus untracked ones. A Tier 3-4 close with no recorded head refuses; Tier 1-2 keeps today's check with one
stderr note. Add the new part `scope` to `tests/cycle.test.sh` (`PARTS`).

`model: opus`: a gate in the script that closes this very story, with the
fixtures of several suites moving with it. Cut from story 09 by lead-architect (plan delta 2026-11-14).
Patch ranges for this story: patch lines 162-180, 226-284, 348-372, 394-421, 478-486, 611-619, 627-675, 708-722, 861-915, 1033-1039.

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
> 8. The scope check also catches edits outside `## Files` that were committed before `close-story`, counting from the head recorded at claim. A subagent cannot `git commit` or `git add` while a DRIVER holds the spec, and worker prompts say never to commit.

## Files
- scripts/cycle.sh
- scripts/lib.sh
- scripts/scope-check.sh
- tests/cycle.test.sh
- tests/council.test.sh
- tests/solo.test.sh
- tests/e2e.test.sh

## Non-goals
- Do not touch `git-guard.sh`, `install.sh`, `settings.json`, `human-check.sh`, `ship-check.sh` or the driver.
- Fix a fixture, never the gate. In `tests/solo.test.sh` and `tests/e2e.test.sh` change fixture lines only (a helper that makes a Tier 3-4 fixture claim or branch first).
- Finish every test-file edit before `stamp-red`: the sealed tests are not edited after the receipt.
- Approval records (story 13) and the paperwork rule (story 14) are not this story's.

## Acceptance criteria
- [ ] Original case: a Tier 3 story, claimed; a file outside `## Files` is edited and committed before the close; `close-story --commit` exits 4 `edited outside ## Files` naming the file (label contains `an edit committed before the close is out of scope`). Neighbour: the same edit staged only, and one committed two commits back, both refuse. A same-wave sibling's close commit and a paperwork commit in the range do not.
- [ ] A Tier 3 close with no claim record exits 2 `no claim head recorded for wave <W>`; a Tier 1 close passes with the stderr note. A second `claim` of the same wave keeps the first head.
- [ ] The notes list each fixture site that moved.

## Verification
`bash tests/cycle.test.sh --part scope`
`bash tests/cycle.test.sh --part gates`
`bash tests/cycle.test.sh --part close`
`bash tests/cycle.test.sh --part close2`
`bash tests/council.test.sh --part verbs`
`bash tests/council.test.sh --part close`
`bash tests/solo.test.sh`
`bash tests/e2e.test.sh`

## Implementation notes
<!-- files changed, decisions, surprises - 1-2 lines each; end with one `CHANGELOG:` line for the ask. -->
