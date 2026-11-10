# Brief: upgrade-findings

Date: 2026-11-10 · Tier: 3

## Request (verbatim)

Pasted by the owner as the whole message, this session. Written by a session in a hive after its upgrade, not by
the owner: it is no owner quote and files no defect card. One path inside the hive is masked by shape
(`<hive>/scripts/<hive>-vulyk-overrides.sh`); the hive root keeps its name. Section A repeats GitHub issue #5, already
public.

> # Prompt for a VULYK session: findings from upgrading a Windows hive 0.44.0 -> 0.50.2
>
> You are working in the VULYK repository (`Black-coffe/vulyk`). A production hive (Windows 11, Git Bash,
> Python 3.12 project, ~4970 pytest tests) was upgraded from 0.44.0 to 0.50.2 on 2026-11-10 with
> `/vulyk-update` and `--constitution replace`. The upgrade worked. Below is everything it surfaced, in priority
> order. Treat each item as a candidate story: reproduce it first, then fix it with a regression test that fails
> on 0.50.2. Do not take any claim here on trust. Each one says what was observed and what was not checked.
>
> Plan this as one spec (study first if you disagree with an item). Tier by your own routing: items A1-A4 touch the
> cycle's gates, so expect Tier 3.
>
> ---
>
> ## A. Gate integrity: state an agent can forge (issue #5)
>
> Threat model: the hive's own agents (a worker or the Queen) sidestepping a gate, not an outside attacker. All four
> items came from an automated security review that only read the code. None was reproduced as an exploit. Line numbers
> are as of v0.50.2 `scripts/cycle.sh`.
>
> **A1. Forgeable resume point in close-story (high).**
> `VSTART="$(verify_resume_start "$STORY" close-story "$VH")"` (~L2877) takes the resume point from a
> `verify_resume` mark in the story file, which the agent can write. `verify_run` then skips every line before `start`
> (`[ "$k" -lt "$start" ] && continue`), and nothing shows those lines passed in the run that paused.
> - Reproduce: put a hand-written `verify_resume` mark past a failing first verification line into a story, then run
>   `close-story`. Expected today: it closes.
> - Fix direction: keep resume state under a cycle-owned path (`.vulyk/`), keyed by story + HEAD + driver stamp, and
>   require a recorded exit 0 for every skipped line. Or have `story_blocks_guard` refuse any `verify_resume` line this
>   verb did not write.
>
> **A2. Predictable temp dir in stamp-red (medium).**
> `OUTD="${TMPDIR:-/tmp}/vulyk-sr-$(printf '%s' "$STORY" | cksum | cut -d' ' -f1)"` (~L2642) is reused whenever it
> already exists, and `verify_run` trusts the `$j.code` / `$j.line` files in it. In a shared `/tmp`, another user can
> pre-create the dir or plant a symlink. In any setup, an agent can plant passing results there before a resumed
> stamp-red. (On Windows, `TMPDIR` is per-user, so only the agent case applies.)
> - Fix direction: create it with `mktemp -d` (0700) and record its path in cycle-owned state. Before reuse, check
>   `[ -d "$OUTD" ] && [ ! -L "$OUTD" ] && [ -O "$OUTD" ]`, and never trust results this call chain did not produce.
>
> **A3. `narrow` repair read from mutable frontmatter (medium).**
> At ~L3153: `[ "$(fm_field "$nrs" narrow)" = true ] && { narrow=1; required="review"; }`, then `second=none`. If an
> agent sets `narrow: true` on a repair story, the next round runs as review-only with no court and no suite.
> - Fix direction: read `narrow` from the approved revision (`git show <approved_rev>:<story>`), or have
>   `cycle.sh repair` write it into `council/round-N/ROUND`. Re-check "exactly one RED item in one non-test file" when
>   the round opens, and add `narrow:` to the blocks `story_blocks_guard` compares.
>
> **A4. Risk-path detection misses renames (medium, one-line fix).**
> `round_second` (~L492): `names="$(git diff --name-only "$base" "$3")"` prints only the new path of a rename, so a file
> moved off a risk path does not trigger the Tier 4 second reviewer.
> - Fix: `git diff --name-only --no-renames`, or `--name-status` and check both sides. Test: `git mv` a risk-path file
>   to a neutral path and assert `round_second` prints `risk`.
>
> ---
>
> ## B. Commands table: the gate runs the whole cell, not the backticked command
>
> `full_suite_row()` in `scripts/cycle.sh` takes `cell[3]`, strips backticks with `gsub(/`/, "", c)` and runs whatever is
> left. A hive row like
>
> ```
> | Full suite / build (round-only) | `python -m pytest -q -m "not slow"` (⚠️ migrates the live DB; never during a recording) |
> ```
>
> becomes the command `python -m pytest -q -m "not slow" (⚠️ migrates the live DB; ...)`, which is a bash syntax error,
> so that suite part goes red. Verified by sourcing `full_suite_row` and printing its output on that constitution.
> Notes after the command are common in real hives (the bootstrap template does not forbid them). The same parsing
> probably affects any `## Commands` lookup that copies a cell into a command; check `command_cell_exists`,
> `verify_programs`, `wave-check.sh` and close-story's ready-line suggestions.
> - Fix direction: when the cell holds one backticked span, the command is that span; text outside it is a note.
>   Several spans: refuse with a clear message. No span: keep today's behaviour.
> - Also: `install.sh --upgrade` / `vulyk-update.sh --check` could lint the hive's rows for this and name each one.
>
> ---
>
> ## C. Gate split (ADR-029): the upgrade warns but does not measure
>
> The dry run prints the generic "a part over 210 s is red ... cut any row over ~210 s" note. The hive's own council
> logs already held the answer: `docs/specs/*/council/round-*/suite.log` and reviewer reports had `SUITE: ok 378s`,
> `ok 434s`, `FAIL 479s` and `TIMEOUT 596s budget 595s`. Without a cut, every round after the upgrade would have been
> red. Nothing in the upgrade said so for this hive.
> - Fix direction: in `vulyk-update.sh --check`, read the newest N `SUITE:` lines (and any `PART` lines) for the
>   hive's full-suite rows. If any is over 210 s, print `full suite measured <N>s in round <ref>: cut before taking
>   this release`, and name `scripts/suite-parts-check.sh`.
> - Docs: `/vulyk-update` step 6 covers renaming the row but not cutting it. Add a short recipe: measure once with
>   per-file timings (`pytest --junitxml`, then sum `testcase@time` per file), cut by a stable selector (file globs
>   such as `tests/test_[a-d]*.py`), check that the parts' test counts add up to the single run, and give every part
>   headroom under 210 s. In this hive, per-file sums undercounted wall time by ~40-70 s per part (import and
>   collection overhead of a heavy app), so the recipe must say to measure each part's wall time, not trust the sums.
>   For the record, the final cut: five parts, 89-121 s each, 4971 tests (same as the single 492 s run). A four-part cut
>   failed at 174-181 s because the heavy `test_e*` files kept landing in one part.
>
> ---
>
> ## D. SessionStart briefs said things that were not true
>
> **D1. Stale "update available".** The SessionStart brief said `installed v0.44.0, latest v0.49.0`.
> `git ls-remote --tags` a minute later showed `v0.50.2` (0.50.0, 0.50.1 and 0.50.2 were all tagged on 2026-11-09/10).
> The update-check cache is probably stale for too long, or read from a foreign/old cache. Check
> `vulyk-update-check.sh`'s TTL and source. A brief that names the wrong target version makes the owner decide on wrong
> data.
>
> **D2. False litopys offer.** The same session start printed both
> `[VULYK] litopys (session chronicle plugin) is not installed here. Ask the owner once: install ... or decline`
> and the plugin's own banner `[litopys] v0.4.1 · project chronicle`. So the plugin was active. The 0.49 changelog says
> the offer "stays quiet when the plugin is enabled at user scope". Either this install is at another scope (project /
> local / marketplace cache) or the detection misses it. Reproduce with litopys enabled at each scope.
>
> ---
>
> ## E. Smaller upgrade-UX notes
>
> - **E1. `would keep + new` on a hive edit the overrides script already re-applies.** `lead-review.md`'s only local
>   edit was `maxTurns: 140` plus `experimental.cacheTtl: 1h`. 0.49 removed `cacheTtl` upstream on purpose. The
>   hive registers its edits in its own `<hive>/scripts/<hive>-vulyk-overrides.sh`, so the right action was "take the new file,
>   re-run overrides". The tool cannot know that. But when a frontmatter-only edit meets an upstream body change, it
>   could merge the frontmatter keys and land the new body instead of parking the whole file as `.vulyk-new`. Worth
>   considering, not required.
> - **E2. CRLF noise.** A plain `diff` of the hive's `lead-review.md` against the release showed the whole file as
>   changed. With `--strip-trailing-cr` it was 5 hunks. If the keep/merge classification compares bytes, a CRLF-only
>   checkout could be misread as a local edit. Check that the classifier normalises line endings (it looked right in
>   this run: `council-opus.md` was correctly `keep (edited)` with a real edit).
> - **E3. `settings.json` re-indented.** The upgrade re-indents the whole file (it says so, and keeps
>   `.claude/settings.json.vulyk-bak`). The only real changes were quoting `"$CLAUDE_PROJECT_DIR"` in every hook command,
>   adding `git-guard.sh`, and SessionEnd timeouts. A re-indent makes the owner's review of a hook change harder.
>   Preserve the existing indent if the JSON writer allows it.
> - **E4. Constitution replace.** It worked as documented. Outside the two blocks, only upstream wording differed plus
>   two hand-written hive lines, restored by hand from the `.pre-0.50.md` backup. Idea: `--check` could print the
>   non-block lines that would exist only in the backup, so the owner sees what to restore before choosing.
>
> ---
>
> ## Out of scope
>
> - Do not change hive-side files (Recall). Everything here is a framework change.
> - Do not touch the A/B measurement study or model profiles.
> - Do not widen `install.sh --upgrade` beyond what is described.
>
> ## Done when
>
> - A1-A4 each have a failing-then-passing regression test in `tests/` and a CHANGELOG line, and issue #5 is closed with
>   the release that ships them.
> - B: the gate runs only the backticked span, with a test using a row with a trailing note.
> - C: `--check` names an over-cap measured suite, and the `/vulyk-update` doc has the cutting recipe.
> - D1 and D2 are reproduced (or shown not reproducible, with how) and fixed.
> - E items are either done or listed under `## Descoped` with a reason.

## Recon (2026-11-10, v0.50.3)

- A1: `verify_resume_start` (scripts/cycle.sh:2276) takes the start line from the story's `verify_resume` frontmatter,
  keyed only by verb and `## Files` hash; close-story reads it at :2877, stamp-red at :2641.
- A2: stamp-red `OUTD` at scripts/cycle.sh:2642 is `${TMPDIR:-/tmp}/vulyk-sr-<cksum of the story path>`.
- A3: scripts/cycle.sh:3154 reads `narrow` with `fm_field` from the repair story.
- A4: `round_second` scripts/cycle.sh:492 runs `git diff --name-only` without `--no-renames`; the paperwork diff in
  scripts/lib.sh:93 and cycle.sh:2959 already passes `--no-renames`.
- B: `full_suite_row` scripts/cycle.sh:1776 strips every backtick from cell 3 and keeps the rest; similar backtick
  stripping in scripts/cycle.sh:2070, scripts/wave-check.sh:121, scripts/lib.sh:355; `command_cell_exists`
  scripts/lib.sh:173, `verify_programs` scripts/lib.sh:254.
- C: the gate-split note is fixed text in install.sh:1748-1754 and reads no hive council log.
- D1: .claude/hooks/vulyk-update-check.sh caches `<epoch> <latest>` for `VULYK_UPDATE_INTERVAL_HOURS` (default 24) and
  prints no date. v0.50.0 was tagged 2026-11-09 22:22 +0200, so a cache written earlier that day still said 0.49.0
  on the 10th. `scripts/vulyk-update.sh --check` already fetches tags fresh (`fetch_tags`, :82) and takes the newest.
- D2: v0.44.0's session-start-brief.sh looked for `litopys@` only in the project's `.claude/settings{,.local}.json`;
  0.49 added `$CLAUDE_CONFIG_DIR`/`~/.claude/settings.json`. The hive's brief came from its 0.44.0 hook, before the
  upgrade. The 0.50.3 hook, run against the same hive (`CLAUDE_PROJECT_DIR=<hive>`), prints no litopys line: litopys
  is enabled at user scope there and in no project settings file.
- E2: `release_copy` (install.sh:151) and `upgrade_edited` (install.sh:157) strip `\r` before hashing and merging.
- E3: five Python writers in install.sh (`json.dump(..., indent=2)` at :844, :1034, :1125, :1191, :1245).
- E1: no frontmatter-aware merge today; `upgrade_edited` is `git merge-file` on whole files, a conflict parks
  `.vulyk-new`.

## Answers

1. Подделка: Своя папка cycle.sh - пауза, результаты прогонов и флаг narrow хранятся в .vulyk/ с привязкой к истории и
   HEAD, а метка, написанная руками в истории, просто не действует. Одно хранилище закрывает все три пункта сразу. От
   агента с полным shell это не спасает полностью, но обычной правкой своих бумаг гейт уже не обойти.
2. Публичность: Как в #5 - в брифе тот же текст, что в issue #5, и ничего сверх него. Коммиты остаются локальными, ветка
   уходит на GitHub только вместе с исправлениями, релиз закрывает #5.
3. Версия: 6 ч + дата + --check - кэш живёт 6 часов вместо 24, строка в брифе пишет «по данным на <дата>», а --check
   перед обновлением всегда спрашивает GitHub заново. Решение принимается по свежим данным, а запросов всё равно мало.
4. Мелочи E: all four picked - E3 отступ settings.json, E4 строки бэкапа, E2 только тест на CRLF, E1 слияние frontmatter.

## Asks

1. A1: close-story and stamp-red never take their resume point from the story file. Resume state lives in a
   cycle-owned path (`.vulyk/`), keyed by story, HEAD and driver stamp, and every skipped line has a recorded exit 0
   from the run that paused. A hand-written `verify_resume` mark past a failing first verification line does not let
   `close-story` close: a regression test that fails on 0.50.2.
2. A2: stamp-red's results directory is made with `mktemp -d` (0700), its path is recorded in that cycle-owned state,
   it is reused only when `[ -d ] && [ ! -L ] && [ -O ]` hold, and results this call chain did not produce are never
   trusted: a regression test that fails on 0.50.2.
3. A3: a round runs narrow only from cycle-owned state written by `cycle.sh repair`, never from the repair story's
   frontmatter; "exactly one RED item in one non-test file" is re-checked when the round opens, and `narrow:` joins
   the blocks `story_blocks_guard` compares. A `narrow: true` an agent writes into a repair story does not shrink the
   round: a regression test that fails on 0.50.2.
4. A4: `round_second` sees both sides of a rename: `git mv` of a risk-path file to a neutral path prints `risk`, a
   regression test that fails on 0.50.2.
5. A1-A4 each get a CHANGELOG line, and issue #5 is closed with the release that ships them.
6. B: a `## Commands` cell holding one backticked span runs exactly that span, and text outside it is a note; where one
   cell becomes one command (the full-suite row, close-story's ready-line suggestion) several spans are refused with a
   clear message, while a lookup that matches a story's line keeps offering each span (`templates/story.md`); no span
   keeps today's behaviour. The same rule holds in every lookup that
   copies a cell into a command (`full_suite_row`, `command_cell_exists`, `verify_programs`, `wave-check.sh`,
   close-story's ready-line suggestions), with a test using a row with a trailing note.
7. B: `install.sh --upgrade` / `vulyk-update.sh --check` names each hive `## Commands` row with text outside its one
   backticked span or with several spans.
8. C: `vulyk-update.sh --check` reads the newest `SUITE:` (and any `PART`) lines of the hive's full-suite rows from its
   council logs; any over 210 s prints `full suite measured <N>s in round <ref>: cut before taking this release` and
   names `scripts/suite-parts-check.sh`.
9. C: the `/vulyk-update` doc's step 6 gets the cutting recipe: measure once with per-file timings, cut by a stable
   selector (file globs), check that the parts' test counts add up to the single run, measure each part's wall time
   instead of trusting per-file sums, and leave every part headroom under 210 s.
10. D1: the update-check cache lives 6 hours by default instead of 24, the `update available` line says when the latest
    version was checked, and `vulyk-update.sh --check` asks GitHub fresh before an upgrade.
11. D2: the litopys offer is reproduced with litopys enabled at each scope (user, project, local) or shown not
    reproducible on 0.50.x with how; every scope where the plugin is enabled silences the offer.
12. E1: when a hive's edit of a framework file touches only its frontmatter and the release changed the file, the
    upgrade lands the release's body with the hive's frontmatter keys merged in, and names each key kept or dropped,
    instead of parking the whole file as `.vulyk-new`.
13. E2: a test shows that a CRLF-only checkout of a release copy is not classified as a local edit (code changes only
    if that test fails).
14. E3: the upgrade keeps `.claude/settings.json`'s existing indent when it rewrites the file.
15. E4: `--check` with `--constitution replace` prints the non-block lines that would exist only in the backup.
16. Out of scope: no hive-side file changes, no change to the A/B measurement study or model profiles, and
    `install.sh --upgrade` widened no further than asks 7, 8, 12, 14 and 15 describe.
