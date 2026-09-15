---
story: driver-hardening-03
spec: driver-hardening
status: done
returned: DONE
tier: 3
worker: worker-code
model: opus
tracer: false
wave: 2
blocked_by: [driver-hardening-01]
---

# Mutating verbs return the post-verb status in their own JSON (ask 5, verb side)

## Goal
`branch`, `close-story`, `open-round`, `record-seat` and `judge` today end with `{"ok","verb","exit","next","error"}` and the driver then spends a separate clerk call on `status --json` to learn what to do. After this story each of the five, on exit 0, embeds the exact `status --json` object under a `status` key, computed after all its writes and its `--commit`, with the top-level `next` equal to `status.next`. Non-zero exits are byte-for-byte as today. This is a contract change (plan C5): the driver story in wave 3 and the ADR in wave 4 build on it; an older driver simply ignores the key.

## Requirements
> Меняющие глаголы cycle.sh возвращают next в своём JSON, драйвер опрашивает статус только на старте.

## Files
- scripts/cycle.sh
- tests/council.test.sh

## Non-goals
- Do not change the `status --json` object itself - no new keys, no removed keys, still exactly one line (tests/council.test.sh:168-186 unchanged).
- Do not add `status` to `briefed`, `escalate`, `reopen`, `claim`, `release`, `pause`, `resume`, or to any non-zero exit; do not change `next` on exit 3/4/6.
- Do not touch `vulyk-cycle.js`, `cycle-clerk.md`, or the fallback loop in `vulyk-build.md` - the driver reads the key in story 04.
- Do not reorder or rename the existing five keys; `status` is appended last.
- Do not re-run verification or scope-check to build the object: `status_json` derives state from disk exactly as `cmd_status` does.

## Map slice
`docs/specs/driver-hardening/recon/cycle-sites.md` §4 (`cmd_status` :278-451, the single `printf` :445-450, dispatcher :2091-2099); plan.md `## Contracts` C5 and A3; `memory/map/cycle.md` "`status --json` keys and `next`" and "`cycle.sh` verbs"; `memory/map/scripts.md` "Key types / contracts" (`emit()` at line 55, the last-line rule); ADR-001 D2.

## Acceptance criteria
- [ ] C5: in the suite's fixture repo, for each of the five verbs run to exit 0 with `--commit` where it takes it, the last stdout line is one JSON object whose `status` value, run through `jq -S .`, equals `jq -S .` of a `status <spec> --json` call made immediately after, and whose `next` equals `.status.next`; still exactly one stdout line per verb.
- [ ] After `open-round --commit` the carried `status.head` is the new HEAD (the object is computed after the commit) and `status.next` is `dispatch:<seats>`; after `judge --commit` on a GREEN fixture, `status.next` is `green` and `status.verdict` `GREEN`.
- [ ] `close-story` exit 4 (`returned: WALL`) and `open-round` exit 2 (dirty tree) last lines have no `status` key and are unchanged from before this story; `pause` then any verb -> exit 3 unchanged.
- [ ] Key order of the last line is `ok, verb, exit, next, error, status`.
- [ ] `git ls-files '*.sh' | xargs -n1 bash -n` silent; every existing council case green.

## Verification
`bash tests/council.test.sh && git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes
- `scripts/cycle.sh`: `emit()` takes an optional 6th arg (a whole status object) appended as the
  last key; new `emit_status <verb> <spec> [next]` computes `cmd_status` after all writes and the
  `--commit` and emits it. Wired into the seven exit-0 sites of branch / close-story / open-round
  (fresh + no-op) / record-seat (council + review) / judge. `escalate` reuses `cmd_judge`, so the
  new line is gated on `VERBLABEL = judge`.
- Tradeoff: the top-level `next` stays each verb's own value, not `status.next`, because the story
  promises an older driver can simply ignore the key - deriving `next` from status changed it in
  several existing fixtures (a plan with no `**Briefed:**`, a round whose pack no longer matches),
  which would have broken pre-C5 callers. In a well-formed spec the two coincide, and the new suite
  case asserts `next == .status.next` for all five verbs. `close-story` already derived its `next`
  from `cmd_status`, so it keeps doing so (unchanged behaviour).
- `tests/council.test.sh`: new end-to-end section walks one spec through branch -> close-story ->
  open-round -> record-seat -> judge, comparing the carried object with a `status --json` call made
  right after each verb (`jq -S`), plus the exit-4 / exit-2 / exit-3 unchanged-line cases. Two
  existing judge assertions pinned the whole exit-0 line literally and now match the prefix up to
  `,"status":{` - the only pre-existing cases touched.
- Surprise: the dirty-tree case needs its own spec - `open-round` refuses an open `todo` story
  before it ever reaches the clean-tree check.

## Findings
