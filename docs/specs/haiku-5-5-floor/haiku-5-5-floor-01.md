---
story: haiku-5-5-floor-01
spec: haiku-5-5-floor
status: done
returned: DONE
tier: 1
worker: worker-code
model: sonnet
wave: 1
blocked_by: []
---

# Haiku 5.5 on the floor, gated by the Claude Code version that maps the alias

## Goal
The haiku floor line reads `haiku 5.5 cc>=2.1.293`. `model_below_floor haiku` is below when the running Claude Code
(`CLAUDE_CODE_VERSION`'s first word, else `claude --version`) is older than 2.1.293 or unknown, and not below from
2.1.293 on; `unreleased` keeps its old meaning. `top-model.sh --floor` names that case with the fix, checks
`ANTHROPIC_DEFAULT_HAIKU_MODEL` in env and settings, and asks a provider hive for a haiku pin too. `cycle-clerk` runs on
`haiku` at effort `low`. The constitution, README, architecture, model-cascade, faq and ADR-015 say the clerk is on
Haiku and why the alias alone is not trusted.

## Requirements
> чтобы теперь Hiku работал на модели 5,5 и не ниже. Минимум Hiku 5,5.
> слово `haiku` в Claude Code может пока вести на старую 4.5. Проверка VULYK этого не заметит. УЧТИ

## Files
- scripts/lib.sh
- scripts/top-model.sh
- .claude/agents/cycle-clerk.md
- .claude/hooks/top-model-brief.sh
- tests/telemetry.test.sh
- CLAUDE.md
- README.md
- docs/architecture.md
- docs/model-cascade.md
- docs/faq.md
- docs/adr/015-sonnet-execution-rung-and-model-floor.md

## Non-goals
- Do not move `council-haiku`, the scout, the docs drone or anything else to Haiku: the clerk only.
- Do not pin a full model ID anywhere: routing stays by family.
- Do not add a `cc>=` gate to fable, opus or sonnet: their aliases reached the floor long ago.
- Do not run a live `claude -p` probe from the check: it costs a request at every session start.
- Do not touch VERSION or CHANGELOG (ship stage), the memory map (drone-docs), or historical ADRs 001/007/012.

## Map slice
memory/map/agents-and-commands.md - cycle-clerk; scripts/lib.sh `model_floor`, `model_below_floor`;
scripts/top-model.sh `floor)` branch

## Acceptance criteria
- [ ] `CLAUDE_CODE_VERSION=2.1.292` -> `model_below_floor haiku` prints `haiku cc 5.5 2.1.292 2.1.293`, exit 0;
      `2.1.293`, `2.1.300`, `2.2.0`, `3.0.0` -> not below; no env and no `claude` -> `haiku cc 5.5 unknown 2.1.293`.
- [ ] `VULYK_MODEL_FLOOR='haiku 5.5 unreleased'` still gives `haiku alias 5.5`; `sonnet` alias is still never below.
- [ ] `--floor` exits 0 on the shipped agents with Claude Code 2.1.293 and exits 1 naming
      `.claude/agents/cycle-clerk.md model = haiku` with 2.1.292.
- [ ] `--floor` names `ANTHROPIC_DEFAULT_HAIKU_MODEL=claude-haiku-4-5` (env) as haiku 4.5, floor 5.5, and a provider
      hive without a haiku pin.
- [ ] `cycle-clerk.md` says `model: haiku`, `effort: low`.

## Verification
`bash tests/telemetry.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes
- `scripts/lib.sh`: floor line `haiku 5.5 cc>=2.1.293`; new `claude_code_version` (first word of
  `CLAUDE_CODE_VERSION`, else `claude --version`, empty unless dotted digits) and `version_lt`
  (numeric, missing parts 0, so 2.1.1000 > 2.1.293 and 2.1.29 < 2.1.293); `model_below_floor` prints
  `<fam> cc <floor> <have|unknown> <need>` for a `cc>=` line not met. `unreleased` unchanged.
- `scripts/top-model.sh --floor`: two new messages (old version with `claude update`, unknown version);
  `ANTHROPIC_DEFAULT_HAIKU_MODEL` joins the env vars, the settings grep and the provider pin check.
- Measured in this session (Claude Code 2.1.292): `--floor` exits 1 and names the clerk's route - the
  check now sees exactly the case the owner raised.
- `tests/telemetry.test.sh`: 13 new checks; stub `claude` binaries on PATH make the unknown and the
  `claude --version` paths deterministic on any box; `floorcheck` pins `CLAUDE_CODE_VERSION=2.1.293`.
  478 checks, 0 failed (8 m 52 s). `tests/maintenance.test.sh` (constitution budget): 100, 0 failed.
- `close-story` under the default 540 s budget: exit 4, "verification timed out after 540s" at 468 of 478
  checks (the suite alone took 532 s an hour earlier). Closed with `VULYK_VERIFY_TIMEOUT=900` from a
  background shell, the same full suite - see plan.md `## Plan deltas`.
- Docs: constitution line, README (clerk row, ladder, floor paragraph), architecture, model-cascade
  (rung table, why-the-clerk paragraph, floor flags, before-the-fact list, effort table), faq,
  ADR-015 Status amendment and revisit note.

## Findings
