# ADR-021: The defect library becomes the project's rules tree (Нельзя / Можно / Как надо)

- Status: accepted (2026-10-19, owner: Andrei - plan stop of spec `rules-tree`, «Да, утверждаю», release 0.32.0)
- Date: 2026-10-19
- Spec: docs/specs/rules-tree
- Evidence: brief `docs/specs/rules-tree/brief.md` (request verbatim, Asks 1-12); supergrill
  `docs/grill/2026-10-19-rules-tree.md` (D1-D15, contradiction log, rejected alternatives, AskUserQuestion hook
  probe 2026-10-19); scouts `scout-machinery.md`, `scout-distribution.md`.
- Amends: ADR-014 (D1, D5, D6, one rejected option), ADR-019 (one invariant), ADR-018 (two new findings).
  Revisits A13/D12 of `docs/grill/2026-09-27-self-learning-corrections.md`; executes its D6/D14 (tree in git, rules shrink).

## Context

The owner saw the same task done differently three days after "можно / нельзя" had been said in the same hive. The
lesson was in private auto memory: its index line was in context, the topic file was never opened before the action.
Three capture channels are blind today: pasted text (voice dictation arrives as `<pasted_content>` and is stripped),
answers in question windows (tool results, not seen by UserPromptSubmit), and model text without a tag (intake fired
on a side-agent note). A sample of 36 private feedback memories: ~60% project rules "how to", ~22% duplicates of
VULYK cards, ~14% personal; almost no verbatim owner words. ADR-014 D12/A13 (27.09) left no place for a positive
"this is allowed here" record, so the agent re-asks what was already allowed. The crossgrill (Fable, Opus, Sonnet,
3/3): no second library; extend `docs/defects/`.

## Options

1. A new rules library next to `docs/defects/` (three folders by branch). Rejected 3/3: a second library, and a
   class and its quotes torn across three files.
2. Keep ADR-014 as is: only prohibitions, "allowed" = a revoked prohibition (A13). Rejected by the owner (Q5):
   an allowance has no scope and no words of its own, so it cannot be delivered where the agent hesitates.
3. Extend `docs/defects/`: cards in area folders, three sections per card, scope = paths + commands + tools,
   generated index, scoped prose delivery for «Можно» / «Как надо», gate unchanged for «Нельзя». Chosen: one
   library, one gate, the cheapest undo (sub-folders and sections are additive; a host with flat cards stays valid).

## Decision

### Amendments to ADR-014

1. **D1 (card).** A card may hold three branches as sections: `## Нельзя` / `## Never`, `## Можно` / `## Allowed`,
   `## Как надо` / `## How-to`. The branch of a card is derived from the sections it has; there is no `kind:` field.
   A «Можно» is a standalone record: its own card with its own `paths:` and verbatim owner words with a date. It cuts
   an exception from a prohibition only by `exception: <id>` (D3 of the grill). Cards live in area sub-folders
   `docs/defects/<area>/<id>.md`; root-level cards stay valid (area `general`).
2. **D5 (intake reads only the human) → reads the human across channels.** Typed text as today. Pasted content:
   only through the explicit phrase or after the owner's typed "yes". Question-window answers: a PostToolUse hook on
   `AskUserQuestion`; text the owner typed is a quote, a picked option is a decision, never a quote. Side-agent notes:
   never. Detection stays deterministic (table below); ADR-014's rejection of an LLM classifier stands.
3. **D6 (delivery).** `defects-inject.sh` pushes the Never, How-to and Allowed lines of matching `text` cards,
   budget ~12 lines per action: narrowest scope first, then the freshest quote; the rest as one line
   «ещё N карточек: id, id». Scope gains `tool:<regex>`; the hook matcher widens to every tool. Block cards are still
   not injected. Re-injection after compaction and clear is unchanged.
4. **Rejected "lesson tree with counters and escalation" stays rejected.** This is not that tree: the axis is the
   project's areas, not a ladder; the only counter is on «Можно» (owner quote lines on a permission card), it is
   shown in the index and `/vulyk-status` and never changes delivery or status. Repeats of «Нельзя» and «Как надо»
   go through the one existing mechanism: debt, red until a check.
5. **A13/D12 (27.09) revisited by the owner on 2026-10-19 (Q5).** "Allowed = revoked prohibition" is withdrawn.
   `status: revoked` remains the way to lift a prohibition; a «Можно» is a positive record, not a revocation.

### Amendment to ADR-019

6. The invariant "a new lesson source is adopted as a check, not as injected prose" is narrowed: «Можно» and
   «Как надо» lines are delivered as path/command/tool-scoped prose under the 12-line budget, because an allowance
   has nothing for a check to fail on, and a how-to becomes a check the moment it repeats. The debt gate still demands
   a failing `check:` for a repeated «Нельзя» or «Как надо» (two or more quotes, new by blame). A repeated «Можно» is
   counted, never red. Every other ADR-019 invariant is kept verbatim: no daemon, database, vectors, graph or
   per-prompt recall; no self-rewriting CLAUDE.md; no memory bank shared across projects; no LLM classifier.

### Amendment to ADR-018 (two new red findings and their new/old cut)

7. **Conflict** (a «Можно» scope overlaps a «Нельзя» scope and the permission card has no `exception:` naming that
   prohibition): red for new material only, by blame against the README add-commit, like Overlap: new = the newer of
   the two `paths:` lines; uncommitted = new; older = one `I` line. At delivery the prohibition always wins regardless
   of age: the unlinked «Можно» lines are not injected. Reason: hives already carry `## Allowed` sections, and an
   upgrade must not turn `lead-review` red over them.
8. **Index drift** (`INDEX.md` disagrees with the cards): an explicit exception, red from day one when the index
   file exists, like C11 Escape, because it compares two things inside the library and a stale index is by
   construction newer than the README commit. A missing index is an `I` line («run the generator»), never red, so an
   upgraded hive stays green until its first generation.
9. **Exception without proof**: a card with `exception: <id>` whose referenced card has a `check:` must list
   `passes:` files, and that check must exit 0 on each. Cut on the `exception:` line by blame, as in 7.

### Data contract

10. **Card** `docs/defects/<area>/<id>.md`. Frontmatter (plain `key: value`): `id` (file stem, unique across the
    whole library; a collision is a parse error `E`), `title`, `status: block | text | revoked`, `check`, `fixtures`
    (must fail), `keys`, `paths`, new `exception: <id>` (the prohibition this permission cuts), new `passes: [...]`
    (files the referenced card's check must exit 0 on). Sections, EN or RU heading, first match wins:
    `## Owner quotes` / `## Цитаты владельца`, `## Cause` / `## Причина`, `## Never` / `## Нельзя`,
    `## Allowed` / `## Можно`, `## How-to` / `## Как надо`, `## Revoked` / `## Отозвано`. A quote line is
    `- YYYY-MM-DD · material · place — «words»` and may cite a litopys session as its place. Only verbatim owner
    words go under `## Owner quotes`; a picked option («chose X on Y») and a memory retold on migration («из памяти,
    пересказ») are written under `## Cause` or `## Как надо`, never in «».
11. **Scope** (`paths:`): path glob from the repo root (`**` allowed; a glob without `/` matches the basename),
    `cmd:<regex>` against the Bash command line, `tool:<regex>` against the tool name (e.g. `tool:^(WebFetch|mcp__)`).
    A card with only `tool:` scope is deliverable. Narrowness for ordering = count of literal (non-wildcard)
    characters in the matched entry; ties by freshest quote.
12. **Index**: `docs/defects/INDEX.md`, generated by `scripts/defects-index.sh`: three tables (запреты / разрешения
    / правила) by area, with the «Можно» counter. Never `README.md`: install.sh ships that file as the format
    contract and never updates it on hosts. Search: `bash scripts/defects-index.sh --grep <words>`.
13. **Path-less rules**: `.claude/rules/always.md`, no `paths:` frontmatter, loaded every session, capped at 40
    lines; the gate reports the cap as red (file-size check, not a card finding), and other files still in
    `.claude/rules/` as one `I` line (not yet migrated into cards).

### Channel table (deterministic, no classifier)

| Channel | Owner words? | Detected how |
|---|---|---|
| Typed prompt text | yes | UserPromptSubmit `prompt` after the BLOCKS strip (as today) |
| Pasted content | after the explicit phrase, or after a typed «да / так / yes» to one one-line question | `<pasted_content>` block; phrase regex RU/UK/EN «внеси в (запрет\|правило\|разрешение)» scanned on the raw prompt before stripping; optional per-user dictation marker (settings.local.json, not shipped) reads a paste that starts with it as typed |
| Question window | typed part only | PostToolUse, matcher `AskUserQuestion`: an answer part string-equal to an option label of `tool_input` = decision; any other part = quote |
| Side-agent note | never | «Here is a note offered by a side agent» joins the BLOCKS strip; a repeat lexicon inside it does not fire |
| Model text | never | reaches no hook input field that is read; card `owner-words-by-builder` governs the session |

## Consequences

Easier: one library, one gate, one hook family; a hive with flat cards and `## Allowed` sections is valid unchanged.
Harder: three loaders (inject, intake, check) learn sub-folders and `tool:`; `lead-review` sees two new findings;
the installer wires one new hook; the constitution pays its new line by trimming Law 6. Accepted debt: `passes:`
fixtures double the fixture vocabulary; the «Можно» counter is self-reported through quote lines. Follow-ups, not
in this ADR: the `/vulyk-gc` migration mode (D13), the pilot on two hives (D15), a small litopys spec for the shared
vocabulary (Answer 1).

## Invariants created

- A card's branch is its sections; no `kind:` field. A «Можно» without `paths:` is undeliverable.
- A «Можно» overrides a «Нельзя» only through `exception: <id>`; an unlinked overlap delivers the prohibition.
- Debt (red) counts only cards with `## Нельзя` or `## Как надо`; a «Можно» repeat is a counter, never red.
- Delivery per action is ≤ 12 lines, narrowest scope first; block cards are never injected.
- `docs/defects/INDEX.md` is generated, never hand-edited; `README.md` stays the shipped format contract.
- `.claude/rules/always.md` is the only path-less rules file and is ≤ 40 lines.
- Only verbatim owner words stand in «»; a picked option, a side-agent note, model text and a retold memory never do.
- Every new red finding keeps the ADR-018 cut; the only day-one reds are Escape and Index drift.

## Revisit when

Measured on the two pilot hives, 4 weeks after migration, against the 4 weeks before: repeats of filed classes per
month = new quote lines on existing «Нельзя» / «Как надо» text cards (quote-line blame) plus litopys
`corrections --lexicon` hits that map to an existing card. Reopen if that number is not below half the baseline,
if any «Можно» card reaches 3 quote lines (the agent still re-asks the allowed), or if the overflow line «ещё N
карточек» appears in more than one action in five (the 12-line budget starves delivery).

## Amendment 2026-10-28: story-read delivery and native auto memory (status: accepted)

- Status: accepted (2026-10-28, owner: Andrei - chose the Queen's option «Принять как есть (Рекомендую)»; harvested
  from spec `auto-memory-subagent-start`, release 0.41.0, D15 revised in 0.41.1)
- Evidence: `docs/specs/auto-memory-subagent-start/brief.md` (Recon facts, Answers 1-3),
  `docs/specs/auto-memory-subagent-start/plan.md` (Goal, Assumptions, Plan deltas).

### Context

Brief, Recon facts: "`SubagentStart` input is the common fields plus `agent_id` and `agent_type`, no prompt";
"Workflow-driver agents are not `Agent` calls in the parent transcript (`subagents/workflows/<run>/`); whether
`SubagentStart` fires for them is not checked." Plan delta, 2026-10-28: "Personal rules stay in `MEMORY.md` after a
triage, so a file still over the threshold would make triage due after every task. The owner chose «Молчать до роста
(Рекомендую)» [...] Rejected: a Profile decline row, which would also silence a real overflow later; shipping
without it."

### Options

1. Deliver cards on `SubagentStart`, filtered by the worker's story `## Files` (the owner's request). Rejected: the
   input has no prompt, so the story is unknown; Workflow workers, the main target, are not `Agent` calls to look up.
2. Deliver cards on a `Read` of a story file (Answer 1). Chosen: works for any executor (Workflow worker, subagent,
   the Queen on Tier 1-2); cost is a bash path check on every Read.
3. Native auto memory: set `autoMemoryEnabled: false`, or only document the switch (Answer 3). Chosen: document only.
   Reasons as the grill question put them (the Queen's wording, not an owner quote): with auto memory off, the
   owner's personal rules, about 40 here plus whatever their global `CLAUDE.md` sends there, stop loading, and no
   card replaces them. The owner's standing rule is to offer, never to switch on for them. VULYK is public, so other
   owners keep personal memory too.
4. Triage signal after a triage: always fire, a Profile decline row, or quiet until growth. Chosen: quiet until growth.

### Decision

14. **D6 extended (delivery trigger).** Besides PreToolUse on the acting tool, `defects-inject.sh` fires on `Read` of
    a story file (`docs/specs/<slug>/<name>.md` with `story:` frontmatter) and shows the cards whose `paths:` match
    the story's `## Files`; `cmd:`/`tool:`-only cards do not fire on a Read. The per-agent dedup (`agent_id` + card
    ref) is shared, so a card shown at the read is not repeated at the first edit. `SubagentStart` is not used for
    card delivery.
15. **Native auto memory.** VULYK never sets `autoMemoryEnabled` nor `CLAUDE_CODE_DISABLE_AUTO_MEMORY`; the docs say
    how to turn it off and what is lost. VULYK only signals: the SessionStart brief offers `memory triage` when
    `MEMORY.md` reaches 160 lines or 20480 bytes (80% of Claude Code's 200 lines / 25 KB load limit), and after a
    triage stays quiet until the file grows by 20 lines or 2 KB more. Since 0.41.1 (spec `memory-triage-offer`,
    owner: «Хотфикс 0.41.1: только предлагать (Рекомендую)») the offer has its own line, outside `maintenance due`:
    the triage reads every private memory file, so the owner is asked first, and a no leaves the mark too.

### Invariants created

- Card delivery never depends on a hook input that carries no story; the story is learned from the file the agent reads.
- Spec files other than story files (`brief.md`, `plan.md`) deliver no cards.
- VULYK writes no setting that turns native auto memory off; the owner does.
- The memory-size signal is size-triggered and growth-gated after a triage; no decline row silences it.

### Consequences

Easier: cards reach Workflow workers before their first edit. Harder: every Read starts the bash wrapper (cost
measured in story 01). A custom `autoMemoryDirectory` is not followed (plan Assumptions). Other consequences not recorded.

### Revisit when

`SubagentStart` input gains the prompt or a story reference, or is shown to fire for Workflow-driver agents with an
identifiable story; otherwise not recorded.
