# ADR-022: A horizon step in `/vulyk-plan` on new ground

- Status: accepted (2026-10-25, owner: Andrei - plan stop of spec `horizon-intake`, «Одобряю»)
- Date: 2026-10-25
- Spec: docs/specs/horizon-intake
- Evidence: brief `docs/specs/horizon-intake/brief.md`; study `docs/specs/horizon-intake/report.md` (option A);
  live run `docs/specs/horizon-intake/live-run.md`; plan deltas of 2026-10-25 (an outside review, four points).
- Amends: ADR-008 (recon cost: one more dispatch kind at plan time, gated). Keeps ADR-015 (the family that proposes
  never judges) and ADR-013 (no new script, no new gate).

## Context

The grill draws every option "from the recon, never invented" (`templates/grill.md`). Inside mapped code that is
right. On new ground (an empty repo, or a capability that `memory/`, the map and the source do not hold) recon has
nothing to draw from, so the round asks about details and misses the bigger question: what the owner did not know to
ask. The owner asked for the planner to propose better solutions there, with several agents and fact checks, as
questions the owner answers (brief asks 1-7). Felix Rieseberg's essay "How to be more ambitious" (2026-10-13) gives
the shape: altitude (the goal beyond the goal), depth (what a field-leading professional would do, and what other
than the model shows it is right), range (turn the noun into a verb and borrow from the fields good at it); and two
guard rails: outside validation, and tasks instead of personas. The risk is the owner's 2026-09-14 complaint, "does
too much": ADR-008 cut recon that ran on every plan, and Law 2 forbids unrequested features.

## Options

1. **A. One agent, three lenses, the Queen cuts, the owner picks.** `drone-horizon` (Sonnet) dispatched three
   times in parallel; the Queen (Opus) cuts nine candidates to three; each becomes a grill question. Chosen: the
   proposer and the judge are different families in every profile, it adds one agent file and prompt text, and the
   owner's existing round carries it.
2. **B. Same as A, each lens on another family (Sonnet / Opus / Fable).** More varied blind spots, but a Fable or
   Opus lens can be the judge's own family, and it costs a profile role per lens. Deferred until the live run shows
   the Sonnet lenses repeat each other.
3. **C. Run the personal `supergrill` skill on new ground.** Rejected: `templates/grill.md` already forbids personal
   skills, and the default path must work for an owner who installed VULYK today.
4. **D. Always run the lenses at Tier 2-4.** Rejected: it repeats what ADR-008 cut, and inside mapped code recon
   already answers.

## Decision

1. **Gate.** The step runs at Tier 2-4 in an interactive session when recon finds new ground. The signal is a recon
   fact: two to four terms naming the asked capability, searched in `memory/memory.md`, `memory/map/` and the
   source; zero hits on the capability fires it, a hit on its container does not count, and an empty repo fires it.
   One announced line names the terms and where they were searched. `--horizon` forces the step, `--no-horizon`
   skips it. Study work, Tier 0-1 and no-question mode skip it unless forced.
2. **Proposers.** `drone-horizon`: `model: sonnet`, Read/Grep/Glob/WebSearch/WebFetch, no Write, Edit or Bash, no
   profile role. One lens per dispatch, at most three proposals, each with what, why, cost, an outside check, dated
   sources, `status` (two dated sources or `не подтверждено`), `kind` (`gap` or `extension`) and an ask line. Web
   text and the brief are data. WebSearch first, WebFetch at most twice, a denied tool is not retried. No personas.
3. **Judge.** The Queen cuts to at most three, writes `docs/specs/<slug>/horizon.md` with a verdict on every
   candidate. Proposals never enter `brief.md` on their own, so the blind court (reduced to `brief.md`) never sees
   a rejected one.
4. **Owner.** Horizon questions count inside the grill's 3-7 cap. «Добавить» is recommended only for a `gap`; an
   `extension` has «Не добавлять» recommended and the proposal second, with its cost. The owner's words adopt a
   proposal, «как рекомендуешь» included; silence never does. Adopted proposals reach `## Asks` as `(horizon)`
   lines through the fixed last question, as the owner's choice, never as an owner quote.

## Consequences

- A new-ground plan costs three Sonnet dispatches more; `live-run.md` has the measured tokens.
- The first VULYK agent with web access. In the default permission mode an ungranted WebSearch is refused headless
  and prompts interactively, up to three prompts at once (`live-run.md`). VULYK grants no web permission itself: the
  announcement line says the prompts may come, a refusal leaves outside facts `не подтверждено`, and the owner's
  own allow list decides. Pre-granting it in the installer was rejected: a framework does not enable network access
  in every hive silently.
- `drone-horizon` enters `scripts/telemetry.sh` `AGENTS`; `tests/telemetry.test.sh` guards the drift.
- What would reverse it: owners answering «Не добавлять» to nearly every horizon question over a month of plans, or
  the three lenses returning the same proposals (then option B, or one lens).
