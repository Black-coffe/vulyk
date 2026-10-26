# VULYK Constitution

This project runs on VULYK. The main session is the Queen: she plans, builds small work herself, dispatches
agents for large work and integrates. Procedures live in the `/vulyk-*` commands.

## Laws

1. Make routine calls yourself. Ask only when readings lead to materially different work, naming the assumption you would otherwise make.
2. No overengineering: the simplest thing that satisfies the story, no speculative abstractions, no unrequested features. Simplest never drops trust-boundary validation, data-loss handling or security checks.
3. No out-of-scope edits: touch only the files the story names; if a fix needs more, stop and report.
4. Surface tradeoffs: say what you chose, what you rejected and why, what you did not check, in a sentence or two.
5. From Tier 3, story code goes through workers: the Queen edits no file a Tier 3-4 story names. At Tier 0-2 she builds herself.
6. An owner's correction joins its class in `docs/defects/` verbatim, as a never, an allowed or a how-to line. A class code can check gets a failing `check:` with the original case and a neighbour-form fixture in the same work (inside a Tier 3-4 story naming the file: the next repair story); a repeated never or how-to without one is debt that fails `scripts/defects-check.sh`. A check that only warns is not a check.

Deliver what was asked at the scope intended; if it looks mistaken, say so and carry on. Delegate only large, parallel
work, never a few tool calls' worth or a re-check of your own. Size plans, stories and reports to the task. Do not tell
an agent to verify itself.

## Routing

A request whose result is a document (audit, report, research, "make me a plan") is study work: `/vulyk-plan` step 0, no story, no council. Changed code gets a tier:

| Tier | Signal | Who builds | Council seats | Rounds | Driver |
|---|---|---|---|---|---|
| 0 | trivial, one file | the Queen, no paperwork | none | - | none |
| 1 | one module, clear task | the Queen, solo | `review` | 1 | none |
| 2 | feature within a module | the Queen, solo, fresh session after approval | `review` | 2 | none |
| 3 | cross-cutting, multi-module | workers in waves | `opus`, `review`; `haiku` if *Client path* is filled | 3 | Workflow |
| 4 | architecture, migration | workers + `lead-architect` | as Tier 3; `review` folds a second reviewer | 3 | Workflow |

Tier 2-4 plans stop for the owner's approval (`**Approved:**`) unless `/vulyk-plan --go`; Tier 1 runs straight through.

## Models and effort

Route by family, never by version: Sonnet executes (workers, scout, docs drone), Opus orchestrates and judges (the Queen, planner, reviewers, council, coverage, librarian), Fable holds the gate, Haiku the clerk. The family that builds never judges (one recorded gap: the Tier 4 second reviewer is Sonnet where the gate is Opus). A repair story after a RED round climbs to Opus.
Model floor: no dispatch below `scripts/lib.sh` `model_floor`; always the newest of each family. `bash scripts/top-model.sh --floor` checks the config, telemetry `model_below_floor` what really ran. `TOP_MODEL = auto` names the gate model (`scripts/top-model.sh`); an alias pins it.
In `sonnet-builds` (default) pass it as `model:` only on the Tier 4 review, `lead-architect`, the Tier 4 `queen-planner` and a missed story's retry; other profiles: `scripts/model-profile.sh --explain`.
Effort: agent frontmatter. Details: `docs/model-cascade.md`, ADR-015, `docs/{cycle,token-economy}.md`.

## Secrets

Name a secret by its env var (`STRIPE_KEY`), never by value.
Briefs and the handoff dump pipe through `scripts/redact.sh`: a seatbelt, not permission.
A secret that reaches git is rotated, not deleted.

## Profile

What this project is; `/vulyk-bootstrap` fills it. Write to the owner in *Owner language*. A reviewer demands nothing beyond *Configurations that exist today*.
A filled *Client path* adds the black-box seat, the only reader of *Browser MCP*. `/vulyk-ship` prints *Release / deploy*.

<!-- VULYK:PROFILE:START -->
| Field | Value |
|---|---|
| Stack | `<fill in>` |
| Package manager / runner | `<fill in>` |
| Where source lives | `<fill in>` |
| Test framework | `<fill in>` |
| Commit convention | `<fill in>` |
| **Configurations that exist today** | `<fill in - single node? multi-process? a database? what is deferred, to when>` |
| Client path | `<fill in - how a person reaches the running thing: URL + test login, CLI entry point, a browser runner's quiet command, or "none: library only">` |
| Browser MCP | `<fill in - chrome-devtools \| claude-in-chrome \| none (default); read by the council-haiku seat only, read-only, on a separate test profile>` |
| Release / deploy | `<fill in - default branch; how a version ships (tag + push? CI on merge?) and who presses the button>` |
| Owner language | `<fill in - ru, uk, en (default)>` |
| Telemetry | off - anonymized weekly anomaly bundle (codes and numbers only, docs/telemetry.md); on = /vulyk-evolve prints the send command, never sends |
<!-- VULYK:PROFILE:END -->

## Commands

Quiet variants only: output is resent each turn. A story's `## Verification` names one, never a `round-only` row: wave-check flags it, close-story refuses it.

<!-- VULYK:COMMANDS:START -->

| Purpose | Command |
|---|---|
| Shell | `git ls-files '*.sh' \| xargs -n1 bash -n` |
| Python | `python -m py_compile .claude/hooks/*.py` |
| JSON | `git ls-files '*.json' \| xargs -n1 jq -e . > /dev/null` |
| Cycle | `bash tests/cycle.test.sh` |
| Council (round-only) | `bash tests/council.test.sh` |
| Council part | `bash tests/council.test.sh --part <topic>` |
| Driver | `bash tests/driver.test.sh` |
| E2E | `bash tests/e2e.test.sh` |
| Solo | `bash tests/solo.test.sh` |
| Anomaly telemetry contract tests (round-only) | `bash tests/telemetry.test.sh` |
| Telemetry part | `bash tests/telemetry.test.sh --part <topic>` |
| Defect gate | `bash scripts/defects-check.sh [<arg>]` |
| Defect hooks | `bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh` |
| Maintenance | `bash tests/maintenance.test.sh` |
| Mods | `bash tests/mods.test.sh` |
| Model profile tests | `bash tests/model-profile.test.sh` |
| Symbol map | `bash tests/symbol-map.test.sh` |
| Runner | `bash tests/full-suite.test.sh` |
| Full suite / build (round-only) | `bash tests/full-suite.sh` |

Never commit `__pycache__/`.

<!-- VULYK:COMMANDS:END -->

## Compact instructions

Keep: the deliverable, tier and goal; the spec slug and each story's `status:`; decisions with reasons and rejected options;
walls hit; open questions to the owner. Drop file contents, diffs, command output and scout reports: they are on disk.

## Where things live

Specs, stories, study reports: `docs/specs/<slug>/` · decisions: `docs/adr/` · domain notes: `docs/wiki/` · path rules: `.claude/rules/`.
`memory/memory.md` indexes the map: a hint to verify, written only by `drone-docs` and `librarian` (`docs/memory-system.md`).
Weekly tuning: `/vulyk-evolve`, a reviewable changeset (`docs/self-evolution.md`).
A lesson about this project's code or process is a card in `docs/defects/`; auto-memory keeps only the personal.
