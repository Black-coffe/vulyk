# Every hive runs Claude Code's "You should know" mod (plan)

**Tier:** 1 · **Spec slug:** `you-should-know` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-005 (installer upgrade contract: host settings.json is the owner's, appended in place, after a backup)
**Depends on:** Claude Code >= 2.1.287 (built-in mods), first-party sessions with telemetry on (Anthropic's gate)

## Goal
Every VULYK host carries `"enabledPlugins": {"cc-plugin-you-should-know@builtin": true}` in its project
`.claude/settings.json`: a fresh install gets it in the settings.json it is given, an upgrade appends it in place. An
owner's explicit `false` is kept. The installer says how to turn it off, because `/plugin disable` cannot.

## Facts this plan rests on (measured 2026-10-04, Claude Code 2.1.288, `claude -p --debug`)
- A project-scope key loads the mod (`hooks module cc-plugin-you-should-know@builtin loaded ... tier builtin`); no key
  anywhere: not loaded.
- `claude plugin enable|disable ... --scope project` ignores `--scope` and writes USER scope. Project `true` beats user
  `false`, so `/plugin disable` does not turn the mod off in a hive. Local `false` beats project `true`: the off switch is
  `.claude/settings.local.json`. Project `false` beats user `true`.
- `DISABLE_TELEMETRY=1` skips the mod silently. In `claude -p` the mod made no extra model request (one `/v1/messages`
  with and without the key, one short turn).

## Council decisions (Fable 5.1, Opus 5.5, Sonnet 5.5; two rounds)
- C1 `wire_plugin` in install.sh, beside `wire_permissions`: missing -> `true`; present `true` -> silent; present `false`
  -> kept, one `kept` line, no backup left behind; `--check` -> `would wire`, file untouched; unparseable -> untouched + NOTE. 3/3.
- C2 the key in VULYK's own `.claude/settings.json`, so a fresh install comes out enabled and prints no wiring line. 3/3.
- C3 after a real wiring: one line naming the off switch; a NOTE when the installing shell's env shows the mod cannot run
  (DISABLE_TELEMETRY, CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC, CLAUDE_CODE_USE_BEDROCK/VERTEX/FOUNDRY). 3/3.
- Rejected: a `claude --version` check (3/3 against: availability is gated by org and telemetry, not version; CI has no
  `claude`), a SessionStart detection or nudge line (3/3: it fires for no host today and costs every session), trimming
  any VULYK mechanism (3/3: YSK is an unpersisted on-screen note; defect-intake is the durable record - they chain).
- C6 no mass edit of the 24 hosts on this machine (3/3): the owner's user-scope key already enables it everywhere here;
  each host gets the committed key at its next `/vulyk-update`. Ship prints a read-only per-host table.
- C7 cost: deferred to the weekly token report and `/vulyk-evolve` (2/3; Fable wanted a bounded A/B before release).
- C8 recorded as a one-line ADR-005 amendment + CHANGELOG, no new ADR. 3/3. C9 keep an explicit `false`. 3/3.

## Assumptions
- "Принудительное включение" = the installer writes the key into every host it installs or upgrades and never needs a
  question; it does not overwrite an owner's deliberate `false` (C9).
- "На все проекты" today = the user-scope key already set on this machine + 0.25.0 carried by each host's `/vulyk-update`.

## Stories

**Wave 1**
- `you-should-know-01` — `wire_plugin` in install.sh, the key in VULYK's settings.json, tests, CI smoke step, ADR-005 line

## Contracts
- none

## Integration gate
`bash tests/telemetry.test.sh` · `git ls-files '*.sh' | xargs -n1 bash -n` · `git ls-files '*.json' | xargs -n1 jq -e . > /dev/null`

## Descoped

- Measuring the side agent's token spend (C7) - next `/vulyk-evolve`.

## Plan deltas

**Approved:**
**Briefed:** via mini-brief, Andrei, 2026-10-03
**Branch:** vulyk/you-should-know
**Checked:**
**Council:**
**Shipped:**
