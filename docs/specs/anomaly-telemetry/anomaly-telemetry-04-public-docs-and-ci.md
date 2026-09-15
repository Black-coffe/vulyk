---
story: anomaly-telemetry-04
spec: anomaly-telemetry
status: done
returned: DONE
tier: 3
worker: worker-code
model: sonnet
tracer: false
wave: 2
blocked_by: [anomaly-telemetry-01]
---

# Public documentation, inbox directory, CHANGELOG, CI validator

## Goal
The public repository says, in the README and on a dedicated page, that anonymized anomaly logs are collected to improve VULYK, exactly which codes and numbers a bundle contains and what never leaves the machine, that sending is opt-in and done by a pull request into `telemetry/inbox/`, and that the inbox is distilled and cleared weekly by `/vulyk-evolve` in the VULYK repo, feeding releases. The inbox directory's placeholder becomes a README, and one CI job validates every incoming bundle with `telemetry.sh check`.

## Requirements
> В публичном репозитории на GitHub написано, что логи собираются для улучшения VULYK, их можно запушить как pull request, раз в неделю логи чистятся и выходит апдейт.
> обязательно об этом нужно в публичном репозитории на GitHub написать, что для улучшения самого Vulik собираются логи, которые вы можете зап ушить как pull request, и раз в неделю будет проводиться очищение тех логов и апдейт самого Vulik для улучшения.
> максимально обезличенные, чтобы никто не придрался, что отправляются какие-то личные файлы

## Files
- README.md
- docs/telemetry.md
- CHANGELOG.md
- telemetry/inbox/.gitkeep
- telemetry/inbox/README.md
- .github/workflows/ci.yml

## Non-goals
- Do not edit `install.sh`, `CLAUDE.md`, `bootstrap/interview.md` or the install-smoke CI job - story 05 owns them and also touches `ci.yml` in wave 3; keep this story's `ci.yml` change to one new, self-contained job.
- Do not promise anything the script does not do: no automatic sending, no scheduler, no server. Do not claim the inbox has been distilled yet; the README's "has never been run against real data" framing stays true until it is not.
- Do not restate thresholds as facts - name the env vars and say the defaults are v1 calibration recorded in every row.
- Replace `.gitkeep` with the README (delete the placeholder); do not keep both.
- Do not write a data-retention policy beyond "distilled and cleared weekly by `/vulyk-evolve`".
- Do not describe the installer's question in detail - one sentence that `install.sh` asks and defaults to off; story 05 owns the wording.

## Map slice
plan.md `## Contracts` (enum table, agent token set, bundle row, `check` rules, Profile row wording, installer prompt) and A1, A11, A12; recon/weekly-and-publish.md Gotchas 6-7 (no jsonl-schema precedent in CI, README lines 225-241); memory/map/agents-and-commands.md `/vulyk-evolve` entry.

## Acceptance criteria
- [ ] README gains a subsection under "What is measured, and what is not" (or directly after it) of at most ~25 lines: logs are collected to improve VULYK; what a bundle row is (the 10 keys) and the full code list; that `agent` is a framework agent name or `other`; what is never included (paths, slugs, story names, dispatch names, emails, free text, file contents); off by default, the installer asks once and the `Telemetry` Profile row holds the answer; `/vulyk-evolve` prints the command, you push the PR; the inbox is distilled and cleared weekly and feeds releases. Links to `docs/telemetry.md`.
- [ ] `docs/telemetry.md` states the same in full: enum table with detector, value, threshold and env var; the agent token set and its `other` rule; the bundle schema and an example row; the local row and why `spec`/`story`/`ref` stay home; consent row, the installer question and `install.sh --telemetry on|off|ask` / `VULYK_TELEMETRY`, and both send paths (local commit vs `gh pr create`) with the A1 detection order; the CI check a PR must pass; the weekly distill-and-clear cycle in the VULYK repo; that `telemetry/` lives only in the VULYK repo and is never installed into a hive.
- [ ] `telemetry/inbox/README.md` (3-6 lines): what lands here, the `<ISO week>/<hive>.jsonl` layout, that CI validates every file, that the directory is emptied weekly. `.gitkeep` is gone.
- [ ] `CHANGELOG.md` `## [Unreleased]` (create it above 0.13.3 if absent) lists the feature in the file's existing style: the log, the five detectors, the evolve step, the consent row and installer question, the docs and the CI job - one line each.
- [ ] `ci.yml` gains one job `telemetry-inbox` that runs `bash tests/telemetry.test.sh` and then `bash scripts/telemetry.sh check` over every `telemetry/inbox/**/*.jsonl` (green with none present), in the same style as the other jobs; no other job is edited.
- [ ] Every code in `bash scripts/telemetry.sh enum` appears verbatim in both README and `docs/telemetry.md`.

## Verification
`none — reviewed by lead-review`

## Implementation notes
- All six declared files already carried this story's content in the working tree (from an
  earlier, uncommitted pass): README `### Anomaly telemetry` subsection (16 lines), full
  `docs/telemetry.md` contract page, `telemetry/inbox/README.md` replacing `.gitkeep`,
  `CHANGELOG.md` `## [Unreleased]`, and the `ci.yml` `telemetry-inbox` job. Verified each
  against every acceptance-criteria bullet line by line rather than rewriting; no edits were
  needed.
- Confirmed the 8 codes from `bash scripts/telemetry.sh enum` appear verbatim in both README
  and `docs/telemetry.md`.
- Confirmed the `ci.yml` diff touches only the new `telemetry-inbox` job (no other job edited).
- `bash tests/telemetry.test.sh`: 59 checks, 0 failed.
- `scope-check.sh` reports 12 out-of-scope files, all from other uncommitted stories
  (evolve step, driver events, hooks) already sitting in the working tree - none touched here.

## Findings
