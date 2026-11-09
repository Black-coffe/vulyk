---
story: mass-audit-fixes-07
spec: mass-audit-fixes
status: todo
returned:
tier: 4
worker: worker-code
wave: 2
blocked_by: [mass-audit-fixes-02]
red: required
red_reason: masks a bare PASS
---

# Redaction masks the remaining secret names in parity with the handoff fallback; a /clear dump keeps the enriched handoff

## Goal
`scripts/redact.sh` masks the secret names the merge left open (private audit 2026-11-08, S2 after P9-04:
`PASS`, `PASSWD`/`PWD`, `DSN` with a credentialed URL, `CREDENTIAL(S)`), and a quoted value is swallowed to its
closing quote whatever its first word's length; `handoff.py`'s `_REDACT_FALLBACK` gains the same entries in the
same story, and the parity rows in `tests/handoff-hooks.test.py` run both on the same fixtures. The dump hook
(`mode_dump_hook`) still writes the new file on a `/clear` SessionEnd but leaves `index.json` pointing at a
same-session handoff marked `enriched: true` (contributor limit (3)). `.claude/hooks/handoff.sh` tries
`$VULYK_PY` first, then python3, python, py, like the two defect hooks. Asks 2, 10 (two of its three parts; the
`## Commands` row is story 13's) and 11. Marked red: a parser.

## Requirements
> 2. P9-04 extended: `redact.sh` (and the handoff built-in pass kept in parity) masks the secret names still unmasked after the merge (the rest of our S2).
> 10. Handoff: a `/clear` dump never repoints `index.json` away from an enriched handoff; `tests/handoff.test.sh` gets a `## Commands` row; `handoff.sh` honours `$VULYK_PY`.
> 11. Every finding of our private audit that the merged branch does not close (Scope E) is fixed, with a regression test wherever code can check it.

## Files
- scripts/redact.sh
- .claude/hooks/handoff.py
- .claude/hooks/handoff.sh
- tests/maintenance.test.sh
- tests/handoff-hooks.test.py
- tests/handoff.test.sh

## Non-goals
- Do not edit `CLAUDE.md` (the `Handoff` row is story 13's) or `docs/hooks-reference.md`.
- Do not gate `handoff.sh prompt`/`stop` in bash (O8 is recorded as an accepted cost, plan.md Assumptions).
- Do not change the `/clear` dump's content or the enrichment flow; only where `index.json` points.
- Do not edit `tests/maintenance.test.sh` outside the redact blocks (story 02 owned the git-guard block in
  wave 1; story 12 owns the hook-bit block in wave 3).
- Keep the counters and prose the P9-04 rows protect unmasked (`max_tokens`, `token_budget`, `the token:`).

## Map slice
`memory/map/scripts.md` → Entry points (`.claude/hooks/handoff.sh`, `redact.sh`), Gotchas;
`memory/map/agents-and-commands.md` → Commands (`/vulyk-handoff`).

## Acceptance criteria
- [ ] `redact.sh` masks `SMTP_PASS=<value>`, `DB_PWD=<value>`, `export PASSWD=<value>`,
  `SENTRY_DSN=https://<key>@host/1`, `CREDENTIALS="<two words>"` and `"secret": "my very long passphrase"`;
  leaves `password_reset_count=3`, `pass the test`, `pwd` as a shell command and `dsn_timeout=30` alone. The
  failing label for the first row contains `masks a bare PASS`.
- [ ] Every new row runs through `h.redact_text` as well and the two outputs are equal (parity rows).
- [ ] `tests/handoff-hooks.test.py`: a session with an enriched handoff in `index.json` followed by a
  SessionEnd `clear` dump writes the dump file and leaves `index.json` on the enriched file; without an enriched
  handoff the dump repoints as today.
- [ ] `tests/handoff.test.sh`: with `VULYK_PY` set to a counting stub and no python on PATH, `handoff.sh status`
  runs through the stub; the existing fall-through cases still pass.

## Verification
`bash tests/maintenance.test.sh`

## Implementation notes

## Findings
