---
story: cross-platform-08
spec: cross-platform
status: todo
returned:
tier: 3
worker: worker-test
model: opus
wave: 5
blocked_by: []
---

# Test suites that hang or misread on Linux and macOS

## Goal
(1) `tests/full-suite.test.sh` hangs for ever on Linux and macOS (both CI jobs hit GitHub's 6 h cap; `inject`/`intake`
`--part latency` never start behind it). Cause: its «dead stubs and no Python on PATH» case builds the PATH by dropping
every directory that holds a python (`nopy_path`); on Linux/macOS that drops `/usr/bin` and every tool the runner needs.
On Windows Python lives in its own folder, so it passed here. Hide Python with dead `python3`/`python`/`py` stubs first on
PATH instead (exit 127; `vulyk_python`'s run-probe rejects them), keep the rest of PATH. (2) BSD `paste` needs a file
operand: `paste -sd'|'` with no `-` prints `usage: paste ...` (`tests/model-profile.test.sh:137`,
`tests/telemetry.test.sh:872,1139,1366` - telemetry parts `terminal`, `scan`; model-profile «--set wrote nothing outside
the config folder»). Add the `-`. (3) Any other test-side cause the macOS tails name in these three files.

Evidence (Queen, 2026-10-29): owner REJECTED after GREEN round 2 (plan.md `**Checked:**`); CI run 40787799947 on 9ca42a6 and the probe run 40857869190 (branch `ci-probe/mac-logs`, macOS only, `VULYK_SUITE_TIMEOUT=1500`). macOS: 21 suites FAIL, 3 TIMEOUT.

Local repro, no Mac needed: bash 3.2 is `MSYS_NO_PATHCONV=1 docker run --rm -v "<repo>:/w" -w /w bash:3.2 bash -c '<cmd>'` (Alpine/musl: `apk add --no-cache git jq python3 coreutils` first when a suite needs them; its awk/sed/paste are busybox, not BSD). Linux is `wsl.exe -d Ubuntu` - run suites in a clone under `~`, never on `/mnt/e` (CRLF working copy, noise). BSD `awk`/`paste` behaviour is reproduced by stubs, as `tests/cycle.test.sh` `part bsd` already stubs BSD sed.

## Requirements
> 3. Перевод всех продуктовых, командных (`.claude/commands/*.md`, `CLAUDE.md:76`) и тестовых файлов на переносимые вызовы.
> 8. `run_capped` без `timeout` и `gtimeout` падает на `"$VULYK_PY"` (subprocess, код 124), тесты таймаутов идут без `skip`.

## Files
- tests/full-suite.test.sh
- tests/model-profile.test.sh
- tests/telemetry.test.sh

## Non-goals
- No product script, no gate, no CI change.

## Acceptance criteria
- [ ] `bash tests/full-suite.test.sh` finishes on Linux (WSL clone under `~`) and here; the no-Python case still proves
      «uncapped and says so».
- [ ] Every `paste -s` in the three files has a file operand.
- [ ] `bash tests/model-profile.test.sh` and telemetry parts `terminal`, `scan` green here.

## Verification
`bash tests/full-suite.test.sh`
`bash tests/model-profile.test.sh`
`bash tests/telemetry.test.sh --part scan`

## Implementation notes

## Findings
