# VULYK Constitution

This project runs on VULYK. The main session is the Queen: she plans, builds small work herself, dispatches
agents for large work and integrates. Procedures live in the `/vulyk-*` commands.

## Laws

1. Make routine calls yourself. Ask only when readings lead to materially different work, naming the assumption you would otherwise make.
2. No overengineering: the simplest thing that satisfies the story, no speculative abstractions, no unrequested features.
3. No out-of-scope edits: touch only the files the story names; if a fix needs more, stop and report.
4. Surface tradeoffs: say what you chose, what you rejected and why, in a sentence or two.
5. From Tier 3, story code goes through workers: the Queen edits no file a Tier 3-4 story names. At Tier 0-2 she builds herself.

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

Opus 5.5 is the workhorse (clerk and black-box seat: Sonnet). `TOP_MODEL = auto` names the gate model (`scripts/top-model.sh`; replace `auto` with an alias to pin).
Pass it as `model:` only on the Tier 4 review, `lead-architect`, the Tier 4 `queen-planner` and a missed story's retry.
Effort lives in agent frontmatter; on Opus 5.5 and Fable 5.1 changing it keeps the cache, a `/model` switch does not.
Details: `docs/model-cascade.md`, `docs/cycle.md`, `docs/token-economy.md`.

## Secrets

Name a secret by its env var (`STRIPE_KEY`), never by value.
Briefs and the handoff dump pipe through `scripts/redact.sh`: a seatbelt, not permission.
A secret that reaches git is rotated, not deleted.

## Profile

What this project is; `/vulyk-bootstrap` fills it. A reviewer demands nothing beyond *Configurations that exist today*.
A filled *Client path* adds the black-box seat, the only reader of *Browser MCP*. `/vulyk-ship` prints *Release / deploy*.

<!-- VULYK:PROFILE:START -->
| Field | Value |
|---|---|
| Stack | `<fill in>` |
| Package manager / runner | `<fill in>` |
| Where source lives | `<fill in>` |
| Test framework | `<fill in>` |
| Commit convention | `<fill in>` |
| **Configurations that exist today** | `<fill in - single node? multi-process? a database at all? what is deferred and to when>` |
| Client path | `<fill in - how a person reaches the running thing: URL + a test login, a CLI entry point, or a browser runner's quiet command; "none: library only" is an honest answer>` |
| Browser MCP | `<fill in - chrome-devtools \| claude-in-chrome \| none; optional, read by the council-haiku seat only, read-only, on a separate test profile - none is the honest default without one>` |
| Release / deploy | `<fill in - default branch; how a version is published (tag + push? npm publish? CI on merge?) and who presses the button>` |
| Telemetry | off - anonymized weekly anomaly bundle (codes and numbers only, docs/telemetry.md); on = /vulyk-evolve prints the send command, never sends |
<!-- VULYK:PROFILE:END -->

## Commands

Quiet variants only: their output is resent every turn. A story's `## Verification` must name one.

<!-- VULYK:COMMANDS:START -->
<!-- Everything between these two markers is VULYK's own and is replaced with blank placeholders
     by install.sh when the constitution is copied into another project. Keep both markers on
     their own lines; install.sh warns loudly if it cannot find them. -->

> **Installed VULYK into your own project? These rows are wrong for you.** They are VULYK's own,
> correct for this repository — a shell + Python + markdown toolkit with no compiler and no test
> runner — and `/vulyk-bootstrap` replaces every one of them with your project's commands. Until it
> does, treat a green result here as meaningless: a command that verifies nothing still exits 0.

| Purpose | Command |
|---|---|
| Shell syntax, all scripts | `git ls-files '*.sh' \| xargs -n1 bash -n` |
| Python syntax, hooks | `python -m py_compile .claude/hooks/*.py` |
| JSON validity | `git ls-files '*.json' \| xargs -n1 jq -e . > /dev/null` |
| Hook self-diagnosis | `bash .claude/hooks/handoff.sh status` |
| Scope gate, per story | `bash scripts/scope-check.sh <story-file>` |
| Story gate, per spec | `bash scripts/wave-check.sh docs/specs/<slug>` |
| Ship gate, per spec | `bash scripts/ship-check.sh docs/specs/<slug>` |
| Cycle status, per spec | `bash scripts/cycle.sh status docs/specs/<slug> --json` |
| Token report, per spec | `python scripts/token-report.py . --spec <slug>` |
| Cycle state contract tests | `bash tests/cycle.test.sh` |
| Council verdict contract tests | `bash tests/council.test.sh` |
| Council verdict contract tests, quick | `bash tests/council.test.sh --quick` |
| Driver contract tests | `bash tests/driver.test.sh` |
| Anomaly telemetry contract tests | `bash tests/telemetry.test.sh` |
| Full suite / build | none exists — VULYK has no test runner and no build step |

The first four are silent on success and non-zero on failure; run them together as the closest
thing this repo has to a suite. The three gates are different on purpose: they always exit 0 and
report — their output is the signal, blocking is a human's or lead-review's decision. `py_compile` writes a gitignored `__pycache__/` — do not commit it.
The absent last row is deliberate: VULYK's shipped behaviour is verified by running the hooks
against real transcripts, not by a suite. Say so plainly rather than inventing a command that
proves nothing.

<!-- VULYK:COMMANDS:END -->

## Compact instructions

Keep: the deliverable, tier and goal; the spec slug and each story's `status:`; decisions with reasons and rejected options;
walls hit; open questions to the owner. Drop file contents, diffs, command output and scout reports: they are on disk.

## Where things live

Specs, stories, study reports: `docs/specs/<slug>/` · decisions: `docs/adr/` · domain notes: `docs/wiki/` · path rules: `.claude/rules/`.
`memory/memory.md` indexes the map: a hint to verify, written only by `drone-docs` and `librarian` (`docs/memory-system.md`).
Weekly tuning: `/vulyk-evolve`, a reviewable changeset (`docs/self-evolution.md`).
