# Symbol map: a model-free link finder for `## Files` (plan)

**Tier:** 3 · **Spec slug:** `symbol-map` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-015 (Sonnet executes, Opus judges), ADR-020 (model profiles; `routine stories: model: haiku`), ADR-022 (horizon step; [horizon.md](horizon.md) H1 adopted, H2 rejected, H3 folded into ask 2), crossgrill verdict `.crossgrill/2026-10-26-symbol-map/verdict.md` (no gate, no block, stdlib only), Law 6 / public-repo rule (no host names in committed files), `tests/maintenance.test.sh` caps (`CONSTITUTION_MAX_BYTES` 7168, `DESCRIPTIONS_MAX_BYTES` 4983)
**Depends on:** 0.36.0 (`tests/full-suite.sh` runs every `tests/*.test.sh`; `install.sh` `OWNED` already ships `scripts/`, `.claude/agents/`, `.claude/commands/`, so no installer change)

## Goal
Add one deterministic script, `scripts/symbol-map.sh <file>...`, that prints for each given file the repo paths that are linked to it and lie outside the story's `## Files`: tests that touch it, who imports it, what it imports (repo-local), tests that walk the repo (guard tests), and files that name its path as a string. Python edges come from `ast`, bash edges from `source`/`.` lines; every line carries `exact` or `textual`; a file block never exceeds 1.5 KB; a missing input is reported, never silently empty. The Queen runs it at recon and hands the output to the planner so `## Files` is complete; the worker runs it before touching a root file instead of grepping; recon gains a five-item checklist line. Before release, the script is replayed on the stories whose needed path turned out to be outside `## Files` and the hit share and noise are recorded as the acceptance number. `memory/map/*.md` is untouched: it keeps meaning and pitfalls (ask 1 is a non-change, covered by the Non-goals of every story).

## Assumptions
- The replay runner lives next to the spec, `docs/specs/symbol-map/replay.py`, not under `scripts/`: it reads host projects outside this repo and must neither ship to hives (`OWNED` covers `scripts/`) nor run in the suite. Its only in-suite coverage is a self-contained case inside `tests/symbol-map.test.sh`.
- The script is a thin `scripts/symbol-map.sh` wrapper over `scripts/symbol-map.py` (stdlib only, `python3` then `python`), following `token-report.py` / `evolve-ledger.py`. Worker creates `.py` files with the Write tool, never a Bash heredoc (CR-byte hazard on this box).
- Exit codes: 0 normal; 1 when at least one input was missing (every input is still reported); 2 usage, or no python. An unparseable Python input is reported with `! unparsed <path>` and still gets the language-independent sections, exit 0.
- The cap is per run: the whole stdout of one call stays at or under 1536 bytes (ask 2 «не больше 1,5 КБ» is what lands in a context). Blocks are filled in input order; the output ends with one `... N more (<k> inputs not shown)` line when the cap cuts it. Coverage drone flagged the per-file reading as assumed; the Queen chose per run.
- Ask 4 says the worker runs the script «а не ищет вызовы grep-ом». Taken literally, a worker in a TypeScript or PHP hive would get an almost empty answer and could read it as "no callers". So the script prints `  ! imports not parsed for <ext>: search callers yourself` for every input outside Python and bash, and the worker line keeps grep for those files and for `textual` names (side-agent note, 2026-10-26; the Queen narrowed the ask to its intent).
- `tests:` is not a new kind of link: it is the importers that are test files, listed first (the panel's "tests first"). `--scope` exists so a recon run without a story file can still drop the plan's own paths (ask 2 «только пути вне ## Files»).
- The recon checklist line (ask 5) names exactly five items: meta-tests that scan the repo, docs/ADR, `.env.example`, re-exports (`__init__.py`, index files), sibling files carrying the same pattern.
- No wiki page and no `docs/` prose in this spec: `--help` plus the protocol lines are the documentation; `drone-docs` refreshes `memory/map/scripts.md` after the merge as usual.
- `wave-check.sh` will report `verify-cell` on story 01 before wave 1 because its `## Verification` names the `## Commands` row the same story adds; `close-story` runs after the edit and finds the row. Accepted: the row cannot land earlier without a story of its own.
- Fixture trees are committed under `tests/fixtures/symbol-map/` and copied by the test into a temp dir where `git init && git add -A` makes them tracked; `tests/full-suite.sh` runs only `tests/*.test.sh`, so fixture test files never execute.
- `.vulyk/symbol-map-replay/cases.json` (13 missed paths across 11 stories) exists locally and is git-ignored; the worker of story 03 runs the replay against the current trees of those hosts and commits only numbers.
- No story carries a model line. Story 03 was drafted on `haiku`; the Queen dropped it: its output must leave no host or client name in a public file, which is judgment, not routine.

## Stories

**Wave 1**
- `symbol-map-01-script` — `scripts/symbol-map.py` + `.sh` wrapper, `tests/symbol-map.test.sh` with fixtures, one `## Commands` row in `CLAUDE.md` (asks 2, 1 as a non-goal).

**Wave 2** (parallel; `## Files` disjoint)
- `symbol-map-02-protocol` — the recon step and planner hand-off in `vulyk-plan.md`, the planner's `## Files` bullet, the worker line in `worker-code.md` step 2 and `vulyk-build.md` solo build, the recon checklist line (asks 3, 4, 5).
- `symbol-map-03-replay` — `docs/specs/symbol-map/replay.py` + a replay case in `tests/symbol-map.test.sh`; run on the local cases, numbers into `docs/specs/symbol-map/replay.md` (ask 6).

## Contracts
- **CLI** (story 01 provides; 02 and 03 consume): `bash scripts/symbol-map.sh [--story <story.md>] [--scope <path>]... <file>...`. Positional files are the inputs; the scope set = inputs + every `--scope` + the `- ` lines of `--story`'s `## Files` (globs matched with `fnmatch`). With `--story` and no positional file, the `## Files` lines are the inputs. Paths are repo-relative or absolute inside the repo; the repo root is `git rev-parse --show-toplevel` of the first input's directory. `--help` prints usage; no flag starts a repo-wide name search without an input.
- **Output** (stdout, one block per input, blank line between blocks):
  ```
  ## <repo-relative path>
  tests:
    exact    tests/test_core.py
    textual  tests/test_misc.py
  importers:
    exact    pkg/api.py
    exact    app.py (via pkg/__init__.py)
  imported:
    exact    pkg/util.py
  guard tests:
    textual  tests/test_tree.py
  path mentions:
    textual  docs/wiki/notes.md
    ... 3 more
  ```
  Sections in that order; an empty section is omitted; a block with no section prints `  (no links outside scope)`. A scope path never appears. `exact` = an `ast` import (absolute, relative, or through a package `__init__` re-export, named `(via <init path>)`) or a bash `source`/`.` resolved to the file (literal path, or `$(dirname "$0")`/`$SCRIPT_DIR`-style prefix resolved against the sourcing script's dir, or a unique basename among tracked files). `textual` = the module stem as a whole word, or the repo path as a substring; the false friend (`core_v2` for `core`, or `core` the word inside an unrelated file) is `textual`, never `exact`. `path mentions` caps at 5 lines; `guard tests` lists test files containing `os.walk`, `rglob`, `glob(`, `git ls-files`, `listdir`, `iterdir`; textual importers cap at 5. The whole stdout is cut at 1536 bytes with one final `... N more` line counting the dropped lines (per run, see `## Assumptions`). Missing input: block `## <path>` with `  ! missing` and final exit 1. Unparseable Python: `  ! unparsed`, language-independent sections still printed, exit 0.
- **Languages**: `.py` and `.sh`/`.bash` get importers and imported; every other extension gets only tests (textual), guard tests and path mentions. Test files: any path with a `tests/` or `test/` segment, or a basename matching `test_*`, `*_test.*`, `*.test.*`, `*.spec.*`. Tracked files come from `git ls-files`; files that fail UTF-8 decoding or exceed 1 MB are skipped silently.
- **Replay** (story 03): `python docs/specs/symbol-map/replay.py <cases.json>`; `cases[]` = `{story_file: <absolute path>, files: [<repo-relative>...], missed: [<repo-relative>...]}`; the repo root per case is the nearest ancestor of `story_file` holding `.git`. For each case it runs the CLI on `files` with `files` as the scope, counts a hit when a `missed` path appears on any line, and counts noise as the number of path lines printed. Last stdout line: `replay: hits <h>/<m> noise <lines> over <n> stories`. Exit 2 on a missing case file or an absent repo, 0 otherwise. `docs/specs/symbol-map/replay.md` holds that line, a per-case table keyed `case 1..n` and a `## Gap` line: current trees, not the trees at plan time.
- **Protocol lines** (story 02 only): the Queen's recon line names the CLI with `--story`-less positional files; the worker line is one sentence in `worker-code.md` step 2 and in `vulyk-build.md`'s solo build; no `description:` frontmatter changes anywhere.

## Rejected (next circle)
- **Close-time gate on a removed Python def still imported outside the diff** (the Queen's frozen position): rejected 3/3 by the panel; leaky through `__init__` re-exports and `getattr`, and a report that blocks nothing is not a check (Law 6). Next step recorded here: replay the script on the 3-7 missed-caller council findings and decide by the number.
- Git co-change block (H2): 1 of 13 misses, already caught by the import graph; drowns long `## Files` lists in noise.
- JS/TS/PHP import edges, tree-sitter/ctags/LSP: the default path must need no extra tool (public-repo rule); the language-independent sections already apply to every stack.
- A cache of the parsed graph: 1.2 s measured on a 445-file repo, nothing to save yet.

## Integration gate
`bash tests/full-suite.sh`

## Descoped

*(empty)*

## Plan deltas

## Open questions (answered by the Queen at plan time, routine calls)
1. Runner location: `docs/specs/symbol-map/replay.py` stays next to the spec (it reads host trees; it must neither ship nor run in the suite).
2. A missing input exits 1 after every input is reported: a missing input is a refusal, never a silent pass (defect card `safeguard-bypassable-or-late`).
3. Story 03 runs with no model line (see `## Assumptions`).
4. Known wave-check noise before wave 1, accepted: `empty-glob` and `verify-gap` on 01 (the fixtures and `tests/symbol-map.test.sh` do not exist yet), `verify-cell` on 01 and 03 (the `## Commands` row lands in 01), `verify-gap` on 02 (`tests/maintenance.test.sh` guards the description budget of the four protocol files; their prose bodies have no test, a trivial change names none).

<!--
The lines below are the cycle's confirmation markers (docs/cycle.md); each placeholder is replaced by
the command or script that owns it, and scripts/ship-check.sh reads them all. Approved is the owner's
word, the stop at Tier 2-4; Briefed is written by `cycle.sh briefed` instead, at Tier 1 ("via
mini-brief"), with `--go`, or in no-question mode ("assumed"). Either closes stage 02. Council and
Checked close stages 04+05 together: a GREEN council row is enough on its own, and Checked is the
owner's override in either direction, newest timestamp wins. No line of this comment may start with
a marker: the scripts read the first line that does.

There is no default tier: `cycle.sh open-round` refuses to open a round while the `**Tier:**` line above
is missing or unparsable.
-->
**Approved:** Andrei, 2026-10-26
**Briefed:**
**Branch:** vulyk/symbol-map
**Checked:**
**Council:**
**Council:** RED round 1, 2026-10-26, at f463897, pack 3fd2e984986b
**Council:** GREEN round 2, 2026-10-26, at 70a8e41, pack 84b25466d1d3
**Shipped:**
