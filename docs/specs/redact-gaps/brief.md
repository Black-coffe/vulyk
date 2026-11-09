# Brief: redact-gaps

Date: 2026-11-09 · Tier: 1

## Request

The owner's words, this session:

> Проверь окно и начинай redact здесь

What "redact" names: item 2 of the leftovers list the owner pasted as the `/vulyk-plan` request. That text is the
model's own earlier reply, not the owner's words:

> 2. Спек про дыры в redact.sh и wire_entry (Tier 1). Вы решили сделать его сразу после этого релиза, я его ещё не начинал.

The decision behind it, as `docs/specs/mass-audit-fixes/journal.md` recorded it on 2026-11-09 (an option label):
redact.sh gaps (passphrase=, ENCRYPTION_KEY=, SESSION_COOKIE=, OTP=, bare ssh-rsa) and wire_entry's no-tag
fallthrough go to a separate Tier 1 spec right after this release.

The findings it rests on: `docs/specs/mass-audit-fixes/council/round-2/opus.md:27` (c), round 1 `opus.md:27`
(the `*_KEY` family, a session cookie header, a URL password with an empty user), and `review.md:15` / `review2.md:15` (install.sh:1572).

## Asks

1. redact.sh and the handoff.py fallback mask passphrase=, ENCRYPTION_KEY=, SESSION_COOKIE=, OTP= and a bare ssh-rsa key, and an install source without the v$PREV tag no longer puts back a hook the owner removed.
