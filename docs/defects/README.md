# Defect library

One card per **class** of work the owner rejected - not per place it happened. A card holds the owner's
verbatim words, the cause, what is never done again and, when code can see the class, a command that fails
on it. Read the cards of your area before you work there. This README is the format contract; it is never a card.

## Areas and refs

A card is `docs/defects/<id>.md` (area `general`) or `docs/defects/<area>/<id>.md`, one folder level, the
folder named after an area of the project (`pay/`, `video/`). `fixtures/`, at the root or inside an area, is never
a card folder; `README.md` and `INDEX.md` (any case) are never cards. The `id` is the file stem and is unique
across the whole library: two cards with one id are `DUPLICATE`, always red. A card's **ref** is `<id>` for a
root card and `<area>/<id>` for a foldered one; findings, `exception:` and the index name cards by ref. One
parser reads the library for the gate and the hooks: `.claude/hooks/defects_lib.py`
(`python3 .claude/hooks/defects_lib.py docs/defects` prints one JSON object per card).

## A card: `docs/defects/<id>.md` or `docs/defects/<area>/<id>.md`

```markdown
---
id: speech-cut
title: Clipped speech
status: block
check: python pipeline/verify_edit.py <arg>
fixtures: [docs/defects/fixtures/speech-cut-original.json, docs/defects/fixtures/speech-cut-neighbour.json]
keys: [clipped, cut off]
paths: ["pipeline/voiceover.py", "EDIT_*.json", "cmd:edit_build\\.py"]
---

# Clipped speech
One paragraph: what the defect is, as the owner sees it.

## Owner quotes
- 2026-09-17 · video 2 · 10:04 — «the owner's words, verbatim»

## Cause
## Never
- one line per forbidden action
## Allowed
## Revoked
```

Frontmatter is plain `key: value` lines; a list is `[a, b, "c"]`. A missing field is empty.

| Field | Meaning |
|---|---|
| `id` | the file stem |
| `title` | the class, not the place |
| `status` | `block`, `text` or `revoked` |
| `check` | a command run from the repo root that exits non-zero on this defect; the first `<...>` token (`<arg>`) is replaced by the argument or fixture path |
| `fixtures` | files the check must fail on: the original case first, then neighbour forms |
| `keys` | words that tie an owner remark to this class |
| `paths` | the card's scope, any mix of: path globs from the repo root (`**` allowed; a glob without `/` also matches the basename), `cmd:<regex>` searched in a Bash command line, `tool:<regex>` matched against the whole tool name (`tool:WebFetch`, `tool:mcp__.*`) |
| `exception` | on a permissive card: the ref of the Never card it carves an exception from (`exception: pay/no-refund`); without it an Allowed card never overrides a Never card |
| `passes` | on a permissive card, a list like `fixtures`: files the `check:` of the `exception:` card must exit 0 on |

Sections: `## Owner quotes` (or `## Цитаты владельца`, `## Цитати власника`), `## Cause`, `## Revoked`, and
the three branches, each under an English, Russian or Ukrainian heading (the first heading of a branch counts):

| Branch | Headings | Lines |
|---|---|---|
| Never | `## Never`, `## Нельзя`, `## Не можна` | `- ` one forbidden action per bullet |
| Allowed | `## Allowed`, `## Можно`, `## Можна` | `- YYYY-MM-DD · «owner words»`, dated, verbatim |
| How-to | `## How-to`, `## Как надо`, `## Як треба` | `- ` one way of doing it right per bullet |

A bullet continues on indented lines. A card with a Never or How-to line is **prohibitive**; a card with Allowed
lines only is **permissive**: a standalone record with its own `paths:` and the owner's dated words, which overrides
a Never card only through its `exception:` key. A **quote line** starts `- YYYY-MM-DD · ` and gives the date,
the material and the place, then the words in «». One line per remark; a repeat is a new line, never an edit.

## Statuses

- `block` - the class is caught by code. Whenever `check:` is set, the gate runs it and the card's
  `## Never` lines are not injected. It has *earned* `block` (no debt, checked in the audit) only when
  `fixtures:` also lists at least two files that exist; with fewer it is reported as
  `block without fixtures (check runs, not earned)`. With no `check:` it is reported as `text`.
- `text` - a rule in words only. Its `## Never` lines are shown to whoever edits the card's `paths:`.
- `revoked` - the owner lifted it: add their words and the date under `## Revoked`. Ignored by everything.

## Fixtures

The first fixture is the original case the owner rejected; the rest are **neighbour forms** - the same
complaint in a different shape (another file, another spot, another wording). Every fixture must make
`check:` exit non-zero. A fixture that passes means the gate is blind to it, and the audit goes red.
A check that only catches the exact original is overfitted: the neighbour form is what proves it.

## Debt

A card with two or more quotes whose status is not an effective `block` is a repeat without a gate: debt.
Debt is **new** when at least one quote line was committed after the commit that added this README (the
commit time from `git blame`, not the date in the quote). Uncommitted quote lines, and a library outside
git, count as new. New debt makes the gate red; pay it by giving the card a failing `check:` and two
fixtures. Debt older than the library is reported as old debt and does not fail.

Three more findings follow the same new/old rule: new is red, older than this README is one `old` line.

- **Undeliverable.** A card shown as `text` (not `block` with a `check:`) with no `paths:` can never be
  shown to anyone, because the hook matches only `paths:`. `area:` is a label, not a glob. Give the card path globs or
  `cmd:<regex>`. New = the card file was added after this README.
- **Overlap.** One key (lowercase, spacing collapsed) on two live cards sends one remark to two classes and
  splits its quotes, so neither card reaches debt. Sharpen a key or merge the cards; quote lines move and are
  never rewritten. New = the newer `keys:` line. A key inside another card's key is an `ambiguous key` line, never red.
- **Escape.** A `block` card got an owner quote after its `check:` line changed, and no fixture or `check:`
  changed since: the check missed a neighbour form. Add that form as a fixture and make the check fail on it.
  An uncommitted fixture edit counts as newest.

## Promoted from hives

A class the owner rejected in the work of several hives gets a card here too, so VULYK's own work carries the rule.
Its hive quotes go under `## Seen in hives`, in the quote-line form, verbatim with people, clients and hives masked,
one per hive. They are the evidence for the class, and each is still a card in its hive's own library, where it
counts. They corrected hive work, not VULYK's, so they are not owner quotes here and do not count toward debt:
the first remark on VULYK's own work goes under `## Owner quotes`, and a second makes the card debt as usual. A
promoted card says under `## Check` why code cannot see the class, or names its check. `install.sh` ships a hive only this README, not the cards.

## The gate

```
bash scripts/defects-check.sh           # audit: debt, effective status, every block check against its fixtures
bash scripts/defects-check.sh <arg>     # before showing work: debt, then every declared block check with <arg>
```

Exit 0 green, 1 red (new debt, a new undeliverable card, overlap or escape, a duplicate id, a red check, a blind fixture),
2 no library or no python. The last line is
the verdict. Check output goes to a log under `${TMPDIR:-/tmp}`. `DEFECTS_DIR` points it at another library.

## Cards

The card list is generated, not hand-written: `docs/defects/INDEX.md` (`scripts/defects-index.sh`). Until
it exists the table below is kept by hand.

| id | class | status | quotes | check | last quote |
|---|---|---|---|---|---|
| `framework-fix-skips-live-hives` | A framework fix ships in VULYK while a live hive keeps the defect | text | 1 | - | 2026-10-14 |
| `upgrade-overwrites-host-edits` | An upgrade overwrites a hive's own edits and deletions in framework files | text | 1 | (spec `upgrade-keeps-host-edits`) | 2026-10-13 |
| `host-internals-in-public-repo` | A host project's insides quoted into the public VULYK repository | block | 1 | `bash scripts/leak-check.sh <arg>` | 2026-10-13 |
| `command-injection-follows-cwd` | A command's injection names its script relative to the session cwd | block | 1 | `bash scripts/injection-check.sh <arg>` | 2026-10-13 |
| `work-handed-back-to-owner` | Work an agent can do is handed back to the owner as a to-do list | text | 1 (+2 hives) | - | 2026-10-13 |
| `claim-not-from-source` | A claim made from memory, a docstring or a guess instead of the source that settles it | text | 0 (+4 hives) | - | - |
| `measurement-unlike-reality` | A test or measurement that does not represent the reality it is used to judge | text | 0 (+4 hives) | - | - |
| `safeguard-bypassable-or-late` | A safeguard that can be bypassed, passes silently on a missing input, or ships after what it guards | text | 0 (+3 hives) | - | - |
| `done-without-real-run` | Work reported done without running it where it will really run | text | 0 (+3 hives) | - | - |
| `outward-artifact-carries-internals` | An artifact going outward carries internal or client content beyond names | text | 0 (+2 hives) | - (name form: `host-internals-in-public-repo`) | - |
| `owner-words-by-builder` | The owner's words or decision written by the builder | text | 0 (+2 hives) | - | - |

**Trust.** `defects-check.sh` runs each card's `check:` as a shell command, and `lead-review` runs the gate on the
branch under review. A card's `check:` is code of this repository, with the same trust as its tests: review a
changed `check:` line like any other script change.
