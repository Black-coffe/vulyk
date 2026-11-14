---
story: audit-fixes-1113-14
spec: audit-fixes-1113
status: done
returned: DONE
tier: 3
worker: worker-code
model: opus
wave: 6
blocked_by: [audit-fixes-1113-13]
red: required
red_reason: a hand edit of the brief asks stales the round
red_verified_at: 2026-11-14T03:04:42Z 6afcb65478b0b20887a51be1557383baaeb9133bb5226404d8f646a19184d8fc
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
- scripts/lib.sh: plan.md/brief.md left is_paperwork_path; new spec_doc_kind/strip/text/same, paperwork_change, hand_edits, approved_shas; paperwork_only reads paperwork_change.
- scripts/cycle.sh: dirty_outside_paperwork and claim_leftover use paperwork_change; named_spec_paths (unknown kind exits 2) replaces "$SPEC" in judge, escalate, briefed, branch, open-round (x4), reopen commits; status_hand_note on the `status` verb skips approved-record (revise) commits.
- Kinds checked against each verb's writes: judge/escalate/open-round plan+journal+council, briefed plan+brief+journal+docs+stories, branch plan+journal, reopen brief+journal+council.
- scripts/scope-check.sh: doc_base reads `git rev-list "$SINCE..HEAD" -- <file>` (a later record commit that left the file alone no longer hides a hand edit); an explicit range measures the docs between its two ends.
- tests/cycle.test.sh: new part `paperwork` (in PARTS); tests/council.test.sh: the escalate part's uncommitted plan-only descope now refuses as dirt (patch fixture).
- docs/cycle.md: one row in "What invalidates a confirmation" for the paperwork rule.
- Surprise: built and swept first in a scratch copy (no implementation in the tree before the receipt); every cycle/council part, solo, e2e, driver, handoff passed there except four council parts (driver, replays2, walks, walks2) whose pinned replays need the repo's .git.
- CHANGELOG: brief.md and plan.md are paperwork only in the lines a cycle script writes; a hand edit refuses a close, stales a round and is named by `status`, and cycle commits stage their named files, never the spec folder.

## Red receipt
- command: bash tests/cycle.test.sh --part paperwork
- exit: 1
- tests: 6afcb65478b0b20887a51be1557383baaeb9133bb5226404d8f646a19184d8fc (tests/council.test.sh, tests/cycle.test.sh)
- impl: 859d8eb02094932c38b0e88c4d61292898b7c39c0f820f6a034aeb9c5cd74b67
- stamped: 2026-11-14T03:04:42Z

```
::error::a hand edit of the brief asks stales the round (a ## Asks line committed after ROUND.head) - expected '"stale":true' in:
::error::a hand edit of the brief asks stales the round (a ## Asks line committed after ROUND.head) - expected '"stale":true' in:
        {"spec":"docs/specs/pone","slug":"pone","stage":"03-built","next":"dispatch:review","briefed":true,"approved":true,"branch":"vulyk/demo","head":"55427a7","pack":"5edd069aae37","now":1794625191,"stories":{"todo":0,"in-progress":0,"done":1,"blocked":0},"wave":null,"wave_stories":[],"round":2,"ceiling":3,"tier":3,"open":true,"court":null,"missing":["review"],"stale":false,"verdict":null,"review":null,"red":[],"round_dir":"docs/specs/pone/council/round-2","paused":false,"shipped":false,"since":"bde7ca2","seat_attempt":{"review":1},"seats":["review"],"manual":[]}
::error::status names brief.md and its commit - expected 'docs/specs/pone/brief.md hand-edited in 55427a7' in:
        {"spec":"docs/specs/pone","slug":"pone","stage":"03-built","next":"dispatch:review","briefed":true,"approved":true,"branch":"vulyk/demo","head":"55427a7","pack":"5edd069aae37","now":1794625191,"stories":{"todo":0,"in-progress":0,"done":1,"blocked":0},"wave":null,"wave_stories":[],"round":2,"ceiling":3,"tier":3,"open":true,"court":null,"missing":["review"],"stale":false,"verdict":null,"review":null,"red":[],"round_dir":"docs/specs/pone/council/round-2","paused":false,"shipped":false,"since":"bde7ca2","seat_attempt":{"review":1},"seats":["review"],"manual":[]}
::error::the **Tier:** line of plan.md committed after ROUND.head stales the round - expected '"stale":true' in:
        {"spec":"docs/specs/pone","slug":"pone","stage":"03-built","next":"dispatch:review","briefed":true,"approved":true,"branch":"vulyk/demo","head":"212904e","pack":"5edd069aae37","now":1794625192,"stories":{"todo":0,"in-progress":0,"done":1,"blocked":0},"wave":null,"wave_stories":[],"round":3,"ceiling":3,"tier":3,"open":true,"court":null,"missing":["review"],"stale":false,"verdict":null,"review":null,"red":[],"round_dir":"docs/specs/pone/council/round-3","paused":false,"shipped":false,"since":"b863a10","seat_attempt":{"review":1},"seats":["review"],"manual":[]}
  ok    status does not call a revise commit of plan.md hand-edited
audit-fixes-1113-14 (P1): a --commit verb commits its named files and leaves a stray file in the spec folder out
::error::a cycle commit took the spec folder: exit=0 files=docs/specs/pwname/brief.md docs/specs/pwname/journal.md docs/specs/pwname/notes.txt docs/specs/pwname/plan.md  out=cycle: pwname - briefed
{"ok":true,"verb":"briefed","exit":0,"next":"branch","now":1794625195}
```
