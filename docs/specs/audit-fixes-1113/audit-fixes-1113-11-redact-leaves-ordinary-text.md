---
story: audit-fixes-1113-11
spec: audit-fixes-1113
status: done
returned: DONE
tier: 3
worker: worker-code
wave: 4
blocked_by: [audit-fixes-1113-02, audit-fixes-1113-07, audit-fixes-1113-08, audit-fixes-1113-09, audit-fixes-1113-10]
red: required
red_reason: redact.sh leaves a password length in prose alone
red_verified_at: 2026-11-14T01:27:12Z 8ba3ab3ed146caa3a6249d7171e38a74362142d46c9f8aeb41f90c71af430713
---

# redact.sh leaves ordinary text alone, and its callers refuse when it fails

## Goal
Story 02 widened `scripts/redact.sh`. Its worker named forms of ordinary text the new masks also catch. Every
`brief.md` holds the owner's words verbatim and goes through `redact.sh` before it is committed, so a false mask
changes a requirement without anyone seeing it. This story narrows the masks to what is a secret and makes the
callers fail loud. Cut by the Queen mid-build (plan.md `## Plan deltas`, 2026-11-13) on a note the owner forwarded.
1. Corpus: every tracked `docs/specs/*/brief.md` and `docs/specs/*/journal.md` passes `redact.sh` byte-identical.
   A file that does not is either a real secret (none is expected: say so in the notes) or a mask to narrow.
2. Ordinary neighbours pass unchanged, each beside a real secret of the same shape that is still masked: prose that
   names a secret word followed by a plain number or word ("the password is 8 chars"); a 40-character base64 run or
   path that is no key; `docker -u name:group`; a command line with several `-p` flags (every credential `-p` on
   it masked, none of the others).
3. `.claude/hooks/handoff.py` `_REDACT_FALLBACK` follows every narrowing, and the parity rows stay green.
4. Callers: when `redact.sh` exits non-zero, `human-check.sh` and `acceptance-log.sh` refuse with a clear error and
   write no record, and `cycle.sh` `redact_note` stops passing the marker on as a note (its comment that
   `redact.sh` always exits 0 is corrected). A stub `redact.sh` that fails proves each.

Private input: `~/.vulyk/audits/framework-audit-2026-11-13/FINAL.md` (the redact section) and `redact-open-shapes.md`
beside it. Masks stay on every form story 02 covers; test inputs use synthetic values only.

## Requirements
> 7. `redact.sh` masks: Russian and Ukrainian secret keywords; credentials passed in command arguments; the service-token shapes in the private audit list, with the privately recorded open shapes. If `redact.sh` itself fails, it says so on stderr and records `redact_degraded`; it never passes the text through silently.

## Files
- scripts/redact.sh
- .claude/hooks/handoff.py
- scripts/human-check.sh
- scripts/acceptance-log.sh
- scripts/cycle.sh
- tests/maintenance.test.sh

## Non-goals
- No new secret form, no change to story 02's failure contract (R1).
- No edit to any brief, journal or other spec file.

## Acceptance criteria
- [ ] A corpus row runs `redact.sh` over every tracked `docs/specs/*/brief.md` and `journal.md` and finds each byte-identical.
- [ ] Each neighbour in Goal 2 passes unchanged, and its same-shape secret is still masked.
- [ ] Parity rows: `redact.sh` and `handoff.py`'s fallback give the same output on every new row.
- [ ] With a failing stub `redact.sh`: `human-check.sh` and `acceptance-log.sh` exit non-zero and write nothing; `redact_note` does not return the marker as a note.
- [ ] Every row of story 02's `redact.sh 1113` block still passes.

## Verification
`bash tests/maintenance.test.sh`

## Implementation notes
- Corpus: all 134 tracked `docs/specs/*/brief.md` and `journal.md` already passed `redact.sh` byte-identical (CR
  stripped: the blob is LF, Git Bash sed drops CR). No real secret in them; the neighbours below were the open part.
- red_reason rewritten to a failing neighbour row (the corpus row was green before any change).
- scripts/redact.sh: the trade-offs that keep ordinary text unmasked; details (moved to a private file before publishing).
- .claude/hooks/handoff.py: `_REDACT_FALLBACK` mirrors each narrowing (`_NOT_P`, lookaheads for the cloud key).
- human-check.sh, acceptance-log.sh: a non-zero redact.sh exit refuses with exit 1 before any write.
- cycle.sh `redact_note`: on failure returns empty, one stderr line, status 1; old "always exits 0" comment fixed.
- tests/maintenance.test.sh: block `1113-11` (corpus, 11 neighbour rows, parity against `redact_builtin` alone,
  failing-stub callers, `redact_note` extracted by sed).
- Surprise: `.claude/hooks/court-guard.sh` and `owner-guard.sh` are committed 100644 (story 08, 4ccafb0d), so
  `maintenance.test.sh` has 2 failures not from this story.

## Findings
- close-story exit 4 on `bash tests/maintenance.test.sh`: 938 checks, 2 failed, neither from this story:
  `hook bit: .claude/hooks/court-guard.sh committed without the executable bit` and the same for
  `.claude/hooks/owner-guard.sh` (both 100644 in the index since 4ccafb0d, story 08). Every 1113-11 row, every
  parity row and every story-02 `redact.sh 1113` row passes. The fix is `git update-index --chmod=+x` on two files
  outside `## Files` (and workers never run git add): who sets the bit before this close-story is rerun?
- Rerun after b0721b25 (Queen set both bits): close-story exit 4 `edited outside ## Files: .claude/hooks/court-guard.sh,
  .claude/hooks/owner-guard.sh` - the mode change is b0721b25, committed after the claim head 7713358b; not my edit.
  Needs a new claim head past b0721b25 (or the Queen's waiver) before close-story can pass scope.

## Red receipt
- command: bash tests/maintenance.test.sh
- exit: 1
- tests: 8ba3ab3ed146caa3a6249d7171e38a74362142d46c9f8aeb41f90c71af430713 (tests/maintenance.test.sh)
- impl: 6e7f0326d3b00c1061844578dffc96630f340ab658c2f659afb09d85b6751362
- stamped: 2026-11-14T01:27:12Z

```
::error::redact.sh leaves a password length in prose alone: got 'the password is [VULYK:REDACTED] chars and the token was [VULYK:REDACTED] days old', want 'the password is [VULYK:REDACTED] chars and the token was [VULYK:REDACTED] days old'
  ok    ship 2a: the plugin.json version moves with VERSION
  ok    ship 2a: the dev build gets a local tag for the next upgrade
  ok    ship 2a: a reverted canary is held too
  ok    ship 2: in the VULYK source the build number comes from 2a
  ok    ship 2a: the canaries go first
  ok    ship 2a: a red canary stops the rollout
--- beta-fixes-1113-03: a paperwork-only suite.log head, --go from the owner
  ok    lead-review: a suite.log head that differs only by paperwork commits is not reported
  ok    plan: --go comes only from the owner's own words
maintenance.test.sh: 938 checks, 16 failed
```
