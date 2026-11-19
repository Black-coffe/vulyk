---
story: guards-1115-03
spec: guards-1115
status: done
returned: DONE
tier: 3
worker: worker-code
model: opus
wave: 2
blocked_by: [guards-1115-01, guards-1115-02]
red: required
red_reason: a receipt with no stamp-red record is refused
red_verified_at: 2026-11-16T08:30:26Z 584fde22fc6e3ab37faf50d9d80faf9bac8624d834142f5275af9346548b652b
---

# The red gate reads the cycle's own record; stamp-red output never outlives its run

## Goal
`scripts/cycle.sh` after this story (plan.md `## Contracts` D1, R1 cycle half):
1. **Receipt record (D1, private S13).** `stamp-red` leaves the receipt's hashes in the cycle's run state, and
   `close-story`'s red gate accepts a story's receipt only when that record carries the same hashes. A missing or
   different record is a refusal that names `stamp-red`.
2. **Stored-output directory (R1 cycle half, private S1).** A verify record's stored-output directory is read or
   removed only when it is a real directory directly under the temp root, carries `stamp-red`'s own name prefix and
   belongs to the caller. Anything else: the record is dropped with a stderr reason, nothing is read or removed.
3. **Temp output (private S14).** `stamp-red` removes its stored output on every way out except a pause; the next
   `stamp-red` or `open-round` removes own-prefix directories older than a day, under the rule of item 2.

Add the new part `runstate` to `tests/cycle.test.sh` (`PARTS`) for the cases of this story.

`model: opus`: a gate in the script that closes this very story, alone in its wave for that reason.
Private input, read first: `~/.vulyk/audits/known-defects-2026-11-15/security.md` S1 (the `cycle.sh` lines of its
by-file list), S13, S14. Comments, labels and notes say what the gate does now, never what used to pass.

Order of work, because your own close meets the gate you build:
1. Write the sealed tests. 2. Build only the `stamp-red` half of item 1 (the record is written and kept). 3. Run
`stamp-red` on this story: the gate half is still missing, so the test is red and your receipt gets its record.
4. Build the gate half and items 2-3. 5. Close. A refusal of your own story by the new gate is `NEEDS_CONTEXT` with
the line; never write a record by hand.
Stories 01 and 02 are live: a shell command that names the run-state folder is refused to you. Search the scripts
by function name (`state_get`, `verify_rec`), read files with Read; the suites run their own fixtures.

## Requirements
> 1. A subagent cannot forge or alter the cycle's run-state records (claim, approval, verification) through the named form classes: a write tool by any spelling of the path (resolved: letter case, dot-dot, trailing dot or space, a link); a shell writer, a spaced redirect or an in-place editor naming the path; an interpreter naming the path. The shell classes git-guard does not close in 0.54.0 are named open in its header, by class. So history, scope and verification checks read only what `cycle.sh` wrote (private S1, S13).
> 8. Leftover raw test output is not left in the temp folder after a pause (private S14).
> 7. Every closed gap has a failing test with the original form and a neighbour form (Law 6), and no legitimate flow of the Queen, a worker or a council seat is denied (existing suites stay green).

## Files
- scripts/cycle.sh
- scripts/lib.sh
- tests/cycle.test.sh
- tests/council.test.sh
- tests/solo.test.sh
- tests/e2e.test.sh
- docs/cycle.md

## Non-goals
- No signature, no key, no git refs for the records (plan.md, rejected alternative): the hooks of stories 01 and 02
  keep a subagent off the records; this story makes the gate read the record and bounds what a record can name.
- Do not change `claim`, the scope check, `story_blocks_guard` or the approved record; `lib.sh` only if the record
  reader itself must change.
- No transition rule that passes a receipt stamped before this change: a missing record is a refusal
  (`stamp-red --baseline` is the Queen's way to re-stamp).
- Fix a fixture, never the gate: in `tests/council.test.sh`, `tests/solo.test.sh` and `tests/e2e.test.sh` change only
  fixture lines that close a marked story without running `stamp-red`.
- Finish every test-file edit before `stamp-red`. Guard array expansions for bash 3.2 (card `shell-needs-gnu-or-bash4`).
- In `docs/cycle.md` change only the "Run state" and red-receipt sentences.

## Map slice
`memory/map/cycle-state.md` → Cycle-owned run state; `memory/map/cycle.md` → Verbs (Red receipt, Approved version,
`close-story` verify runner); `memory/map/scripts-checks.md` → Tests (split parts).

## Acceptance criteria
- [ ] Original case: a marked story carrying `red_verified_at` and a `## Red receipt` that no `stamp-red` run
  produced does not close: exit 4, the message names `stamp-red` (label contains `a receipt with no stamp-red record
  is refused`). Neighbour: a receipt whose hashes differ from the record's is refused the same way.
- [ ] A story stamped by `stamp-red` closes as today: in one call, after a pause and resume (exit 7), and after
  `stamp-red --baseline`. The existing refusals (`no red receipt`, `test changed after red receipt`, `no
  implementation change since red receipt`) keep their messages.
- [ ] A record naming a stored-output directory outside the temp root, without the prefix, a link, or a file: the
  path is neither read nor removed, the record is dropped with a stderr reason, the run restarts at line 1.
  Neighbour: the directory of a real paused run still resumes.
- [ ] A run that ends red, green, or on a refusal leaves no stored-output directory; a paused one keeps it. The next
  `stamp-red` removes an own-prefix directory older than a day and keeps a younger one and any other temp entry.
- [ ] `docs/cycle.md` says which record the red gate reads and when stored output is removed;
  `bash scripts/prompt-check.sh --touched scripts/cycle.sh` has no error.

## Verification
`bash tests/cycle.test.sh --part runstate`
`bash tests/cycle.test.sh --part red`
`bash tests/cycle.test.sh --part red2`
`bash tests/cycle.test.sh --part close`
`bash tests/cycle.test.sh --part close2`
`bash tests/cycle.test.sh --part approved`
`bash tests/council.test.sh --part close`
`bash tests/solo.test.sh`
`bash tests/e2e.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes
<!-- files changed, decisions, surprises - 1-2 lines each. End with one `CHANGELOG:` line per ask (1, 8) that says
what the cycle does now. -->
- scripts/cycle.sh: `red_rec`/`red_rec_put` write `verify.<id>.stamp-red.receipt` (tests=, impl=, stamped=) on a finished stamp-red; `red_gate` refuses no record / other hashes before its three old refusals, whose messages are unchanged.
- Decision: the receipt record is a file beside the resume record, not keys in `verify.<id>.stamp-red`, so a refused re-stamp keeps the last good record and the resume record still goes away on finish (existing "leaves no record behind" checks in cycle/council stay as they are).
- scripts/cycle.sh: `outd_why` is the one rule for a stored-output path (directly under `sr_root`, `vulyk-sr.` prefix, not a link, a directory, owned); `verify_resume_start` and `verify_rec_drop` use it, so a path failing it is neither read nor removed.
- scripts/cycle.sh: `sr_exit` EXIT trap removes stamp-red's stored output on every exit but a pause (and calls `red_baseline_restore`); `sr_sweep` at stamp-red and open-round removes own-prefix dirs older than a day (`find -mmin +1440`).
- tests/cycle.test.sh: new part `runstate` (in PARTS, shares the red fixtures block). docs/cycle.md: Run state paragraph and row 04 receipt sentence.
- No edit to lib.sh, council.test.sh, solo.test.sh, e2e.test.sh: none of their fixtures closes a marked story without stamp-red.
- CHANGELOG: (ask 1) close-story accepts a red receipt only when stamp-red's own run-state record carries its hashes, and stamp-red uses a recorded stored-output directory only when it is its own under the temp root.
- CHANGELOG: (ask 8) stamp-red removes its raw test output on every exit except a pause, and the next stamp-red or open-round removes such output older than a day.

## Findings

## Red receipt
- command: bash tests/cycle.test.sh --part runstate
- exit: 1
- tests: 584fde22fc6e3ab37faf50d9d80faf9bac8624d834142f5275af9346548b652b (tests/council.test.sh, tests/cycle.test.sh, tests/e2e.test.sh, tests/solo.test.sh)
- impl: 65672237ac6135aa2433aa74fbbfcb98c1150cfb288b7f918602e4c7683f5af2
- stamped: 2026-11-16T08:30:26Z

```
::error::a receipt with no stamp-red record is refused - exit=0 out=cycle: red-50 - closed, verification green
guards-1115-03: stamp-red leaves no stored output on a red, a green or a refusal; a pause keeps it; a day-old one is swept
  ok    a run that ends red leaves no stored output
  ok    a run that ends green leaves no stored output
  ok    a run that ends on a refusal leaves no stored output
  ok    a paused run keeps its stored output
::error::sweep - exit=0 left=other.old
vulyk-sr.bSOTgZ
vulyk-sr.old
vulyk-sr.oldfile
vulyk-sr.young
```
