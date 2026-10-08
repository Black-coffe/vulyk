# ADR-015: Sonnet executes, Opus judges, Fable holds the gate - and no model runs below the floor

- Status: accepted (2026-09-28, owner: Andrei - "бери в работу и давай делать минорное обновление");
  amended 2026-10-07 (0.26.0, spec `haiku-5-5-floor`, owner: "Минимум Hiku 5,5"): Haiku 5.5 shipped,
  `cycle-clerk` moves to `haiku`, and the haiku floor line reads `haiku 5.5 cc>=2.1.293` - the alias
  table ships inside Claude Code, and 2.1.292 still ran `haiku` as Haiku 4.5. `--floor` reads the
  running Claude Code's version, and checks the haiku remap and a provider's haiku pin. `/vulyk-build` now
  refuses to launch the hive while `--floor` exits 1: the floor is enforced at that launch, not only reported.
- Date: 2026-09-28 · Version: 0.20.0
- Spec: docs/specs/sonnet-5-5-ladder (study report and source table; built by the Queen's session
  directly, the Law 5 exception the owner granted on 2026-09-22)
- Supersedes:
  - the rungs of ADR-012 (its gate rule, `TOP_MODEL` and effort-in-frontmatter stand);
  - the "junior rung" of ADR-013 (its gate scope, D3, stands);
  - ADR-012 D3's `status --json` default story `model` (`opus` becomes `sonnet`).

  ADR-007's Haiku rule stands and is now written as a floor.

## Context

Sonnet 5.5 shipped on 2026-09-28. The evidence and the source table are in
`docs/specs/sonnet-5-5-ladder/report.md`. What decided the change:

- Price per MTok: Sonnet 5.5 $2/$10, Opus 5.5 $4/$20, Fable 5.1 $10/$50. Cache read $0.20, $0.20
  and $0.25.
- Anthropic's own table, Sonnet 5.5 against Opus 5.5:
  - Terminal-Bench 4.0: 70.6% against 66.4%.
  - OSWorld 2.1: 80.1 against 81.8.
  - GDPval-AA: 1844 against 1846.
  - FrontierCode 1.1: 46.2 against 54.4.
  - HLE: 64.5 against 67.7.

  That is a vendor table with no independent replication yet.
- Anthropic's guidance: Sonnet 5.5 for "well-scoped everyday tasks, fixing bugs, and creating polished
  documents"; Opus 5.5 for "complex work requiring careful judgment"; "for the hardest long-horizon
  work, an Opus model is the better choice".
- Sonnet 5.5's prompting guide names four behaviours:
  - at `low`/`medium` it may stop and check in before a long task is done;
  - at `low` it may skip verification;
  - at every level it adds unrequested tests and docs;
  - at `xhigh`/`max` it starts its own review rounds.
- Claude Code's model-config page: the `sonnet` alias resolves to Sonnet 4.5 on Bedrock and Google
  Cloud, and to Sonnet 4.6 on Claude Platform on AWS. On Microsoft Foundry, `opus` resolves to
  Opus 4.6. Six env vars can remap any alias to any ID. Routing by alias therefore does not guarantee
  the newest model, and nothing in VULYK noticed when it did not.

## Decision

1. **Four families, cut by kind of work.** The family that builds never judges.

   | Family | Job | Agents |
   |---|---|---|
   | Fable (gate, `TOP_MODEL`) | short, high-stakes calls | the Tier 4 `lead-review`, `lead-architect`, the Tier 4 `queen-planner`, a missed story's retry |
   | Opus | orchestrate, plan, judge | the Queen, `queen-planner`, `lead-review` at Tier 1-3 and the second reviewer beside Fable, `lead-architect` where the gate is `opus`, `council-opus`, `council-haiku`, `drone-coverage`, `librarian` |
   | Sonnet | execute well-scoped work | `worker-code`, `worker-test`, `drone-scout`, `drone-docs`, `cycle-clerk`; the Tier 4 second reviewer beside an Opus gate |
   | Haiku | mechanical, and only at or above the floor | none today; `cycle-clerk` once a Haiku >= 5.5 ships |

2. **Stories default to `model: sonnet`.** Changed in `templates/story.md`, `cycle.sh status --json`,
   `queen-planner` and `/vulyk-plan`. A planner writes `model: opus` for a story that is long-horizon
   or judgment-heavy, and says why in one line.
3. **The black-box seat moves to `opus`.** It judges, and the workers now write on Sonnet. The plan to
   move it to Haiku is retired.
4. **Effort.**
   - Workers: `medium`, per Anthropic's "well-specified" advice. Their prompts carry Anthropic's scope
     and verification paragraphs.
   - `drone-scout`, `drone-docs`, `cycle-clerk`: `low`.
   - Everything else as in ADR-012.
5. **The model floor.** A few lines of data, `model_floor` in `scripts/lib.sh`:
   `fable 5.1 · opus 5.5 · sonnet 5.5 · haiku 5.5 unreleased`. `unreleased` marks a floor no model
   meets yet, so the bare `haiku` alias counts as below it. Env `VULYK_MODEL_FLOOR` overrides it line
   by line. Three places enforce it:
   - `scripts/top-model.sh --floor` runs before the fact. It checks env and settings pins, a provider
     flag with no family pin, and the `model:` of agent frontmatter, the story template and every
     story. It exits 1 on a finding, and the SessionStart brief prints its result.
   - Telemetry code `model_below_floor` runs after the fact. `scan` reads the model each main and
     subagent transcript actually ran on.
   - Routing names families, never versions, so a new generation still arrives without an edit.

6. **A repair story climbs to `opus`.** `cycle.sh repair` writes `model: opus`. The Sonnet work
   was judged wrong by a RED round, so the repair climbs a rung, as a missed story's retry climbs to
   the gate.

## Rejected

- **Workers stay on Opus.** It is simpler, but it keeps the reviewer at Tier 3 on the builder's
  model, and it leaves the retry on Pro and API with no rung to climb.
- **The black-box seat on Sonnet or Haiku.** Sonnet would judge its own family's code, and the
  owner asked for Haiku to stay minimal.
- **Pin full model IDs.** That is the per-release rewrite this ADR exists to end.
- **A self-raising floor from the highest version seen in local transcripts.** It needs a state file
  and gives different answers on different machines. The alias already brings the newest model; the
  floor only has to catch regressions.
- **`availableModels` / `deniedModels`.** They are managed settings for enterprise administrators, not
  something a framework can ship.

## Consequences

- The retry climbs a rung on every plan: Sonnet to Fable on Max, Sonnet to Opus on Pro and API. The
  gap ADR-012 recorded is closed.
- At Tier 3, `lead-review` (Opus) judges code a different family wrote.
- On Pro and API the Tier 4 second reviewer is `sonnet`, the builder's family. Fable would bill
  credits there, and a second Opus would duplicate the gate. This is the accepted gap.
- Raising the floor when a model ships is a one-line diff in `scripts/lib.sh` plus a CHANGELOG line.
- `--floor` warns and never edits settings. The provider's model IDs are the owner's to set.

## Revisit when

- `token-report.py` shows a Sonnet story costs more per closed story than the 0.19 Opus stories.
  Then `model: opus` goes back into the template and the `cycle.sh` default.
- The `agent_empty` rate rises on Sonnet workers. Then the worker files get `effort: high`.
- Haiku 5.5 ships. Then `cycle-clerk` moves to `haiku`, after its model is checked against the floor.
  Done in 0.26.0 (see the Status amendment).
- Artificial Analysis or another independent source publishes Sonnet 5.5's per-task cost.
