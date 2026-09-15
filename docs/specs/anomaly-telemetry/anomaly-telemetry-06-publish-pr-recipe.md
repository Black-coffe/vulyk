---
story: anomaly-telemetry-06
spec: anomaly-telemetry
status: done
returned: DONE
tier: 3
worker: worker-code
model: opus
tracer: false
wave: 4
blocked_by: [anomaly-telemetry-01, anomaly-telemetry-03, anomaly-telemetry-04]
---

# Fix (council round 1, ask 2): the cross-machine recipe must produce a pull request

## Goal
`telemetry.sh publish` on a machine without a local VULYK checkout prints a recipe that, pasted as-is, ends in an open pull request: fork-and-clone, branch, copy, add, commit, push, `gh pr create`. Today it prints only `cp ...` then `cd ... && gh pr create`, so after the copy the tree holds `?? telemetry/` and `gh` has nothing to open (opus seat, round 1). The same recipe on `docs/telemetry.md` is corrected, both recipes survive paths with spaces, `#` or `&`, and a weekly run no longer silently drops the previous week's rows.

## Requirements
> Раз в неделю логи отправляются в репозиторий VULYK: локально в основной проект, с других машин как pull request.
> иначе печатает готовую команду gh pr create в публичный репозиторий. Ничего не отправляет само.

## Files
- scripts/telemetry.sh
- tests/telemetry.test.sh
- docs/telemetry.md

## Non-goals
- Do not execute anything new: the script still never calls `git commit`, `git push`, `gh`, `git clone` or `gh repo fork` - it prints them. The PATH-shim assertion in the suite stays and must still pass.
- Do not change the bundle schema, `check` rules, the enum, `record`, `scan`, the detectors, or the local-checkout branch's behaviour beyond quoting (that branch was judged GREEN by all seats).
- Do not add a config file, a state marker or a "last published week" file - the week fix below is a default, not a ledger.
- Do not touch `README.md`, `telemetry/inbox/README.md`, `.claude/commands/vulyk-evolve.md`, `install.sh` or `CLAUDE.md` - other round-1 findings live there and are the Queen's to route.
- Do not fix review findings 2, 4-13, 15, 16 here even when they are one line away; this story closes ask 2 only.

## Map slice
memory/map/scripts.md (`lib.sh` exports, quoting conventions); plan.md `## Contracts` (`publish` verb) and A1, A14, A15; `docs/specs/anomaly-telemetry/council/round-1/opus.md` ASK 2 and UNASKED (1); `review.md` finding 14.

## Acceptance criteria
- [ ] With consent `on` and no local checkout (A1 misses), `publish` prints one fenced block whose lines, in order, are: `gh repo fork <slug> --clone <dir>` (worker confirms the flag with `gh repo fork --help`; if `--clone` takes no directory argument, use `git clone` of the fork URL as the next line instead), `cd <dir>`, `git switch -c telemetry/<week>-<hive>`, `mkdir -p telemetry/inbox/<week>`, `cp <bundle> telemetry/inbox/<week>/<hive>.jsonl`, `git add telemetry/inbox/<week>/<hive>.jsonl`, `git commit -m "telemetry(<week>): <hive>"`, `git push -u origin telemetry/<week>-<hive>`, `gh pr create --repo <slug> --head telemetry/<week>-<hive> --title "telemetry(<week>): <hive>" --body "<one sentence, no paths>"`. `<slug>` resolves per A1 (`VULYK_REPO`, `.claude/vulyk-origin`, `Black-coffe/vulyk`); `<dir>` is a fixed relative name such as `vulyk-telemetry`.
- [ ] Every path in both recipes (local commit and PR) is single-quoted or escaped so a bundle path or repo path containing a space, `#` or `&` pastes and runs; `check`'s `<file>:<line>:` prefix no longer goes through `sed "s#^#$f:#"` and survives a `#` in the path (finding 14).
- [ ] A15: `publish` and `bundle` with no `--week` process the previous ISO week and the current one; each week with rows gets its own `.vulyk/telemetry/<week>-<hive>.jsonl` and its own inbox path / recipe line set; a week with no rows is skipped silently; `--week` still selects exactly one week. `--dry-run` covers both.
- [ ] `tests/telemetry.test.sh` gains cases that: (a) run `publish` with no local checkout and assert the block contains, in order, `fork`, `switch -c`, `git add`, `git commit`, `git push`, `gh pr create`; (b) run `publish` with `VULYK_LOCAL` and a bundle path containing a space and a `#` and assert the printed `cp`/`git add` lines are quoted and `check` reports `<path>:<line>:` intact; (c) backdate one row to the previous ISO week and assert a bare `publish --dry-run` names both weeks while `--week <current>` names one; (d) the existing shim assertion that `push`, `commit`, `pr`, `clone`, `fork` never execute still passes.
- [ ] `docs/telemetry.md` cross-machine section shows the same nine-line recipe verbatim (generated form, `<week>`/`<hive>` placeholders) and states that `publish` covers the previous and current ISO week by default; no other section changes.

## Verification
`bash tests/telemetry.test.sh`

## Implementation notes

- `scripts/telemetry.sh`: new `prev_week`/`default_weeks` (A15 default: previous ISO week +
  current), `shq()` (single-quotes every path that reaches a recipe), `origin_slug()` factored
  out of `local_vulyk_repo`, `recipe_local`/`recipe_pr` printers, `cmd_bundle` and
  `cmd_publish` now loop over the week list (one bundle file, one inbox path and one recipe
  per week; an empty week is skipped silently, "nothing to send" only when no week had rows).
- `check`'s `<file>:<line>:` prefix no longer goes through `sed "s#^#$f:#"` - a `while read`
  loop prints it, so a `#` in the path survives (review finding 14).
- Decision: `gh repo fork --clone` is a boolean flag (`gh repo fork --help`), and git-clone
  arguments are passed after `--`, so the first recipe line is
  `gh repo fork '<slug>' --clone -- 'vulyk-telemetry'` rather than the story's literal
  `--clone <dir>`; the story's `git clone`-of-the-fork-URL fallback was rejected because the
  fork URL needs the user's login, which the script cannot know.
- With two weeks and no local checkout, two full nine-line PR blocks are printed (one per
  week); the second one's fork/clone is a no-op for a human who already cloned.
- Tests: new `expect_order` helper; a second fixture hive and checkout whose paths hold a
  space and a `#`; ordered fork->PR assertion; backdated row for the two-week default;
  the shim's never-executed list now also covers `clone` and `fork`. Two existing needles
  (`git add telemetry/...`) were updated to the new quoted form - the only intended change to
  the local-checkout branch.
- `docs/telemetry.md`: the cross-machine section now shows the nine-line recipe verbatim and
  states the two-week default; no other section touched.
- Surprise: `local_vulyk_repo` returns `git rev-parse --show-toplevel`, which on Windows is a
  `C:/...` path, not the `mktemp -d` `/tmp/...` form - the new test resolves it the same way.

## Findings
