---
story: ab-run-fixes-06
spec: ab-run-fixes
status: done
returned: DONE
tier: 3
worker: worker-code
wave: 3
blocked_by: [ab-run-fixes-02, ab-run-fixes-04, ab-run-fixes-07]
red: required
red_reason: brief: no litopys offer when the plugin is enabled at user scope
red_verified_at: 2026-11-08T22:17:46Z eacdfd70dc3be8c2bb22725d9b5bd45216f5ab39fee977e9e7f8a01df274b1ec
---

# Onboarding and the README: bootstrap from the repo, docker rows, no telemetry question, litopys at user scope, the honest result

## Goal
After this story:
- **Bootstrap.** By default `/vulyk-bootstrap` takes the Profile and Commands from repo facts: manifests, lockfiles, CI, compose files and the README. It asks the owner only where a fact is missing or two facts disagree. It builds no every-area scout map (maps come later from `/vulyk-plan` recon or `/vulyk-map`) and ends without pushing the owner to `/vulyk-handoff` or `/clear` (recon Q9 for `handoff.py:777`).
- **Docker rows.** In a docker stack, bootstrap writes Commands rows as `docker compose exec -u <user> <service> <cmd>`, with `<user>` read from the repo (compose `user:` or the Dockerfile `USER`).
- **Telemetry question.** A bare interactive `install.sh` asks nothing about telemetry and leaves it off. `--telemetry ask` asks once, and `on|off` are unchanged.
- **litopys offer.** The SessionStart brief does not offer litopys when it is enabled in the user's settings (`session-start-brief.sh:126` reads only the project files today).
- **README.** It states the A/B run's result plainly.

## Requirements
> 6. Bootstrap: факты берутся из репо, вопросы — только при расхождении. На старте не строит карту всех областей и не толкает к handoff/clear.
> 12. В docker-стеке bootstrap пишет строки Commands с `exec -u <user>`.
> 14. `install.sh` по умолчанию не спрашивает про телеметрию (выключена), спрашивает только при `--telemetry ask`.
> 15. README: результат прогона, каскад моделей не проверялся, тезис про окно 1M не подтверждён.
> 21. Предложение поставить litopys не всплывает, если плагин включён на уровне пользователя.

## Coverage additions (Queen, from drone-coverage)
- Ask 6: bootstrap no longer maps every module at start (`vulyk-bootstrap.md` step 4 becomes "list modules in `memory/memory.md` as unmapped; `/vulyk-plan` recon maps what a task touches"), and nothing at bootstrap end pushes `/vulyk-handoff` + `/clear`.
- Ask 15: the README paragraph states both that the model cascade was not measured (workers ran on Opus) and that the "1M window is a trap" claim is not confirmed by this run.

## Files
- .claude/commands/vulyk-bootstrap.md
- bootstrap/interview.md
- .claude/hooks/handoff.py
- .claude/hooks/session-start-brief.sh
- install.sh
- tests/maintenance.test.sh
- tests/telemetry.test.sh
- README.md
- docs/getting-started.md
- docs/telemetry.md
- docs/hooks-reference.md

## Non-goals
- No host or client project name, path or folder anywhere (public repo; card `host-internals-in-public-repo`). The run is "an A/B run on an open-source Laravel app".
- README: no number beyond the run's facts listed below, no claim that VULYK is better or worse in general, and no roster or grill lines (stories 04 and 02).
- Do not remove `/vulyk-map` or the map format. Do not change `handoff.py`'s thresholds outside the bootstrap push, or `--telemetry on|off`.
- No new Commands row.

## Map slice
memory/map/scripts.md (install.sh: the upgrade contract; `session-start-brief.sh`; `handoff.sh`); memory/map/agents-and-commands.md (`/vulyk-bootstrap`)

## Acceptance criteria
- [ ] `brief: no litopys offer when the plugin is enabled at user scope`: a fake `HOME` whose settings enable `litopys@litopys` gets no offer line. It fails on HEAD and passes after. The project-scope case is unchanged, and with neither the offer still shows.
- [ ] `install: no telemetry question without --telemetry ask`: with a TTY and no flag, there is no prompt and the Profile row reads off. `--telemetry ask` prompts once.
- [ ] `vulyk-bootstrap.md` and `interview.md`:
  - Facts first; a question only on a discrepancy or a gap; no all-area map step.
  - The final step has no handoff/clear push.
  - The docker `exec -u <user>` rule is in the Commands step.
- [ ] README:
  - Line 40's 1M-window sentence becomes a hypothesis this run did not confirm.
  - "What is measured" gains one paragraph with these facts: one task, n=1; quality equal on the checklist and the tests; 1.8x weighted tokens; 18 stops against 4; workers ran on Opus, so the cascade was not measured; fixes followed, and a measurement is planned. "Not measured" stays true.
  - The bootstrap sentence (line 95) and the installer paragraph (line 272) match the new behaviour.
- [ ] `docs/getting-started.md`, `docs/telemetry.md` and `docs/hooks-reference.md` are corrected wherever they state the old behaviour.
- [ ] `## Implementation notes` ends with one `CHANGELOG:` line.

## Verification
`bash tests/maintenance.test.sh`
`bash tests/telemetry.test.sh --part install`
`bash scripts/py.sh -m py_compile .claude/hooks/*.py`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes
- tests/maintenance.test.sh: the red test (fake HOME with `litopys@litopys` in `~/.claude/settings.json`), plus the project-scope and no-scope cases.
- tests/telemetry.test.sh: install part gains the bare-install pty case (no question, row off); terminal part's pty case now runs `--telemetry ask` and counts one question; the scan part's brief() gets a temp CLAUDE_CONFIG_DIR so the owner's real user settings decide nothing. Both pty cases skip on a box without util-linux `script` (this one), so they were not run here.
- session-start-brief.sh: the litopys grep also reads `$conf/settings.json` (`$CLAUDE_CONFIG_DIR`, else `~/.claude`, already resolved for the mod check above it).
- install.sh: `telemetry_decide` puts the question only on `ask`; with no flag a missing row is written off, an existing one stays. `on|off` and `--check` unchanged. Binary-mode edit, the one intentional CR byte kept.
- vulyk-bootstrap.md / interview.md: facts first, a question only on a gap or a clash; `--quick` asks nothing and lists gaps; step 4 lists modules as unmapped, no scout; docker `exec -u <user>` rule in the Commands step; the summary does not suggest `/vulyk-handoff` or `/clear`.
- handoff.py: not edited. Its `:777` push is the level-2 context banner; bootstrap reached it because step 4 mapped every module with scouts, and that step is gone. Changing the banner would touch thresholds, a non-goal.
- README: the 1M sentence is a hypothesis the run did not confirm; one "Measured once" paragraph with the run's facts; bootstrap and installer sentences match. getting-started, telemetry.md, hooks-reference.md (the litopys line, which it lacked) corrected.
CHANGELOG: bootstrap reads the Profile and Commands from the repo and asks only on a gap or a clash, maps nothing up front and writes docker rows as `exec -u <user>`; a bare `install.sh` no longer asks about telemetry (`--telemetry ask` does); the litopys offer respects a user-scope install; the README states the A/B run's result.

## Findings
- close-story exit 4 on `bash tests/maintenance.test.sh`: 390 checks, 2 failed, both `portability-check: the tree exits 0` / `prints its ok line`. Every other check passes, the red test included (`brief: no litopys offer when the plugin is enabled at user scope` ok).
- The hits are in `scripts/cycle.sh`, outside this story's `## Files`: committed HEAD d31b363 (story 04) already has `case-in-subst` (`case "$reach" in ...`, the narrow-repair NARROW line) and `heredoc-in-subst` (`done <<EOF` after it); the live tree adds a third, `array` (`for p in "${PP[@]}"`), from story 05's uncommitted edits. Running portability-check on a copy of HEAD's cycle.sh gives the 2 hits.
- Rerun 2026-11-09: story 05 is now committed (e1b2597) and `scripts/portability-check.sh` still reports 3 hits, all in committed `scripts/cycle.sh` (3532 array, 3799 case-in-subst, 3818 heredoc-in-subst); the tree is clean there. Still outside this story's files.
- Needed: story 04's owner (a repair) and story 05 fix the cycle.sh lines, then this story's close-story is rerun; nothing in this story's files causes the red.
- Driver stop 2026-11-09 (missed twice): worker returned, but docs/specs/ab-run-fixes/ab-run-fixes-06-onboarding-readme.md is still todo - close-story did not close it. Queen check: `bash scripts/portability-check.sh` on HEAD e1b2597 gives the same 3 hits (cycle.sh:3532 array, 3799 case-in-subst, 3818 heredoc-in-subst); story 06 edits are left uncommitted in the tree.
## Red receipt
- command: bash tests/maintenance.test.sh
- exit: 1
- tests: eacdfd70dc3be8c2bb22725d9b5bd45216f5ab39fee977e9e7f8a01df274b1ec (tests/maintenance.test.sh, tests/telemetry.test.sh)
- impl: 56ce1c512e4d728a4ff8c5019bc7339348021436acc7ea036f0ca7f87a48fd27
- stamped: 2026-11-08T22:17:46Z

```
::error::brief: no litopys offer when the plugin is enabled at user scope
  ok    git-guard: no interpreter exits 0, silent
  ok    git-guard: --check fails on the original fixture
  ok    git-guard: --check fails on the neighbour fixture
  ok    git-guard: --check passes a file that is no hook input
--- git guard: a mod with tool.check
  ok    git-guard: an enabled mod with tool.check gets a brief line
  ok    git-guard: a disabled mod is not named
  ok    git-guard: no such mod, no line
  ok    git-guard: an enabled mod without tool.check, no line
maintenance.test.sh: 390 checks, 3 failed
```
