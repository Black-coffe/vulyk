# ADR-032: A story's gates are read from its committed version; the close is a commit

- Status: accepted (2026-11-09, owner: Andrei, approved with the plan, the `**Approved:**` line of
  `docs/specs/mass-audit-fixes/plan.md`; built by stories 01, 05, 08 and 10 of that spec)
- Date: 2026-11-09
- Spec: docs/specs/mass-audit-fixes (Asks 12, 13, 14; amends ADR-025 D3 and its Consequences)

## Context
`close-story` is the only per-story gate, and every input it trusts lives in the story file the worker must
edit anyway (`returned:`, `## Findings`): the `## Verification` lines it runs, the `## Files` block scope-check
measures, and the `red:` mark that turns the red-receipt gate on. Nothing compares those blocks with the version
the owner approved. A story that reads `status: done` on a clean tree is taken as closed by `close-story`,
`status` and the driver, with no evidence that any check ever ran. A `block` defect card is hidden from agents
"because the gate runs it", and no flow runs `defects-check.sh` with an argument. The approval stop for Tier 2-4
plans is prose: `cycle.sh briefed` opens the build at any tier. ADR-025's only re-stamp escape (stash the
implementation, `stamp-red`, pop) is denied by the 0.48 git guard. The owner chose, for each: trust git, not
the working copy; no new state file; a gate, not a text; a refusal in code. This ADR fixes the shapes.

## Options
1. **Read the gate blocks from the story's approved commit and refuse when the working copy differs (chosen).**
   No new file, no new field; the proof is the commit the cycle already writes.
2. Trust `HEAD:<story>`. Rejected: a worker commits nothing before `close-story`, but nothing stops a commit
   either, so HEAD can be the worker's own version; and a story revised after NEEDS_CONTEXT must be committed
   anyway, so HEAD buys nothing the paperwork grammar does not.
3. Compare against the merge-base with the default branch. Rejected: a repair story is born on the spec branch,
   after the merge-base, and would never have a baseline.
4. A sealed hash of the blocks in the frontmatter (`blocks_hash:`). Rejected: a second worker-editable field
   guarding the first; the committed version is already that hash.
5. A `closed:` frontmatter line as the close evidence. Rejected: worker-editable; the commit is not.
6. Keep injecting a `block` card's Never lines and leave the check to review. Rejected by the owner: a block
   card must be stronger than a text card, so its check runs on real work.

## Decision
- **D1 - the approved version.** The approved version of a story is its content at the newest commit that
  touches the story file and whose subject is a paperwork subject of the cycle: `vulyk(<slug>): <text>`, or
  `chore(vulyk-<slug>): <text>` under conventional commits (`commit_subject`). Today that set is the plan commit
  (`plan`), `asks revised`, `briefed`, `repair round N`, and a new one, `vulyk(<slug>): revised <story-id>`,
  which `/vulyk-build` (after NEEDS_CONTEXT) and `/vulyk-plan` step 9 use when the Queen changes a story's
  `## Files` or `## Verification`. `approved_rev <story>` walks `git log --format=%H%x09%s -- <story>` and
  returns the first such commit; `git show <sha>:<story>` is the baseline. Three blocks are compared, each
  through the parser that already reads it (`verify_of`, `files_of`, `fm_red`), so comments, backticks and
  whitespace never count: `## Verification` (with `repeat:`), `## Files`, and `red:`. Everything else is the
  worker's or stamp-red's (`returned:`, `status:`, `red_reason:`, `red_verified_at:`, `## Red receipt`,
  `## Findings`, implementation notes). Any difference refuses, exit 4, naming the blocks and the short sha:
  `story blocks differ from the approved version (<sha7>): ## Files, red:`. The check runs in `close-story`
  right after the `returned:` check and before scope-check, and in `stamp-red` before it runs anything, so
  every later reader (scope-check, `red_gate`, `verify_of`) reads a working copy proven equal to git.
  **No baseline** (an untracked story, or none of its commits carries a paperwork subject): at Tier 3-4
  (`tier_of`) refuse, exit 2, `no approved version in git for <story>: commit the plan or a revision first`;
  at Tier 1-2, or with no plan.md or tier, one stderr note and the working copy stands. The worker tiers are
  the threat model (Law 5); the Queen's solo story and a test fixture have no second author to distrust.
- **D2 - the close is a commit.** The evidence that `close-story` closed a story is its own commit, subject
  `story(<id>): <title>` (`chore(story-<id>): ...` under conventional commits), which always carries the story
  file. `cmd_status` reads `git log --format=%s -- <spec>/` once per call and counts a `done` story as done only
  when such a subject exists for its id; otherwise it is counted and listed as `in-progress`, so `wave_stories`
  keeps it and the driver's `left.has` reads it as a miss, with no driver change. `close-story` on a `done`
  story with a clean tree and no close commit no longer answers "already done": it takes the self-marked path
  (`returned:` check, D1, scope, red gate, D3, verification) and, green, writes the close commit even when
  nothing but the story is staged (`--allow-empty`), journaling `closed over a hand-committed tree`. The scope
  row of such a story reads `changed 0`; the journal line is what says why.
- **D3 - the block-card gate.** `defects-check.sh` gains `--files <path>...`: for every card that declares
  `block` with a `check:`, the check runs once per given file that matches one of the card's glob `paths:`
  (a `cmd:`/`tool:` entry matches no file and never runs here); exit 0 green, 1 red (one line per red:
  `<ref> fails on <file>: <first output line>`), 2 no python or no parser. `close-story` calls it once, after
  `red_gate` and before prompt-check, with `## Files` expanded to files (`git ls-files -co --exclude-standard`
  per entry, as `red_sets` does), only when a card file under `docs/defects/` says `status: block`; a red is
  exit 4 `defect card <ref> fails on <file>`, exit 2 from the gate is exit 2 `defect gate could not run`
  (fail closed, like `no sha256 tool`). The hook treats every non-revoked card as text: `injected_as` loses
  its `block` branch and the header no longer says "no check guards them". The hook stays cheap in bash:
  it lists card files (`docs/defects/*.md`, `docs/defects/*/*.md`, never `README.md`/`INDEX.md` in any case
  and never `fixtures/`) and exits before Python when there are none; for a tool with no path and no command
  line it exits unless `grep -lF 'tool:'` over those card files finds one. The Read skip stays as it is.
- **D4 - the approval stop in code.** `cmd_briefed` takes `--go`. At Tier 2-4 with no `**Approved:**` and no
  `--go` it refuses, exit 2, `Tier <N> plan needs **Approved:** or an explicit --go`. With `--go` the variant
  carries it: `**Briefed:** via grill (--go), <owner>, <date>` / `via grill (assumed, --go), ...`; on an
  existing Briefed line `--go` re-stamps it (idempotent, journaled `briefed --go recorded`), which is the
  migration for a hive mid-build. `cmd_branch` applies the same rule before creating the branch. `ship-check`
  stage 02 at Tier 2-4 passes on `**Approved:**`, or a `**Briefed:**` containing `--go`, or any marker when
  `**Shipped:**` is already set (a shipped spec is history, not a pack to judge); otherwise `fail 02 "plan:
  Tier <N> was briefed without approval or --go - run cycle.sh briefed <spec> --go --commit if the owner opted
  out"`. Tier 1 and a plan with no tier keep today's rule. ADR-001 D1's "accept either" is amended to this.
- **D5 - the re-stamp escape.** `stamp-red <story> --baseline` does inside the verb what ADR-025 asked the
  Queen to do by hand: it copies the story's implementation set (`RED_IMPL`) aside, writes each file back to
  its HEAD content (`git show HEAD:<p>`; a file new since HEAD is removed), runs the stamp, and restores the
  copies in a trap, whatever the exit. No `git stash`, so the git guard, which passes `stamp-red` already, has
  nothing to deny, and no stash entry can be lost. Workers still never run it (worker-code: NEEDS_CONTEXT
  naming the test edit); the Queen runs it after `/vulyk-pause`, as ADR-025 says. ADR-025 Consequences,
  second bullet, gets a one-line pointer here.

## Named bypasses (card `safeguard-bypassable-or-late`)
- **A worker commits under a forged paperwork subject.** D1 would then take its version as approved. Nothing in
  code stops a subagent's `git commit`; the worker prompt forbids committing outside `close-story`, and
  `lead-review` reads the branch log, where a `vulyk(<slug>):` commit not followed by a plan/repair/revision
  action stands out. Recorded, not closed: denying subagents `git commit` would also deny legitimate hives.
- **The Queen revises blocks and commits `revised <id>` at Tier 3-4.** Allowed on purpose (NEEDS_CONTEXT needs
  it); the commit is visible in the log and `lead-review` reads it with the story diff.
- **The owner's terminal.** `**Approved:**` written by hand, a `--go` re-stamp, a story closed or a stash run
  outside the session. These are the owner's levers and stay so; the journal lines (D2, D4) record them.
- **A `block` card without glob `paths:`.** Its check never runs in D3; the hook shows its Never lines, and
  `defects-check.sh` audit reports it as `block with no file scope` so the card author sees it.

## Consequences
- `close-story` gains two git reads (`log`, `show`) per call; `status` one `git log` per call.
- Test fixtures that hand-write `status: done`, or run `close-story` on an untracked story under a Tier 3-4
  plan, must first commit it under a paperwork subject; `tests/cycle.test.sh` gets one helper for that.
- A hive mid-build on a Tier 2-4 plan briefed without `--go` needs one owner command (`briefed --go --commit`)
  before `branch`, `claim` or `ship-check` pass; the refusal names it.
- ADR-025 D3 now reads `red:` from the approved version; ADR-025's stash escape is superseded by D5.
- The `defects-check.sh <arg>` gate form (every block card on one argument) stays for scripts that call it;
  `--files` is the form the cycle uses.

## Invariants created
- `close-story` and `stamp-red` read no gate block (`## Verification`, `## Files`, `red:`) before the working
  copy is proven equal to the story's approved version in git; at Tier 3-4 a story with no approved version
  does not close.
- A story is closed only by a commit whose subject is `story(<id>):` (or its conventional form); `status: done`
  without it is in progress, for `status`, the driver and `close-story` alike.
- A `block` card's check runs in `close-story` on every declared file its `paths:` match, and its Never lines
  are shown to agents like a text card's; a red check refuses the close.
- The build of a Tier 2-4 plan opens only on `**Approved:**` or a `**Briefed:**` line that records `--go`;
  `briefed`, `branch` and ship-check stage 02 apply one rule.
- The cycle never asks an agent to run a git verb the guard denies; a documented escape is a `cycle.sh` verb.

## Revisit when
A hive needs a second paperwork subject grammar (D1's set grows past what one regex holds); `status` on a spec
of 40+ stories measurably slows on the extra `git log`; a forged-subject close is seen in a review (then the
subagent `git commit` deny is on the table); or a block card legitimately needs a `cmd:`-only scope to run at
close time.
