# Brief: drop-haiku

Date: 2026-11-09 · Tier: 3 (cross-cutting: agents, scripts, the Workflow driver, installer, tests, docs) · Status: brief only, grill and plan in a fresh session

## Request

> Вырежи с ВУЛИКА такое явление как ХАЙКУ вообще, он там не нужен вовсе

## Recon (2026-11-09, this session)

- Haiku runs as a model in three places: `cycle-clerk` (`model: haiku` in its frontmatter), the `routine` role of the model profiles (`scripts/model-profile.sh:72`: haiku in every profile except sonnet-builds) and the model floor (`scripts/lib.sh:387`, `haiku 5.5 cc>=2.1.293`).
- `council-haiku` is only a name: the black-box seat runs `model: opus` (`.claude/agents/council-haiku.md:6`). Its seat key `haiku` lives in `scripts/cycle.sh`, the council ledgers and `memory/stats/council.jsonl`, in this repo and in every hive.
- 45 live files mention Haiku (outside `docs/specs`, `docs/adr`, `CHANGELOG.md`, `memory/stats`); history (specs, ADRs, changelog) is a record and is not rewritten.
- Queued in the same files: the Fable 5.2 spec (floor `fable 5.2 cc>=2.1.321`, Fable plans Tier 1-2 too; owner's option label 2026-11-09). Both change `lib.sh` model_floor, `model-profile.sh`, `top-model.sh` and the ladder docs.

## Open for the grill

1. The black-box seat's name: rename `council-haiku` (and its seat key `haiku`, read-compatible with old ledgers in hives) or keep the name, as it runs on Opus already.
2. The clerk's model once Haiku is gone (default: Sonnet, "Sonnet executes").
3. Routine stories: fold into the ordinary worker (default) or route them to Sonnet.
4. Build it together with the Fable 5.2 spec (one change to the ladder, one release) or apart.
