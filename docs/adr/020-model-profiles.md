# ADR-020: Three model profiles, chosen once per machine

- Status: accepted (2026-10-18, owner: Andrei - the four profile asks of spec `model-profiles`, release 0.30.0)
- Date: 2026-10-18 · Version: 0.30.0
- Spec: docs/specs/model-profiles
- Amends: ADR-015 (the ladder becomes one of three profiles; the floor and the rule "the family that builds never
  judges" stand). ADR-013 D3 (the gate model) stands, with the profile added to its resolution order.

## Context

ADR-015 fixed one ladder: Sonnet writes, Opus judges, Fable holds the gate. The owner asked for a choice: some want
Opus to write and Fable to judge; others want no Fable at all. The choice is the owner's, not the framework's, so it
needs a place to live, a quiz that asks once, and a rule that keeps the builder and the judge apart in every variant.

## Decision

1. **Three profiles, named by family only.** Roles by profile:

   | role | sonnet-builds | opus-builds | economy |
   |---|---|---|---|
   | planner (Tier 3) | opus | fable | opus |
   | review (Tier 1-3 `lead-review`) | opus | fable | opus |
   | seat (both blind seats) | opus | fable | opus |
   | worker | sonnet | opus | sonnet |
   | routine | sonnet | haiku | haiku |
   | gate / architect | today's plan rule | fable | opus |
   | review-second (Tier 4) | today's rule | sonnet | sonnet |

   The Queen is `opus` in every profile.
   - `sonnet-builds` ("как сейчас") is ADR-015's ladder unchanged, and the default.
   - `opus-builds` ("Opus пишет, Fable судит"): Opus writes new code and logic; Fable plans big tasks, designs and
     judges all code.
   - `economy`: no Fable. Sonnet writes, Haiku takes the routine, Opus judges.
2. **`model: haiku` for routine stories.** Under `opus-builds` and `economy` the planner marks a routine or reusable
   story (helpers, boilerplate, a repeated pattern) `model: haiku`, with a one-line reason; the worker role writes the
   rest. This is a split by kind of story, not a ratio, and nothing counts a share. Haiku still obeys the floor
   (`top-model.sh --floor`).
3. **The family that builds never judges, in every profile.** Under `opus-builds` Fable judges, and that includes both
   blind seats (`council-opus` and `council-haiku`), which would otherwise be Opus judging Opus. The Tier 4 second
   reviewer is `sonnet`, because it must differ from the top reviewer and Fable is not it.
4. **The accepted gap.** Under `economy` the second reviewer is `sonnet`, which is also the builders' family. This is
   the gap ADR-015 already accepts on Pro and API; here it holds on every plan.
5. **One file per machine, never written by the installer.** `${CLAUDE_CONFIG_DIR:-<home>/.claude}/vulyk-model-profile`
   holds one line: `opus-builds`, `sonnet-builds` or `economy`. The installer and upgrades never write or remove it;
   only `scripts/model-profile.sh --set` does. A missing, garbled or unknown file reads as `sonnet-builds` (fail open),
   so no file means today's behaviour byte for byte, and `--chosen` exits 1 so the quiz is offered again.
6. **The resolver is the one reader.** `scripts/model-profile.sh` prints the active profile, a family per role
   (`--role`), a recommendation by plan (`--recommend`: `opus-builds` on a premium plan, else `sonnet-builds`) and a
   table (`--explain`). The gate order in `top-model.sh` is: `VULYK_TOP_MODEL`, the constitution `TOP_MODEL` pin, the
   profile, the plan, `opus`.
7. **No arguments under `sonnet-builds`.** The driver, `/vulyk-build`, `/vulyk-review` and `/vulyk-plan` pass
   `worker_model`, `review_model` and `seat_model` only when the profile is not `sonnet-builds`, so a hive that pinned
   its worker or reviewer frontmatter (ADR-015 D2, amended 2026-10-16) is not overridden. A retry still runs on the
   gate, except where the gate family also reviews (`opus-builds`): there it climbs to `opus`, so Fable never
   judges code Fable wrote.
8. **`/vulyk-models` asks once.** One quiz, in the owner's language, the recommended profile first with the plan as the
   reason, each option saying what Fable, Opus, Sonnet and Haiku do and what it costs in limits. The SessionStart brief
   offers it while no profile is chosen and never chooses for the owner. The choice can be changed at any time.

## Rejected

- **The choice stored in the hive** (a `MODEL_PROFILE = ` line in the constitution, like `TOP_MODEL`, or a key in
  `.claude/settings.json`). The owner chose one choice per machine for all hives. A constitution line costs bytes the
  7168-B budget does not have, travels in git to other people's clones, and would have to be merged on every upgrade.

## Consequences

- Under `opus-builds`, code that Sonnet wrote moves to Opus, and review moves to Fable. Whether that spends the Opus
  limit faster depends on the mix of big and small tasks; this is an estimate from VULYK's design, not a measurement.
  Watch the spend for a week after the release (`/vulyk-status`, `scripts/token-report.py`) and switch back with
  `/vulyk-models` if it hurts.
- On a non-premium plan `opus-builds` bills Fable to usage credits on top of the subscription (the quiz says so).
- A hive on 0.29 or older keeps today's ladder until it upgrades to 0.30.0; one quiz answer then covers every hive on
  the machine.

## Revisit when

- Token reports show `opus-builds` or `economy` costs more per closed story than `sonnet-builds`.
