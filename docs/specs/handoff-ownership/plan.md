# In a hive, VULYK's handoff is the only one that answers (plan)

**Tier:** 2 · **Spec slug:** `handoff-ownership` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-005 (installer upgrade contract: what the installer may write in a host)
**Depends on:** `handoff-cwd` (0.26.1: ask 1, the cwd bug, split out on the owner's word after the plan review);
`constitution-merge` (0.27.0) merged first, because both edit `install.sh` and `.claude/commands/vulyk-update.md`

## Goal
The hive takes the handoff over. A new `scripts/handoff-owner.sh` lists every other handoff the project can see (user-
and project-level commands and skills with "handoff" in the name), says which user-level hooks also write handoffs
(reported, never touched), and on the owner's yes switches the named ones off for this project in
`.claude/settings.local.json` (`skillOverrides: {"<name>": "off"}`); a "keep" is recorded as `"on"` so the question is
asked once. The installer asks on a terminal; `/vulyk-update` asks in chat and runs the script. A hive that splits
handoffs by folder (`.claude/context-guard.json` with `subproject_globs`) gets a warning and "keep" as the default,
because VULYK's handoff cannot split them yet. Every question says plainly what the switch-off does not reach: a
user-level hook keeps writing its own handoffs and keeps suggesting `/handoff`.

## Assumptions
- "Another handoff" = a command or skill whose name contains `handoff` (any case), other than `vulyk-handoff`, in the
  user's Claude config folder (`${CLAUDE_CONFIG_DIR:-$HOME/.claude}`: `commands/`, `skills/`) or the hive's own
  `.claude/commands|skills`. Plugins are not scanned: `skillOverrides` cannot switch a plugin skill off (Claude Code
  2.1.296 returns "on" for `source === "plugin"`), and the one plugin hit on this machine is a false positive (Opus
  review).
- A foreign hook = a user-level hook whose command or script file mentions `handoff`; reported with its path. Claude
  Code has no per-project off switch for one user hook (owner answer 1). The owner's own `context_guard.py` learns to go
  quiet where the project switched `handoff` off - a separate change to the owner's tool, outside VULYK (owner's word,
  2026-10-13, after the plan review).
- Switched off only in `.claude/settings.local.json`, merged, never in the committed `settings.json` (owner answer 2);
  `install.sh:1022` already gitignores it; the owner already keeps `skillOverrides` there in `E:/Projects/AI`.
- No terminal (CI, a pipe, `/vulyk-update` run by the Queen): the installer writes nothing and prints what it found and
  the one command that switches it off. `--check` writes nothing either. Claude Code rewrites `settings.local.json` in a
  live session, so the script says the change takes effect in a new session.
- After the switch-off a typed `/handoff` answers Claude Code's own `Skill "handoff" is disabled via skillOverrides`
  line. VULYK's command stays `/vulyk-handoff`: a project command named `handoff` does not shadow a user-level one
  (probed), and the override would hide both.
- Teaching VULYK's handoff the folder split ("directions") is the next spec, not this one (owner answer 3).
- The tests join `tests/telemetry.test.sh`, the installer's existing suite (already in `## Commands` and CI): the
  constitution sits at its 7168-byte cap (`tests/maintenance.test.sh`), so a new `## Commands` row would breach it.
- Ships after `constitution-merge` (0.27.0), as 0.28.0.

## Stories

**Wave 1**
- `handoff-ownership-01` — `scripts/handoff-owner.sh` (list / own / keep), the installer's question, `/vulyk-update`'s
  chat question, its cases in `tests/telemetry.test.sh`, ADR-005 amendment, command reference

## Contracts
- `scripts/handoff-owner.sh <hive> [--check]` -> one line per finding (`skill <name> <path>`, `hook <path>`,
  `off <name>` / `kept <name>` for one already answered, `directions <file>` when the hive splits by folder), exit 0;
  `--own <name>...` merges `"<name>": "off"` and `--keep <name>...` merges `"<name>": "on"` into
  `<hive>/.claude/settings.local.json` (created when missing; an unparsable file is left alone with exit 1). The user's
  config folder is `${CLAUDE_CONFIG_DIR:-$HOME/.claude}`.

## Integration gate
`bash tests/telemetry.test.sh` · `bash tests/maintenance.test.sh` · `bash scripts/defects-check.sh` ·
`git ls-files '*.sh' | xargs -n1 bash -n`

## Next circle
- VULYK's `handoff.py` learns the folder split: reads `.claude/context-guard.json` (`subproject_globs`,
  `subproject_aliases`) and writes the handoff into the matching folder, so a hive like `E:/Projects/AI` can switch the
  global one off too (owner answer 3).

## Descoped

*(empty)*

## Plan deltas

**Approved:** <owner, date - the approval stop>
**Briefed:** <written by scripts/cycle.sh briefed>
**Branch:** <written by /vulyk-build before wave 1>
**Checked:** <written by scripts/human-check.sh after the owner has looked>
**Council:** <written by scripts/cycle.sh judge/escalate>
**Shipped:** <written by scripts/ship-check.sh --record>
