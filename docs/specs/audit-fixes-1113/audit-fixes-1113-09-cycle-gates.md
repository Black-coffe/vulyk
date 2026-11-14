---
story: audit-fixes-1113-09
spec: audit-fixes-1113
status: done
returned: DONE
tier: 3
worker: worker-code
model: opus
wave: 3
blocked_by: [audit-fixes-1113-03]
red: required
red_reason: an edit committed before the close is out of scope
red_verified_at: 2026-11-14T01:01:11Z 19a72a60640311331bcae9c20f434e9c7617069e8caf09229511021569e451cb
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
- scripts/lib.sh: `cycle_state_dir` and `state_get` read the run state's claim record. The approved-record helpers in the partial patch belong to story 13 and were left out.
- scripts/cycle.sh: `state_put` and `record_claim_head` (writes once per wave); `claim` records the head (both on a fresh claim and on a re-claim by the holder); `advance` records it on `build:<W>` when a DRIVER is held.
- scripts/cycle.sh close-story: at Tier 3-4 with no record (or a record that is not a commit) it exits 2 `no claim head recorded for wave <W>`. It then passes `--since <head>`; an out-of-scope path changed between the head and HEAD gets exit 4 at once, whichever wave-mates are still open. Tier 1-2 or no tier: one stderr note, and the check is the same as before.
- scripts/scope-check.sh: `--since <sha>` counts the diff from the head to the working tree plus untracked files; a done same-wave story's paths and story file are excluded in that mode. The P1 plan/brief `doc_base` from the patch was left out (story 14).
- Fixture sites moved: tests/cycle.test.sh close2 `trust_story` now puts every trust story in wave 1 and claims and releases once after `vulyk(trust): plan`; tests/council.test.sh `nr_red` (verbs2) claims and releases after `repair`. tests/solo.test.sh (Tier 1-2) and tests/e2e.test.sh (the driver's `advance --claim` records the head) needed no change.
- tests/cycle.test.sh: new part `scope` added to `PARTS`.
- Surprise: the git-guard hook refuses a Bash heredoc with unbalanced quotes, so edits went through Edit.
CHANGELOG: close-story at Tier 3-4 now counts scope from the head `claim` recorded for the wave, so an edit outside `## Files` committed before the close is refused. A Tier 3-4 close with no claim record exits 2.

## Findings
- close-story exit 2: `no claim head recorded for wave 3`. This is the expected case the Goal names: the wave was claimed by the old script, so no claim head was recorded. The Queen needs to relaunch the driver so `advance --claim` writes the record. No record was written by hand. All eight `## Verification` rows passed when run one by one before the close (scope, gates, close, close2, council verbs and close, solo, e2e).

## Red receipt
- command: bash tests/cycle.test.sh --part scope
- exit: 1
- tests: 19a72a60640311331bcae9c20f434e9c7617069e8caf09229511021569e451cb (tests/council.test.sh, tests/cycle.test.sh, tests/e2e.test.sh, tests/solo.test.sh)
- impl: 3c3f290c49ca622bcb153dcbb554640dbfc4359e4fde19294c85abc5b5e9b1a4
- stamped: 2026-11-14T01:01:11Z

```
::error::an edit committed before the close is out of scope - exit=4 out=scope-check: sone-01 - declared 1, changed 5, out of scope 4
{"ok":false,"verb":"close-story","exit":4,"next":"repair","error":"edited outside ## Files: docs/specs/sone/sone-03.md, docs/specs/sonet/sonet-01.md, sone-c.txt, sone-x.txt, sonet-a.txt","now":1794617727}
::error::the clean close refused - exit=4 out=scope-check: sone-01 - declared 1, changed 5, out of scope 4
  ! docs/specs/sone/sone-03.md
  ! docs/specs/sonet/sonet-01.md
  ! sone-c.txt
  ! sonet-a.txt
  -> Law 3: these files were touched but never named. Either the story was wrong
     or the worker went wide. Both are worth knowing; neither is decided here.
cycle: close-story - edited outside ## Files: docs/specs/sone/sone-03.md, docs/specs/sonet/sonet-01.md, sone-c.txt, sonet-a.txt - undo your own edits to them (a closed wave-mate's may be among them); if none are yours, return NEEDS_CONTEXT naming them
{"ok":false,"verb":"close-story","exit":4,"next":"repair","error":"edited outside ## Files: docs/specs/sone/sone-03.md, docs/specs/sonet/sonet-01.md, sone-c.txt, sonet-a.txt","now":1794617728}
```
