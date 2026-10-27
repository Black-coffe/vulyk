# Brief: post-037-tails

Date: 2026-10-27 · Deliverable: code (`/vulyk-plan --go`, Tier 3: the ship gate, telemetry, the symbol-map script and its
protocol lines, the ship command's publish step) · Source: the owner, two sessions

## Request (verbatim)

> Собери все в зендоф и в слдедующей сессии запусти все в реализацию, закрыть все хвасты и мелочи по твоим рекомендациям и рекомендациям тройногоь агентрирования

(2026-10-26, end of the symbol-map session; «зендоф» = handoff, «тройногоь агентрирования» = the three-model panel, crossgrill.)

> Бери в работу то что в хендофе прописано прошлом

(2026-10-27, this session.)

## The work list (model text from the handoff, not owner quotes)

Source: `.claude/handoff/20261027-071125-2f8f3db1.md` `### Work list`, items A-D. Item E (hive upgrades) runs after the
release; item F (stats commit, untracking the litopys chronicle) was done in `7cbce05` before this brief.

- A. `scripts/ship-check.sh` printed READY at stage 05 while `bash scripts/human-check.sh --check docs/specs/symbol-map`
  said STALE: commit `ef21b7c` landed after the owner's ACCEPTED at `3f5fe9a`. Cause (Queen's recon): in the council
  branch, a `**Checked:** ACCEPTED` newer than the council row overrides to READY without the pack/commit staleness
  test that the no-council branch and `human-check --check` apply (`scripts/ship-check.sh:236-255`).
- B. v0.36.0 and v0.37.0 were tagged on a red CI run. The publish step `/vulyk-ship` prints says nothing about CI.
- C. symbol-map leftovers (council round-1/2 `UNASKED` and minors, panel verdict): C1 a `.py` run from a bash wrapper
  (`"$(dirname "$0")/symbol-map.py"`) is invisible; C2 `tests/fixtures/**` shows up as tests and guard tests for
  every input; C3 path mentions list `CHANGELOG.md`, `CLAUDE.md`, `README.md` first and the cap of 5 is spent on them;
  C4 speed on a bash input (5.3 s measured then, 1.55 s on `scripts/lib.sh` today, 0.34 s on a `.py`; the owner's
  wish was ~0.2 s); C5 a one-line doc for the script; C6 `vulyk-plan.md` has one 163-char line in a file wrapped at
  ~104; C7 tighter planner hand-off; C8 round-1 minors: `! missing` lost past the byte cap, `replay.py` glob expansion
  under MSYS bash, every path under a `tests/` segment counts as a test.
  Not to build (panel 3/3, owner agreed): a close-time gate on removed defs, git co-change, JS/TS/PHP edges,
  tree-sitter/ctags/LSP.
- D. Telemetry rows in the VULYK repo carry `"vulyk":"0.0.0"`. Cause (Queen's recon): `vulyk_version()` reads only
  `.claude/vulyk-version`, which `install.sh` writes into hives; VULYK's own tree has `VERSION` (0.37.0) and no stamp
  (`scripts/telemetry.sh:154-163`). No hive under `E:/Projects` carries `install.sh` or `VERSION`.

## Answers (grill, 2026-10-27; the owner picked the options quoted)

1. B, how to stop tagging on red CI: «Правило в /vulyk-ship (Рекомендую)». The publish step `/vulyk-ship` prints
   orders push, then green CI on the release commit, then the tag. VULYK's own Profile row stays `<fill in>` (its
   CLAUDE.md ships to new hives as the template).
2. D, the 0.0.0 version: «Читать VERSION (Рекомендую)». No stamp, but `install.sh` and `VERSION` side by side (VULYK's
   own tree) -> the version comes from `VERSION`.
3. C4, speed: «Замер + дешёвые правки (Рекомендую)». Profile, cut needless reads and parses, no on-disk cache, record
   the before and after figures; no hard time limit in a test.
4. The list read back and confirmed: «Верно, запускай (Рекомендую)». Straight through, no approval stop.

## Asks

1. `scripts/ship-check.sh` no longer prints READY when code changed after the owner's `**Checked:** ACCEPTED`: stage 05 applies the same pack/commit staleness rule as `scripts/human-check.sh --check`, with a failing test on the 0.37 case (ACCEPTED, then a code commit, under a GREEN council row).
2. `/vulyk-ship`'s printed publish step says: tag only after CI on the release commit is green.
3. `scripts/symbol-map.sh`: a `.py` run from a bash script shows as linked; `tests/fixtures/**` never shows; path mentions list code, ADR and tests before `CHANGELOG.md`, `CLAUDE.md`, `README.md`.
4. symbol-map speed on a bash input is profiled and the cheap fixes made, before/after figures recorded.
5. symbol-map gets a one-line doc where the docs list scripts; the 163-char line in `vulyk-plan.md` is rewrapped.
6. The planner hand-off from symbol-map is tighter: `exact` lines plus counts of the rest.
7. The council's round-1 minors on symbol-map are checked and the live ones fixed (`! missing` lost past the byte cap, `replay.py` glob expansion under MSYS bash, any path under a `tests/` segment counting as a test).
8. Telemetry rows in VULYK's own repo carry the version from `VERSION`, not 0.0.0.
