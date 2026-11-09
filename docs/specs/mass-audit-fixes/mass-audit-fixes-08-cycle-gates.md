---
story: mass-audit-fixes-08
spec: mass-audit-fixes
status: done
returned: DONE
tier: 4
worker: worker-code
wave: 2
blocked_by: [mass-audit-fixes-01, mass-audit-fixes-05]
red: required
red_reason: needs **Approved:** or an explicit --go
red_verified_at: 2026-11-09T13:48:22Z 8b516e77ed67830b9e4e5b914b24cd7ea5e339cc62b54c5fc057656d1c56fd69
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
- tests/solo.test.sh

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
`bash tests/solo.test.sh`

## Implementation notes
- First pass stopped before any edit on the solo.test.sh finding below; built after the Queen's ruling.
- scripts/cycle.sh: `go_guard` (D4) in `briefed` and `branch`, both take `--go`; branch also passes a Briefed line carrying `--go`, and a bare `branch --go` prints a note that it is not recorded.
- scripts/cycle.sh: `briefed --go` writes `via grill (--go)` / `via grill (assumed, --go)` / `via mini-brief (--go)`; on a Briefed line without `--go` it re-stamps once, journal `briefed --go recorded`.
- scripts/cycle.sh: `block_card_gate` (D3) after `red_gate`; exit 1 with no `fails on` line is treated as could-not-run (exit 2), and so is a missing defects-check.sh.
- scripts/cycle.sh: `git_commit_or_fail` takes optional paths and commits `--only -- <paths>`; `commit_paperwork` passes its paths (S5).
- scripts/ship-check.sh: stage 02 reads the plan's tier; at Tier 2-4, a Briefed line with no Approved, no `--go` and no Shipped fails with the D4 message.
- scripts/scope-check.sh: a sibling's declared ## Files drop only when it has the same `wave:`. Surprise: dropping the sibling's own story file for every wave keeps story 05's trust fixtures (one wave per story) green; it is bookkeeping, not code.
- scripts/wave-check.sh: `red-seals-impl` when the sealed set holds a non-test program and nothing else is under ## Files.
- templates/plan.md: the Briefed comment names `cycle.sh briefed <spec> --go` for Tier 2-4.
- tests/cycle.test.sh: new cases in parts ship, close, gates, hooklog; tests/solo.test.sh: a Tier >1 mkfix plan is Briefed `via grill (--go)`.
- The close case for "no python" uses a missing parser (defects_lib.py), which is the same exit 2 branch of defects-check.sh.

## Findings
- NEEDS_CONTEXT (worker, before any edit): D4's `cmd_branch` rule breaks `tests/solo.test.sh`, a file
  outside `## Files`. Its `mkfix` (line 65) writes a Tier `$2` plan with `**Briefed:** via mini-brief` and no
  `**Approved:**`; part `rejected` runs `mkfix ... 2` and `cycle.sh advance`, whose first step is `branch`.
  With this story's gate, `branch` on that Tier 2 plan exits 2 (`Tier 2 plan needs **Approved:** or an
  explicit --go`), so `advance` stops at `branch` and the part fails (Integration gate red). Asked: add
  `tests/solo.test.sh` to `## Files` (the smallest fix: `mkfix` writes `**Briefed:** via grill (--go), ...`
  when `$2` > 1, or an `**Approved:**` line), or name another story that owns it. Other suites checked by grep:
  council.test.sh's branch/advance fixtures with a tier carry `**Approved:**`; e2e.test.sh's Tier 3 plan
  carries `**Approved:**`; maintenance.test.sh's Tier plans never reach `branch`.
- Queen ruling (2026-11-09): `tests/solo.test.sh` joins `## Files` (no other story names it) for the one-line
  `mkfix` change only (a Tier >1 plan carries `**Approved:**` or a `--go` Briefed line), and `bash tests/solo.test.sh`
  joins `## Verification`. No other edit to that suite.

## Red receipt
- command: bash tests/cycle.test.sh --part ship && bash tests/cycle.test.sh --part close
- exit: 1
- tests: 8b516e77ed67830b9e4e5b914b24cd7ea5e339cc62b54c5fc057656d1c56fd69 (tests/cycle.test.sh, tests/solo.test.sh)
- impl: f561a7273b94bc948598d218bb43453359283380c077c11e975b913e58750f18
- stamped: 2026-11-09T13:48:22Z

```
::error::briefed on a Tier 3 plan with no Approved: exit 2 - needs **Approved:** or an explicit --go - expected 'exit=2' in:
::error::briefed on a Tier 3 plan with no Approved names the rule - expected 'Tier 3 plan needs **Approved:** or an explicit --go' in:
::error::branch on a Tier 3 plan briefed without --go: exit 2 - needs **Approved:** or an explicit --go - expected 'exit=2' in:

- 2026-11-09T13:46:55Z · 03-building · branch vulyk/t3old created · next: build:1 - expected '<never>' in:
        
  ok    branch on the --go plan exits 0
  ok    a Tier 1 plan: briefed without --go exits 0 as before
  ok    the Tier 1 line is the plain via grill
  ok    a plan with no tier: briefed without --go exits 0 as before
  ok    ship-check 02 passes a Tier 1 plan briefed without --go
  ok    ship-check 02 passes a no-tier plan briefed without --go
  ok    branch on a Tier 1 plan briefed without --go exits 0 as before
```
