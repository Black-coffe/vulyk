---
story: cross-platform-07
spec: cross-platform
status: todo
returned:
tier: 3
worker: worker-code
model: opus
wave: 5
blocked_by: []
red: required
red_reason:
---

# Product scripts that break on stock macOS: awk -v with a newline, bash 3.2 parsing

## Goal
Every product script runs under macOS `/bin/bash` 3.2 with the BSD `awk` and `paste`. Known causes, from the CI logs:
(1) BSD awk refuses a newline inside a `-v` value (`awk: newline in string`): `install.sh:245,341` (`-v repl="$repl"`, the
Profile/Commands block restore - install-smoke on macOS fails, telemetry part `constitution` «VULYK's own Commands rows
never land in a hive»), `scripts/cycle.sh:2826` (`-v ins="$block"`, council parts `escalate`/`ceilings` print
`awk: newline in string`), and any other `-v` whose value can hold a newline. Pass such values through the environment
(`name="$val" awk '... ENVIRON["name"] ...'`), which also stops `-v`'s implementation-defined escape processing (`\|` in
the Profile rows must survive byte for byte). (2) bash 3.2 mis-parses `case ... in pat)` inside a multi-line `$( ... )`:
`scripts/trace-check.sh:127` (`syntax error near unexpected token newline`, then `line 125: l: unbound variable`) - every
trace-check call fails on macOS (council `roster`, cycle `gates`). Use the `(pat)` form or move the case into a function.
(3) Then run each suite that FAILs on macOS (council parts judge seats escalate ceilings replays roster driver walks
advance; cycle parts hooklog gates ship red; e2e; solo; defects) under bash 3.2 in Docker and fix every product-script
error it shows; the CI tails showed no reason for several of them, most are expected to be cascades of (1) and (2).

Evidence (Queen, 2026-10-29): owner REJECTED after GREEN round 2 (plan.md `**Checked:**`); CI run 40787799947 on 9ca42a6 and the probe run 40857869190 (branch `ci-probe/mac-logs`, macOS only, `VULYK_SUITE_TIMEOUT=1500`). macOS: 21 suites FAIL, 3 TIMEOUT.

Local repro, no Mac needed: bash 3.2 is `MSYS_NO_PATHCONV=1 docker run --rm -v "<repo>:/w" -w /w bash:3.2 bash -c '<cmd>'` (Alpine/musl: `apk add --no-cache git jq python3 coreutils` first when a suite needs them; its awk/sed/paste are busybox, not BSD). Linux is `wsl.exe -d Ubuntu` - run suites in a clone under `~`, never on `/mnt/e` (CRLF working copy, noise). BSD `awk`/`paste` behaviour is reproduced by stubs, as `tests/cycle.test.sh` `part bsd` already stubs BSD sed.

## Requirements
> 3. Перевод всех продуктовых, командных (`.claude/commands/*.md`, `CLAUDE.md:76`) и тестовых файлов на переносимые вызовы.
> 5. Джоба `macos-latest` в `.github/workflows/ci.yml`.

## Files
- install.sh
- scripts/cycle.sh
- scripts/trace-check.sh
- scripts/lib.sh
- scripts/telemetry.sh
- scripts/wave-check.sh
- scripts/ship-check.sh
- scripts/human-check.sh
- scripts/state.sh
- scripts/redact.sh
- scripts/journal.sh
- tests/cycle.test.sh

## Non-goals
- No test-file changes beyond `tests/cycle.test.sh` (stories 08 and 09 own the other suites, the gate and CI).
- No behaviour change on Windows or GNU/Linux: same output bytes.

## Acceptance criteria
- [ ] `tests/cycle.test.sh` `part bsd` gains a BSD awk stub (refuses a `-v` value holding a newline, as BSD awk does) and
      proves `install.sh --upgrade`'s block restore and `cycle.sh`'s `:2826` insertion work under it, byte for byte,
      `\|` rows included - red before the fix, written and stamped first.
- [ ] `bash scripts/trace-check.sh <spec>` under Docker `bash:3.2` prints its normal summary (no syntax error).
- [ ] Each suite listed in (3), run under Docker `bash:3.2`, shows no product-script error; what remains is named under
      `## Findings` with its cause (a BSD-only tool difference the container cannot show, or a test-side issue for 08).
- [ ] `bash tests/cycle.test.sh` green here (Windows).

## Verification
`bash tests/cycle.test.sh`

## Implementation notes

## Findings
