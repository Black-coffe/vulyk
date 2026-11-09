---
story: mass-audit-fixes-16
spec: mass-audit-fixes
status: done
returned: DONE
tier: 4
worker: worker-code
wave: 2
red: required
red_reason: a garbled claim line stops the run
red_verified_at: 2026-11-09T13:55:48Z 5ba3d6aa2f2a866d349087d032e9bd2c8fd304c3ea2f71376ecdbf2d856a9236
---

# A garbled `advance --claim` line is proven by a short re-claim, not given up

## Goal
`.claude/workflows/vulyk-cycle.js` `advance()` stops the run with "the claim is unproven, launch again" whenever
the `--claim` call comes back as a line that is not JSON (or an ok line without a status). On this spec the
Haiku cycle-clerk garbled that ~1.8 KB line twice in a row (once cut short, once with a fragment repeated), so
the driver never got past its first call. `cycle.sh claim <spec> <stamp>` is idempotent for the stamp that
already holds the spec (`already claimed by <stamp>`, a one-line `{"ok":true,"verb":"claim",...}`), so a short
re-claim proves or refuses the claim where a re-read of `status` cannot. After this story an unreadable
`--claim` answer costs one `claim <spec> <stamp>` clerk call: `ok:true` proves the claim and the driver goes on
to its existing `status --json` read; a refused claim (`ok:false`, held by another stamp) clears `claimed` and
stops before any dispatch, as a refused `--claim` does today; an unreadable re-claim stops with today's
"claim is unproven" error. Ask 17.

## Requirements
> 17. (Added by the owner mid-build on 2026-11-09: «Почини драйвер сразу, не жди конца сборки».) The Workflow driver survives a cycle-clerk that garbles the long `advance --claim` line: it proves the claim with a short re-claim by the same stamp instead of stopping the run.

## Files
- .claude/workflows/vulyk-cycle.js
- tests/driver.test.sh

## Non-goals
- Do not touch `scripts/cycle.sh` (story 08 holds it in this wave) or `.claude/agents/cycle-clerk.md`.
- Do not shorten the status line or change the clerk model: the long `status --json` relay is a separate
  follow-up, recorded under `## Findings` if this story meets it.
- A re-claim by the holder carries no `leftover` list; the driver proceeds without leftover notes on that path
  (say so in a code comment), it does not invent them.
- Do not change the retry-model code story 06 landed.

## Map slice
`memory/map/cycle.md` → The Workflow driver (`advance`, `clerk`, claim and release).

## Acceptance criteria
- [ ] `tests/driver.test.sh`: a scripted clerk answers `advance ... --claim` with a cut-off JSON line and
  `claim <spec> <stamp>` with `{"ok":true,"verb":"claim","exit":0,"next":"claimed"}`; the run reads status and
  dispatches the wave (the failing label contains `a garbled claim line stops the run`). Original case: the
  cut-off line from this spec's first launch.
- [ ] Neighbour form: the same with a line that repeats a fragment (valid prefix, broken middle) behaves the same.
- [ ] A re-claim answered `ok:false` (held by another stamp) stops before any dispatch, and the run's release
  is still attempted; a re-claim that is itself unreadable stops with the existing "claim is unproven" error.
- [ ] The static check that lists the clerk verbs the driver sends admits `claim` and nothing else new; every
  existing driver check passes.

## Verification
`bash tests/driver.test.sh`

## Implementation notes
- .claude/workflows/vulyk-cycle.js: `advance()` answers an unreadable `--claim` line with one `claim <spec> <stamp>`; ok:true goes on to the existing `status --json` read, ok:false stops with verb claim, unreadable stops with the old "claim is unproven" error, exit 3 pauses.
- Decision: a refused re-claim does not clear `claimed`, so the release is still attempted (the acceptance criterion); the Goal's "clears claimed" reading was rejected because the release is harmless and a skipped one strands the lock.
- The proven path carries no leftover list (code comment); no leftover notes are invented.
- tests/driver.test.sh: static verb check admits only the `claim ${spec} ${stamp}` template; the P10-12 cases now script an unreadable re-claim; new cases for the cut-off line (4 of 6 stories, no brace), a repeated fragment, and a refused re-claim.
- Surprise: a backticked `claim <spec> <stamp>` in a code comment tripped the static template check; reworded the comment.

## Findings

## Red receipt
- command: bash tests/driver.test.sh
- exit: 1
- tests: 5ba3d6aa2f2a866d349087d032e9bd2c8fd304c3ea2f71376ecdbf2d856a9236 (tests/driver.test.sh)
- impl: d4e916d44dd12478e98fd157ab1770bc3f4a2e16547a3aab51633dd75fbda61f
- stamped: 2026-11-09T13:55:48Z

```
::error::ask 17 (cut-off line): a garbled claim line stops the run - want re-claim, status read, wave dispatched - got {"seq":"advance docs/specs/demo --stamp 0123456789abcdef --claim | release docs/specs/demo 0123456789abcdef","mm":[{"n":1,"want":"claim docs/specs/demo 0123456789abcdef","got":"release docs/specs/demo 0123456789abcdef"}],"result":{"stop":{"verb":"advance","failed":"claim","exit":2,"next":"error","error":"unreadable result from \"advance docs/specs/demo --stamp 0123456789abcdef --claim\": the claim is unproven, launch again; clerk line: {\"ok\":true,\"verb\":\"advance\",\"exit\":0,\"next\":\"build:1\",\"steps\":[],\"rejected\":[],\"status\":{\"spec\":\"docs/specs/demo\",\"slug\":\"demo\",\"stage\":\"03\",\"tier\":3,\"branch\":\"vulyk/demo\",\"head\":\"h1\",\"wave_stories\":[{\"file\":\"docs/specs/demo/demo-01-x.md\",\"story\":\"demo-01\",\"worker\":\"worker-code\",\"model\":\"opus\",\"repeat\":1},{\"file\":\"docs/specs/demo/demo-02-x.md\",\"story\":\"demo-02\",\"worker\":\"worker-code\",\"model\":\"opus\",\"repeat\":1},{\"file\":\"docs/specs/demo/demo-03-x.md\",\"story\":\"demo-03\",\"worker\":\"worker-code\",\"model\":\"opus\",\"repeat\":1},{\"file\":\"docs/specs/demo/demo-04-x.md\",\"story\":\"demo-04\",\"worker\":\"worker-code\",\"model\":\"opus\",\"repeat\":1}","steps":[]},"fallbacks":[]}}
::error::ask 17 (repeated fragment): a garbled claim line stops the run - want re-claim, status read, wave dispatched - got {"seq":"advance docs/specs/demo --stamp 0123456789abcdef --claim | release docs/specs/demo 0123456789abcdef","mm":[{"n":1,"want":"claim docs/specs/demo 0123456789abcdef","got":"release docs/specs/demo 0123456789abcdef"}],"result":{"stop":{"verb":"advance","failed":"claim","exit":2,"next":"error","error":"unreadable result from \"advance docs/specs/demo --stamp 0123456789abcdef --claim\": the claim is unproven, launch again; clerk line: {\"ok\":true,\"verb\":\"advance\",\"exit\":0,\"next\":\"build:1\",\"steps\":[],\"rejected\":[],\"status\":{\"spec\":\"docs/specs/demo\",\"slug\":\"demo\",\"stage\":\"03\",\"tier\":3,\"branch\":\"vulyk/demo\",\"head\":\"h1\",\"wave_stories\":[{\"file\":\"docs/specs/demo/demo-01-x.md\",\"story\":\"demo-01\",\"worker\":\"worker-code\",\"model\":\"opus\",\"repeat\":1},{\"file\":\"docs/specs/demo/demo-02-x.md\",\"story\":\"demo-02\",\"worker\":\"worker-cody\":\"demo-01\",\"worker\":\"worker-code\",\"model\":\"opus\",\"repeat\":1},{\"file\":\"docs/specs/demo/demo-02-x.md\",\"story\":\"demo-02\",\"worker\":\"worker-code\",\"model\":\"opus\",\"repeat\":1},{\"file\":\"docs/specs/demo/demo-03-x.md\",\"story\":\"demo-03\",\"worker\":\"worker-code\",\"model\":\"opus\",\"repeat\":1},{\"file\":\"docs/specs/demo/demo-04-x.md\",\"story\":\"demo-04\",\"worker\":\"worker-code\",\"model\":\"opus\",\"repeat\":1},{\"file\":\"docs/specs/demo/demo-05-x.md\",\"story\":\"demo-05\",\"worker\":\"worker-code\",\"model\":\"opus\",\"repeat\":1},{\"file\":\"docs/specs/demo/demo-06-x.md\",\"story\":\"demo-06\",\"worker\":\"worker-code\",\"model\":\"opus\",\"repeat\":1}],\"round\":0,\"court\":null,\"round_dir\":null,\"since\":null,\"seat_attempt\":{},\"seats\":[],\"red\":[],\"next\":\"build:1\"}}","steps":[]},"fallbacks":[]}}
  ok    checkpoint: after a wave, before the gate and the seats
  ok    checkpoint: after one gate step, before the next
  ok    checkpoint: after the gate finished, before the seat dispatch
  ok    checkpoint: a terminal state returns as itself, no checkpoint
  ok    checkpoint: 50 min after launched_at by the verb clock, the default fires
  ok    checkpoint: 49 min, the default does not fire
  ok    checkpoint: no launched_at, no time source - the checkpoint does not fire and the driver runs on
  ok    checkpoint: no `now` in any verb answer - the checkpoint does not fire
  ok    no queen-planner dispatch in any scenario
122 passed, 7 failed
```
