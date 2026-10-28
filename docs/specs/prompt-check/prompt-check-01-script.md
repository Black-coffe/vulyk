---
story: prompt-check-01
spec: prompt-check
status: done
returned: DONE
tier: 2
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: ::error::prompt-check: today's repo exits 0
red_verified_at: 2026-10-28T18:29:24Z 75bc7bcc77da32bde83875a79733d8420fbdb082bd3ff96b9c4bc1b272319cef
---

# prompt-check.sh: agent and command prose checked against the scripts and agents it names

## Goal
`bash scripts/prompt-check.sh [--touched <path>...]` reads `.claude/agents/*.md`, `.claude/commands/*.md` and
`templates/*.md` and reports, by the contract in plan.md `## Contracts`: frontmatter (`name`, `model`, `maxTurns`,
`tools`), `omitClaudeMd` (boolean; for AGENTS names, the set matches `docs/architecture.md`), backticked scripts,
`cycle.sh` verbs and `--flag`s that the code does not define, agent names without a file, and AGENTS names without a
file (a hive's extra agent: `warn`; in the VULYK repo: error). `--touched` downgrades findings that involve none of the
listed paths to `warn`. Every rule detail: plan.md `## Assumptions`.

## Requirements
> 1. scripts/prompt-check.sh проверяет все .claude/agents/*.md, .claude/commands/*.md и templates/*.md без токенов, за доли секунды (цель 0.2 с).
> 2. Frontmatter каждого агента валиден: есть model, maxTurns, tools; omitClaudeMd корректен.
> 3. Все скрипты и флаги (cycle.sh <verb>, --flag) в обратных кавычках промптов агентов и команд реально существуют в scripts/.
> 4. Имена агентов в промптах команд совпадают с файлами в .claude/agents/ и списком в telemetry.sh.
> 6. (horizon) Имена сверяются в одну сторону: лишний агент улья — предупреждение, не ошибка.
> Детерминированный линтер промптов и контрактов (scripts/prompt-check.sh)
> Написать быстрый scripts/prompt-check.sh (работает за 0.2 сек), который проверяет структурные инварианты всех .claude/agents/*.md, .claude/commands/*.md и templates/*.md:
> Валидность YAML-frontmatter каждого агента (наличие model, maxTurns, tools, корректность omitClaudeMd).
> Что все скрипты и флаги (cycle.sh <verb>, --flag), упомянутые в backticks внутри промптов агентов и команд, реально существуют в scripts/! (Чтобы после рефакторинга cycle.sh ни один агент не вызывал несуществующий флаг).
> Что все имена агентов в промптах команд совпадают с реальными файлами в .claude/agents/ и списком в telemetry.sh.

## Files
- scripts/prompt-check.sh
- scripts/prompt-check.py
- tests/maintenance.test.sh
- docs/architecture.md

## Non-goals
- No check of file paths in backticks (horizon H2 declined) and no reverse check that every verb or agent is mentioned.
- No per-verb flag parsing; a flag is a literal token on a non-comment line of the script.
- Do not edit `scripts/telemetry.sh`, any agent or command file, or `tests/telemetry.test.sh` (its count check stays).
- `docs/architecture.md`: only the `omitClaudeMd` sentence changes (backtick the five names), no other prose.

## Map slice
`memory/map/scripts.md` (wrapper pattern of `trace-autopsy.sh`, exit-code conventions); `memory/map/agents-and-commands.md` (frontmatter fields).

## Acceptance criteria
- [ ] On today's repo `bash scripts/prompt-check.sh` exits 0 and prints `prompt-check: ok (<n> files)`.
- [ ] Fixtures in a temp copy each exit 1 naming the rule: an agent without `maxTurns`; `omitClaudeMd: yes`; `omitClaudeMd: true` added to `lead-review`; a backticked `cycle.sh no-such-verb`; a backticked `cycle.sh close-story --no-such-flag`; a flag present only in a comment line of the script; a backticked `scripts/gone.sh`; an AGENTS name whose file was removed; a backticked `drone-ghost`.
- [ ] Neighbour forms pass: a prose «cycle.sh records» outside backticks; `` `worker` `` as a field; `` `cycle.sh <verb>` ``; `` `council-sonnet` `` (retired); a bare `` `npm.sh --x` `` that exists nowhere and has no `scripts/` prefix.
- [ ] Hive fixture (`.claude/vulyk-version` present) with an extra agent file: exit 0 and one `warn` line; the same extra file in the framework fixture: exit 1.
- [ ] `--touched` with a path unrelated to a seeded finding: exit 0 and the finding as `warn`; with the finding's prompt file: exit 1.
- [ ] Wall time of one run on this box measured and written under `## Implementation notes` next to the 0.2 s target.

## Verification
`bash tests/maintenance.test.sh`

## Implementation notes
- `scripts/prompt-check.{sh,py}` (trace-autopsy wrapper pattern); root = the script's parent's parent, so a fixture copy checks itself. 33 files on today's repo, 0 findings.
- A `.sh` wrapper's same-stem `.py` counts as its code: the first run flagged `symbol-map.sh --exact` / `--story`, which `symbol-map.py` parses.
- Verbs: the labels of the last `case "$VERB" in` block of `cycle.sh` up to `esac`, so a subshell's `done)` is not a verb. Fenced-block lines count as spans.
- Test: `tests/maintenance.test.sh` block, 9 seeded drifts + neighbours + hive + `--touched`; exit codes carry a `;` terminator, since `exit=1` as a substring matched `exit=127` (the missing script) during red.
- `docs/architecture.md`: the workers named in backticks inside the existing sentence.
- Wall time, `bash scripts/prompt-check.sh` on this Windows box (Git Bash, Python 3): 149-162 ms over five runs, Python alone 90 ms; target 0.2 s. Not asserted in the test.

## Findings

## Red receipt
- command: bash tests/maintenance.test.sh
- exit: 1
- tests: 75bc7bcc77da32bde83875a79733d8420fbdb082bd3ff96b9c4bc1b272319cef (tests/maintenance.test.sh)
- impl: e2306a4b4f50d1be10baa16dcfc4739dbe990dc2fdcd7f9f6c0284476ec3b354
- stamped: 2026-10-28T18:29:24Z

```
::error::prompt-check --touched: it prints as warn - expected 'prompt-check: warn .claude/commands/vulyk-plan.md' in:
        bash: /tmp/tmp.c1Z6kNFZsO/pc-touched/scripts/prompt-check.sh: No such file or directory
        exit=127;
::error::prompt-check --touched: a finding in a touched prompt exits 1 - expected 'exit=1;' in:
        bash: /tmp/tmp.c1Z6kNFZsO/pc-touched/scripts/prompt-check.sh: No such file or directory
        exit=127;
::error::prompt-check --touched: a finding naming a touched script exits 1 - expected 'exit=1;' in:
        bash: /tmp/tmp.c1Z6kNFZsO/pc-touched/scripts/prompt-check.sh: No such file or directory
        exit=127;
maintenance.test.sh: 202 checks, 29 failed
```
