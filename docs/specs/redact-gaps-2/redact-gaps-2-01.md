---
story: redact-gaps-2-01
spec: redact-gaps-2
status: done
returned: DONE
tier: 1
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: redact.sh masks a whole Cookie header: got
red_verified_at: 2026-11-10T08:01:00Z 4a198b69ef82fd46ea03d97709e5aa236579e6a885f8cc669ab6ea050a518cee
---

# redact.sh closes the redact-gaps review's mask minors

## Goal
redact.sh and the handoff.py fallback mask a Cookie / Set-Cookie header value whatever its first pair, a `*_KEY`
value in `base64:` form, a glued upper-case (`ENCRYPTIONKEY`) or dotted (`encryption.key`) key name, `TOTP` and
`otp_code`, and a `*_AUTH` name with a 16+ char value; the S2 parity loop shows both agree on each new row.

## Files
- scripts/redact.sh
- .claude/hooks/handoff.py
- tests/maintenance.test.sh

## Non-goals
- No change to install.sh (the two session hooks it wires back are another story).
- No lower-case glued key names, no new token vendor shapes.

## Map slice
memory/map/scripts.md (redact.sh)

## Acceptance criteria
- [ ] Each new masking row in the S2 table passes on redact.sh, and the fallback agrees on every row.
- [ ] `cookie: see the policy`, `otpauth_url=otpauth://totp/x`, `basic_auth=true`, `monkey business` stay unchanged.

## Verification
`bash tests/maintenance.test.sh`

## Implementation notes
- redact.sh: a Cookie / Set-Cookie header rule (a name=value pair after the colon -> the rest of the line), run before
  the keyword rule; KEY_KEY gains dotted names, glued upper-case `KEY` and `*_AUTH`; its value takes an optional
  `base64:`; OTP_KEY takes `TOTP` and a `_code` suffix. handoff.py's fallback carries the same three changes.
- Order kept this time: the S2 rows first, `stamp-red` (8 failed on the old code), then the implementation.

## Findings

## Red receipt
- command: bash tests/maintenance.test.sh
- exit: 1
- tests: 4a198b69ef82fd46ea03d97709e5aa236579e6a885f8cc669ab6ea050a518cee (tests/maintenance.test.sh)
- impl: ec3b6505e97edf18e7b22b673586a02d436aa9f15d0f7ff113ab385813e479ba
- stamped: 2026-11-10T08:01:00Z

```
::error::redact.sh masks a whole Cookie header: got 'Cookie: a=1; sessionid=qqqqqqqqqq42ZZZZZZZZ', want 'Cookie: [VULYK:REDACTED]
  ok    git-guard: --check fails on the neighbour fixture
  ok    git-guard: --check passes a file that is no hook input
--- git guard: a mod with tool.check
  ok    git-guard: an enabled mod with tool.check gets a brief line
  ok    git-guard: a disabled mod is not named
  ok    git-guard: no such mod, no line
  ok    git-guard: an enabled mod without tool.check, no line
--- plan step 3a: the existing-repo horizon gate
  ok    plan 3a: the existing-repo gate counts a module under ## Unmapped territory beside ## Codebase map
maintenance.test.sh: 523 checks, 8 failed
```
