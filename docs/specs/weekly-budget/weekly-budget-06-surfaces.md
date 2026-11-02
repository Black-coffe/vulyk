---
story: weekly-budget-06
spec: weekly-budget
status: todo
returned:
tier: 4
worker: worker-code
wave: 3
blocked_by: [weekly-budget-03]
red: required
red_reason:
---

# Where the owner sees it, and how a hive gets it

## Goal
Four surfaces on top of `budget.sh` (ADR-028 §3 «Surfaces»), and the installer that carries them: a new SessionStart hook
`.claude/hooks/budget-brief.sh` (sibling of `top-model-brief.sh`) runs `budget.sh gate` (lazy poll, capped) and prints one
`[VULYK] budget: ...` line; a new Stop hook `.claude/hooks/budget-banner.py` refreshes a stale journal (`budget.sh poll`) and
shows a `systemMessage` banner once per state change through `budget.sh announce`; `/vulyk-status` step 9 prints
`budget.sh explain`; the pulse band appends the `state` one-liner. `install.sh` ships the new scripts and wires both hooks into a
hive's `settings.json` additively, so `/vulyk-update` after the release carries it to live hives. Test first (ADR-025).

## Requirements
> 8. Видно: старт, баннер при смене, полоса pulse, /vulyk-status.
> и предупреждал, что у тебя столько-то, столько-то

## Files
- .claude/hooks/budget-brief.sh
- .claude/hooks/budget-banner.py
- .claude/settings.json
- install.sh
- .claude/commands/vulyk-status.md
- .claude/mods/vulyk-pulse/**
- docs/pulse.md
- tests/maintenance.test.sh
- tests/mods.test.sh
- tests/telemetry.test.sh

## Non-goals
- Hooks never write under the journal dir themselves (`budget.sh` is its only writer) and never pause anything.
- Both hooks exit 0 on every path (missing `budget.sh`, no Python, `VULYK_BUDGET=0`, `VULYK_BUDGET_POLLING=1`), fail open.
- No `statusLine` entry, no edit of `top-model-brief.sh`, `session-start-brief.sh` or `handoff.py`.
- No pulse `plugin.json` version bump (done on `main` after the merge); the band makes no model call and no poll.
- `install.sh`: additive wiring with today's `.vulyk-bak`; never overwrite a hive's own hook entries.

## Map slice
`memory/map/scripts.md` «Entry points» (`session-start-brief.sh`), «install.sh - the upgrade contract», «Tests»;
recon.md «Surfaces» (`handoff.py` once-per-level banner, `top-model-brief.sh` off switch); `docs/pulse.md`.

## Acceptance criteria
- [ ] SessionStart prints one line, e.g. `[VULYK] budget: ok - week <U>% used, <D>%/day allowed, resets <weekday HH:MM> UTC`
      (Fable bucket appended when present); `budget: off` / `n/a` / `no-data - <why>` when so; `VULYK_BUDGET_BRIEF=0` silences it.
- [ ] Stop: polls only when the newest row is older than the interval, within the hook's own timeout (set in `settings.json`
      above the 90 s cap); a banner appears once per new state (`warn`, `downgrade-*`, `reserve-pause`, `boost`, `poll-disabled`)
      and not again for the same state.
- [ ] Cases in `tests/maintenance.test.sh` for brief and banner (stubbed `budget.sh`): one line, off switches, once-per-state,
      fail-open; `tests/mods.test.sh` covers the band with and without `budget.sh`.
- [ ] `/vulyk-status` step 9 prints `bash scripts/budget.sh explain` beside `top-model.sh --explain`.
- [ ] `install.sh --upgrade` on a hive wires both hooks once (re-run = no duplicate) and ships `scripts/budget.sh`,
      `scripts/budget.py` and both hooks. Where that is asserted is recon Q5: the Queen adds the named suite to `## Files` and
      `## Verification` before dispatch; without it, `NEEDS_CONTEXT`.

## Verification
`bash tests/maintenance.test.sh && bash tests/mods.test.sh`
`bash scripts/py.sh -m py_compile .claude/hooks/*.py`
`git ls-files '*.json' | xargs -n1 jq -e . > /dev/null`
`bash tests/telemetry.test.sh --part wiring`
`bash tests/telemetry.test.sh --part upgrade`

## Implementation notes

## Findings
