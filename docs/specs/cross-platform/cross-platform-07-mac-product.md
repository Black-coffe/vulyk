---
story: cross-platform-07
spec: cross-platform
status: done
returned: DONE
tier: 3
worker: worker-code
model: opus
wave: 5
blocked_by: []
red: required
red_reason: ::error::fresh install under BSD awk
red_verified_at: 2026-10-29T11:17:50Z 3f283b5bed2aea8601f2e81e82aca3568235f7959fbae66a826af4aedd85f506
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
- tests/cycle.test.sh `part bsd`: BSD awk stub (refuses a `-v` value holding a newline); fresh install + `--upgrade` block restore and `reopen`'s insertion under it, `\|` byte for byte. Red stamped first.
- install.sh: `reset_marked_block` and `ensure_marked_block` pass `repl` through `ENVIRON["VULYK_REPL"]`; the Browser MCP placeholder row now holds `\|` itself (it held `\\|` only because `-v` halved it). GNU/Windows output checked identical: fresh install and `--upgrade` CLAUDE.md `cmp`-equal to HEAD's install.sh.
- scripts/cycle.sh: `append_after_answers` passes the block through `ENVIRON["VULYK_INS"]` (side effect: a `\` in an owner decision now survives on GNU awk too, where `-v` used to eat it); `red_sets`' `case` inside `$( { ... } )` uses the `(pat)` form (bash 3.2 parse error at :2092); `descope_not_in_brief` never `grep -f`s an empty pattern list (BusyBox grep matches every line then).
- scripts/lib.sh: `paperwork_only` reads `git diff -z` from a temp file instead of `wait $!` on a process substitution - bash 3.2 returns 127 there, so every paperwork-only range read as STALE (cascade behind council seats/ceilings/replays/roster/driver/advance, cycle ship/hooklog/red, solo).
- scripts/trace-check.sh: the `case` inside the multi-line `$( ... )` (:117) uses `(pat)`; under Docker `bash:3.2` it now prints its normal summary.
- Docker `bash:3.2` (clone of HEAD + this diff, BusyBox tools and again with GNU grep/sed/gawk): every suite of (3) exits 0 except `tests/defects.test.sh` - see Findings.
- `bash tests/cycle.test.sh` here (Windows): exit 0, no error. First attempt returned NEEDS_CONTEXT (defects-check.sh); re-dispatch kept `## Files`, so closed with that item under Findings.
- Other `-v` values checked: install.sh:653 `newrow` and cycle.sh:140/144/2187 are one line; no change.

## Findings
- Remains, outside this story's `## Files` (re-dispatched with `## Files` unchanged, so closed with it named here; needs its own story): `scripts/defects-check.sh` does not parse under bash 3.2: `line 407: unexpected EOF while looking for matching ''` - the `<<'PY'` heredoc inside `plan="$( ... )"` (:82-332) is scanned for quotes by bash 3.2. Every `tests/defects.test.sh` case fails on it. Verified fix (in a throwaway container copy only): wrap the python call in a function `read_cards() { PYTHONIOENCODING=utf-8 "$PY" - ... <<'PY' ... PY }` and set `plan="$(read_cards)" || { ...`; with it `bash -n` passes and `tests/defects.test.sh` exits 0 under bash 3.2.
- Not reproducible in the container (BSD-only, for 08/CI): BSD `paste`/`awk` differences beyond the `-v` newline; the BusyBox tools are not BSD.

## Red receipt
- command: bash tests/cycle.test.sh
- exit: 1
- tests: 3f283b5bed2aea8601f2e81e82aca3568235f7959fbae66a826af4aedd85f506 (tests/cycle.test.sh)
- impl: 769553ac3c6e96ec6143a63bc8cb11fe7e5d6d0234b0deb47b283812aeb5f9ac
- stamped: 2026-10-29T11:17:50Z

```
red-receipt: an unmarked story built from templates/story.md closes as before
  ok    the template story closes and commits, no receipt asked
red-receipt: close-story on a marked story - the sealed test edited, no implementation change, then a real change closes
  ok    red-12 stamped
  ok    a sealed test edited after the stamp: exit 4
  ok    the implementation unchanged since the stamp: exit 4
  ok    receipt + changed implementation + green: closed, the receipt in the commit
red-receipt: close-story on a marked story that was never stamped
  ok    the unstamped story: exit 4, nothing committed
  ok    the refusal names stamp-red and the story
```
