---
story: fast-verification-05
spec: fast-verification
status: todo
returned:
tier: 3
worker: worker-code
model: haiku
wave: 2
blocked_by: [fast-verification-01]
---

# Bootstrap, templates, planner and workers teach the fast/full split

## Goal
A fresh hive learns the same split VULYK uses: the bootstrap interview asks for per-story rows that fit in a minute
or two and one `Full suite / build` row marked `round-only`; the story template says never to name a marked row and
to take the part under your files; the plan template says the integration gate is the marked row, run by
`lead-review` under `VULYK_SUITE_TIMEOUT`; the planner and the workers know what exit 2 `verification is round-only`
means; the installer's placeholder Commands block shows the shape. `model: haiku`: routine text edits following a
fixed contract, one small test case.

## Requirements
> 5. Первичная настройка (bootstrap) и шаблоны учат ульи так же делить свои команды на быстрые и полные.

## Files
- .claude/commands/vulyk-bootstrap.md
- templates/story.md
- templates/plan.md
- .claude/agents/queen-planner.md
- .claude/agents/worker-code.md
- .claude/agents/worker-test.md
- install.sh
- tests/telemetry.test.sh

## Non-goals
- Do not touch a `description:` frontmatter line of any agent or command (the byte budget
  `tests/maintenance.test.sh` enforces is already at its edge) - body text only, and lean: one or two sentences
  per file.
- Do not edit `lead-review.md` (story 06), `CLAUDE.md` (story 01), `docs/cycle.md` or the command reference.
- Do not ship the runner to hives or add an installer manifest entry.
- Do not touch `install.sh` beyond the placeholder Commands block (`print_commands_placeholder`, `:209` comment).

## Map slice
memory/map/agents-and-commands.md `## Commands - what each runs` (`/vulyk-bootstrap`), `## Agents` (queen-planner,
worker-code/worker-test); memory/map/scripts.md `## install.sh - the upgrade contract`; scout-plumbing.md
`## Files by ask` (Ask 5 lines).

## Acceptance criteria
- [ ] `vulyk-bootstrap.md` `:31-37`: the Commands step asks for quiet per-story rows that run in a minute or two and
      one full-suite row marked `round-only` in its Purpose cell; a suite over that gets a part switch (`--part
      <topic>` or the runner's equivalent) and the story names the part.
- [ ] `templates/story.md` `## Verification` comment: a segment in a `round-only` row is reported by wave-check and
      refused by close-story (exit 2); name the part that covers `## Files`.
- [ ] `templates/plan.md` `## Integration gate` comment: the `round-only` full-suite row; `lead-review` runs it once
      per round under `VULYK_SUITE_TIMEOUT` (default 540 s); a timeout escalates with the time.
- [ ] `queen-planner.md` `:29-31`: verification comes from rows without the mark. `worker-code.md` `:24-25` and
      `worker-test.md` `:24-25`: exit 2 `verification is round-only` = NEEDS_CONTEXT naming the row.
- [ ] `install.sh` placeholder block written on a fresh install shows a `Full suite / build (round-only)` example
      row and a one-line comment on the mark; `tests/telemetry.test.sh` part `install` gains one case: a fresh
      install's constitution contains `round-only` in its Commands block.

## Verification
`bash tests/telemetry.test.sh --part install`

## Implementation notes

## Findings
