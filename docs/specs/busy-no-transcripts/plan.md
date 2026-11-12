# A hive with no session transcripts is idle, not unknown (plan)

**Tier:** 1 · **Spec slug:** `busy-no-transcripts` · **Brief:** [brief.md](brief.md)
**Model profile:** opus-builds
**Governed by:** ADR-033 (local hives are the beta channel), ADR-034 (proposed: busy hives are held), card `public-release-per-change`
**Depends on:** post-052-tails, shipped as 0.52.0-dev.2 (96bed506, local tag)

## Goal
A hive where no Claude Code session ever ran stops being held on every ship. `--busy` reads "no transcript folder"
as idle, with its own reason line, once the naming rule is proven in this run by at least one registry hive that
does resolve to a folder; with no such hive, or no registry, it stays `unknown`, so a changed naming scheme can
never make every hive look idle.

## Assumptions
- The proof reads the registry `${VULYK_HIVES_FILE:-~/.vulyk/hives}` (paths before ` | `, `#` and blank lines
  skipped) and the same roots as `--busy`; one exact `<root>/projects/<slug>/` folder for any registered hive is
  enough. The hive being judged counts too (if it has a folder, the old path runs anyway).
- Reason line: `idle no session transcript folder for <hive> (no Claude Code session has run there)`; exit 0, so
  `/vulyk-ship` step 2a needs no text change (it upgrades on `idle`).
- Map and ADR-034 wording are left to the ship's docs pass.

## Stories

**Wave 1**
- `busy-no-transcripts-01` — `--busy`: no transcript folder = idle when the registry proves the naming rule; tests (red: required)

## Contracts
- none

## Integration gate
`bash tests/full-suite.sh`

## Descoped

*(empty)*

## Plan deltas

**Briefed:** via mini-brief, Andrei, 2026-11-12
**Branch:** vulyk/busy-no-transcripts
**Council:** ESCALATE round 1, 2026-11-12, at e4701761, pack 16fba058c6bd
**Council:** GREEN round 2, 2026-11-12, at 8e52d3ed, pack 4b61f37ccd66

## Needs a human
- reason: ceiling · round 1 · 2026-11-12
- ask 1: BLOCK by the reviewer - see docs/specs/busy-no-transcripts/council/round-1/review.md
- seats: docs/specs/busy-no-transcripts/council/round-1/
