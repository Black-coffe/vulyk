---
story: model-profiles-01
spec: model-profiles
status: todo
returned:
tier: 3
worker: worker-code
model: opus # owner, 2026-10-18 approval: framework code this spec moves off Sonnet
wave: 1
blocked_by: []
---

# One file per machine names the profile, and the resolver tells each role its family

## Goal
`scripts/model-profile.sh` exists and follows the plan's `## Contracts`. It reads and writes the per-machine profile
file and prints the family for each role. It recommends a profile from the plan `top-model.sh --plan` reports, and it
explains who does what. `top-model.sh` gets `--plan`, and its gate and second reviewer honour the profile after the env
and constitution pins. With no profile file every output stays as today. `top-model-brief.sh` names the active profile
on its line. `tests/model-profile.test.sh` pins all of it. `CLAUDE.md` gets a one-line pointer to the profiles in
"Models and effort" and a `## Commands` row for the new test, paid for with trims so the file does not grow.

## Requirements
> и записываем где-то какой-то константой. Всегда, во всех сессиях, во всех обновлениях это распределение будет.
> 2. Вариант «Opus пишет, Fable судит»: главная сессия на Opus; Fable делает планы больших задач и архитектуру и проверяет весь код; Opus пишет новое и логику; Haiku пишет рутину и переиспользуемое.
> 3. Вариант «Как сейчас»: Sonnet пишет, Opus судит, Fable на воротах.
> 4. Экономный вариант: без Fable, Sonnet пишет, Haiku рутину, Opus судит.
> 5. Выбор лежит в одном файле на компьютере и переживает любые сессии и обновления; пока выбора нет, работает «как сейчас».
> 7. Подписка определяется сама; если не определилась, рекомендуется «как сейчас».

## Files
- scripts/model-profile.sh
- scripts/top-model.sh
- .claude/hooks/top-model-brief.sh
- tests/model-profile.test.sh
- tests/telemetry.test.sh
- CLAUDE.md

## Non-goals
- Do not copy plan detection into `model-profile.sh`. `--recommend` calls `top-model.sh --plan`.
- Do not parse the profile file in `top-model.sh`. Call `model-profile.sh` with no arguments.
- Do not rename or reorder any `--explain` label that `top-model-brief.sh` parses (`top model : `, `plan      : `,
  `second reviewer (Tier 4): `, `decided by: `, `queen session: pinned opus in `). Do not change `QUEEN` or `--apply`.
- No per-project override, no custom profile, no percentages, no env var that picks a profile.
- Do not touch `install.sh`. The new script ships through the `scripts` tree in `OWNED`, and nothing writes the profile
  file except `--set`.
- In `CLAUDE.md`, do not add a second `TOP_MODEL = ` line or move the existing one. Do not drop a Law, a rule or a
  `## Commands` row to pay for the bytes. Shorten pointers and wording only (for example the `Details:` list and the
  `(cache effects: ...)` aside). The line "Pass it as `model:` only on..." must stay true for `sonnet-builds` and point to
  the profile for the rest.

## Map slice
memory/map/scripts.md (`top-model.sh` entry, Key contracts); memory/map/agents-and-commands.md (agent frontmatter
models); docs/model-cascade.md (plan->gate table and second reviewer); tests/maintenance.test.sh lines 35-87 (the
constitution budget: CR not counted, the shipped render checked too)

## Acceptance criteria
- [ ] With `CLAUDE_CONFIG_DIR` pointed at an empty temp folder, `model-profile.sh` prints `sonnet-builds`, `--chosen`
      exits 1, and every `--role` prints the `sonnet-builds` column. `top-model.sh` and `top-model.sh --explain` print
      exactly what they print today. The test compares this with a run that has no profile machinery.
- [ ] After `--set opus-builds` and after `--set economy`, each role prints its column in the plan's role table.
      `top-model.sh` prints `fable` / `opus`, the second reviewer is `sonnet`, and `--explain` says
      `decided by: profile <name>`. A `VULYK_TOP_MODEL` pin and a constitution `TOP_MODEL` pin still win over the profile.
- [ ] `--set bogus` exits 2 and leaves the file unchanged. A file holding garbage reads as `sonnet-builds`, and
      `--chosen` exits 1 for it. A file holding `economy\r\n` reads as `economy`.
- [ ] `--recommend` prints `opus-builds <plan>` for a Max fixture and `sonnet-builds <plan>` for a Pro fixture and for a
      missing account file, with the plan fixture fed through `VULYK_CLAUDE_CONFIG`.
- [ ] The test proves `CLAUDE_CONFIG_DIR` is honoured, and that the `USERPROFILE` fallback works when `HOME` is unset.
      After `--set`, the test lists the temp HOME and the temp config folder and finds nothing new outside that folder.
- [ ] `top-model-brief.sh`'s line ends with ` · models <profile>`, and with ` (not chosen)` while no file exists.
- [ ] `CLAUDE.md` is no bigger in bytes than before (CR not counted), and `bash tests/maintenance.test.sh` passes. The
      new row reads `| Model profile tests | \`bash tests/model-profile.test.sh\` |`.

## Verification
`bash tests/model-profile.test.sh`
`bash tests/telemetry.test.sh`
`bash tests/maintenance.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes

## Findings
