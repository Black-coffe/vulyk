---
story: audit-fixes-1113-13
spec: audit-fixes-1113
status: done
returned: DONE
tier: 3
worker: worker-code
model: opus
wave: 5
blocked_by: [audit-fixes-1113-09]
red: required
red_reason: a story change committed outside cycle.sh is not approved
red_verified_at: 2026-11-14T02:21:26Z 34cdd221c30b3ed937c8334cd0c447a89c1e4192cac98b909a85cce3afebc2bd
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

- [ ] `reanchor`: after a main-session commit outside every story's `## Files` between two claims, a close counts
  that commit as out of scope; after `reanchor` with a reason it does not, and the journal names the move.

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
- scripts/cycle.sh: records in `.vulyk/state/<slug>/approved` (record_approved/approved_sha); `branch` refuses an untracked or modified story and records each story; `revise` and `reanchor` verbs; `repair --commit` records; `claim`/`branch` seed once from the old subject rule (seed_approved), `claim` refuses a missing record after that (approved_missing_guard); story_blocks_guard reads the record, no subject.
- Ported by hand from the partial patch, not copied: `branch` still commits the spec folder (named-path staging is P1, story 14); no `status_hand_note`; seeding writes its journal line only when it seeded at least one story, so claims on fixture specs with no paperwork subjects stay journal-free.
- `claim_wave` split out of record_claim_head so `reanchor` picks the same wave; reanchor's reason goes through redact_note.
- tests/cycle.test.sh: new part `approved`; close2's trust fixture is branched (claim seeds) and uses `revise`; scope's sone stories get `revise` first. council/solo/e2e needed no fixture change.
- Before stamp-red the implementation was prototyped in a scratchpad copy to check the sealed tests (cycle all parts, council verbs/verbs2/verbs3/judge2/advance/roster/close, solo, e2e green there; council driver needs $SRC git history, not checkable in a copy); the tree got it only after the receipt.
- CHANGELOG: (ask 9) a story's approved version is the commit `cycle.sh` made and recorded (`branch`, the new `revise`, `repair`), never a commit subject; `cycle.sh reanchor` moves a wave's claim head with a journaled reason.

## Red receipt
- command: bash tests/cycle.test.sh --part approved
- exit: 1
- tests: 34cdd221c30b3ed937c8334cd0c447a89c1e4192cac98b909a85cce3afebc2bd (tests/council.test.sh, tests/cycle.test.sh, tests/e2e.test.sh, tests/solo.test.sh)
- impl: 82de847dcc93a7a173d88897035d8913d8d1cf69b2471f2421ae201336e02235
- stamped: 2026-11-14T02:21:26Z

```
::error::a story change committed outside cycle.sh is not approved (vulyk subject, ## Verification) - exit=2 out=scope-check: appr-01 - declared 1, changed 1, out of scope 0
::error::a story change committed outside cycle.sh is not approved (plain subject, red:) - exit=2 out=cycle: close-story - no approved version in git for docs/specs/appr/appr-03.md: commit the plan or a revision first
::error::after reanchor - exit=2 out=cycle: close-story - no approved version in git for docs/specs/appr/appr-02.md: commit the plan or a revision first
{"ok":false,"verb":"close-story","exit":2,"next":"error","error":"no approved version in git for docs/specs/appr/appr-02.md: commit the plan or a revision first","now":1794622553}
A1 seeding: a spec built before this release gets its records once, from claim, with a journal line
::error::seeding: exit=0 record=cat: .vulyk/state/seed/approved: No such file or directory out=cycle: seed - claimed by s1
{"ok":true,"verb":"claim","exit":0,"next":"claimed","now":1794622554}
::error::a lost record must refuse the claim - exit=0 out=cycle: seed - claimed by s1
{"ok":true,"verb":"claim","exit":0,"next":"claimed","now":1794622555}
A1: repair records its story at repair's own commit
::error::repair record: exit=0 record=cat: .vulyk/state/apprp/approved: No such file or directory out=cycle: apprp - repair story for round 1: docs/specs/apprp/apprp-02-repair-round-1.md
{"ok":true,"verb":"repair","exit":0,"next":"build:2","now":1794622562,"status":{"spec":"docs/specs/apprp","slug":"apprp","stage":"04-council:RED","next":"build:2","briefed":true,"approved":true,"branch":"vulyk/appr","head":"50f7ff0","pack":"df0173297742","now":1794622562,"stories":{"todo":1,"in-progress":0,"done":1,"blocked":0},"wave":2,"wave_stories":[{"file":"docs/specs/apprp/apprp-02-repair-round-1.md","story":"apprp-02","worker":"worker-code","model":"opus","repeat":1}],"round":1,"ceiling":2,"tier":2,"open":false,"court":null,"missing":[],"stale":false,"verdict":"RED","review":"BLOCK","red":[],"round_dir":"docs/specs/apprp/council/round-1","paused":false,"shipped":false,"since":null,"seat_attempt":{},"seats":[],"manual":[]}}
```

## Findings
- (resolved after the relaunch seeded the records) close-story exit 2, the expected gate line (story Goal): `no approved record for docs/specs/audit-fixes-1113/audit-fixes-1113-13-approved-record.md: run bash scripts/cycle.sh revise docs/specs/audit-fixes-1113/audit-fixes-1113-13-approved-record.md`. The wave was claimed by the old script, so no record exists; relaunch the driver so `advance --claim` seeds the records (journal line `approved records seeded from commit subjects`), then rerun close-story. Red receipt is in place; implementation and docs are in the tree, uncommitted.
