---
story: solo-gate-1118-01
spec: solo-gate-1118
status: done
returned: DONE
tier: 2
worker: worker-code
wave: 1
blocked_by: []
---

# Tier 1-2 rounds run no full suite; the merge run is the one full run

## Goal
At Tier 1-2 the round's test gate writes a finished `SUITE: none` log instead of running the full suite, also in
the narrow round after a repair; Tier 3-4 and an owner's `--full` round run it as today. The merge run stays.

## Requirements
> Правку гейта Tier 1 бери в 0.54
> 1. At Tier 1-2 the round's test gate runs no full suite: `cycle.sh suite` writes a finished `SUITE: none` log with its reason (the stories' own checks ran at close-story; the full suite runs once before merge), so the full suite runs once per Tier 1-2 spec, at the merge run.
> 2. The narrow round after a Tier 1-2 repair runs no gate step either (`rerun=` empty, `SUITE: none - narrow repair round`), never `all` because round 1 logged no steps.
> 3. Tier 3-4 rounds, and a round the owner opened with `--full` at any tier, run the gate as today.
> 4. The tier is the round's frozen `tier=` (ROUND), not plan.md read again.
> 5. `lead-review.md` and the docs and command files that describe the round's gate say so; the reviewer treats the Tier 1-2 `none` as expected, not a finding.
> - 2026-11-18, from a side-agent note the owner forwarded (Queen's wording): split every gate part that ran over 185 s in the docs-1115 green merge run (council `roster` 207 s, `round-scope2` 191 s; telemetry `upgrade` 189 s, `wiring` and `wiring2` 186 s), so this spec's own merge run does not go red by growth; `tests/telemetry.test.sh` joins the story's Files.
> 6. Opt-in only: the change acts only where the repo's default branch holds a root file `.vulyk-solo-gate` whose content is exactly `merge-only`; missing, empty or any other content is today's behaviour, and a spec branch cannot switch its own gate off. The installer does not ship the file; VULYK's own repo carries it.

## Files
- .vulyk-solo-gate
- scripts/cycle.sh
- tests/council.test.sh
- tests/telemetry.test.sh
- tests/cycle.test.sh
- .claude/agents/lead-review.md
- .claude/commands/vulyk-build.md
- .claude/commands/vulyk-review.md
- docs/cycle.md
- docs/command-reference.md
- docs/token-economy.md
- docs/defects/*

## Non-goals
- No change to `ship-check.sh` (it already demands the merge run when the round log is not `SUITE: ok`), to
  Tier 3-4 gates, the driver, or `CLAUDE.md`.

## Acceptance criteria
- [ ] The switch: one helper reads `git show "$(default_branch):.vulyk-solo-gate"`; true only for exactly `merge-only`
      (CR and trailing newline dropped). `.vulyk-solo-gate` (content `merge-only`) is committed at the repo root.
- [ ] cmd_suite: with the switch on, a non-narrow round whose `round_tier` is 1 or 2 and whose ROUND is not `full=asked` writes
      `head=<round head> steps=0` + `SUITE: none - Tier 1-2: the stories' checks ran at close-story; the full suite
      runs once before merge`, commits it as paperwork, emits done; no step runs.
- [ ] round_rerun: with the switch on, at Tier 1-2 (the repaired round's frozen tier) returns empty, so the narrow round takes the
      existing `SUITE: none - narrow repair round` path.
- [ ] Tests (council.test.sh, the suite parts): the existing fixtures name their tier explicitly where they need a
      running gate; new cases: switch off (no file / typo / file only on the spec branch) -> Tier 1 runs as today; switch on: Tier 1 none, Tier 2 none, Tier 3 runs, `--full` at Tier 1 runs, Tier 1 repair then
      round 2 runs no step; ship-check still says `suite: no full run` for a Tier 1 spec with only the round log.
- [ ] install.sh unchanged: its trees (install.sh:1827) hold no root dotfile; a note line says so.
- [ ] Gate parts split: council `roster`, `round-scope2`; telemetry `upgrade`, `wiring`, `wiring2`; blocks moved as they
      are, each old part's check count equal to the sum of its new parts (the `bash -n` preamble counted per part).
- [ ] lead-review.md: a `SUITE: none - Tier 1-2 ...` line is copied like any other and is no finding.
- [ ] Doc lines: vulyk-build.md step 3, vulyk-review.md step 2, docs/cycle.md gate lines, command-reference solo
      paragraph, token-economy narrow-round paragraph.

## Verification
`bash tests/council.test.sh --part suite`
`bash tests/council.test.sh --part suite2`
`bash tests/council.test.sh --part suite3`
`bash tests/council.test.sh --part solo-gate`
`bash tests/council.test.sh --part round-scope`
`bash tests/council.test.sh --part round-scope2`
`bash tests/council.test.sh --part round-scope5`
`bash tests/council.test.sh --part round-scope6`
`bash tests/council.test.sh --part round-scope7`
`bash tests/council.test.sh --part roster`
`bash tests/council.test.sh --part roster3`
`bash tests/telemetry.test.sh --part upgrade`
`bash tests/telemetry.test.sh --part upgrade2`
`bash tests/telemetry.test.sh --part wiring`
`bash tests/telemetry.test.sh --part wiring2`
`bash tests/telemetry.test.sh --part wiring3`
`bash tests/cycle.test.sh --part merge-gate`
`bash tests/solo.test.sh`
`bash tests/maintenance.test.sh --part upkeep`
`bash scripts/defects-check.sh`

## Implementation notes
- scripts/cycle.sh: `solo_gate_on` reads `git show <default_branch>:.vulyk-solo-gate` (CR dropped) and is true only for
  exactly `merge-only`; `solo_tier` reads the round's frozen tier (`round_tier`). cmd_suite: a non-narrow round with no
  log yet, Tier 1-2, opt-in on and `full=` neither `asked` nor `design` writes `head=<round head> steps=0` + `SUITE: none -
  Tier 1-2: ...`, commits it as paperwork and emits done. round_rerun returns empty at Tier 1-2 with the opt-in on, so the
  narrow round after a repair takes the existing `SUITE: none - narrow repair round` path (Fable's trap: `all` otherwise).
- `.vulyk-solo-gate` (`merge-only`) at the repo root. install.sh unchanged: its trees (`.claude memory bootstrap templates
  scripts docs/wiki docs/specs docs/adr docs/defects`) hold no root dotfile, so no hive gets the file.
- tests/council.test.sh part `solo-gate`: on/Tier 1 (original case), Tier 2, Tier 3 runs, `--full` at Tier 1 runs, a Tier 2
  repair (round 2 narrow, `rerun=` empty, no step), off: no file / a typo / the file only on the spec branch. Red on the
  old cycle.sh (Tier 1, Tier 2 fail); red without the round_rerun line (the narrow case fails). `sx_nr` moved to the
  shared suite helpers. tests/cycle.test.sh part merge-gate: a Tier 1-2 none log is no full run (`suite: no full run`).
- lead-review.md, vulyk-build.md step 3, vulyk-review.md step 2, docs/cycle.md, command-reference solo paragraph,
  token-economy narrow-round paragraph: one line each.
- Gate parts split (plan delta): council roster -> roster + roster3 (38 = 19 + 19 checks), round-scope2 -> round-scope2 +
  round-scope7 (7 = 3 + 4); telemetry upgrade -> upgrade + upgrade2 (39 = 19 + 22 - 2 per-part bash -n), wiring -> wiring +
  wiring3 (86 = 65 + 23 - 2); wiring3 builds the install cache it reads, two checks that read files of the first half stayed
  there. Not split: telemetry wiring2 (121 s alone): its time is the shared fixture (two installs and a tagged clone), so a
  split would run it twice; the next growth there is a fixture cut, not a block move.
- No docs/defects card edited: no owner correction in this work.

## Findings
