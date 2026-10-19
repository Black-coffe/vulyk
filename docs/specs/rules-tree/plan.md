# The defect library becomes the project's rules tree (plan)

**Tier:** 4 · **Spec slug:** `rules-tree` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-021 (`docs/adr/021-rules-tree.md`, written in parallel by `lead-architect`; amends ADR-014 D1/D6/
"rejected: a lesson tree", ADR-018 new/old findings, ADR-019 "a lesson is a check, not prose"); ADR-016 (constitution
byte budget, `tests/maintenance.test.sh`); ADR-005 upgrade contract (release copies replaced, host edits merged); owner
rules "upgrade keeps host framework edits", "no client data in the public VULYK repo", "offer, never auto-enable";
grill `docs/grill/2026-10-19-rules-tree.md` D1-D15.
**Depends on:** v0.30.0 (`884541f`); scout reports `scout-machinery.md`, `scout-distribution.md` in this folder.

## Goal
No second library. `docs/defects/` grows into the project's rules tree: cards may live in one level of area folders
(a root card is area `general`, so every library in every hive stays valid), and a card carries three branches as
sections: Never (today's `## Never`), Allowed (a dated line in the owner's words, overriding a Never only through an
explicit `exception:` link proven by a fixture the Never check passes) and How-to (the project's "this is how", today
scattered over private memory and path rules). Scope stays in `paths:` and gains `tool:<regex>` beside globs and
`cmd:`. The three loaders (inject, intake, gate) read one shared parser so no loader is blind to a sub-folder. The
inject hook delivers at most ~12 lines per action, narrowest scope first, then freshest quote, and lists the rest in one
line. The gate stays red for a repeated Never/How-to without a check, turns a repeated Allowed into a counter (index and
`/vulyk-status`), goes red on an Allowed/Never overlap without a link and on a stale generated index. Capture hears the
owner in every channel: an explicit «внеси в запрет / правило / разрешение» (RU/UK/EN) anywhere, including pastes, is an
order to write the card now; an auto-found correction in typed text is filed at once with a report line and «отмени»;
one inside a paste is a quote only after the owner's yes (an optional dictation tag skips the question); an
AskUserQuestion answer is heard by a PostToolUse mode of the intake hook (typed text = quote, a chosen option =
decision); a side-agent note is never the owner's words. Rules bound to no file live in one always-loaded
`.claude/rules/always.md` of at most 40 lines. One constitution line sends project lessons to `docs/defects/` and
leaves auto-memory for the personal; Law 6 names the three branches and is paid for by trims. `/vulyk-gc memory` is the
one-off triage of private memory into cards / personal / delete, approved as one list, retold and never quoted.

## Assumptions
- **ADR-021 lands after this plan.** The `## Contracts` below are the planner's concrete proposal for the card data
  contract, the scope syntax, the section headings, the index file name (`docs/defects/INDEX.md`, not `README.md`:
  the README ships and would collide) and the channel table. The Queen reconciles the contracts with ADR-021 before
  wave 1 is dispatched; a worker follows the contracts in this file.
- **One shared parser is the simplest thing.** Today's parser is duplicated three times (inject/intake "kept identical"
  block, the gate's own). Sub-folders, three sections in three languages, `tool:` scopes and `exception:` links would
  have to be written three times otherwise. `.claude/hooks/defects_lib.py` is shipped and synced by `install.sh`
  (`.claude/hooks` is OWNED) and covered by the `py_compile .claude/hooks/*.py` row; the gate imports it relative to
  its own location, never relative to `DEFECTS_DIR`. Not a speculative abstraction: it removes duplication.
- **`paths:` keeps its name.** No `scope:` rename: every existing card in every hive stays valid without an edit. The
  key now also holds `tool:<regex>` entries.
- **VULYK's own twelve cards stay flat.** Root = area `general`; the migration into area folders is not cheap enough to
  earn a story (git history, blame cut, README links) and buys nothing for this repo. A hive moves cards when its
  library grows.
- **`bash tests/constitution.test.sh` does not exist** although `## Commands` lists it ("Merge tests"). No story uses
  it. Story 02 proposes deleting that dead row as its first byte trim; the owner can veto at approval.
- **The shipped constitution render.** `tests/maintenance.test.sh` checks the shipped render (`:84-88`). Story 02
  lists `install.sh` in case `render_constitution` (`:329`) carries its own copy of the Laws; if the render is produced
  from `CLAUDE.md`, the worker touches nothing there. Recon question 2 below settles it before dispatch.
- **Hook messages stay in the hooks' current language (English, with the owner's own words untouched).** The report
  line a session prints after filing («записал в … → карточка X; скажи отмени, если не так») is in the owner language
  of the constitution Profile; the hook only instructs the session.
- **The dictation tag is an environment variable** (`VULYK_DICTATION_TAG`, set per project in
  `.claude/settings.json` `env` or in the shell), not a new config file. Unset = a paste always gets the one-line
  question. Fewer files; the owner sets it once.
- **The PreToolUse matcher widens to** `Edit|Write|MultiEdit|NotebookEdit|Bash|WebFetch|WebSearch|Agent|mcp__.*`, not
  to `.*`: Read/Grep/Glob calls pay no python start-up. `install.sh` unwires the old wiring and rewires with the new
  matcher (`py_wire` ignores a changed matcher today, `install.sh:683-686`).
- **A side-agent note is stripped, not fixtured into a card.** No owner quote exists for ask 10 (it came from a
  side-agent note the owner confirmed), so no card gets a fabricated quote; the original case (today's two «опять»
  misfires) and a neighbour form are test cases in `tests/intake.test.sh`.
- **The installer wiring case lives in `tests/intake.test.sh`** (a scratch hive upgraded by `install.sh --upgrade`,
  then a `jq` assertion on the matcher and the PostToolUse block). No suite is known to exercise `install.sh` wiring;
  recon question 1 may move it.
- **No `model: haiku` story.** The brief says `routine stories: model: haiku`; none of the six is routine: each adds a
  branch or a parser with judgment attached, and the two small routine pieces (CHANGELOG, ADR amendment lines) are
  folded into story 06 rather than paying a worker.
- **UK section headings** are `## Не можна`, `## Можна`, `## Як треба`; ADR-021 may rename them, the parser keeps all
  three languages as aliases.
- Out of scope, no stories: litopys changes (a separate spec in the litopys repo, after this one, on the shared
  vocabulary and the paste/window rules); the owner's global `~/.claude/CLAUDE.md` edit (the Queen, after the owner's
  yes, outside the repo); the pilot on two hives and the rollout to live hives (release work after `/vulyk-ship`); the
  weekly litopys-based catch-up in `/vulyk-evolve` (already prints the corrections counter).
- The release number and `VERSION` stay with `/vulyk-ship`; story 06 writes the CHANGELOG entry under `[Unreleased]`.

- Recon answers (Queen, 2026-10-19, read in install.sh): the shipped render takes its Laws from `$SRC/CLAUDE.md`
  (`install.sh` ~:329-345), so story 02 needs no `install.sh` edit unless a placeholder moves; `unwire_hook <event>
  <script>` (:925) removes by event + script name regardless of matcher, so story 05's unwire+rewire of the inject
  matcher works; the only suite that drives `install.sh --upgrade` today is `tests/telemetry.test.sh` — story 05 may put
  its wiring case there instead of `tests/intake.test.sh` (worker's call, report it in INTERFACES).
- Contract names follow ADR-021 (reconciled by the Queen before approval): `exception: <ref>` frontmatter key on a
  permissive card (not a per-line suffix), `.claude/rules/always.md` (not `general.md`), `EXCEPTION` takes the blame
  cut on the `exception:` line (ADR-021 D9).

- Coverage (drone-coverage, 2026-10-19), carried forward for the owner's veto:
  - Ask 1: area folders are supported by every loader; VULYK's own 12 cards stay flat (root = `general`) — the move is
    not built here.
  - Ask 6: a hive with no `INDEX.md` gets one `no index` info line, not red (ADR-021 D8: upgraded hives stay green until
    they generate it); a present but stale index is red.
  - Work with no ask behind it, kept because it serves an ask: deleting the dead `tests/constitution.test.sh` row (byte
    trim for ask 12), `DUPLICATE` (ids must stay unique once cards live in folders), ADR-014/018/019 amendment pointers,
    CHANGELOG, `.claude/rules/README.md` and the `docs/memory-system.md` layers row (they describe ask 4's split).
  - `routine stories: model: haiku` came from `/vulyk-plan` step 5 (`model-profile.sh --role routine`), not the brief;
    the planner found no routine story.
  - Patched by the Queen: `CONFLICT` covers overlapping, not only identical, scopes (story 03); the prohibition wins in
    delivery when unlinked (story 04); moved lessons are deleted from private memory after approval (story 06).

## Stories

**Wave 1**
- `rules-tree-01-card-contract` — `.claude/hooks/defects_lib.py` (areas, three sections in en/ru/uk, `tool:` scope,
  `exception:`/`passes:`, specificity), `defects-check.sh` discovery and parsing through it (sub-folder blame paths,
  `DUPLICATE`), cases in `tests/defects.test.sh`, the format contract in `docs/defects/README.md`. `model: opus`.
- `rules-tree-02-constitution` — Law 6 for three branches + the ask-12 line, paid with trims; `.claude/rules/always.md`
  (always loaded, ≤40 lines) with its cap in `tests/maintenance.test.sh`; `.claude/rules/README.md` and the
  `docs/memory-system.md` layers table.

**Wave 2** (all `blocked_by: [rules-tree-01]`)
- `rules-tree-03-gate-and-index` — gate logic: debt only for Never/How-to, Allowed repeat counter, `CONFLICT`,
  `EXCEPTION`, `INDEX`, `UNDELIVERABLE` accepts `tool:`; `scripts/defects-index.sh` (generate, `--check`, `--grep`,
  `--counts`) and the generated `docs/defects/INDEX.md`; the README `## Cards` table replaced by a pointer;
  `/vulyk-status` counter line.
- `rules-tree-04-delivery` — `defects-inject.sh` on the shared parser: `tool:` matching on `tool_name`, 12-line budget,
  narrowest scope first then freshest quote, How-to and Allowed lines, area paths, overflow line; cases in
  `tests/inject.test.sh`.
- `rules-tree-05-capture` — `defect-intake.sh` on the shared parser: explicit phrase in any channel incl. pastes,
  auto-capture report line with «отмени», paste yes-question and dictation tag, side-agent note stripped, `answer`
  mode for AskUserQuestion; `.claude/settings.json` + `install.sh` wiring (PostToolUse block, widened PreToolUse
  matcher); `docs/hooks-reference.md` rows; cases in `tests/intake.test.sh`.
- `rules-tree-06-memory-triage` — `/vulyk-gc memory` mode with `scripts/memory-triage.sh` and its case in
  `tests/maintenance.test.sh`; CHANGELOG entry; amendment lines on ADR-014/018/019 pointing at ADR-021.

## Contracts
All "per ADR-021": the planner's concrete shape; the Queen reconciles with the ADR once it lands.

- **Library layout.** Cards are `docs/defects/<id>.md` (area `general`) or `docs/defects/<area>/<id>.md`, one folder
  level. `fixtures/` (root or inside an area) is never a card folder; `README.md` and `INDEX.md` (case-insensitive) are
  never cards. `id` = file stem, unique across the library (`DUPLICATE` is red). A card's **ref** is `<id>` for a
  root card and `<area>/<id>` for a foldered one: flat libraries print exactly as today. Gate git calls use the path
  relative to the library root (`<area>/<id>.md`); the README add-commit (blame cut, ADR-018) stays the root README.
- **Sections** (first match each): Never `## Never` | `## Нельзя` | `## Не можна`; Allowed `## Allowed` | `## Можно` |
  `## Можна`; How-to `## How-to` | `## Как надо` | `## Як треба`. Lines are `- ` bullets. An Allowed line is dated:
  `- YYYY-MM-DD · «owner words»`. A permissive card names the Never card it carves an exception from in the frontmatter
  key `exception: <ref>` (ADR-021). Owner quotes stay under `## Owner quotes` as today. A card with ≥1 Never or How-to line is **prohibitive**;
  a card with Allowed lines only is **permissive**. New frontmatter key `passes: [<fixture>, ...]` on a permissive card:
  files the referenced Never card's `check:` must exit 0 on.
- **Scope** (`paths:` entries): path glob (as today) | `cmd:<regex>` (Bash command line, as today) | `tool:<regex>`
  (full match against `tool_name`). **Specificity** of a matched entry = count of its characters that are not
  `*?[]{}().|+^$\`; higher = narrower. Order: specificity desc, newest dated line in the card desc, ref asc.
- **`.claude/hooks/defects_lib.py`.** `load_cards(lib_dir) -> list[Card]`; `Card` fields: `ref, id, area, path, fm,
  status, check, fixtures, keys, paths, passes, quotes, never, allowed, howto, revoked`; `effective_status(card)`
  (today's rule); `parse_scope(entry) -> (kind, value)` with `kind in {"glob","cmd","tool"}`; `scope_matches(entry,
  tool_name, file_path, command) -> bool`; `specificity(entry) -> int`; `allowed_date(line) -> str|None`;
  `allowed_except(line) -> ref|None`. `python3 defects_lib.py <lib-dir>` prints one JSON object per card (for tests).
  Importers: `sys.path.insert(0, <dir of the hook>)`; the gate uses `$(dirname "$0")/../.claude/hooks`.
- **Delivery** (inject, PreToolUse matcher `Edit|Write|MultiEdit|NotebookEdit|Bash|WebFetch|WebSearch|Agent|mcp__.*`).
  Budget `DEFECTS_INJECT_LINES`, default 12, counted after the header line. A card block is `<ref> — <title>` then
  `✗ <never line>`, `→ <how-to line>`, `✓ <allowed line>` (with the card's `exception: <ref>` shown); a matched card with no branch
  lines prints `read docs/defects/<path>`. Cards that do not fit: one line `+N cards: <ref>, <ref>, …`. Block-with-check
  and revoked cards are skipped; dedup state and `reset` unchanged. For a tool that is not Edit-family or Bash, only
  `tool:` entries can match.
- **Capture** (intake, one line each, ≤600 chars, raw prompt scanned for the phrase before stripping, side-agent block
  stripped first). Phrase regex, case-insensitive: RU `(внеси|запиши|добавь)\s+в\s+(запрет|правило|разрешение)`;
  UK `(внеси|запиши|додай)\s+(в|до)\s+(заборон\S*|правил\S*|дозв[іо]л\S*)`; EN
  `(add|file|put)\s+(this\s+)?(to|as|in|under)\s+(a\s+|the\s+)?(never|rule|allowed)`. Outputs:
  phrase → `[VULYK] owner asks to file a <never|allowed|how-to> card: write it now, verbatim, in docs/defects/<area>/<id>.md (choose area and scope), then report one line: filed → <ref>`;
  typed auto → `[VULYK] looks like a correction (<trigger>): file the quote now in <ref candidates or a new card> and report one line with «отмени»`;
  paste auto → `[VULYK] a pasted text looks like a correction (<trigger>): ask the owner in one line whether these are their words before filing`;
  a paste starting with `$VULYK_DICTATION_TAG` (when set) is treated as typed. Side-agent block = from a line starting
  `Here is a note offered by a side agent` to the end of that paragraph/tag.
  `defect-intake.sh answer` (PostToolUse, matcher `AskUserQuestion`): reads `tool_input.questions[].options[].label`
  and `tool_response.answers`; a part of an answer equal to an option label → `[VULYK] decision: «<label>» on
  «<question>»` (a decision, never a quote); the remaining free text runs through the phrase and typed-auto passes.
- **Index and gate.** `bash scripts/defects-index.sh` writes `docs/defects/INDEX.md`; `--check` exits 1 and prints
  `index stale` when a regeneration differs; `--grep <pattern>` prints `<ref>:<line>: <text>` (case-insensitive, over
  cards only); `--counts` prints `cards <n> · never <n> · allowed <n> · how-to <n> · allowed repeats <n>`.
  INDEX.md = header + three tables `## Never`, `## Allowed`, `## How-to`, rows `| area | card | title | status |
  lines | quotes | repeats | last |` sorted by area then ref; a card is a row in each table where it has lines;
  `repeats` = max(0, dated Allowed lines − 1) in the Allowed table, max(0, owner quotes − 1) elsewhere.
  Gate: `DEBT` only for prohibitive cards; a permissive card with ≥2 dated Allowed lines is an info line `allowed
  repeats <n> <ref>`; `CONFLICT` (new/old by blame of the newest Allowed line): a permissive and a prohibitive live
  card have overlapping scope (identical entries, or one glob matches the other entry as a path) and no
  `exception:` links them; `EXCEPTION` (new/old by blame of the `exception:` line, ADR-021 D9): an `exception:` ref names
  no live card, or a `passes:` fixture on which the referenced card's `check:` exits non-zero; `INDEX` (red only when
  INDEX.md exists, else one `no index` info line): `defects-index.sh --check` non-zero; `DUPLICATE` (always red);
  `UNDELIVERABLE` treats `cmd:` and `tool:` entries as deliverable.
- **Constitution** (story 02; bytes ≤7168, lines ≤120 with CRs stripped). Law 6 becomes: `6. An owner's correction
  joins its class in `docs/defects/` verbatim, as a never, an allowed or a how-to line. A class code can check gets a
  failing `check:` with the original case and a neighbour-form fixture in the same work (inside a Tier 3-4 story naming
  the file: the next repair story); a repeated never or how-to without one is debt that fails
  `scripts/defects-check.sh`. A check that only warns is not a check.` New line under `## Where things live`:
  `A lesson about this project's code or process is a card in `docs/defects/`; auto-memory keeps only the personal.`
- **Always-loaded rules file.** `.claude/rules/always.md`, no frontmatter, ≤40 lines; `tests/maintenance.test.sh`
  gains `RULES_ALWAYS_MAX_LINES=40` applied to every `.claude/rules/*.md` without a `paths:` frontmatter.
- **Memory triage.** `bash scripts/memory-triage.sh [<memory-dir>]`: default dir
  `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/<slug>/memory` where `<slug>` is the repo root path with `[:/\\]`
  replaced by `-` (`E:\Projects\vulyk` → `E--Projects-vulyk`); prints TSV `path<TAB>type<TAB>first heading` for every
  `*.md` except `MEMORY.md`/`memory.md`; `no private memory: <dir>` and exit 0 when absent. A card made from memory has
  no `## Owner quotes` line and a `## Source` section: `- YYYY-MM-DD · auto memory <file> · retold, not a quote`.

## Rejected alternative
- **A separate PostToolUse hook script for AskUserQuestion.** Rejected: it would duplicate the lexicon, the phrase
  regex and the stripping a third time and need its own `## Commands` row the constitution cannot afford. An `answer`
  mode of `defect-intake.sh` reuses all of it and its test suite. (Three folders by branch were already rejected in the
  grill, Q6: it tears a class and its quotes across three files.)

## Integration gate
`git ls-files '*.sh' | xargs -n1 bash -n` · `python -m py_compile .claude/hooks/*.py` ·
`git ls-files '*.json' | xargs -n1 jq -e . > /dev/null` ·
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh` · `bash scripts/defects-check.sh` ·
`bash tests/maintenance.test.sh` · `bash tests/telemetry.test.sh`

## Descoped

*(empty)*

## Plan deltas

**Approved:** Andrei, 2026-10-19 («Да, утверждаю (Рекомендую)»)
**Briefed:** <written by scripts/cycle.sh briefed>
**Branch:** vulyk/rules-tree
**Checked:** <written by scripts/human-check.sh>
**Council:** <written by scripts/cycle.sh judge/escalate>
**Shipped:** <written by scripts/ship-check.sh --record>
