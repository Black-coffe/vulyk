---
story: handoff-ownership-01
spec: handoff-ownership
status: todo
returned:
tier: 2
worker: worker-code
model: sonnet
wave: 1
blocked_by: []
---

# The hive takes the handoff over, with the owner's yes

## Goal
`scripts/handoff-owner.sh` (contract in plan.md) tells the owner which other handoffs this project can see and switches
the named ones off for this project only, in `.claude/settings.local.json`; a "keep" answer is recorded too, so the
question is asked once. The installer (install and `--upgrade`) runs it after copying: on a terminal it lists the
findings and asks one question per run; a hive that splits handoffs by folder gets a warning and "keep" as the default;
with no terminal it writes nothing and prints the command. `/vulyk-update` runs the listing after the upgrade, asks the
owner in chat, and runs `--own` on a yes. Every question says plainly that a user-level hook which writes handoffs
keeps doing so, and keeps suggesting `/handoff`, after the switch-off.

## Requirements
> /handoff
> в командах Handoff и в триггерах Handoff, когда пользователь говорит в вызове или «Запусти Handoff», должен работать только один — тот, который к Vultr имеет отношение.
> А тот другой должен вырезаться конкретно с этого проекта.
> Vultr при инсталляции должен смотреть, если есть какой-либо Handoff, он предлагает его вырезать, удалить, отключить на этом конкретно проекте
> Если отключить там глобальный, такая раскладка пропадёт.

## Files
- scripts/handoff-owner.sh
- install.sh
- .claude/commands/vulyk-update.md
- tests/telemetry.test.sh
- docs/adr/005-installer-upgrade-contract.md
- docs/command-reference.md

## Non-goals
- Do not delete or edit anything under the user's Claude config folder: switching off is a project setting, never a
  removal.
- Do not write `.claude/settings.json` (owner answer 2), and do not edit a user-level hook or its config (owner
  answer 1), including `context_guard.py` and `.claude/context-guard.json`.
- Do not scan plugins: `skillOverrides` cannot switch a plugin skill off (the binary returns "on" for
  `source === "plugin"`), and the only plugin hit on the owner's machine is a false positive.
- Do not add an installer flag, and do not ask name by name: one question per run; `--own <name>...` covers a subset by
  hand.
- Do not rebuild `constitution-merge`'s changes to `install.sh` / `vulyk-update.md`: build on top of them.

## Map slice
memory/map/scripts.md (`install.sh - the upgrade contract`, `vulyk-update.sh`); install.sh telemetry consent
(`telemetry_tty`, `telemetry_decide`) as the pattern for one question through `/dev/tty`

## Acceptance criteria
- [ ] With `HOME`, `USERPROFILE` and `CLAUDE_CONFIG_DIR` pointed at a temp config holding `commands/handoff.md`, and a
      temp hive, `handoff-owner.sh <hive>` lists `skill handoff <path>`; `--own handoff` leaves
      `"skillOverrides": {"handoff": "off"}` in `<hive>/.claude/settings.local.json` with every key it already had kept;
      a second listing says `off handoff`; `--keep handoff` records `"handoff": "on"` and a later listing says
      `kept handoff`, and the installer does not ask about it again.
- [ ] `vulyk-handoff` is never listed; a user hook whose command or script mentions `handoff` is listed as a `hook`
      line, and `--own` never writes it.
- [ ] The merge survives a `settings.local.json` with a BOM and CRLF line ends (read `utf-8-sig`, written LF without a
      BOM through a temp file and a rename); an unparsable file is left byte-for-byte alone with exit 1; the output says
      the change takes effect in a new session.
- [ ] A hive with `.claude/context-guard.json` holding `subproject_globs` gets a `directions` line, and the installer's
      question defaults to keep there.
- [ ] `install.sh` with no terminal and with `--check` writes no `settings.local.json`, and prints the findings and the
      command; the test drives both.
- [ ] The installer's question and `/vulyk-update`'s say, in plain words, that a listed `hook` keeps writing its own
      handoffs and keeps suggesting `/handoff` after the switch-off; `/vulyk-update` asks once and runs `--own` only on
      a yes.
- [ ] ADR-005 has a dated amendment: the one host file the installer may now write on consent, and why.

## Verification
`bash tests/telemetry.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes

## Findings
