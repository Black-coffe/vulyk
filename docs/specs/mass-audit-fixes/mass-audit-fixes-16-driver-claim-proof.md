---
story: mass-audit-fixes-16
spec: mass-audit-fixes
status: todo
returned:
tier: 4
worker: worker-code
wave: 2
red: required
red_reason: a garbled claim line stops the run
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

## Findings
