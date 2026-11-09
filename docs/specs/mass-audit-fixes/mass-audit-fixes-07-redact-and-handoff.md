---
story: mass-audit-fixes-07
spec: mass-audit-fixes
status: done
returned: DONE
tier: 4
worker: worker-code
wave: 2
blocked_by: [mass-audit-fixes-02]
red: required
red_reason: masks a bare PASS
red_verified_at: 2026-11-09T13:48:19Z 127a55aa51821807c6f9f54fe904d2c23d00a4211e9c6bc8a7a48b2e5237f3d7
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
- scripts/redact.sh: CREDENTIAL(S) joins KEYWORDS; new END_KEY rule masks keys ending in PASS (bare or after _/-) or _PWD/-PWD; DSN_KEY rule masks a DSN value whole only when its URL has userinfo (scheme://x@host); quoted values match from 1 char (was 6+).
- Decision: bare `PWD=` stays unmasked (it is the shell's current folder); `bypass:`/`compass=` stay readable via a captured left boundary (sed has no lookbehind).
- .claude/hooks/handoff.py: `_VALUE` shared by the keyword rules; same three rules in `_REDACT_FALLBACK` (lookbehind instead of the captured boundary); `indexed_enriched()` keeps index.json on a same-session `enriched: true` handoff when the dump reason is `sessionend-clear`; the file is still written.
- .claude/hooks/handoff.sh: `${VULYK_PY:+"$VULYK_PY"}` first, as the defect hooks.
- tests/maintenance.test.sh: S2 block (11 redact_is rows + 11 parity rows via h.redact_text on the same fixtures).
- tests/handoff-hooks.test.py: /clear dump case, enriched true vs false.
- tests/handoff.test.sh: counting $VULYK_PY stub with PATH pythons shadowed by logging exit-1 stubs; the two old fall-through cases now run with VULYK_PY empty so a preset one cannot mask them.
- Surprise: portability-check flagged the bare `"${S2[@]}"` loops (bash 3.2 + set -u); fixed to `${S2[@]+"${S2[@]}"}` by editing my implementation back to HEAD, re-stamping red (same impl hash), then re-applying it.

## Findings

## Red receipt
- command: bash tests/maintenance.test.sh
- exit: 1
- tests: 127a55aa51821807c6f9f54fe904d2c23d00a4211e9c6bc8a7a48b2e5237f3d7 (tests/maintenance.test.sh)
- impl: 1a624dc91ae806e8545e2e8526e48d84a413a0ac3996efea70ac04d205af9517
- stamped: 2026-11-09T13:48:19Z

```
::error::redact.sh masks a bare PASS key (SMTP_PASS): got 'SMTP_PASS=qqqqqqqqqq42ZZZZZZZZ', want 'SMTP_PASS=[VULYK:REDACTED]'
  ok    handoff.py fallback agrees with redact.sh: masks a bare PASS key (SMTP_PASS)
  ok    git-guard: --check fails on the neighbour fixture
  ok    git-guard: --check passes a file that is no hook input
--- git guard: a mod with tool.check
  ok    git-guard: an enabled mod with tool.check gets a brief line
  ok    git-guard: a disabled mod is not named
  ok    git-guard: no such mod, no line
  ok    git-guard: an enabled mod without tool.check, no line
--- plan step 3a: the existing-repo horizon gate
  ok    plan 3a: the existing-repo gate counts a module under ## Unmapped territory beside ## Codebase map
maintenance.test.sh: 463 checks, 5 failed
```
