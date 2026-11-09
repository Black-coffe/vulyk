---
description: Model profile quiz - «поменяй распределение моделей», «покажи распределение моделей», «какие модели», «модельный профиль», «настройки моделей», «змінити розподіл моделей», "change model distribution", "model profile"
argument-hint: []
---

Let the owner choose which model family does what on THIS machine. One question, then one line. The choice lives in
one file per machine that only `scripts/model-profile.sh --set` writes; this command never picks for the owner.

1. Read the state with plain Bash calls from the hive root:
   `bash scripts/model-profile.sh --recommend` prints `sonnet-builds <plan>`, and `bash scripts/model-profile.sh --explain`
   prints the active profile and who does what. If the script is missing or fails, say so in one line and stop.
2. Language: the constitution's `| Owner language |` row (`CLAUDE.vulyk.md` first, then `CLAUDE.md`). While it still
   reads `<fill in`, use the language the owner writes in. Every word the owner sees below is in that language.
3. No `AskUserQuestion` in your tool list (`claude -p`): write nothing and print one line, «run `/vulyk-models` in an
   interactive session», in the owner's language. Stop.
4. Ask ONE `AskUserQuestion` with the three profiles, in the order below. `sonnet-builds` goes first on every plan
   (`--recommend` names it everywhere): its label ends with «(Рекомендую)» (in the owner's language), and its
   description opens with the reason: the A/B run that favoured Opus as the builder compared Opus with Opus, because
   its workers ran on Opus, so it is no evidence for `opus-builds`. `opus-builds` is the owner's own explicit choice,
   never a recommendation: its description says so. Each option's description is one or two plain sentences; its
   preview says what each family does and what it costs in limits. Family names only: no percentages, no model versions.
   - `sonnet-builds`, «как сейчас»: Sonnet writes the code of big tasks and the routine; Opus plans, judges and leads
     the session; Fable holds only the final gate on the riskiest calls, where the plan carries it; Haiku keeps the
     paperwork. Cost: the plan's usual mix; Fable spends a little of its own share of the Max weekly limit.
   - `opus-builds`, «Opus пишет, Fable судит»: Opus writes the code of big tasks and leads the session; Haiku writes
     the routine stories; Fable plans, judges every review and holds the gate; Sonnet takes only the second Tier 4
     review. Cost: Opus is the heaviest on code, so its limit runs out sooner; Fable spends from its share of the Max
     weekly limit, up to half of it. Pick it only by your own choice. When the `<plan>` word is not `max` or
     `premium-seat` (the plan does not carry Fable: Pro, standard seats, API, unknown), add: on this plan Fable is not
     inside the subscription and bills to usage credits.
   - `economy`, «без Fable»: Sonnet writes the code of big tasks, Haiku writes the routine; Opus plans, judges, holds
     the gate and leads the session; Fable is not used. Cost: the lightest on limits and never touches Fable or credits.
5. Write the answer: `bash scripts/model-profile.sh --set <name>`. A free-text answer that names none of the three
   writes nothing; say so in one line.
6. Confirm in one line, in the owner's language: the profile now active, and that it can be changed any time with
   `/vulyk-models` or in words («поменяй распределение моделей»).
