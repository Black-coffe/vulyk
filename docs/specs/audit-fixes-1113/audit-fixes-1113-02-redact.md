---
story: audit-fixes-1113-02
spec: audit-fixes-1113
status: done
returned: DONE
tier: 3
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: masks a non-English secret keyword
red_verified_at: 2026-11-13T16:48:11Z 51383b200c5f0ab4d4b5cd7259b0c76db02919706aa7281b0c711b7e3a0d6866
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
- scripts/redact.sh: Russian/Ukrainian keyword rule, prose `<secret word> is <value with a digit or symbol>`, bare key/auth and lower-case pwd names, command-argument credentials, ten service-token shapes, a 40-char cloud secret key (one ERE alternative per upper-case position), URL passwords holding `:`/`@`, cookie and OTP name variants.
- scripts/redact.sh: failure path is now `degrade()`: `[VULYK:REDACT-FAILED]` on stdout, `redact: degraded: <why>` on stderr, `telemetry.sh record redact_degraded`, exit 1; output is buffered under `pipefail` so a failing awk or sed leaks nothing.
- .claude/hooks/handoff.py: `_REDACT_FALLBACK` mirrors every new rule in the same order; the URL rule tries the `@`-holding password first, matching sed's longest match. `redact_text` already treats exit 1 as "use the built-in pass".
- scripts/telemetry.sh + docs/telemetry.md: `redact_degraded` appended to ENUM, one table row, "eleven" -> "twelve" codes in the same doc.
- tests/maintenance.test.sh: block `redact.sh 1113` (43 rows + parity through `h.redact_text`, sed and awk failure stubs, enum and doc row). tests/handoff-hooks.test.py untouched (its rows still pass).
- Decision: `PWD=` (upper case) stays readable as the shell's folder; `-u 1000:1000`, `-p 8080:80`, `mkdir -pv`, `--password-stdin` stay readable.
- Surprise: `bash tests/maintenance.test.sh` has one failure at HEAD that is not this story's: `memory/map/scripts-hooks.md` line 46 is 140 chars (map cap 130), from commit 440c4681.
- CHANGELOG: redact.sh and the handoff fallback now mask Russian and Ukrainian secret keywords, secrets stated in prose, credentials passed as command arguments, more service-token and webhook shapes and bare cloud secret keys; when redaction cannot run, the text is withheld and `redact_degraded` is recorded.

## Findings
- close-story exit 4 on `bash tests/maintenance.test.sh`: 703 checks, 1 failed, and that one is not this story's:
  `map: scripts-hooks.md has a 140-char line` (`memory/map/scripts-hooks.md` line 46, last touched by 440c4681, map cap
  130). Every redact row, parity row, failure-stub row and enum/doc row passes. The fix is a wrap of that map line,
  in `memory/` (outside `## Files`, and workers never edit `memory/`): who wraps it - the librarian / drone-docs,
  or the Queen before rerunning this close-story?
- Resolved: the map line was wrapped in ca9ae757; close-story rerun.

## Red receipt
- command: bash tests/maintenance.test.sh
- exit: 1
- tests: 51383b200c5f0ab4d4b5cd7259b0c76db02919706aa7281b0c711b7e3a0d6866 (tests/maintenance.test.sh)
- impl: 200eb0e30e6b5df4f7faef0508d60ab44dc617ff102592c7dc576754181849b6
- stamped: 2026-11-13T16:48:11Z

```
::error::redact.sh masks a non-English secret keyword (пароль:): got 'пароль: qqqqqqqqqq42ZZZZZZZZ', want 'пароль: [VULYK:REDACTED]'
  ok    handoff.py fallback agrees with redact.sh: masks a non-English secret keyword (пароль:)
  ok    ship 2a: the plugin.json version moves with VERSION
  ok    ship 2a: the dev build gets a local tag for the next upgrade
  ok    ship 2a: a reverted canary is held too
  ok    ship 2: in the VULYK source the build number comes from 2a
  ok    ship 2a: the canaries go first
  ok    ship 2a: a red canary stops the rollout
--- beta-fixes-1113-03: a paperwork-only suite.log head, --go from the owner
  ok    lead-review: a suite.log head that differs only by paperwork commits is not reported
  ok    plan: --go comes only from the owner's own words
maintenance.test.sh: 703 checks, 43 failed
```
