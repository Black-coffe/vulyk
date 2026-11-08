---
story: ab-run-fixes-06
spec: ab-run-fixes
status: todo
returned:
tier: 3
worker: worker-code
wave: 3
blocked_by: [ab-run-fixes-02, ab-run-fixes-04]
red: required
red_reason: brief: no litopys offer when the plugin is enabled at user scope
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

## Findings
