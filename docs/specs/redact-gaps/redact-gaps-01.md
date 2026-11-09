---
story: redact-gaps-01
spec: redact-gaps
status: todo
returned:
tier: 1
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: redact.sh masks a passphrase: got
---

# redact.sh masks the open secret names; a tagless install source wires nothing back

## Goal
redact.sh and the handoff.py fallback mask passphrase=, `*_KEY=` with a key-shaped value, SESSION_COOKIE= and a Cookie
header, OTP=, a bare ssh-rsa / ssh-ed25519 / ecdsa key line and a URL password with an empty user, in agreement with each
other. `install.sh --upgrade` from a source without the `v$PREV` tag prints `note: v<PREV> is not a tag in <src>` and
reports every missing hook as `unwired` with its `--wire` command; it wires none back (it used to wire them all).

## Files
- scripts/redact.sh
- .claude/hooks/handoff.py
- install.sh
- tests/maintenance.test.sh
- tests/telemetry.test.sh

## Non-goals
- No change to how the window size is detected in handoff.py (a separate fix, its own spec).
- No `*_AUTH` rule, no OTP shorter than six characters.
- No change to wire_hook, report_unwired or the moved entries (Stop -> SessionEnd scan, the inject matcher).

## Map slice
memory/map/scripts.md (redact.sh, install.sh) · memory/map/agents-and-commands.md (hooks)

## Acceptance criteria
- [ ] Each new S2 row in tests/maintenance.test.sh passes on redact.sh and the fallback agrees with redact.sh on every row.
- [ ] footprint=, primary_key=True, `the key: value`, the npm :443/@scope URL and the git remotes stay unchanged.
- [ ] From an untagged source copy, a 0.49.0 hive with ysk-offer, context-guard and git-guard removed gets the note, three
      `unwired` lines, and none of the three back in settings.json.

## Verification
`bash tests/maintenance.test.sh`
`bash tests/telemetry.test.sh --part install-xp2`

## Implementation notes

## Findings
