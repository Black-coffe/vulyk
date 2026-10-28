# Horizon - prompt-check

**Date:** 2026-10-28

## Terms and where they were searched

`prompt-check`, `prompt lint`, `static prompt`, `frontmatter valid` (plus `lint`, `flag.*exist`) in `memory/memory.md`,
`memory/map/`, `scripts/`, `tests/`, `.claude/hooks/`: zero hits on the capability (`lint` hits are commitlint /
lint-staged comments and a Profile fixture; `flag.*exist` is an unrelated council test). The step ran.

## Candidates

| Lens | Candidate | Verdict | Reason |
|---|---|---|---|
| altitude P1 | reverse direction: every `cycle.sh` verb and AGENTS name mentioned somewhere | dropped | not tied to the goal (a prompt calling a missing flag); verbs used only by the driver JS would be false orphans |
| altitude P2 | `--root`, framework vs hive mode | merged into H1 | same fix as depth P1 / range P2 |
| altitude P3 | replace the count check in `tests/telemetry.test.sh:236` | dropped | touches a round-only suite for no new protection; the linter's name check covers it |
| depth P1 | agent names compared as sets, one way | kept as H1 | |
| depth P2 | flag existence from case labels + mutation fixtures | dropped as a proposal | the parsing rule is an ordinary implementation question of the grill; failing fixtures come with `red: required` anyway |
| depth P3 | backticked paths exist; omitClaudeMd vs `docs/architecture.md:22` | paths kept as H2; omitClaudeMd moved to an ordinary question | a dry run today gives 5 false positives (`.claude/vulyk-origin`, `.claude/vulyk-setup`, `.claude/vulyk-version`, `tests/test_a.py`, `tests/test_resume.py`) |
| range P1 | scripts publish their own verbs/flags (`--list-verbs`) | dropped | edits every checked script; flags are parsed both by case labels and `[ "$a" = "--commit" ]` (`scripts/cycle.sh:3362`), a literal-token rule reaches the same guarantee |
| range P2 | frontmatter schema, one-way names, omitClaudeMd vs architecture.md | merged into H1 (names) and the omitClaudeMd question | |
| range P3 | one negative test per rule + a `## Commands` row | dropped as a proposal | negative fixtures are the `red: required` test; the row is a placement question (CLAUDE.md 7153/7168 B) |

## Kept

### H1 - agent names one way, hives stay green
- what: every name in `scripts/telemetry.sh` AGENTS must have a file in `.claude/agents/`, and every agent name a command
  or template mentions in backticks must have a file; a file absent from AGENTS is a warning in a hive and an error only in
  the VULYK repo itself.
- why: `install.sh` ships all of `scripts/` to hives, and ADR-005 lets a hive add its own agents; strict equality would
  turn the check red in every such hive, and it would be switched off there.
- cost: one branch (how the script tells the VULYK repo from a hive) and one hive fixture in the test.
- check: a hive fixture with an extra agent exits 0 with a warning; an AGENTS name with its file removed exits 1.
- sources: none: repo only · status: confirmed · kind: gap
- fragment: «работает мгновенно в CI и close-story» - close-story runs in hives too.
- ask line: Имена агентов сверяются в одну сторону: каждое имя из списка telemetry.sh и из промптов команд имеет файл в .claude/agents/; лишний агент улья - предупреждение, не ошибка.

### H2 - backticked paths exist
- what: a repo path in backticks (`docs/...`, `scripts/...`, `templates/...`, `.claude/...`, `tests/...`, `memory/...`)
  must exist; placeholders (`<slug>`, `*`) are skipped.
- why: the same drift class as a removed flag: a renamed file breaks a prompt silently.
- cost: an allowlist from day one: 5 false positives today (hive-only files and example names).
- check: a fixture with a renamed path exits 1; the repo with the allowlist exits 0.
- sources: none: repo only · status: confirmed · kind: extension
- ask line: (horizon) Пути к файлам репо в обратных кавычках промптов существуют (плейсхолдеры и короткий список исключений пропускаются).
