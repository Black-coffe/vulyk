---
story: audit-fixes-1113-02
spec: audit-fixes-1113
status: todo
returned:
tier: 3
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: masks a non-English secret keyword
---

# redact.sh masks more secret forms and never fails silently

## Goal
`scripts/redact.sh` masks three more classes of secret: values that follow a Russian or Ukrainian secret keyword,
credentials passed as command arguments, and the service-token shapes of the private lists. `handoff.py`'s
`_REDACT_FALLBACK` gains the same masks in the same story, and parity rows run both on the same inputs. When
`redact.sh` cannot do its work (a tool it pipes through fails), it withholds the text and says so (plan.md
`## Contracts` R1), and `scripts/telemetry.sh` knows the new code `redact_degraded`. Marked red: a parser on the
path every brief, handoff and acceptance note goes through.

Private input, read before writing a line: the `redact.sh` section of
`~/.vulyk/audits/framework-audit-2026-11-13/FINAL.md` and `redact-open-shapes.md` in the same folder. They hold the
exact keywords, argument forms and token shapes. Nothing from them goes into the repo except as test inputs with
synthetic values, and no comment, label or note says which form was unmasked before.

## Requirements
> 7. `redact.sh` masks: Russian and Ukrainian secret keywords; credentials passed in command arguments; the service-token shapes in the private audit list, with the privately recorded open shapes. If `redact.sh` itself fails, it says so on stderr and records `redact_degraded`; it never passes the text through silently.

## Files
- scripts/redact.sh
- .claude/hooks/handoff.py
- scripts/telemetry.sh
- docs/telemetry.md
- tests/maintenance.test.sh
- tests/handoff-hooks.test.py

## Non-goals
- Do not touch `handoff.py` outside `_REDACT_FALLBACK` and its helpers (story 05 edits its session modes in wave 2).
- Do not edit `tests/maintenance.test.sh` outside the redact blocks.
- Do not change the mask text `[VULYK:REDACTED]` or any existing rule's result: every row the suite has today
  still passes.
- Do not correct the count of telemetry codes in `README.md` (the later docs spec).
- Keep ordinary text readable: a keyword with no value after it, a port or a directory flag that only looks like a
  credential flag, and the words the existing rows protect.
- `ENUM` is append-only: add `redact_degraded` at the end, remove nothing.

## Map slice
`memory/map/scripts-hooks.md` → Entry points (`redact.sh`, `handoff.sh` / `_REDACT_FALLBACK`, `telemetry.sh`);
`memory/map/scripts.md` → Gotchas (bash 3.2 / BSD sed).

## Acceptance criteria
- [ ] Every keyword, argument form and token shape of the two private lists has a row in the redact block of
  `tests/maintenance.test.sh` that expects `[VULYK:REDACTED]` in place of a synthetic value, and a parity row that
  runs the same input through `h.redact_text` and expects the same output. The first keyword row's failing label
  contains `masks a non-English secret keyword`.
- [ ] Each class has neighbour rows that must stay unmasked: prose that uses the keyword with no value, a
  look-alike flag that carries no credential, a string that shares a token prefix but is too short to be a token.
- [ ] A URL credential whose password itself holds `:` or `@` is masked whole.
- [ ] With a `sed` or `awk` stub that fails, `redact.sh` prints exactly `[VULYK:REDACT-FAILED]` on stdout, a line
  starting `redact: degraded:` on stderr, exits 1, and no part of the input reaches stdout. The same run leaves a
  `redact_degraded` record where `telemetry.sh record` writes.
- [ ] `bash scripts/telemetry.sh enum` ends with `redact_degraded`, and `docs/telemetry.md` lists the code with one
  line on what it means.
- [ ] `bash scripts/portability-check.sh scripts/redact.sh scripts/telemetry.sh` is clean (BSD sed: ERE with `-E`).

## Verification
`bash tests/maintenance.test.sh`
`bash scripts/py.sh -m py_compile .claude/hooks/*.py`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each. End with one `CHANGELOG:` line
that says what is masked now by class, never which form was open. -->

## Findings
