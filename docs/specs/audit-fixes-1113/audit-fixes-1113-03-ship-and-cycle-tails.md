---
story: audit-fixes-1113-03
spec: audit-fixes-1113
status: todo
returned:
tier: 3
worker: worker-code
wave: 1
blocked_by: []
red: required
# red_reason: the failing label of the parked stamp-red case, copied from the test before `stamp-red`
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

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each. End with one `CHANGELOG:` line
per ask (20, 3, 21, 2). -->

## Findings
