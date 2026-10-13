# Brief: handoff-ownership

**Date:** 2026-10-13
**Tier:** 2 - one feature of one module (the session handoff: its command, its hook, and how the installer/upgrade hands it the project), no new architecture
**Source:** owner bug report with a screenshot, then a mid-turn feature ask in the same session; the mechanism was probed locally on Claude Code 2.1.296 (see `## Recon`)
**Escaped from:** none - both relative injections predate the spec system (`cf10a7c` v0.3.0 `handoff.sh dump`, `a3d824a` v0.9.1 `scripts/state.sh`)

## Request (verbatim)

> [Image #1] Пытаюсь сделать в проектах work handoff и получаю ошибки. Ты можешь разобраться, в чём проблема, почему так выходит и как это побороть?

The screenshot, as text:

> /vulyk-handoff
>   Shell command failed for pattern "!`bash scripts/state.sh`": [stderr]
>   bash: scripts/state.sh: No such file or directory
>
> /handoff

Sent mid-turn, same session:

> Нужно как-то решить. Смотри, если есть в проекте Handoff и в проекте есть Vultr Handoff, то и тот, и тот можно вызвать. А это конфликт. Нужно как-то на уровне Vultr пофиксить эту проблему, чтобы если в проекте доступен скилл Handoff, но он глобальный, например, на компьютере, и у пользователя есть, то в командах Handoff и в триггерах Handoff, когда пользователь говорит в вызове или «Запусти Handoff», должен работать только один — тот, который к Vultr имеет отношение. А тот другой должен вырезаться конкретно с этого проекта. То есть Vultr при инсталляции должен смотреть, если есть какой-либо Handoff, он предлагает его вырезать, удалить, отключить на этом конкретно проекте, и будет использоваться Handoff, который встроенный в Vultr.

("Vultr" is speech-to-text for VULYK.)

## Reproduction

Host `E:/Projects/AI`, sessions `465c0602` (2026-10-12 17:54Z) and `cf1d2449` (2026-10-13 13:14Z). Both
transcripts record the session `cwd` at the failing `/vulyk-handoff` as a subfolder of the hive
(`docs/specs/<client>/<folder>`, `docs/specs/<client>/<folder>`); each got
there through a Bash `cd <hive>/docs/specs/<client>/... && ...`. `scripts/state.sh` exists in that hive.

## Recon

- Claude Code keeps a Bash `cd` that stays inside the project and resets only one that leaves it
  (`Shell cwd was reset to ...`); the `cd <another project>/...` calls in the same session were reset, the
  `cd <hive>/docs/...` calls were kept.
- `.claude/commands/vulyk-handoff.md:9` `!`bash scripts/state.sh`` and `:13` `!`bash .claude/hooks/handoff.sh dump``
  run in that kept cwd. These are the only `!` injections in VULYK's commands.
- `scripts/state.sh:23` already finds its root with `git rev-parse --show-toplevel`; `handoff.sh:8` finds
  `handoff.py` by its own path. `handoff.py:84` `project_root()` reads `CLAUDE_PROJECT_DIR` (absent in an
  injection's environment), then the payload cwd, then `os.getcwd()`; in `dump` mode `:1000` sets the payload
  cwd to `os.getcwd()` and looks the transcript up by that slug - from a subfolder the handoff would land in
  `<subfolder>/.claude/handoff/` with no transcript.
- Claude Code substitutes `${CLAUDE_PROJECT_DIR}` in a command's body before the injections run and in its
  `allowed-tools`; it is the project root with forward slashes (`C:/...`), not the shell cwd. Probed
  headlessly: `!`bash "${CLAUDE_PROJECT_DIR}/scripts/state.sh"`` ran. Not probed: an interactive session
  with a drifted cwd (headless sessions never keep a `cd`), and the `allowed-tools` match outside bypass
  (headless injections were not permission-gated at all).
- A project `.claude/commands/handoff.md` does NOT shadow the user-level `~/.claude/commands/handoff.md`:
  `/handoff` still ran the user's one.
- `"skillOverrides": {"handoff": "off"}` in the project's `.claude/settings.local.json` (also in
  `.claude/settings.json`): `handoff` leaves the slash list, typed `/handoff` answers
  `Skill "handoff" is disabled via skillOverrides. Remove the override from your settings to run it.`,
  and "Запусти handoff" finds no such skill; `/vulyk-handoff` is untouched.
- User-level hooks cannot be switched off one by one per project. On this machine
  `~/.claude/settings.json` wires `context_guard.py` (stop, prompt, precompact, sessionend, sessionstart),
  which writes its own handoffs into the same `<project>/.claude/handoff/` and has per-folder
  "directions" (`subproject_globs`) that VULYK's `handoff.py` lacks; `E:/Projects/AI` uses them.
- `install.sh` already asks one consent question (telemetry, `:457-530`): through `/dev/tty`, a flag that
  wins (`--telemetry on|off|ask`), `--check` never asks or writes, no terminal = no question.
  `scripts/vulyk-update.sh:90` passes the flag through.
- Approved, not built: `constitution-merge` (2026-10-08) owns `install.sh`, `scripts/vulyk-update.sh`,
  `.claude/commands/vulyk-update.md` and `tests/telemetry.test.sh` in its stories.

## Answers

1. **Хуки** - Только сообщать (Рекомендую): Установщик находит такие хуки и пишет: «работает параллельно, вот чем выключить», но сам их не трогает. Почему: VULYK не может знать чужие инструменты, а в E:\Projects\AI context_guard нужен ради «направлений» (subproject_globs), которых у хендоффа VULYK нет.
2. **Где откл.** - Только эта машина (Рекомендую): Запись в .claude/settings.local.json: в git она не попадает, и отключается ровно то, что установщик нашёл на твоём компьютере. Почему: глобальный /handoff лежит в ~/.claude, а не в репозитории. На другой машине его может не быть или он будет называться иначе.
3. **Направления** - Сейчас беречь, потом научить (Рекомендую): В этой спеке установщик, увидев направления, предупреждает и по умолчанию глобальный не отключает. Обучение хендоффа VULYK направлениям идёт следующей отдельной спекой. Почему: в context_guard.py выбор направления — отдельная большая логика (подсчёт очков по файлам и алиасам, индекс на старте). Если затащить её сюда, исправление ошибки застрянет.
4. **Требования** - Да, показать план (Рекомендую): Пять строк приняты как есть, план покажу на одобрение.

Question 3 answers the owner's mid-grill message, verbatim:

> В проекте AI хендоффы разложены по направлениям (<client> и другие), а хендофф VULYK направлений не знает. Если отключить там глобальный, такая раскладка пропадёт.

## Asks

1. Пытаюсь сделать в проектах work handoff и получаю ошибки. Ты можешь разобраться, в чём проблема, почему так выходит и как это побороть?
2. в командах Handoff и в триггерах Handoff, когда пользователь говорит в вызове или «Запусти Handoff», должен работать только один — тот, который к Vultr имеет отношение.
3. А тот другой должен вырезаться конкретно с этого проекта.
4. Vultr при инсталляции должен смотреть, если есть какой-либо Handoff, он предлагает его вырезать, удалить, отключить на этом конкретно проекте, и будет использоваться Handoff, который встроенный в Vultr.
5. В проекте AI хендоффы разложены по направлениям (<client> и другие), а хендофф VULYK направлений не знает. Если отключить там глобальный, такая раскладка пропадёт.

## Plan review (2026-10-13)

The owner asked for an independent review of the plan by Fable 5.1, Opus 5.5 and Sonnet 5.5
(`plan-review/BRIEF.md`, `fable.md`, `opus.md`, `sonnet.md`). All three agreed with amendments; none refuted. Two
questions to the owner followed, answered:

1. **План** - Разделить и править (Рекомендую): ask 1 (the cwd bug) moves to its own Tier 1 spec `handoff-cwd`, built
   now and shipped as 0.26.1; this spec keeps asks 2-5 with the reviewers' amendments.
2. **context_guard** - Да, отдельно от VULYK (Рекомендую): the owner's `~/.claude/hooks/context_guard.py` learns to go
   quiet in a project whose settings switch `handoff` off - a change to the owner's own tool, not to VULYK.
