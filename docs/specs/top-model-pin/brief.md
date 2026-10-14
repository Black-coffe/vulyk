# Brief: top-model-pin

**Date:** 2026-10-14
**Tier:** 1 - one module (the gate-model resolver `scripts/top-model.sh` and its tests), a clear bug fix
**Source:** found 2026-10-14 while settling the owner's open questions on five finished hives, with a second opinion
from Fable 5.1 that the owner asked for
**Escaped from:** none - `constitution_pin()` reads only the first existing file since v0.10.0 (`020ec10`, the
resolver's birth); `--floor` (v0.20.0) never looked at the resolved gate model

## Request (verbatim)

The owner, 2026-10-14, answering five recommendations (one of them: keep `TOP_MODEL = auto` in the merged hive
constitutions):

> «1-5 как рекомендуешь Но с советом фейбл 5.1 и тебя

The owner, 2026-10-14, on the plan's first cut (the fix alone would leave that hive on the dead model):

> Исправление выбора модели в VULYK до <hive> само не дойдёт: модель для самых важных проверок там так и останется старой claude-opus-4-8.

## Reproduction

A sidecar hive (the project keeps its own `CLAUDE.md`; VULYK's constitution is `CLAUDE.vulyk.md` beside it). The
constitution says `TOP_MODEL = auto`. The project's `CLAUDE.md` carries a July Profile note in prose:

> - **Budget posture:** BALANCED (cap ~4 parallel workers). `TOP_MODEL = claude-opus-4-8` (per constitution).

```
$ bash scripts/top-model.sh --explain
top model : claude-opus-4-8 (claude-opus-4-8)
decided by: constitution - CLAUDE.md pins TOP_MODEL = claude-opus-4-8
$ bash scripts/top-model.sh --floor
model floor: fable>=5.1 opus>=5.5 sonnet>=5.5 haiku>=5.5 - ok
```

Every gate dispatch there (the Tier 4 lead-review, lead-architect, the Tier 4 planner, a missed story's retry) would
carry `model: claude-opus-4-8`, below the opus floor 5.5, while the session brief said "floor ok". A second hive (a
clone of the same project) resolves the same way today.

## Recon

- `scripts/top-model.sh:118-128` `constitution_pin()`: loops over `CLAUDE.md`, `CLAUDE.vulyk.md`, but `return`s after
  the first file that exists, so a sidecar hive's `CLAUDE.vulyk.md` is never read; the first regex hit anywhere in that
  file wins, prose included.
- `scripts/top-model.sh` `floor` mode feeds `below()` env variables, three settings files and frontmatter `model:`
  lines; never the resolved `$MODEL` (constitution pin or `VULYK_TOP_MODEL`). `model_below_floor claude-opus-4-8` itself
  classifies correctly (`opus 4.8 5.5`).
- The same file is byte-identical in the release clone, VULYK HEAD and every hive (Fable's md5 check).
- Survey of all 25 hives on this machine (2026-10-14): reading `CLAUDE.vulyk.md` when it exists changes the resolved
  gate in exactly one hive (the clone above: `claude-opus-4-8` -> its constitution's `opus`); every other hive resolves
  as today (`fable` by plan, or one explicit at-floor full-ID pin kept in both files).
- A project section in one hive tells its readers to pin in `CLAUDE.md` because the resolver "stops at CLAUDE.md"; no
  hive actually pins there today (survey), so nothing relies on the bug.
- Docs naming the pin's home: `docs/model-cascade.md:21,64`; the resolver's own header `scripts/top-model.sh:30-35`.

## Asks

1. `constitution_pin()` reads the constitution: `CLAUDE.vulyk.md` when it exists, else `CLAUDE.md`; a project's own
   `CLAUDE.md` beside a sidecar constitution is never read for the pin.
2. `--floor` judges the resolved gate model too (a constitution pin or `VULYK_TOP_MODEL` below the floor fails it).
3. Tests in `tests/telemetry.test.sh`: the original case (prose pin in `CLAUDE.md` + `auto` in `CLAUDE.vulyk.md` ->
   decided by plan), the neighbour (`CLAUDE.vulyk.md` pins a below-floor ID -> `--floor` exit 1 naming it), a sidecar
   pin honoured (today ignored), a single-file hive still pinned from `CLAUDE.md`.
4. The owner's correction above joins `docs/defects/` (Law 6) as a text card, and the affected hive loses its
   triggering line now, not at its next upgrade.
