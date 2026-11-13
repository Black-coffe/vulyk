---
story: audit-fixes-1113-11
spec: audit-fixes-1113
status: todo
returned:
tier: 3
worker: worker-code
wave: 4
blocked_by: [audit-fixes-1113-02, audit-fixes-1113-07, audit-fixes-1113-08, audit-fixes-1113-09, audit-fixes-1113-10]
red: required
red_reason: a brief of the repo passes redact.sh unchanged
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
