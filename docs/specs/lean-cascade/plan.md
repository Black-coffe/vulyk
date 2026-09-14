# Lean cascade: the framework stops doing more than it was asked (plan)

**Tier:** 3 · **Spec slug:** `lean-cascade` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-001 (state contract - `wave_stories` gains a key, nothing else moves), ADR-002 (council never to zero - held), ADR-007 and ADR-008 (written by this spec)
**Depends on:** v0.12.0 (`a7e8c5d`) and the `v0-12-0-remainders` branch at `30a6e3d` (this branch forks from it so the `cycle.sh` edits sit on the newest `close-story`/`wave_stories` code)

## Goal
Answer the owner's three asks with files, not intentions: (1) a validation of the "does too much"
claim against the framework's own text - it holds, and ADR-008 quotes the lines; (2) an
optimisation that removes the mechanisms behind it - the deliverable check, the approval stop as
default, capped recon, one suite run per close, the fallback driver behind a flag, a leaner
constitution; (3) the four-rung model ladder with no Haiku until a Haiku 5 exists, the retry one
rung up, and Tier 2's court shrunk to `sonnet` + `review`.

## Assumptions
- **Law 5 is suspended for this spec by the owner's word** ("это должен делать только ты, Fable
  5.1. Никакие другие AI"): every edit was made by the Queen in a separate worktree, no worker
  and no council seat (Sonnet/Opus) was dispatched. The one review is `lead-review` on the top
  model - a second context on the same model, which is the closest the owner's rule allows to a
  gate. Recorded here so `/vulyk-ship`'s reader knows why there is no `**Council:**` row.
- The seat id `haiku` stays as the black-box seat's name and `council.jsonl` key; renaming it
  across `cycle.sh` and 2 400 lines of tests buys nothing the rule needs (ADR-007).
- No resolver detects the Haiku generation - the flip is a documented three-file edit.
- The `v0-12-0-remainders` driver was running on the main tree throughout; this branch rebases
  onto that branch's head before merge and expects a small conflict in `scripts/cycle.sh`
  (`required_seats_for_tier`, `wave_story_json`) if story 11/13 touch the same lines.

## Stories

Done by hand under the assumption above; listed so the diff has a map.

**Wave 1 - the state machine and its tests**
- `lean-cascade-01` — `scripts/cycle.sh`: Tier 2 seats `sonnet review`; `wave_stories` objects carry `"model"` from story frontmatter (default `sonnet`). `tests/council.test.sh` tier-2 scenarios and `wave_stories` fixtures updated; an extra recorded seat is still accepted.
- `lean-cascade-02` — `.claude/workflows/vulyk-cycle.js`: first dispatch on the story's `model`, second dispatch on `opus`. `tests/driver.test.sh` asserts both.

**Wave 2 - the roster**
- `lean-cascade-03` — `council-haiku.md`, `cycle-clerk.md`, `session-end-learnings.sh` on `sonnet` (junior rung); `lead-review.md` runs only what the diff makes suspicious.

**Wave 3 - the commands**
- `lean-cascade-04` — `/vulyk-plan`: step 0 deliverable check and `--study`; capped recon; coverage at Tier 3-4; the approval stop as default, `--go` opt-in; `model:` per story. `templates/grill.md`: straight-through opt-in replaces the two-stop opt-out.
- `lean-cascade-05` — `/vulyk-build --fallback` gate and the per-dispatch model rule; `/vulyk-review` seats by tier; `scripts/state.sh` shows `study`.

**Wave 4 - the constitution and the record**
- `lean-cascade-06` — `CLAUDE.md` rewritten lean (236 -> ~200 lines): deliverable rule, ladder table, cycle table, token economy; markers preserved for `install.sh`.
- `lean-cascade-07` — ADR-007, ADR-008, CHANGELOG 0.13.0, VERSION, `docs/model-cascade.md`, `token-economy.md`, `cycle.md`, `architecture.md`, `getting-started.md`, `command-reference.md`, `hooks-reference.md`, `self-evolution.md`, README, the two map slices, a learnings note.

## Contracts
- `status --json` `wave_stories[]` = `{"file","story","worker","model","repeat"}` (C3 amended). Consumers: the Workflow driver, the fallback loop in `/vulyk-build`, the council suite fixtures.
- `required_seats_for_tier`: 1 → `sonnet`; 2 → `sonnet review`; 3 and 4 → `haiku sonnet opus review` (C15 amended). Frozen into a round at `open-round` as before.
- `plan.md` stage 02: `**Approved:**` is the default confirmation; `**Briefed:**` is written only by `--go`, Tier 1, and no-question mode with `--go`.

## Integration gate
`git ls-files '*.sh' | xargs -n1 bash -n && python -m py_compile .claude/hooks/*.py && git ls-files '*.json' | xargs -n1 jq -e . > /dev/null && bash tests/cycle.test.sh && bash tests/driver.test.sh && bash tests/council.test.sh`

## Descoped
- Renaming the `haiku` seat id to an angle name (`blackbox`) - ADR-007 says why not now.
- A `ceiling` of 2 rounds instead of 3 - the half-RED early escalation already covers the plan-is-wrong case, and 53 test assertions pin the number; left for a measured decision.
- A Haiku-generation resolver - would be a guess in a script.

## Plan deltas

*(none)*

**Approved:** Andrei, 2026-09-14 - in chat, the request itself: "Вот это всё нужно сделать, поправить"
**Briefed:** <n/a - approved directly>
**Branch:** vulyk/lean-cascade (worktree ../vulyk-lean, forked from vulyk/v0-12-0-remainders at 30a6e3d)
**Checked:** <owner's look after the lead-review pass>
**Council:** <none - Law 5 suspended by the owner, see Assumptions>
**Shipped:** <written by scripts/ship-check.sh --record>
