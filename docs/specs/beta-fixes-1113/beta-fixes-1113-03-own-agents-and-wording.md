---
story: beta-fixes-1113-03
spec: beta-fixes-1113
status: todo
returned: NEEDS_CONTEXT
tier: 3
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: agent_prefix_high skips an agent type VULYK does not dispatch
red_verified_at: 2026-11-13T08:11:01Z 83ccffc813a04cf47fe3f1ed1683ec30e0acb4c0f6466591272282e15d3767f7
---

# Less noise in what the owner reads: own agents only, a quiet paperwork head, `--go` from the owner

## Goal
Three small changes. **Ask 4.** The `agent_prefix_high` detector in `scripts/telemetry.sh` (the scan over
subagent transcripts) records a row only when the agent type is one of VULYK's own: a member of the `AGENTS`
list the script already carries. A built-in type (`general-purpose`) or a hive's own agent is skipped, whatever
its prefix. If `docs/telemetry.md` describes the code, its line says so. **Ask 5.** `.claude/agents/lead-review.md`,
the sentence on a `suite.log` whose `head=` is not the reviewed head, gains the exception of plan.md `## Contracts`
T1: a difference of paperwork commits only is the round's own log and is not reported; any other path in the
difference keeps today's `## Minor`. **Ask 6.** `.claude/commands/vulyk-plan.md`, the straight-through `--go`
bullet, gains T2: `--go` only from the owner's own words, never added by the Queen. Both wordings are pinned by
a needle in `tests/maintenance.test.sh`.

## Requirements
> 4. `agent_prefix_high` counts only agents VULYK dispatches (its own agent types), not built-in ones such as `general-purpose`.
> 5. `lead-review` no longer reports a `suite.log` head that differs from the reviewed head only by paperwork commits.
> 6. `/vulyk-plan`: `--go` comes only from the owner's own words, never added by the Queen.
> 9. The `handoff-offered-too-early` card check judges the tree's `.claude/hooks/handoff.py` when the card fires on `scripts/telemetry.sh`, so a story that edits `telemetry.sh` can close (added by the Queen mid-build, card `framework-defect-deferred-mid-build`: it stopped story 03).

## Files
- scripts/telemetry.sh
- tests/telemetry.test.sh
- docs/telemetry.md
- .claude/agents/lead-review.md
- .claude/commands/vulyk-plan.md
- tests/maintenance.test.sh
- scripts/handoff-window-check.py

## Non-goals
- Do not change the prefix threshold, the other anomaly codes, the `ENUM` / `AGENTS` lists or how any other
  detector treats agent types; one membership test in one detector.
- Do not read `.claude/agents/*.md` from the scan: the set is the script's own list (plan.md `## Assumptions`).
- `lead-review.md`: extend the existing sentence, keep its words (a test elsewhere may pin them); no change to
  the suite line, the BLOCK rule or the five items. If a pin outside `## Files` cannot stay green, return
  `NEEDS_CONTEXT` naming the test.
- `vulyk-plan.md`: the `--go` bullet only; no change to `cycle.sh briefed --go` or to `/vulyk-build`.
- Edit `tests/telemetry.test.sh` only in part `scan`; in `tests/maintenance.test.sh` add the two pins, nothing else.
- Fixture transcripts use stand-ins (`acme-writer`, `Acme`); no hive transcript, slug or path.

## Ask 9 (added by the Queen after this story's NEEDS_CONTEXT)
- `scripts/handoff-window-check.py`: when its argument is a file named `telemetry.sh`, judge `.claude/hooks/handoff.py`
  of the tree instead (the card guards `telemetry.sh` because the window logic is shared; running `telemetry.sh` as
  the hook can never offer). Any other argument, the card's two fixtures included, keeps today's behaviour.
- Original case: `bash scripts/py.sh scripts/handoff-window-check.py scripts/telemetry.sh` exits 1 on HEAD and 0 after;
  `bash scripts/defects-check.sh` stays green (the fixtures still go red the way the card expects). Say both in
  `## Implementation notes`.

## Map slice
`memory/map/scripts-hooks.md` → Entry points (`telemetry.sh`: `scan`, `AGENTS`, `RETIRED_AGENTS`);
`memory/map/agents-and-commands.md` → lead-review (Suite line), `/vulyk-plan` (approval stop, `--go`);
`memory/map/scripts-checks.md` → `prompt-check.sh` (`AGENTS` vs agent files), Tests (`maintenance.test.sh`).

## Acceptance criteria
- [ ] `--part scan`, the original case: a fixture window with a `general-purpose` subagent transcript over the
  prefix threshold and a `worker-code` one over it: the scan records `agent_prefix_high` for `worker-code` only.
  The failing label contains `agent_prefix_high skips an agent type VULYK does not dispatch`.
- [ ] `--part scan`, neighbour: a type that is no VULYK agent but looks like one (`acme-writer`) is skipped too;
  a window with only skipped types records no `agent_prefix_high` row; the existing scan cases pass unchanged.
- [ ] `tests/maintenance.test.sh` fails when `lead-review.md` lacks `only by paperwork commits` and when
  `vulyk-plan.md` lacks `only from the owner's own words`; both pins fail on HEAD before the edits.
- [ ] `lead-review.md` still tells the reviewer to report, under `## Minor`, a log whose head differs by any
  path outside the spec's `plan.md`, `journal.md`, `brief.md`, `council/`, and names the one command that shows it.
- [ ] `bash scripts/portability-check.sh scripts/telemetry.sh .claude/agents/lead-review.md
  .claude/commands/vulyk-plan.md` and `bash scripts/prompt-check.sh --touched <the three prompt and script
  paths>` are clean.
- [ ] `## Implementation notes` ends with three `CHANGELOG:` lines, one per ask.

## Verification
`bash tests/telemetry.test.sh --part scan`
`bash tests/maintenance.test.sh`
`bash scripts/defects-check.sh`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each -->
- scripts/telemetry.sh: the scan's agent_prefix_high call gains `in_set "$agent_type" "$AGENTS"`; agent_empty, record_floor and the lists are untouched.
- tests/telemetry.test.sh (part scan): sid1's my-custom-agent and the built-in fixture now expect no prefix row (2 -> 1 rows, also the Stop-hook count); "found one directory deeper" reads the seen-list, since a2 no longer writes a plain-scan row; new worker-code/acme-writer fixtures and a skip-only window.
- The near-miss `explore` case moved to agent_empty (fixture now tool_use) so the `other` mapping stays covered.
- Surprise: the first receipt left a discovery check red after the fix; implementation edited back, test fixed, re-stamped, implementation re-applied.
- docs/telemetry.md, lead-review.md, vulyk-plan.md: one added sentence each; tests/maintenance.test.sh: the two pins.
- CHANGELOG: telemetry: `agent_prefix_high` counts only VULYK's own agent types; `general-purpose` and a hive's own agents are skipped.
- CHANGELOG: lead-review: a `suite.log` whose head differs from the reviewed head only by paperwork commits is the round's own log and is not reported.
- CHANGELOG: /vulyk-plan: `--go` comes only from the owner's own words, never added by the Queen or taken from an agent's message.

## Findings
- close-story exit 4: `defect card handoff-offered-too-early fails on scripts/telemetry.sh` (check prints `handoff-window-check: C 710k of 1M (71%): no /vulyk-handoff offer`). The same check prints the same line on HEAD's `scripts/telemetry.sh`, so it does not come from this story's edit; a decision about the card is needed.
- Queen, 2026-11-13: decided. A card defect, fixed in this story as ask 9 (see `## Ask 9`); `scripts/handoff-window-check.py` joins `## Files`. Both verification lines pass locally (`--part scan` 174/0, maintenance 609/0).
- Second attempt (2026-11-13): close-story rerun with the same stamp gives the same exit 4 on the same card; scope-check clean (6 of 6 declared).

## Red receipt
- command: bash tests/telemetry.test.sh --part scan
- exit: 1
- tests: 83ccffc813a04cf47fe3f1ed1683ec30e0acb4c0f6466591272282e15d3767f7 (tests/maintenance.test.sh, tests/telemetry.test.sh)
- impl: 3f20e3aca60eda2c83caea39d4309fd79744e126402e85f1dd8317c86431c05e
- stamped: 2026-11-13T08:11:01Z

```
::error::agent_prefix_high skips an agent type VULYK does not dispatch (a hive's own) - expected [0], got [1]
::error::agent_prefix_high skips an agent type VULYK does not dispatch (general-purpose, workflow-subagent, acme-writer, explore) - expected [worker-code], got [general-purpose other worker-code other workflow-subagent]
::error::agent_prefix_high skips an agent type VULYK does not dispatch: a window of only such types records none - expected [0], got [2]
  ok    absent: the hive brief line is still first
  ok    absent: the offer names the install commands
  ok    absent: the offer names the decline row
  ok    absent: exactly one litopys line
  ok    installed (settings.json): no offer
  ok    installed (settings.local.json, any marketplace): no offer
  ok    a different plugin from the litopys marketplace is not litopys
  ok    declined in the Profile: no offer
  ok    declined: the hive brief line stays
telemetry.test.sh: 174 checks, 5 failed
```
