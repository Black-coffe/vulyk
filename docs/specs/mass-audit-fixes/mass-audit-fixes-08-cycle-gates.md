---
story: mass-audit-fixes-08
spec: mass-audit-fixes
status: todo
returned:
tier: 4
worker: worker-code
wave: 2
blocked_by: [mass-audit-fixes-01, mass-audit-fixes-05]
red: required
red_reason: needs **Approved:** or an explicit --go
---

# The approval stop, the block-card gate, same-wave scope and pathspec paperwork commits

## Goal
Four gates land in the cycle, all in `scripts/cycle.sh` and its neighbours. ADR-032 D4: `cmd_briefed` takes
`--go`; at Tier 2-4 with no `**Approved:**` and no `--go` it refuses (exit 2, `Tier <N> plan needs
**Approved:** or an explicit --go`); with `--go` the Briefed line carries `(--go)` and re-stamps an existing
line (journal `briefed --go recorded`); `cmd_branch` applies the same rule; `scripts/ship-check.sh` stage 02 at
Tier 2-4 passes on `**Approved:**`, a `**Briefed:**` containing `--go`, or any marker once `**Shipped:**` is
set, else fails with the message in plan.md `## Contracts`. ADR-032 D3 call site: `close-story` runs
`defects-check.sh --files` (story 01) on the expanded `## Files` after `red_gate`, only when a card says
`status: block`; red is exit 4 `defect card <ref> fails on <file>`, gate exit 2 is exit 2 `defect gate could
not run`. `scripts/scope-check.sh` drops a sibling's declared paths only when the sibling is not `done` and in
the same `wave:` (G3) and gets the G4 fixture (a rename out of scope into a declared dir counts). `scripts/
wave-check.sh` reports `red-seals-impl` when a sealed program is also the only implementation in `## Files`
(G8). `commit_paperwork` commits by pathspec (`--only`), never the whole index (S5). `templates/plan.md`'s
Briefed comment names `--go`. Asks 14, 13, 11 (I4, G3, G4, G8, S5). Marked red: gate branches.

## Requirements
> 14. `cycle.sh` refuses to open the build of a Tier 2-4 plan without the owner's `**Approved:**` or an explicit `--go`, records the `--go`, and the pre-release check requires the same.
> 13. A `block` defect card's check runs in close-story on the story's matching files and a failure refuses the close; the card's never-lines are shown to agents again.
> 11. Every finding of our private audit that the merged branch does not close (Scope E) is fixed, with a regression test wherever code can check it.

## Files
- scripts/cycle.sh
- scripts/ship-check.sh
- scripts/scope-check.sh
- scripts/wave-check.sh
- tests/cycle.test.sh
- templates/plan.md

## Non-goals
- Do not touch `approved_rev`, the D1 compare or the D2 status counting (story 05, landed); do not write
  `stamp-red --baseline`, `verify_files_hash` or the `git add` check (story 10, wave 3).
- Do not change `defects-check.sh` itself; consume its `--files` contract as story 01 shipped it.
- Do not edit `.claude/commands/*.md` or `docs/`: story 13 follows with the prose (`/vulyk-plan --go` →
  `briefed --go`).
- Tier 1 and a plan with no tier keep today's `briefed` behaviour.

## Map slice
`memory/map/cycle.md` → Verbs (briefed, branch, close-story, Branch guard), `status --json` `next`, Repair
(paperwork subjects); `memory/map/scripts.md` → Entry points (`ship-check.sh`, `scope-check.sh`,
`wave-check.sh`), Key contracts (`is_paperwork_path`).

## Acceptance criteria
- [ ] `--part ship`: a Tier 3 plan with no Approved: `briefed` exits 2 with the message (label contains
  `needs **Approved:** or an explicit --go`); `briefed --go` writes `via grill (--go)`; `--go` on an existing
  Briefed line re-stamps once, idempotent; `branch` refuses the same plan without `--go`; ship-check stage 02
  fails a Tier 3 Briefed-without-`--go` plan, passes it with `--go`, and passes a `**Shipped:**` plan either way.
  A Tier 1 plan and a plan with no tier behave as before.
- [ ] `--part close`: with a fixture block card whose check fails on a declared file, `close-story` exits 4
  naming the card and the file; with no block card the gate does not run; a check needing no python exits 2
  `defect gate could not run`; a `block` card whose `paths:` match nothing in `## Files` runs nothing.
- [ ] `--part gates`: a wave-1 story's edit of a file only a wave-2 todo story declares counts as out of scope;
  a same-wave sibling's file is still dropped; a `git mv` of an out-of-scope file into a declared directory
  reports `out of scope 1` (G4 fixture); `wave-check` prints `red-seals-impl` for a red story whose
  verification calls its one implementation script, and nothing for a suite-only verification.
- [ ] `--part hooklog`: a `--commit` verb with a foreign file staged commits only its paperwork paths and leaves
  the foreign file staged.

## Verification
`bash tests/cycle.test.sh --part ship && bash tests/cycle.test.sh --part close`
`bash tests/cycle.test.sh --part gates && bash tests/cycle.test.sh --part hooklog`

## Implementation notes

## Findings
