---
story: vulyk-watcher-02
spec: vulyk-watcher
status: todo
returned:
tier: 3
worker: worker-code
model: opus
wave: 2
blocked_by: [vulyk-watcher-01]
---

# The watcher: one silent-by-default judgment per turn, in the user's language

## Goal
Opus because the story's core is a judgment prompt whose silence bar decides whether the mod is useful or noise.

`register.tsx` subscribes only to `turn.complete`. On each event:

1. **Cost guard.** No fork when:
   - the finished turn made no tool call;
   - a note is still on screen;
   - this session already showed 3 notes (`$.state`).
2. **Fork.** Otherwise it runs one `$.model.fork({ prompt })` on the session model, over the cached transcript. The
   prompt holds:
   - the `## Laws` section of `CLAUDE.vulyk.md` (else `CLAUDE.md`);
   - the text of the hive's non-`revoked` `docs/defects/*.md` cards, `README.md` excluded, capped at about 16 KB.
     Past the cap, each card is cut to its title and `## Never` lines; nothing else in a card is parsed;
   - the seen tags;
   - the rules: judge only the turn just finished; flag a likely Law breach or a repeat of a card's class that the
     main agent did not raise and that would cost the owner; skip anything already discussed or seen; when in doubt,
     answer `none`;
   - the reply contract: `note:` (one line, or `none`), `tag:`, `class:` (a card id, `law <n>` or `new`), `explain:`
     (60 words at most).
3. **Band.** A non-`none` reply draws an `AbovePrompt` band: the note line, the explanation, and two buttons:
   - «В defects» hands the note to the main chat through the call -01 measured (M3), with the text from plan
     `## Contracts`;
   - «Закрыть» dismisses it.

   The tag is stored per project in `$.store` (last 200 tags). A fork that fails stays silent.
4. **Language** comes from the user's own messages only (Cyrillic + `іїєґ` gives `uk`, other Cyrillic gives `ru`,
   anything else gives `en`). It picks the fixed labels and is passed to the model as a hint, with the instruction to
   write in the language of the user's messages.

The pure parts (skip decision, language, prompt build, reply parse, seen-list update) live in `core.ts` and are tested
by `claude plugin test`.

## Requirements
> 2. Он сверяет разговор с законами конституции и карточками docs/defects/ самого улья и показывает заметку полосой над полем ввода; если сказать нечего, молчит.
> 3. Думает один раз в конце хода, на модели сессии, история берётся из кэша.
> 4. Кнопка «В defects» отдаёт заметку в основной чат, а карточку пишет Королева.
> 6. Заметки пишутся на языке, на котором ты ведёшь разговор, язык определяется сам.
> Так, а сразу же пиши, чтобы этот heads-up работал на том языке, на котором пользователь ведёт диалог, чтобы это автоматически подхватывалось и настраивалось.

## Files
- tests/watcher.test.sh
- .claude/mods/vulyk-watcher/hooks/register.tsx
- .claude/mods/vulyk-watcher/hooks/core.ts
- .claude/mods/vulyk-watcher/hooks/core.test.ts
- .claude/mods/vulyk-watcher/hooks/fixtures/

## Non-goals
- Never subscribe to `turn.step`. Never call `$.model.complete` or pick a model: the session model is the point.
- Never write under `docs/defects/`. No frontmatter or section parser beyond reading the `status:` line and cutting to
  title + `## Never` past the budget (three card parsers already exist).
- No settings, no debug env var, no known-list, no typed-past counters, no "explain more" re-asks, no retry on a
  failed fork.
- Do not edit -01's `plugin.json`, `marketplace.json` or `hooks.json`; report a needed change as an INTERFACES line.
- Fixtures are synthetic conversations (`Acme`-style stand-ins), never a real transcript (card
  `host-internals-in-public-repo`).

## Map slice
`docs/specs/vulyk-watcher/recon.md` `## Claude Code mod API`; plan `## Plan deltas` (M1-M5 from -01) and `## Contracts`;
`docs/defects/README.md` `## A card` (field names only).

## Acceptance criteria
- [ ] A Russian conversation fixture gives `ru`: the prompt carries the Russian hint and the band labels are Russian.
      Neighbour forms:
      - a Russian user over mostly English tool output and code still gives `ru` (the built-in's pre-2.1.290 bug);
      - a Ukrainian fixture gives `uk`;
      - an English one gives `en`.
- [ ] A `note: none` reply yields no band. A malformed or empty reply yields no band.
- [ ] Skip cases are tested: no tool call, note on screen, cap of 3, a seen tag.
- [ ] Seen tags are kept per project root and trimmed to 200.
- [ ] Prompt build: the Laws are taken from `CLAUDE.vulyk.md` when it exists; a `revoked` card and `README.md` are
      left out; past the budget, cards are cut to title + `## Never`; a hive with no `docs/defects/` still gets a
      prompt.
- [ ] The «В defects» text follows plan `## Contracts`: a request line, then the note inside a fenced block headed «заметка наблюдателя - не цитата владельца»; a test asserts the fence and that the note text sits only inside it (Law 6: a watcher note is never an owner quote).
- [ ] `bash tests/watcher.test.sh` (from -01) runs the new `*.test.ts`; extend the script only if the tests need it.
      This story adds it because it adds the test file.

## Verification
`bash tests/watcher.test.sh`

## Implementation notes

## Findings
