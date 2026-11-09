---
story: mass-audit-fixes-12
spec: mass-audit-fixes
status: todo
returned:
tier: 4
worker: worker-code
model: haiku
wave: 3
blocked_by: [mass-audit-fixes-06, mass-audit-fixes-07, mass-audit-fixes-09]
---

# Hooks run from a Unix clone: executable bits, UTF-8 reports, LF skills.json

## Goal
Three portability leftovers of the private audit (2026-11-08): the hooks `settings.json` runs directly are
committed as 100755 (`git update-index --chmod=+x` on `anomaly-scan.sh`, `top-model-brief.sh`,
`vulyk-update-check.sh`) and `tests/maintenance.test.sh` asserts the bit for every hook `settings.json` names,
not only `git-guard.sh` (P4); `scripts/leak-check.sh` and `scripts/injection-check.sh` call Python with
`PYTHONIOENCODING=utf-8` like the other report scripts, so a Cyrillic hit prints instead of crashing the
reporter (P6); `.claude/hooks/skill-usage-counter.sh` strips `\r` before moving the rewritten `skills.json`
into place, so Windows `jq` no longer leaves the tracked file CRLF (P8). Ask 11. `model: haiku`: routine,
repeated-pattern fixes with no design choice.

## Requirements
> 11. Every finding of our private audit that the merged branch does not close (Scope E) is fixed, with a regression test wherever code can check it.

## Files
- .claude/hooks/anomaly-scan.sh
- .claude/hooks/top-model-brief.sh
- .claude/hooks/vulyk-update-check.sh
- scripts/leak-check.sh
- scripts/injection-check.sh
- .claude/hooks/skill-usage-counter.sh
- tests/maintenance.test.sh

## Non-goals
- Do not change the content of the three hooks: the mode bit is the whole change (story 06 edited
  `top-model-brief.sh` and story 09 `vulyk-update-check.sh`; those edits are in).
- Do not change what `leak-check.sh` or `injection-check.sh` detect, or their exit codes.
- Do not touch `memory/stats/skills.json` itself (live data; never check it out).
- Do not edit `tests/maintenance.test.sh` outside the hook-bit block.

## Map slice
`memory/map/scripts.md` → Entry points (`leak-check.sh`, `injection-check.sh`, `session-start-brief.sh`),
Gotchas (portability).

## Acceptance criteria
- [ ] `git ls-files -s .claude/hooks/*.sh` shows 100755 for every hook named in `.claude/settings.json`;
  `tests/maintenance.test.sh` derives that list from `settings.json` and fails on any 100644 among them.
- [ ] `env -u PYTHONIOENCODING PYTHONUTF8=0 bash scripts/leak-check.sh <file with a Cyrillic path>` prints the
  `file:line` hit and exits 1 without a traceback; the same for `injection-check.sh` on a Cyrillic finding.
- [ ] The skill counter's output file has no `\r` bytes after a run with a `jq` that prints CRLF (stub), and
  stays valid JSON.

## Verification
`bash tests/maintenance.test.sh`

## Implementation notes

## Findings
