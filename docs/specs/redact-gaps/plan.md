# redact.sh masks the names round 2 found open; a tagless install source wires nothing back (plan)

**Tier:** 1 · **Spec slug:** `redact-gaps` · **Brief:** [brief.md](brief.md)
**Model profile:** opus-builds
**Governed by:** CLAUDE.md `## Secrets` (redact.sh is a seatbelt), ADR-005 (installer upgrade contract), defect card `upgrade-overwrites-host-edits`
**Depends on:** 0.50.0 (mass-audit-fixes: S2 redaction parity, Ask 18 wire_entry / wire_shipped)

## Goal
`scripts/redact.sh` and its mirror in `.claude/hooks/handoff.py` mask a passphrase, a `*_KEY` assignment (ENCRYPTION_KEY,
SIGNING_KEY, appKey) with a key-shaped value, a cookie (SESSION_COOKIE, a Cookie header), an OTP, a bare ssh public key
line and a URL password with an empty user, and leave footprint, primary_key=True and prose about a key alone.
`install.sh --upgrade` from a source that lacks the `v$PREV` tag prints one note and names each hook missing from the
hive's settings.json with its `--wire` command, instead of wiring it back: wire_entry, wire_shipped and the git guard.

## Assumptions
- The `*_KEY` rule needs a 16+ char value with no spaces (the bare-token rule's shape); a shorter value stays readable.
  A long non-secret value under a `*_key` name (`"sort_key": "created_at_timestamp"`) is masked: loud over clever, as the
  script's header says.
- The cookie keyword masks the value after any cookie name, as `password` does; `cookie: session=...` in prose is masked.
- The round-1 seat's `TWILIO_AUTH=` and `SESSION_KEY` in other spellings are not in the owner's list; `*_KEY` covers the
  latter, `*_AUTH` is left out.
- A tagless source on upgrade wires no missing hook, a new one included: the owner gets the `--wire` line for it. A fresh
  install (no installed release) still wires everything.

## Stories

**Wave 1**
- `redact-gaps-01` — the masks in redact.sh and handoff.py, the tagless-source rule in install.sh, their tests

## Contracts
- none

## Integration gate
`bash tests/full-suite.sh`

## Descoped

*(empty)*

## Plan deltas
**Briefed:** via mini-brief, Andrei, 2026-11-09
**Branch:** vulyk/redact-gaps
