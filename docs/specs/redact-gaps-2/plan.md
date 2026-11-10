# redact.sh closes the redact-gaps review's mask minors (plan)

**Tier:** 1 · **Spec slug:** `redact-gaps-2` · **Brief:** [brief.md](brief.md)
**Model profile:** opus-builds
**Governed by:** CLAUDE.md `## Secrets` (redact.sh is a seatbelt); private memory rule: no list of open holes in outward text
**Depends on:** 0.50.1 (redact-gaps)

## Goal
The three mask minors of `docs/specs/redact-gaps/council/round-1/review.md` and the `*_AUTH` name are masked by
`scripts/redact.sh` and by the `.claude/hooks/handoff.py` fallback alike: a Cookie header's whole value, a `*_KEY`
value written as `base64:...`, a key name glued (`ENCRYPTIONKEY`) or dotted (`encryption.key`), `TOTP` and `otp_code`,
and a `*_AUTH` name with a key-shaped value. Prose about cookies, `otpauth_url`, `basic_auth=true` stay readable.

## Assumptions
- A Cookie header (`Cookie:` / `Set-Cookie:` followed by a `name=value` pair) is masked to the end of its line.
- Glued names are matched in upper case only (`ENCRYPTIONKEY`): lower-case glued `...key` is ordinary words.
- The CHANGELOG entry for 0.50.2 says what is masked now, never what is still open.

## Stories

**Wave 1**
- `redact-gaps-2-01` — the masks in redact.sh and handoff.py and their rows in the S2 table

## Contracts
- none

## Integration gate
`bash tests/full-suite.sh`

## Descoped

*(empty)*

## Plan deltas
**Briefed:** via mini-brief, Andrei, 2026-11-10
