---
story: haiku-5-5-floor-02
spec: haiku-5-5-floor
status: done
returned: DONE
tier: 1
worker: worker-code
model: sonnet
wave: 2
blocked_by: [haiku-5-5-floor-01]
---

# The hive does not launch below the floor

## Goal
`/vulyk-build` runs `bash scripts/top-model.sh --floor` before it launches the hive (Tier 3-4, the only path that
dispatches `cycle-clerk`, and with it every family) and stops on exit 1 with the `below floor` lines and the fix,
so "a Haiku below the floor is never dispatched" is enforced, not only announced. `/vulyk-resume` relaunches through
`/vulyk-build`, so it is covered. A `cc>=` value that is not a dotted version fails closed (below) instead of
crashing the arithmetic and reading "not below". The docs say the gate exists.

## Requirements
> Минимум Hiku 5,5.
> слово `haiku` в Claude Code может пока вести на старую 4.5. Проверка VULYK этого не заметит. УЧТИ

## Files
- .claude/commands/vulyk-build.md
- scripts/lib.sh
- tests/telemetry.test.sh
- docs/model-cascade.md
- docs/adr/015-sonnet-execution-rung-and-model-floor.md

## Non-goals
- Do not gate the solo path (Tier 1-2): it dispatches only `lead-review` on `opus`, and a haiku finding would block it
  for nothing. A finding on its own family is already in the SessionStart line.
- Do not make the driver pick a fallback model for the clerk: frontmatter is not conditional (ADR-007), and a
  fallback would silently run Sonnet where the owner chose Haiku.
- Do not change `--floor`'s output or exit codes.

## Map slice
memory/map/agents-and-commands.md - /vulyk-build; scripts/lib.sh `model_below_floor`

## Acceptance criteria
- [ ] `vulyk-build.md` Hive step 1 runs `--floor` first; on exit 1 it prints the `below floor` lines, journals
      nothing, launches no driver, and stops, naming `claude update` / the pin as the fix.
- [ ] `VULYK_MODEL_FLOOR='haiku 5.5 cc>=2.1.x' CLAUDE_CODE_VERSION=2.1.292` -> `model_below_floor haiku` is below
      (exit 0, no arithmetic error on stderr).
- [ ] model-cascade.md and ADR-015 say the hive launch is refused while `--floor` fails.

## Verification
`bash tests/telemetry.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes
- `vulyk-build.md` Hive step 1 opens with the `--floor` gate; "for both launches below" covers the Workflow driver
  and the no-Workflow loop, and `/vulyk-resume` relaunches through `/vulyk-build`.
- `scripts/lib.sh`: `need` must be a dotted version, else the alias is below (fails closed) - no `10#x` error.
- `tests/telemetry.test.sh`: the malformed-line case (stdout + stderr, exit code) and a text guard that Hive step 1
  keeps the gate.
- Closed with `VULYK_VERIFY_TIMEOUT=900` from a background shell, as story 01 (plan.md `## Plan deltas`).

## Findings
