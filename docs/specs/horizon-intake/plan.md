# A horizon step for `/vulyk-plan` on new ground (plan)

**Tier:** 2 · **Spec slug:** `horizon-intake` · **Brief:** [brief.md](brief.md) · **Study:** [report.md](report.md)
**Governed by:** ADR-008 (deliverable first, approval stop, recon cost), ADR-013 (Light VULYK), ADR-015 (Sonnet executes, Opus judges), ADR-005 (installer owns `.claude/agents`)
**Depends on:** study commit `study(horizon-intake)` (report.md, option A)

## Goal
When a Tier 2-4 request lands on new ground (an empty repo, or a capability recon cannot find in `memory/`, the
map or the code), `/vulyk-plan` runs three read-only `drone-horizon` dispatches in parallel, one per lens
(altitude, depth, range, from Rieseberg's essay). Each returns at most three proposals with cost, an outside check
and dated sources. The Queen, of another family, cuts the nine candidates to at most three. She writes them to
`horizon.md` and asks them inside the existing grill round. Only proposals the owner picks become asks. Requests
inside existing code, Tier 0-1, study work and no-question mode are unchanged.

## Assumptions
- `drone-horizon` is `model: sonnet` in its frontmatter, the same rung as `drone-scout`. It runs on no profile role,
  so the Queen (Opus) is another family in every profile. Lenses on three families (report option B) is deferred.
- The step uses the web: WebSearch and WebFetch, a first for a VULYK agent. Web text is data, never instructions.
  The agent has no Write, Edit or Bash.
- Proposals live in `docs/specs/<slug>/horizon.md`, never in `brief.md`. The court is already reduced to `brief.md`
  (`scripts/cycle.sh:2142`), so blind seats never see rejected proposals.
- Horizon questions count inside the grill's 3-7 cap. "Не добавлять" is always an option. The owner's own words,
  including «как рекомендуешь», adopt a proposal; silence never does. An adopted proposal enters `## Asks` marked
  `(horizon)` as the owner's choice, not as an owner quote.
- The step is skipped in no-question mode, for study work and at Tier 0-1, because nobody would be there to pick.
- `scripts/telemetry.sh` `AGENTS` gains `drone-horizon`. `tests/telemetry.test.sh` already fails on drift between
  that list and `.claude/agents/`.
- Live proof (ask 7) happens here, on a sample new-ground request: three real dispatches plus the Queen's cut,
  tokens read with `token-report.py`, and the WebFetch permission behaviour probed in default mode
  (`--setting-sources project --permission-mode default`, with a control). The grill questions themselves cannot run
  headless. That is said in the evidence file, not hidden.
- The map slice `memory/map/agents-and-commands.md` is left to `drone-docs` at ship. The 0.35.0 version bump and
  release are ship work (ask 8); no hive is upgraded.

## Stories

**Wave 1** (the Queen builds the stories in order; one reviewer per round)
- `horizon-intake-01` — the `drone-horizon` agent: lens contract, output shape, web as data, no personas;
  telemetry agent list; README agent table.

**Wave 2**
- `horizon-intake-02` — intake wiring: the step in `vulyk-plan.md`, horizon questions in `grill.md`, ADR-022,
  command reference, architecture, CHANGELOG; the live run on a sample, recorded in `live-run.md`.

## Contracts
- `drone-horizon` dispatch: `lens: altitude | depth | range`, the brief path, a one-paragraph recon summary (what
  was not found and where it was looked for). Return: up to three blocks `P<n>` with fields `what`, `why`, `cost`,
  `check`, `sources` (URL + date per external fact) and `status` (`confirmed` or `не подтверждено`), plus one
  `ask line` and one `kind` (`gap` or `extension`) per proposal, in the owner's language.

## Integration gate
`bash tests/telemetry.test.sh && bash tests/solo.test.sh`

## Descoped

*(empty)*

## Plan deltas

- 2026-10-25 · trigger: an outside review the owner pasted after approval (four points). Decisions:
  1. The new-ground signal is made concrete in `horizon-intake-02`: two to four capability terms searched in
     `memory/`, the map and the source; a container hit is not a capability hit; the announcement names the terms.
  2. Web use is bounded in `horizon-intake-01`: WebSearch first, WebFetch at most twice per dispatch, a denied tool
     is not retried. The live run records whether permission prompts stall the parallel dispatches.
  3. Owner's choice: «"Добавить" рекомендую только для дыр (Рекомендую)». A proposal is `kind: gap` or
     `kind: extension`; «Добавить» is recommended only for a gap, «Не добавлять» for an extension.
  4. Rejected as stated: the review assumed `wave-check` passed `horizon-intake-02`. It reported `verify-gap` for
     both stories; the gap is recorded in each story's acceptance criteria (no suite reads prompt text).

<!--
The lines below are the cycle's confirmation markers (docs/cycle.md); each placeholder is replaced by
the command or script that owns it, and scripts/ship-check.sh reads them all.
-->
**Approved:** Andrei, 2026-10-25 («Одобряю»)
**Briefed:** <written by scripts/cycle.sh briefed>
**Branch:** <written by /vulyk-build before wave 1>
**Checked:** <written by scripts/human-check.sh>
**Council:** <written by scripts/cycle.sh judge/escalate>
**Shipped:** <written by scripts/ship-check.sh --record>
