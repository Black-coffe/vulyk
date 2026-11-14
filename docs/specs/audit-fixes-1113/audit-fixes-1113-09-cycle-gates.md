---
story: audit-fixes-1113-09
spec: audit-fixes-1113
status: blocked
returned:
tier: 3
worker: worker-code
model: opus
wave: 3
blocked_by: [audit-fixes-1113-03]
red: required
red_reason: an edit committed before the close is out of scope
---

# The cycle's three gates: scope from the claim head, approval bound to cycle.sh's own commit, a narrower paperwork rule

## Goal
Three gates in `scripts/cycle.sh` and its two helpers, each to the letter of plan.md `## Contracts`.
1. **S1, scope.** `claim` records the wave's head once. `close-story` at Tier 3-4 hands it to `scope-check.sh`,
   which counts every file changed between that head and the working tree, committed or not, plus untracked ones.
   A Tier 3-4 close with no recorded head refuses; Tier 1-2 keeps today's check with one stderr note.
2. **A1, approval.** The approved version of a story is the story file in a commit `cycle.sh` itself made and
   recorded: at `branch`, at the new verb `revise <story-file>`, at `repair`. `close-story` and `stamp-red` compare
   `## Verification`, `## Files` and `red:` with that commit and read no commit subject. The subject walk survives
   only as the one-time seeding that `claim` and `branch` do for a spec built before this release.
   `/vulyk-build` and `/vulyk-plan` tell the Queen to run `cycle.sh revise` where they told her to commit by hand.
3. **P1, paperwork.** `brief.md` and `plan.md` are paperwork only in the lines a cycle script writes. Any other
   change is a hand edit: it refuses a close, stales an open round and is named by `status`. Every cycle commit
   stages its named files, never the whole spec folder.

`model: opus`: long-horizon and judgment-heavy. Three gates change in the script that closes this very story, and
the fixtures of two suites move with them. Marked red: security gates.

Private input: the sections on the scope check, the approved version and the paperwork list in
`~/.vulyk/audits/framework-audit-2026-11-13/FINAL.md`. Comments, test labels and the ADR say what the gates do
now, never what used to pass.

Expected on this spec only: the wave was claimed by the old script, so your own `close-story` can exit 2 with `no
claim head recorded` or `no approved record`. That is the gate working. Return `NEEDS_CONTEXT` with that line; the
Queen relaunches the driver and its `advance --claim` writes the records. Do not write a record by hand.

## Requirements
> 8. The scope check also catches edits outside `## Files` that were committed before `close-story`, counting from the head recorded at claim. A subagent cannot `git commit` or `git add` while a DRIVER holds the spec, and worker prompts say never to commit.
> 9. A story's approved version is bound to a commit that `cycle.sh` itself made, not to a commit subject.
> 10. Only files `cycle.sh` writes count as paperwork. A hand edit of `brief.md` or `plan.md` stales the round and is reported, and paperwork commits stage the named files, not the spec folder.

## Files
- scripts/cycle.sh
- scripts/lib.sh
- scripts/scope-check.sh
- .claude/commands/vulyk-build.md
- .claude/commands/vulyk-plan.md
- docs/cycle.md
- docs/adr/032-*.md
- tests/cycle.test.sh
- tests/council.test.sh
- tests/solo.test.sh
- tests/e2e.test.sh
- scripts/defects-check.sh

## Non-goals
- Do not touch `git-guard.sh` (story 07 closes `revise` and the other Queen verbs to subagents), `install.sh`,
  `settings.json`, `human-check.sh` or `ship-check.sh`: `verdict_stale` changes through `lib.sh` alone.
- `VERSION`, `CHANGELOG.md`, `CITATION.cff`, `memory/stats/*.jsonl`, `journal.md` and `council/` stay paperwork.
- `close-story` and `stamp-red` never seed a record and never read a commit subject: a missing record at Tier 3-4
  is exit 2. Seeding is `claim`'s and `branch`'s, once, with a journal line.
- No ledger of commits, no trailer, no new committed file: the records live in the cycle's run state beside the
  verify records.
- Do not change the driver (`vulyk-cycle.js`), the verdict rule or the red-receipt checks.
- In `tests/solo.test.sh` and `tests/e2e.test.sh` change fixture lines only (a helper that makes a Tier 3-4
  fixture claim or branch first). Fix the fixture, never the gate. A fourth suite that trips is `NEEDS_CONTEXT`.
- Finish every test-file edit before `stamp-red`: the sealed tests are not edited after the receipt.
- In the two commands change only the sentences about committing a revised story or plan.

## Map slice
`memory/map/cycle.md` → Files one writer each, Verbs (Story trust from git, close-story, Cycle-owned run state,
`claim`), Staleness, Repair; `memory/map/scripts.md` → Entry points (`lib.sh`, `scope-check.sh`), Key contracts,
Gotchas; `memory/map/agents-and-commands.md` → Commands (0.50 command changes).

## Acceptance criteria
- [ ] Scope, original case: a Tier 3 story, claimed; a file outside `## Files` is edited and committed before the
  close; `close-story --commit` exits 4 `edited outside ## Files` naming the file (label contains `an edit
  committed before the close is out of scope`). Neighbour: the same edit staged only, and one committed two
  commits back, both refuse. A same-wave sibling's close commit and a paperwork commit in the range do not.
- [ ] A Tier 3 close with no claim record exits 2 `no claim head recorded for wave <W>`; a Tier 1 close passes
  with the stderr note. A second `claim` of the same wave keeps the first head.
- [ ] Approval, original case: after `branch` recorded a story, a commit not made by `cycle.sh` that changes the
  story's `## Verification`, `## Files` or `red:`, whatever its subject, leaves the approved version where it was:
  the close exits 4 `story blocks differ from the approved version`. Neighbour: the same change through
  `cycle.sh revise <story>` is approved and closes.
- [ ] `branch` on a spec with an untracked or modified story exits 2 `commit the plan first`; `repair` records its
  story; a Tier 3 story with no record exits 2 `no approved record for <story>` in `close-story` and `stamp-red`.
- [ ] Seeding: a spec with stories committed before this release and no record gets one from `claim`, with a
  journal line; a record missing after that line makes `claim` exit 2 naming `cycle.sh revise`.
- [ ] Paperwork, original case: a `## Asks` line of `brief.md` or the `**Tier:**` line of `plan.md` changed by
  hand: dirty at close is exit 4 naming the file; committed after `ROUND.head` makes the round stale, and
  `status` names the file and the commit. Neighbour: a `## Stories` line of `plan.md`. A commit holding only
  marker lines or `reopen`'s `## Answers` lines keeps the round current; a `revise` commit of `plan.md` before the
  round is accepted by the wave's closes.
- [ ] A `--commit` verb run with a stray file inside the spec folder commits its named files and leaves the stray
  one out.
- [ ] `docs/cycle.md` describes the three records and `revise`; ADR-032 has a dated amendment stating the rule.
  `bash scripts/prompt-check.sh --touched scripts/cycle.sh .claude/commands/vulyk-build.md
  .claude/commands/vulyk-plan.md` has no error.
- [ ] `defects-check.sh --files` (the close-story block gate) does not run a card's check on that card's own
  `fixtures:` files: a story that adds a fixture to a block card and names it in `## Files` closes; the same file
  under a different card is still checked (original case: story 04's two new fixtures, 2026-11-13).
- [ ] Every part of `tests/cycle.test.sh` and `tests/council.test.sh` is green, and the notes list each fixture
  site that moved.

## Verification
`bash tests/cycle.test.sh --part gates`
`bash tests/cycle.test.sh --part close`
`bash tests/cycle.test.sh --part hooklog`
`bash tests/council.test.sh --part verbs`
`bash tests/council.test.sh --part close`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each. End with one `CHANGELOG:` line
per ask (8, 9, 10) that says what the gate does now. -->

## Findings
- 2026-11-14, driver stop: missed twice, "worker returned empty - turn cap suspected (worker-code, maxTurns 90)".
  Both workers built in a scratchpad copy of the repo (cycle.sh 4.7k lines, long test parts) and hit the cap before
  moving anything into the tree; the tree stayed clean. Their partial diff (~660 lines: cycle.sh, lib.sh,
  scope-check.sh, defects-check.sh, cycle and council tests) is saved, untracked, at
  `.vulyk/reports/audit-fixes-1113/story-09-partial.patch`. Sent to lead-architect for a split.
