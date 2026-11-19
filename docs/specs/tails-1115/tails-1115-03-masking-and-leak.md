---
story: tails-1115-03
spec: tails-1115
status: done
returned: DONE
tier: 3
worker: worker-code
wave: 2
blocked_by: []
red: required
red_reason: a journal line is refused when masking cannot run
red_verified_at: 2026-11-17T10:04:50Z 7be6da4cd0d9a343b5a8ae154c3c4734bab30ba0ba1567dd190d78b9960f40f2
---

# Masking covers the privately listed shapes, a masking failure stops the write, the leak check covers one more path form

## Goal
Three changes on the path every brief, journal line and ship record goes through.
1. `scripts/redact.sh` and `handoff.py` `_REDACT_FALLBACK` mask the shapes of private item S15, with parity rows
   that run both filters on the same inputs.
2. `scripts/journal.sh` and `ship-check.sh --record` refuse when masking cannot run (private item S16): non-zero
   exit, nothing written, as `human-check.sh` and `acceptance-log.sh` already do (plan.md `## Contracts` R1).
3. `scripts/leak-check.sh` flags the path form of private item S17.

Private input, read before writing a line: `~/.vulyk/audits/known-defects-2026-11-15/security.md`, items S15,
S16, S17. It holds the exact forms. Nothing from it goes into the repo except as test inputs with synthetic
values; no comment, label, note or commit text says which form was open before. Marked red: parsers and a
data-write refusal on a security path.

## Requirements
> 4. Secret masking and leak checking cover the shapes listed privately, and a masking failure stops the write instead of passing it through (S15-S17); CI actions are pinned to immutable versions (S18).
> 10. Every fix that code can check gets a failing test with the original case and a neighbour form; all suites green.

## Files
- scripts/redact.sh
- .claude/hooks/handoff.py
- scripts/journal.sh
- scripts/ship-check.sh
- scripts/leak-check.sh
- tests/maintenance.test.sh
- tests/handoff-hooks.test.py
- tests/defects.test.sh
- CLAUDE.md

## Non-goals
- In `handoff.py` touch only `_REDACT_FALLBACK` and its helpers: story 07 edits the window logic in wave 3.
- In `ship-check.sh` touch only the `--record` masking call: story 09 adds a gate step in wave 4.
- Do not change the mask text or any existing rule's result. Ordinary text stays byte-identical: the corpus check
  of the redact blocks (every brief and journal) stays green, and each new rule gets neighbour rows that must stay
  unmasked (a keyword with no value, a look-alike flag, a value too short to be a secret).
- Do not edit `tests/maintenance.test.sh` outside the redact blocks, nor `tests/defects.test.sh` outside the leak
  rows (guards-1115 edits the owner-guard block of that file).
- A test fixture outside `## Files` that journals or records in a scratch tree with no `redact.sh` is
  `NEEDS_CONTEXT`, naming file and part; do not weaken the refusal to keep it green.
- The leak rule keeps passing what passes today: a URL, a path under the repo root, a `<placeholder>` first
  segment, system locations.
- Run `bash scripts/portability-check.sh scripts/redact.sh scripts/journal.sh scripts/ship-check.sh
  scripts/leak-check.sh` after each edit (BSD sed: ERE with `-E`).

## Map slice
`memory/map/scripts-hooks.md` → Entry points (`redact.sh`, `handoff.sh` / `_REDACT_FALLBACK`);
`memory/map/scripts-checks.md` → Entry points (`leak-check.sh`); `memory/map/scripts.md` → Entry points
(`ship-check.sh`), Gotchas.

## Acceptance criteria
- [ ] Every form of S15 has a row in the redact block of `tests/maintenance.test.sh` that expects the mask in
  place of a synthetic value, and a parity row through `h.redact_text` with the same result.
- [ ] Each class of S15 has neighbour rows that stay readable, and the ordinary-text corpus is byte-identical.
- [ ] With `redact.sh` missing, and with it failing (`[VULYK:REDACT-FAILED]`, exit 1), `journal.sh` exits non-zero
  and the journal file is unchanged. The label contains `a journal line is refused when masking cannot run`.
  Neighbour: `ship-check.sh --record` in the same two states exits non-zero and `plan.md` is unchanged. With a
  working `redact.sh` both write as today.
- [ ] `bash scripts/leak-check.sh <file>` exits 1 on a file holding each spelling of the S17 form with synthetic
  names, and 0 on a file holding only look-alikes that are no such path (a URL among them).
- [ ] Every new case fails on HEAD; the notes list them by class, never by form.

## Verification
`bash tests/maintenance.test.sh --part upkeep`
`bash tests/maintenance.test.sh --part redact`
`bash tests/maintenance.test.sh --part guards`
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh`
`bash tests/handoff.test.sh`
`bash scripts/py.sh -m py_compile .claude/hooks/*.py`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each. End with one `CHANGELOG:` line
per item that says what is masked or refused now by class, never which form was open. -->
- scripts/redact.sh: more secret shapes are masked (inflected ru/uk keywords, Cyrillic values, passwords in prose, more user:pass commands, long secret flags).
- .claude/hooks/handoff.py: the same rules in `_REDACT_FALLBACK`, same order, with `_infl` and helpers beside it; nothing else touched.
- scripts/journal.sh: masks before it creates or appends; no redact.sh, a failing one or empty output -> stderr refusal, exit 1, file untouched.
- scripts/ship-check.sh: `--record` refuses (exit 1, plan.md and ship.jsonl untouched) with no or a failing redact.sh; header comment says so.
- scripts/leak-check.sh: one more path rule (a path on another machine), a URL still passes; no new hit across the tracked tree.
- tests/maintenance.test.sh: one new redact block (R15 rows, parity through redact_text and redact_builtin, journal/record refusal in scratch trees); tests/defects.test.sh: two hit rows and one look-alike row in the leak block.
- Decision: command-argument credentials are masked after known client commands only, since other commands use the same argument shape for non-secrets.
- New cases by class, each red on HEAD: long secret flags, inflected keywords, non-ASCII values, command-argument credentials, the journal and record refusals, the share path.
- CLAUDE.md: the `Maintenance` row is now `Maintenance part` (`bash tests/maintenance.test.sh --part <topic>`); the line under `## Commands` drops `A story's` and `a ... row` to pay for it: 7166 bytes with CR removed (cap 7168). Then upkeep's baa5219 check (no bigger than 7162) failed: "output is resent each turn" became "output resent per turn", 7162 bytes.
- CHANGELOG: redact.sh and the handoff fallback mask more secret shapes: long secret flags, inflected Russian/Ukrainian keywords, Cyrillic values, user:pass arguments of more commands.
- CHANGELOG: journal.sh and ship-check.sh --record refuse to write when masking cannot run.
- CHANGELOG: leak-check.sh flags one more path form.

## Findings
- close-story exit 4: `verification timed out after 300s: bash tests/maintenance.test.sh`. Measured on this tree
  (a wave-mate's suites running beside it): the whole file 368 s, 1449 checks, 0 failed; by part upkeep 61 s,
  redact 101 s (87 s before this story's block), guards 143 s. The whole file was already near the 300 s line cap
  before this story. Question: may `## Verification` name `bash tests/maintenance.test.sh --part upkeep`,
  `--part redact` and `--part guards` as three lines (card test-gate-one-long-limit: split, never raise)? That is
  an approved-block change, so it is the Queen's revision; the implementation and the sealed tests are in place.

## Red receipt
- command: bash tests/maintenance.test.sh
- exit: 1
- tests: 7be6da4cd0d9a343b5a8ae154c3c4734bab30ba0ba1567dd190d78b9960f40f2 (tests/defects.test.sh, tests/maintenance.test.sh)
- impl: fd071b02f023cc7a3bd004489b17e510e1109f1c919c4ee67f229f639884aa92
- stamped: 2026-11-17T10:04:50Z

```
::error::a journal line is refused when masking cannot run (redact.sh missing): exit 0, journal - 2026-11-17T09:59:46Z · 03-building · note secret=[VULYK:REDACTED] · next: next
::error::a journal line is refused when masking cannot run (redact.sh failing): exit 0, journal [VULYK:REDACT-FAILED]
  ok    ship 2a: the plugin.json version moves with VERSION
  ok    ship 2a: the dev build gets a local tag for the next upgrade
  ok    ship 2a: a reverted canary is held too
  ok    ship 2: in the VULYK source the build number comes from 2a
  ok    ship 2a: the canaries go first
  ok    ship 2a: a red canary stops the rollout
--- beta-fixes-1113-03: a paperwork-only suite.log head, --go from the owner
  ok    lead-review: a suite.log head that differs only by paperwork commits is not reported
  ok    plan: --go comes only from the owner's own words
maintenance.test.sh: 1449 checks, 20 failed
```
- Queen (2026-11-17): yes, split (card test-gate-one-long-limit) into the three parts. A verification line must be a
  `## Commands` cell, and none takes `--part` for this file yet, so `CLAUDE.md` joins `## Files` for one change only: the
  `Maintenance` row becomes a `Maintenance part` row whose cell is `bash tests/maintenance.test.sh --part <topic>`
  (like `Council part`). CLAUDE.md must stay under 7168 bytes with CR removed (tests/cycle.test.sh pins it; it is
  at 7162): pay for the extra bytes by shortening another VULYK-only Commands row or the line under the table,
  never a Law, the Profile, or a row label tests key on (`Anomaly telemetry contract tests`, `(round-only)`).
  Later stories that name the whole file are revised by the Queen to the parts.
  Order: make the CLAUDE.md change first, check the cap, then return NEEDS_CONTEXT; the Queen then switches
  `## Verification` to the three `--part` lines (advance checks them against the row) and you close.
- Builder (2026-11-17): the CLAUDE.md change is made, 7166 bytes with CR removed. Waiting for `## Verification` to
  name `bash tests/maintenance.test.sh --part upkeep`, `--part redact` and `--part guards`, then close-story.
