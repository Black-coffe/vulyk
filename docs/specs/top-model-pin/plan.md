# The gate-model pin is read from the constitution, and --floor judges it (plan)

**Tier:** 1 · **Spec slug:** `top-model-pin` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-013 D3 (the gate model), ADR-015 (the model floor)
**Depends on:** v0.26.1; shares no file with `constitution-merge`, `upgrade-keeps-host-edits` or `handoff-ownership`

## Goal
`scripts/top-model.sh` takes the `TOP_MODEL` pin from the constitution only: `CLAUDE.vulyk.md` when a hive keeps its
own `CLAUDE.md` beside it, else `CLAUDE.md`. Prose in a project's own `CLAUDE.md` can no longer pin the gate, and a pin
in `CLAUDE.vulyk.md` is honoured. `--floor` also judges the resolved gate model, so a constitution pin or a
`VULYK_TOP_MODEL` below the floor fails it instead of printing "ok" beside it.

## Assumptions
- The one hive whose gate this changes is on 0.17 mid-build and would not get the fix by `/vulyk-update` soon; its
  triggering prose line was removed there by hand on 2026-10-14 (the owner's correction, card
  `framework-fix-skips-live-hives`).
- No fallback to the project's `CLAUDE.md` when `CLAUDE.vulyk.md` exists: that fallback is exactly how the prose pin
  got in. Survey of 25 hives: one hive's gate changes (a dead `claude-opus-4-8` -> its constitution's `opus`).
- A below-floor pin still resolves to itself (no silent swap to `auto`); `--floor`, which the session brief and the
  hive launch already run, is where it gets loud.
- The first `TOP_MODEL = ...` match inside the constitution file still wins (no line anchoring): the release puts the
  line in `## Models and effort`, before any project section.

## Stories

**Wave 1**
- `top-model-pin-01` — `constitution_pin()` reads the constitution file, `--floor` judges the gate model, the header
  and `docs/model-cascade.md` name the pin's home, cases in `tests/telemetry.test.sh`, the Law 6 card for the owner's correction
  (a fix in VULYK does not reach a live hive on an old version by itself)

## Contracts
- `--floor` line for the gate: `below floor: gate model (<constitution|env>) = <id> is <family> <version>, floor <floor>`
  (the `below()` shape with `gate model (<source>)` as the where).
- `--explain` `decided by: constitution - <CLAUDE.vulyk.md|CLAUDE.md> pins TOP_MODEL = <alias>`.

## Integration gate
`bash tests/telemetry.test.sh` · `git ls-files '*.sh' | xargs -n1 bash -n`

## Descoped

*(empty)*

## Plan deltas

**Approved:** <owner, date - the approval stop>
**Briefed:** via mini-brief, Andrei, 2026-10-13
**Branch:** vulyk/top-model-pin
**Checked:** <written by scripts/human-check.sh after the owner has looked>
**Council:** GREEN round 1, 2026-10-14, at ae40209, pack f28b46d7666c
**Shipped:** 0.26.2, 2026-10-14, at ee34fdc - merged to main
