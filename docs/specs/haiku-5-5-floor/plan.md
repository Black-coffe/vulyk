# Haiku 5.5 reaches the floor, and the floor check reads Claude Code's alias table (plan)

**Tier:** 1 · **Spec slug:** `haiku-5-5-floor` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-015 (Sonnet execution rung and the model floor; its revisit trigger "Haiku 5.5 ships. Then
`cycle-clerk` moves to `haiku`, after its model is checked against the floor"), ADR-007's Haiku rule (Haiku 4.5 is never
dispatched), the owner's rule "Haiku stays minimal: only the clerk"
**Depends on:** v0.25.0 (8587c3e)

## Goal
Haiku 5.5 shipped on 2026-10-07, so the haiku floor line loses `unreleased` and `cycle-clerk` moves from `sonnet` to
`haiku` (effort `low`, which Haiku 5.5 now accepts). An alias still is not a guarantee: Claude Code 2.1.292 runs `haiku`
as Haiku 4.5, and only 2.1.293 maps it to 5.5. A floor line therefore learns a second flag, `cc>=<version>`: the bare
alias reaches the floor only from that Claude Code version on. `top-model.sh --floor` reads the running session's
version (`CLAUDE_CODE_VERSION`, set by Claude Code for its hooks and tools; `claude --version` as the fallback), and a
route to `haiku` on an older or unknown Claude Code is reported below the floor with the fix (`claude update`). Because
`haiku` becomes a live route, the haiku remap (`ANTHROPIC_DEFAULT_HAIKU_MODEL`) and a provider without a haiku pin join
the before-the-fact check, as opus and sonnet already are.

## Facts this plan rests on (measured 2026-10-07)
- `claude -p --model haiku` on Claude Code 2.1.292: `modelUsage` = `claude-haiku-4-5-20251001`.
- `claude -p --model claude-haiku-5-5 --effort low` on 2.1.292: ran `claude-haiku-5-5`, printed
  `[claude-code:unrecognized_model]`, `costBasis: unknown`. A pinned full ID works, but the constitution routes by
  family and pins only to freeze behaviour, so the clerk gets the alias plus the version gate, not the ID.
- Claude Code CHANGELOG 2.1.293: "Added Claude Haiku 5.5 (`claude-haiku-5-5`), now the default Haiku model on the
  Anthropic API". npm latest on 2026-10-07: 2.1.293.
- In this session `CLAUDE_CODE_VERSION` = `2.1.292 (Claude Code)`: the first word is the version.
- The previous spec rejected a `claude --version` check for the "You should know" mod because availability there is
  gated by organisation and telemetry, not version. Here the alias table itself is versioned, so the reading differs.

## Assumptions
- "Минимум Hiku 5,5" = the floor stays `haiku 5.5` and is enforced; the one Haiku route is `cycle-clerk` (owner's
  standing rule: Haiku only for the clerk). `council-haiku` stays on `opus`: it judges (ADR-015).
- An unknown Claude Code version (no env, no `claude` on PATH) counts as below for a `cc>=` line: the check cannot
  vouch for the alias, and the floor's rule is "never below", not "probably fine".
- A hive that pins `ANTHROPIC_DEFAULT_HAIKU_MODEL` at or above the floor on an old Claude Code still sees the cautious
  line until it updates. Rare, the safe direction, and the fix is the same `claude update`.
- `ANTHROPIC_SMALL_FAST_MODEL` stays out of the check: it is Claude Code's own background model, not a VULYK route.
- Release (VERSION, CHANGELOG) is the ship stage's commit, as in 0.25.0; publishing waits for the owner's word.

## Stories

**Wave 1**
- `haiku-5-5-floor-01` — floor line `haiku 5.5 cc>=2.1.293`, version gate in `model_below_floor`, haiku pins and
  provider in `--floor`, clerk on `haiku`, tests, and the docs that name the rung

## Contracts
- `model_floor` lines: `<family> <major.minor> [unreleased | cc>=<x.y.z>]`.
- `model_below_floor <alias>` prints `<family> alias <floor>` for `unreleased` (unchanged) and
  `<family> cc <floor> <have|unknown> <need>` for a `cc>=` line the running Claude Code does not meet; exit 0 iff below.

## Integration gate
`bash tests/telemetry.test.sh` · `git ls-files '*.sh' | xargs -n1 bash -n`

## Descoped

*(empty)*

## Plan deltas
- 2026-10-07, close-story: `bash tests/telemetry.test.sh` outgrew the 540 s verification budget on this Windows box
  (532 s standalone; timed out at 468/478 checks under `close-story`). Decision: close with
  `VULYK_VERIFY_TIMEOUT=900` from a background shell, same command, nothing skipped. Rejected: a narrower
  `## Verification` line (no `## Commands` cell reaches `lib.sh`/`top-model.sh` logic short of the full suite).
  Evidence for the owner-ordered "fast/full verification" item of 2026-09-23, still unbuilt.

**Approved:** <owner, date - stage 02, the unconditional gate. /vulyk-build refuses without this line.>
**Briefed:** via mini-brief, Andrei, 2026-10-07
**Branch:** vulyk/haiku-5-5-floor
**Checked:** <written by scripts/human-check.sh after the owner has looked>
**Council:** <written by scripts/cycle.sh judge/escalate>
**Shipped:** <written by scripts/ship-check.sh --record>
