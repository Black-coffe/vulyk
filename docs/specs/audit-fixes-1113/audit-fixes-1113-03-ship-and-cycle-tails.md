---
story: audit-fixes-1113-03
spec: audit-fixes-1113
status: done
returned: DONE
tier: 3
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: an output rewritten by a later line reached the verdict
red_verified_at: 2026-11-13T21:00:28Z 1826d8926c75ae069ccdcaba09697415363bb948e2e2509c0041e947ffc8f21b
---

# stamp-red re-hashes stored output; the ship text gains its review and its pin; skills.json is no clean-tree exception

## Goal
Four small changes in the cycle scripts and the ship command.
1. `cycle.sh stamp-red`, on a resumed run, hashes each stored `<k>.out` and compares it with the hash in the verify
   record before it reads the file again; a mismatch drops the record and restarts at line 1 with a stderr reason.
   The parked tests come in from branch `wip/a2-minor-tests` (commit `ad70ef80`, `tests/cycle.test.sh`, 46 lines):
   read them with `git show ad70ef80 -- tests/cycle.test.sh` and apply the hunk by hand. One of the three cases
   fails today; it is this story's red.
2. `/vulyk-ship` already pushes a spec branch only to a private origin and asks the owner on a public one (commit
   `86e15292`). A test now pins that text and the card's Never line.
3. The publish step of `/vulyk-ship` gains an outward-text review. Before the publish command is printed,
   `lead-review` reads the CHANGELOG section going out, the release notes and the `UNASKED:` / Minor lines of the
   spec folders being published, under one explicit rule: flag every line that names a gate bypass or a hole not
   fixed in the version being published. The main session moves each flagged line to a private file under
   `~/.vulyk/` and removes it from the outward text; the publish command is printed only after a clean pass. Card
   `public-release-per-change` gets one Never line for it.
4. `memory/stats/skills.json` is untracked and gitignored (the Queen did that before this wave), so the clean-tree
   exceptions made for it go: in `lib.sh` `is_paperwork_path`, in `ship-check.sh` and in `scope-check.sh`. Any step
   of `/vulyk-ship` that commits the counters goes too.

Marked red: a hash check on the red-receipt path.

## Requirements
> 20. `stamp-red` re-hashes `<k>.out` against its record before the re-read, and the parked tests from `wip/a2-minor-tests` come in.
> 3. `/vulyk-ship` pushes a spec branch only to a private origin; with a public origin it asks the owner (landed as Tier 0 in 86e15292); a test pins it.
> 21. `/vulyk-ship` reviews outward text before every publish. A reviewer reads the CHANGELOG, the release notes and the UNASKED/Minor lines of the spec folders being published, by an explicit rule, and a line naming an unfixed gate bypass or hole moves to private notes.
> 2. `memory/stats/skills.json` is no longer tracked (`git rm --cached`, gitignored) and public history is not rewritten. It counts only VULYK's own skills and `vulyk-*` commands and lives locally. `install.sh` does not ship it, no ship step commits it, and the clean-tree exceptions made for it are gone.

## Files
- scripts/cycle.sh
- scripts/lib.sh
- scripts/ship-check.sh
- scripts/scope-check.sh
- .claude/commands/vulyk-ship.md
- docs/defects/public-release-per-change.md
- docs/defects/INDEX.md
- tests/cycle.test.sh
- tests/council.test.sh

## Non-goals
- In `cycle.sh` touch only the stamp-red resume path. `approved_rev`, the scope call, `claim` and
  `commit_paperwork` are story 09's in wave 3; `brief.md` / `plan.md` stay in `is_paperwork_path` until then.
- Do not change what `/vulyk-ship` pushes or when: item 2 is a pin of text that already landed.
- The review step dispatches an agent that exists (`lead-review`) and adds no script.
- Do not run `git cherry-pick`, `git add` or `git commit`: `close-story` commits your paths.
- Do not touch `memory/stats/skills.json`, `.gitignore`, the counter hook or `session-start-brief.sh` (story 05)
  or `install.sh` (story 06).
- Run `bash scripts/defects-index.sh` after the card edit; never edit `INDEX.md` by hand.

## Map slice
`memory/map/cycle.md` → Verbs (Red receipt, Cycle-owned run state); `memory/map/scripts.md` → Entry points
(`lib.sh`, `ship-check.sh`, `scope-check.sh`), Key contracts; `memory/map/agents-and-commands.md` → Commands
(`/vulyk-ship`).

## Acceptance criteria
- [ ] The three parked cases are in `tests/cycle.test.sh`; the one that fails on HEAD passes after the change and
  its label is the story's `red_reason`. A stored output changed between two `stamp-red` calls makes the resume
  restart at line 1 with a stderr reason; an untouched one still resumes.
- [ ] Cycle part `ship` pins: `vulyk-ship.md` carries the private-origin rule and the question to the owner on a
  public origin, and has no instruction to push a spec branch to `origin` unconditionally; the card has its Never
  line on spec branches. Removing either sentence fails the pin.
- [ ] Cycle part `ship` pins the review step: the three sources by name, the rule sentence, the move to private
  notes, and that the publish command comes after it. The card has the new Never line and `INDEX.md` is fresh
  (`bash scripts/defects-index.sh --check` exits 0).
- [ ] With a fixture repo that tracks `memory/stats/skills.json` and has it modified: `is_paperwork_path` answers
  no, `ship-check.sh` reports the tree dirty, `scope-check.sh` lists the file as out of scope. Existing cases that
  pinned the exception are flipped, not deleted.
- [ ] `vulyk-ship.md` names no step that stages or commits `skills.json`.
- [ ] `bash scripts/prompt-check.sh --touched .claude/commands/vulyk-ship.md scripts/cycle.sh` reports no error.

## Verification
`bash tests/cycle.test.sh --part red`
`bash tests/cycle.test.sh --part red2`
`bash tests/cycle.test.sh --part ship`
`bash tests/cycle.test.sh --part gates`
`bash tests/cycle.test.sh --part close`
`bash tests/cycle.test.sh --part hooklog`
`bash tests/council.test.sh --part seats`
`bash tests/council.test.sh --part escalate`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each. End with one `CHANGELOG:` line
per ask (20, 3, 21, 2). -->
- `tests/cycle.test.sh`: the three parked `wip/a2-minor-tests` cases applied from `ad70ef80` (sr34 was the red; sr35/36 passed already, sr37 skips without passwordless sudo).
- `scripts/cycle.sh` stamp-red: after the last line runs and before the verdict, every `<k>.out` is re-hashed against its `line=` entry; a mismatch refuses (exit 4, "stored output of line <k> changed after it was checked") and drops record and directory. The resume path's own re-hash (upgrade-findings-07) was already there.
- `scripts/lib.sh`, `scripts/ship-check.sh`, `scripts/scope-check.sh`: skills.json exceptions removed (scope-check had only the comment; it goes through `is_paperwork_path`).
- `tests/cycle.test.sh` flips: hooklog commits a tracked skills.json, then pins is_paperwork_path no / scope-check `! memory/stats/skills.json` / ship-check 03 not clean; close part: an undeclared skills.json now refuses; the stray-06 foreign-staging case uses `memory/stats/evolve.jsonl` as its foreign paperwork path instead (its subject is staging, not the exception).
- `tests/council.test.sh` flips (the earlier Findings question, resolved by the revision naming the file): a skills.json commit stales the round (seats); a dirty skills.json is refused by open-round's clean check (escalate); learnings-only cases kept.
- `.claude/commands/vulyk-ship.md` step 3 gains the `lead-review` outward-text review before the publish command; no step there named skills.json. Card `public-release-per-change` gains one Never line; `INDEX.md` regenerated by `defects-index.sh`.
- Ship part pins: flattened-text sentence pins for the spec-branch rule, the card Never lines and the review step, plus a line-order check (review before `to publish, run:`).
- CHANGELOG: ask 20 - stamp-red re-hashes each stored line output against its record before the verdict reads it; the parked A2-minor stamp-red tests are in the suite.
- CHANGELOG: ask 3 - a test pins `/vulyk-ship`'s spec-branch rule (push only to a private origin, ask the owner on a public one) and its card line.
- CHANGELOG: ask 21 - `/vulyk-ship` has `lead-review` read the outward text (CHANGELOG section, release notes, published UNASKED/Minor lines) before printing the publish command; flagged lines move to a private file.
- CHANGELOG: ask 2 - `memory/stats/skills.json` is no longer a clean-tree exception in `is_paperwork_path`, ship-check or scope-check.

## Findings
- NEEDS_CONTEXT (builder, before any edit): removing `memory/stats/skills.json` from `lib.sh` `is_paperwork_path` (ask 2,
  required by the acceptance criteria) turns two cases in `tests/council.test.sh` red, and that file is not under
  `## Files`: line ~1248 "record-seat: still NOT stale after a commit touching only skills.json + memory/learnings/*.md
  (C2)" (`paperwork_only` now calls the skills.json commit code, `stale` becomes true) and line ~2369 "open-round:
  preconditions - only skills.json/learnings dirty -> not refused as unclean" (open-round's dirty check now refuses).
  plan.md recon question 3 says a pin outside `tests/cycle.test.sh` joins story 03 or 05; no scout ran, so it was not
  added. Question: add `tests/council.test.sh` to this story's `## Files` (flip both cases, verification gains
  `bash tests/council.test.sh --part <part holding them>`), or hand those two flips to story 09 (wave 3, already names
  `tests/council.test.sh`) and accept a red council suite between waves 1 and 3?

## Red receipt
- command: bash tests/cycle.test.sh --part red
- exit: 1
- tests: 1826d8926c75ae069ccdcaba09697415363bb948e2e2509c0041e947ffc8f21b (tests/council.test.sh, tests/cycle.test.sh)
- impl: f4aab3511979648845d90b0e9cc3d7b727b0bbb67cafa040abafaacee530b3b0
- stamped: 2026-11-13T21:00:28Z

```
::error::an output rewritten by a later line reached the verdict - exit=0 calls=2 out=cycle: red-34 - red receipt written (bash tests/sr34.sh exits 1)
  ok    no test-shaped path: the seal falls back to every verification path under ## Files
red-receipt: close-story on a marked story that was never stamped
  ok    the unstamped story: exit 4, nothing committed
  ok    the refusal names stamp-red and the story
beta-fixes-1113 (ask 7): a quoted red_reason: matches as an unquoted one; an inner or unmatched quote is compared as written
  ok    red_reason: "acme: boom" (double quotes) stamps on a line holding acme: boom
  ok    red_reason: 'acme: boom' (single quotes) stamps on a line holding acme: boom
  ok    red_reason: acme: boom (unquoted) stamps as before
  ok    red_reason: it's red (an inner quote) is compared as written
  ok    red_reason: "half (an unmatched quote) is compared as written: no line holds "half
```
