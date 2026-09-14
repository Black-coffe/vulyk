# Scout: install.sh escaping + council.test.sh probes (2026-09-14, drone-scout on sonnet)

## install.sh block insertion (major 1)
- `print_profile_placeholder` install.sh:150-164 is a quoted heredoc; the Browser MCP row at :161 ships as literal `\|` - pre-escaped to survive exactly ONE `awk -v` pass (CLAUDE.md:131 carries `\|`).
- Three consumers, different pass counts:
  1. fresh install - `reset_marked_block` :108-129, one `awk -v repl=` pass at :124 - correct.
  2. `--upgrade` EOF-append - `ensure_marked_block` :180-230: one pass builds `block` (:209-215), then `printf '%s\n' "$block"` at :226 - correct.
  3. `--upgrade` anchor-insert :220-224: the once-processed `block` is fed to a SECOND `awk -v block=` to splice at the anchor line - the bug; `\|` under a second pass is implementation-defined (gawk warns).
- Model to converge on: `reset_marked_block` (single pass). No helper in scripts/lib.sh does anything comparable (no `awk -v`/`getline`/`ENVIRON` there).
- Variants: (a) anchor line number via `grep -n -F -x`, reassemble with `head -n`/`printf '%s\n' "$block"`/`tail -n +` - no second awk; (b) write `block` to a temp file and splice with awk `getline`; (c) gawk `ENVIRON["block"]` (gawk-only).
- Coverage: only CI job `install-smoke` scenario "D4.7" at .github/workflows/ci.yml:321-339 - exercises path 3, asserts marker presence (:329-330), row COUNT (:331-334), heading order (:335-338), one stdout grep (:339). Nothing asserts the Browser MCP row's content. No `tests/*.sh` touches install.sh.

## tests/council.test.sh probe machinery (majors 2, 3)
- Harness :1-22: `fail=0`; `expect()` :18-22 sets `fail=1`; inline `{ ...; fail=1; }` elsewhere. Final `exit "$fail"` not verified by the scout.
- `lr31w` :1387-1421 uses `expect` (fail-capable): A todo wave 1 `blocked_by: [lr31w-02]`, B `status: blocked`; asserts `wave_stories == []`, then B done -> lists A. Never puts a ready story and a not-ready todo in the same wave (major 2's condition).
- `probe_lr31wall` :2409-2439: same shape, `echo ok || echo FAIL` at :2438 - print-only.
- `wave_stories` scripts/cycle.sh:319-360, LR31 fix :345-347 (only `done` blockers count).
- `run_wall_probes` :2084-2133: scratch repo with a swapped `cycle.sh`; 6 built-in probes :2118-2123 + extras :2125-2128, each `echo "  [$wlabel] $extra:  $($extra)"` - never inspects, never sets `fail=1`.
- Pinned copies via `git -C "$SRC" show <sha>:scripts/cycle.sh > tmp`, no error handling: `3e200bb` :2030 (run :2135-2136), `b9f36e8` :2358 (:2359-2360), `eb3203a` :2461 (:2462-2463), `$PRESHA11` computed at :2687 (`git log --grep='story(v0-12-0-remainders-11)'`^), :2689-2691.
- All 20 `probe_*` functions are `echo ok`/`echo FAIL` display-only.
- CI `council` job .github/workflows/ci.yml:109-116: `actions/checkout@v4` with no `fetch-depth` (shallow, depth 1).
