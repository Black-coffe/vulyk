---
story: constitution-merge-02
spec: constitution-merge
status: todo
returned:
tier: 2
worker: worker-code
model: sonnet
wave: 2
blocked_by: [constitution-merge-01]
---

# The installer no longer replaces a constitution

## Goal
`install.sh --upgrade --constitution replace` and `scripts/vulyk-update.sh --constitution replace` are gone: the flag is
refused with one line that names `/vulyk-update`'s merge, and the replace code path (`replace_constitution`, its
preflight, the render used only by it) is removed. A plain `--upgrade` still never writes the constitution; where it
printed the replace command it now prints that the constitution changed and `/vulyk-update` merges it, with the
`constitution-merge.sh draft` line for running it by hand. `scripts/constitution-merge.sh` ships to hives. The replace
cases in `tests/telemetry.test.sh` become refusal and hint cases. ADR-005 gets an amendment: replace removed, why
(the owner's words, `E:/Projects/AI`), and the merge contract.

## Requirements
> чтобы не потерялся смысл, сенс, логика и правила того проекта, в который заходит Wulic
> Сейчас нужно с этой версией Wulica внести изменение

## Files
- install.sh
- scripts/vulyk-update.sh
- tests/telemetry.test.sh
- docs/adr/005-installer-upgrade-contract.md

## Non-goals
- Do not make `install.sh` write a merged constitution: the merge needs the owner's yes and the Queen (story 03).
- Do not change the `VULYK:PROFILE` / `VULYK:COMMANDS` block insertion (ADR-005 D3): it keeps working as before.
- Do not rename `.pre-<version>.md` backups already on disk.

## Map slice
memory/map/scripts.md - install.sh constitution section, vulyk-update.sh

## Acceptance criteria
- [ ] `--constitution replace` exits non-zero before touching any file and names the merge.
- [ ] A plain `--upgrade` of a hive whose constitution differs prints the merge hint, writes no constitution.
- [ ] A fresh install ships `scripts/constitution-merge.sh`, executable.
- [ ] No `replace_constitution` or `--constitution replace` remains in `install.sh`, `vulyk-update.sh` or the tests.

## Verification
`bash tests/telemetry.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes

## Findings
