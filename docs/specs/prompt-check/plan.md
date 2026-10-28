# Prompt check: agent and command prose against the scripts it names (plan)

**Tier:** 2 · **Spec slug:** `prompt-check` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-005 (hives add their own agents), ADR-015 (model families in frontmatter), ADR-023 (`round-only` rows), `docs/architecture.md` (who carries `omitClaudeMd`)
**Depends on:** v0.42.0 (`e1cde7c`)

## Goal
A deterministic `scripts/prompt-check.sh` reads every `.claude/agents/*.md`, `.claude/commands/*.md` and
`templates/*.md` and fails on drift between that prose and the code: an agent frontmatter missing `model`,
`maxTurns` or `tools`, or carrying an `omitClaudeMd` the architecture rule does not give it; a backticked
`scripts/x.sh`, `cycle.sh <verb>` or `--flag` that the named script does not define in code; an agent name that has
no file, or a `telemetry.sh` AGENTS name without a file. It runs in CI over the whole tree and in close-story
whenever a story touches scripts or prompts; in a hive an owner-added agent is a warning. No model, no tokens.

## Assumptions
- **close-story blocks only on findings tied to what the story touched** (the planner's call on a side-agent note of 2026-10-28, not an owner quote; veto at approval):
  each finding names the files it involves (the prompt file, the script it names, the agent file, `telemetry.sh`,
  `docs/architecture.md`); with `--touched <files>` a finding blocks only when one of them is among the story's
  `## Files`, every other finding prints as `warn`. Without `--touched` (CI, a manual run) every finding blocks. So an
  old drift elsewhere in a hive never stops an honest story. Rejected: block on any finding (stops unrelated stories).
- **Framework vs hive**: a hive has `.claude/vulyk-version` (installed by `install.sh`), the VULYK repo does not. In the
  VULYK repo every `.claude/agents/*.md` must also be in AGENTS (error); in a hive an extra agent file is `warn`.
- **Agent names in prose**: a backticked token counts as an agent name when it is in AGENTS, `RETIRED_AGENTS` or a
  file under `.claude/agents/`, or has the framework shape `(council|drone|lead|queen|worker|cycle)-<word>`; so the JSON
  field `worker` is not one, and a retired name (`council-sonnet`) in a history note passes.
- **Scripts and flags**: only backticked spans are read; prose such as «cycle.sh records» is not. A span is split at
  `&&`, `||`, `|` and `;`. `scripts/x.sh|py` must exist; a bare `x.sh` resolves in `scripts/`, then the repo root
  (`install.sh`), and is skipped when neither has it and no `scripts/` prefix was written (a host tool). The word right
  after `cycle.sh` must be a label of its top-level dispatcher (`^  verb)` arms); placeholders (`<verb>`, `<...>`) are
  skipped. Each `--flag` after a script name must appear as a literal token on a non-comment line of that script.
- **omitClaudeMd rule source**: `docs/architecture.md` names the agents that keep the constitution; story 01 rewrites that
  sentence so all five names are backticked (today «the workers» is prose) and the checker reads them from it. The value,
  when present, must be `true` or `false`. Agents outside AGENTS (a hive's own) get the syntax check only. When
  `docs/architecture.md` is absent (a hive that dropped it) the rule check is skipped with a `warn`.
- **Frontmatter**: `name` equals the file's basename; `model` is a family alias (`opus`, `sonnet`, `haiku`, `fable`,
  `inherit`) or a `claude-` model id; `maxTurns` a positive integer; `tools` non-empty.
- **Python 3**, through the `trace-autopsy.sh` wrapper pattern. Exit 0 clean (warnings allowed), 1 a blocking finding,
  2 usage or no python. close-story treats exit 2 as «not run»: one stderr note, the close goes on (a lint, not a
  security gate); CI has python, so CI never skips it.
- **Speed**: «0.2 с» is the owner's target, measured and written in the story's notes on this Windows box and not
  asserted in a test (a timing assert flakes on CI runners).
- **Tests**: story 01 in `tests/maintenance.test.sh` (Commands row «Maintenance»), story 02 in `tests/cycle.test.sh`;
  no new suite, so no new `## Commands` row (CLAUDE.md 7153/7168 B). `tests/full-suite.sh` already runs both.
- **CI**: one step in the `shell` job, `bash scripts/prompt-check.sh`, so a drift fails the fast job by name, not only
  inside the full suite.
- **Hives**: `install.sh` ships all of `scripts/`, so the next `/vulyk-update` carries the checker; no hive is upgraded in
  this spec. Today's repo has zero drift (61 script/flag pairs in a dry run), so the failing fixtures, not the repo, prove
  the checks bite.

## Stories

**Wave 1**
- `prompt-check-01-script` — `scripts/prompt-check.{sh,py}`, the four rule groups, `--touched`, hive mode, the architecture sentence; tests in `tests/maintenance.test.sh`.

**Wave 2**
- `prompt-check-02-wiring` — close-story runs it on a story touching scripts/prompts (exit 4 on a blocking finding), CI step, command-reference and CHANGELOG.

## Contracts
- `bash scripts/prompt-check.sh [--touched <path>...]` from the repo root. stdout: one line per finding,
  `prompt-check: error <file>:<line>: <rule>: <message>` or `prompt-check: warn ...`, then `prompt-check: ok (<n> files)`
  or `prompt-check: <n> error(s)`. Rules: `frontmatter`, `omit-claude-md`, `script`, `verb`, `flag`, `agent`, `telemetry`.
  Exit 0 / 1 / 2 as above.

## Integration gate
`bash tests/full-suite.sh`

## Descoped

*(empty)*

## Plan deltas

**Approved:** Andrei, 2026-10-28 («/vulyk-build prompt-check»)
**Briefed:** <written by scripts/cycle.sh briefed>
**Branch:** vulyk/prompt-check
**Checked:** <written by scripts/human-check.sh after the owner has looked>
**Council:** <written by scripts/cycle.sh judge/escalate>
**Shipped:** <written by scripts/ship-check.sh --record>
