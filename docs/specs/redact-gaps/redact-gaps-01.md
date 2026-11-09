---
story: redact-gaps-01
spec: redact-gaps
status: done
returned: DONE
tier: 1
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: redact.sh masks a passphrase: got
red_verified_at: 2026-11-09T21:20:27Z eb622cf64105cc3c7d650dcd2e2876f7ff5c0650a98a0696c53a342bfbf533b0
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
- redact.sh: `passphrase` and `cookie` join KEYWORDS; new OTP_KEY (an END key, like PASS) and KEY_KEY (`*_KEY`, `-key`,
  camel `Key`, value in TOKEN_VALUE's 16+ char shape); an ssh public key line keeps its type and loses its body; the URL
  rule takes an empty user. handoff.py's fallback carries the same five patterns; the S2 parity loop checks them all.
- install.sh: PREV_UNKNOWN is set once, after PREV, when `v$PREV` is not a tag in $SRC (PREV none excepted), with one
  note line; wire_entry, wire_shipped and the git-guard branch then call report_unwired. Moves (Stop scan, inject matcher)
  are unchanged.
- Order: the implementation came before the red receipt (written before this spec existed in this session); the receipt
  was stamped with `stamp-red --baseline` against HEAD's code, the route vulyk-build names for that case. A manual run of
  HEAD's install.sh from an untagged copy put all three removed entries back (3), the new test asserts 0.
- The new cookie and empty-user URL masks fired on this spec's own brief while it was written (`cookie: session=` in
  backticks, a placeholder URL): reworded there, behaviour as designed.

## Findings

## Red receipt
- command: bash tests/maintenance.test.sh
- exit: 1
- tests: eb622cf64105cc3c7d650dcd2e2876f7ff5c0650a98a0696c53a342bfbf533b0 (tests/maintenance.test.sh, tests/telemetry.test.sh)
- impl: dd81edfcd5f2b0861378c2e4fdc1d69b1d09244d755864f860b309454529e4dc
- stamped: 2026-11-09T21:20:27Z

```
::error::redact.sh masks a passphrase: got 'passphrase=qqqqqqqqqq42ZZZZZZZZ', want 'passphrase=[VULYK:REDACTED]'
  ok    git-guard: --check fails on the neighbour fixture
  ok    git-guard: --check passes a file that is no hook input
--- git guard: a mod with tool.check
  ok    git-guard: an enabled mod with tool.check gets a brief line
  ok    git-guard: a disabled mod is not named
  ok    git-guard: no such mod, no line
  ok    git-guard: an enabled mod without tool.check, no line
--- plan step 3a: the existing-repo horizon gate
  ok    plan 3a: the existing-repo gate counts a module under ## Unmapped territory beside ## Codebase map
maintenance.test.sh: 499 checks, 10 failed
```
