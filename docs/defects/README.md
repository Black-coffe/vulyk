# Defect library

One card per **class** of work the owner rejected - not per place it happened. A card holds the owner's
verbatim words, the cause, what is never done again and, when code can see the class, a command that fails
on it. Read the cards of your area before you work there. This README is the index; it is never a card.

## A card: `docs/defects/<id>.md`

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
| `paths` | where the class lives: path globs from the repo root (`**` allowed), or `cmd:<regex>` matched in a Bash command line |

Sections: `## Owner quotes` (or `## Цитаты владельца`), `## Cause`, `## Never` (or `## Нельзя`), optional
`## Allowed` (or `## Можно`) and `## Revoked`. A **quote line** starts `- YYYY-MM-DD · ` and gives the date,
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

## The gate

```
bash scripts/defects-check.sh           # audit: debt, effective status, every block check against its fixtures
bash scripts/defects-check.sh <arg>     # before showing work: debt, then every declared block check with <arg>
```

Exit 0 green, 1 red (new debt, a red check, a blind fixture), 2 no library or no python. The last line is
the verdict. Check output goes to a log under `${TMPDIR:-/tmp}`. `DEFECTS_DIR` points it at another library.

## Cards

| id | class | status | quotes | check | last quote |
|---|---|---|---|---|---|

**Trust.** `defects-check.sh` runs each card's `check:` as a shell command, and `lead-review` runs the gate on the
branch under review. A card's `check:` is code of this repository, with the same trust as its tests: review a
changed `check:` line like any other script change.
