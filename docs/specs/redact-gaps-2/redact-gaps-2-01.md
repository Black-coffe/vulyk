---
story: redact-gaps-2-01
spec: redact-gaps-2
status: todo
returned:
tier: 1
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: redact.sh masks a whole Cookie header: got
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

## Findings
