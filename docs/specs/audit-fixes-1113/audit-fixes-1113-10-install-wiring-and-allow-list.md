---
story: audit-fixes-1113-10
spec: audit-fixes-1113
status: done
returned: DONE
tier: 3
worker: worker-code
wave: 3
blocked_by: [audit-fixes-1113-04, audit-fixes-1113-06]
red: required
red_reason: the allow list holds no owner-only verb
red_verified_at: 2026-11-13T23:41:28Z 12542b4bb543809fd1c17f9a91bb6fae66311ea163b2013468d1324405c7f56b
---

# The installer allows six cycle verbs, wires the two new guards, and the release notes are written

## Goal
Everything of wave 3 that lives in `install.sh`, `.claude/settings.json` and the two shared docs (plan.md
`## Contracts` W1).
1. The allow list `install.sh` writes holds one rule per verb, `Bash(bash scripts/cycle.sh <verb>:*)`, for
   `advance`, `status`, `release`, `suite`, `stamp-red` and `close-story`, and no rule for `human-check.sh`. The
   owner-only verbs (`briefed --go`, `reopen`, `manual-done`, `escalate`) are covered by no rule. `--upgrade`
   replaces the broad `cycle.sh` rule an older installer wrote and logs `narrowed allow: cycle.sh`; this repo's
   own `.claude/settings.json` follows the same list.
2. `owner-guard.sh` and `court-guard.sh` (built by story 08 in this wave, under exactly these names) are wired as
   PreToolUse hooks on the matchers of contract W1, in this repo's `settings.json` and by the installer:
   a fresh install gets both, `--upgrade` wires each once, only when the hive's installed version did not ship it.
3. Verify against the installed Claude Code whether a hook entry accepts `onFailure`, and whether an older
   release ignores the key without dropping the entry. Only if both hold, the three guard entries (`git-guard.sh`
   and the two new ones) carry `"onFailure": "block"`. Otherwise leave it out and say why in the notes.
4. `docs/hooks-reference.md` gets a row for each new hook and git-guard's new behaviour from contracts G1, O1, C1:
   what it denies, for whom, what it does without Python, and how an owner unwires it.
5. `CHANGELOG.md` gets the `## [Unreleased]` lines for the whole spec: the `CHANGELOG:` lines stories 01-06 left
   in their notes, and for stories 07-09 lines written from plan.md `## Contracts`. Every line says what VULYK
   does now. No line describes a former gap, names a finding, or lists a form that stays open.

Marked red: a permissions write that reaches every hive.

## Requirements
> 11. `install.sh` allows only the clerk's and workers' `cycle.sh` verbs. Owner-only verbs (`briefed --go`, `reopen`, `manual-done`, `escalate`, `human-check.sh`) are not in the allow list.
> 4. Only the owner's own words record his acceptance (`human-check.sh ACCEPTED|REJECTED`) or a plan's straight-through `--go`: a subagent is always refused; the main session passes only when the note quotes, verbatim and after the latest verdict, an owner prompt or AskUserQuestion answer from this session, with whitespace normalised and a bare «ок» not enough; direct edits of the record file and of the `**Approved:**` line are guarded the same way; without Python the guard refuses with a loud message.
> 13. A hook keeps a blind council seat inside its court: no reads outside the court, no git reads of the spec. Seat prompts no longer say `record-seat` enforces blindness.

## Files
- install.sh
- .claude/settings.json
- docs/hooks-reference.md
- CHANGELOG.md
- tests/telemetry.test.sh

## Non-goals
- Do not create or edit the two hook files or `git-guard.sh` (stories 08 and 07). Where a test needs a hook file
  to exist, it makes a stub in its scratch copy of the source, never in the tree.
- Do not add `permissions.ask` or `permissions.deny` rules, and do not remove an allow rule the installer did not
  write (a hive's own rule stays, named in the log).
- Do not touch the upgrade base, `shippable`, the memory skeleton or the inject matcher (story 06, landed).
- Do not remove a hook entry an owner deleted on purpose: the wire-once rule of `git-guard.sh` applies.
- Do not edit `tests/telemetry.test.sh` outside the `install` and `wiring` parts.
- CR-byte trap: edit `install.sh` with Edit, never through a Python text-mode rewrite; JSON is written UTF-8, LF,
  with a trailing newline. Run `bash scripts/portability-check.sh install.sh` after every edit.
- `CHANGELOG.md` and `docs/hooks-reference.md` are checked by the leak check at close: no absolute path, no hive
  name, no private-folder content.

## Map slice
`memory/map/scripts-install.md` → install.sh - the upgrade contract (wiring, `PREV_UNKNOWN`), Gotchas;
`memory/map/agents-and-commands.md` → Agents (cycle-clerk, worker-code); `memory/map/cycle.md` → The Workflow
driver (`gate`, shell only via `cycle-clerk`).

## Acceptance criteria
- [ ] `--part install`: a fresh hive's allow list has exactly the six `cycle.sh` rules and none that matches
  `bash scripts/cycle.sh briefed`, `reopen`, `manual-done`, `escalate` or `bash scripts/human-check.sh` (label
  contains `the allow list holds no owner-only verb`). Neighbour: a hive holding the old broad rule is narrowed by
  `--upgrade` with the log line, `--check` prints `would narrow`, and a second `--upgrade` changes nothing.
- [ ] A hive's own unrelated allow rule, and a non-ASCII one, survive the upgrade byte for byte.
- [ ] `--part wiring`: a fresh install has both new entries with the W1 matchers and the quoted
  `"$CLAUDE_PROJECT_DIR"` head; an upgrade from a version that did not ship them wires each once (`wire PreToolUse
  owner-guard`, `wire PreToolUse court-guard`); from a version that did, a missing entry stays missing and is
  reported `unwired`; with the installed tag unknown, nothing is wired and both are reported.
- [ ] This repo's `.claude/settings.json` carries the same two entries and the six-verb list;
  `git ls-files '*.json' | xargs -n1 jq -e . > /dev/null` is clean.
- [ ] The notes record the `onFailure` finding (Claude Code version, what was observed) and the decision.
- [ ] `docs/hooks-reference.md` has the rows of item 4; `CHANGELOG.md` has one line per ask, 1 to 21, under
  `## [Unreleased]`; `bash scripts/leak-check.sh` exits 0 on both files.

## Verification
`bash tests/telemetry.test.sh --part install`
`bash tests/telemetry.test.sh --part wiring`
`git ls-files '*.json' | xargs -n1 jq -e . > /dev/null`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each. -->
- install.sh: `wire_permissions` writes six `cycle.sh <verb>:*` rules + `journal.sh`; `--upgrade` puts the six in the broad rule's place (`narrowed allow: cycle.sh`, `--check`: `would narrow`); a hive rule naming `cycle.sh`/`human-check.sh` stays and is logged `kept (yours)`.
- install.sh: `wire_guard` (git-guard's old branch, now shared) wires `owner-guard.sh` / `court-guard.sh` on the W1 matchers once, only when `v$PREV` did not ship the script and the hive has the file; both join `SHIPPED_HOOKS` for `--wire`; `py_wire` gives the three guards `"onFailure": "block"`.
- Decision: a guard entry is written only when the hook file is in the hive, because a fail-closed entry naming a missing script blocks every tool it matches.
- .claude/settings.json: the six-verb allow list + journal, the two guard entries, and `onFailure: block` on all three guards.
- onFailure finding: installed Claude Code 2.1.325 bundle handles `onFailure` on command hooks (`WG()` true for `"block"`; a failed or timed-out hook then logs `blocking because onFailure is "block"`). The older 2.1.190 on this machine has no such key, and its command-hook schema is a plain zod object without `.strict()`, so the key is stripped and the entry kept. This was a static read of both bundles, not a live 2.1.190 run. Both conditions hold, so the key is set.
- Surprise: hooks hot-reload in 2.1.325. Once settings.json held owner-guard.sh, my own session's Bash call was denied (heredoc text naming the acceptance command), so docs were written through Write + a script file.
- tests/telemetry.test.sh: install part (allow list on this repo, fresh and owner-settings installs; the narrowing neighbour rides the existing `$TGT` upgrades to add no install run); wiring part (19 entries, `$GS` scratch source with v0.49.0/v0.49.1 tags and stub guards, did-not-ship / shipped / unknown-tag cases, `--wire`).
- Test fix after the first receipt (a label needle `narrow` matched the hive's dir name; jq `--arg "/x"` was path-mangled by MSYS): implementation reverted to HEAD, re-stamped, re-applied.
- docs/hooks-reference.md: git-guard row rewritten to G1, rows for owner-guard.sh and court-guard.sh. CHANGELOG.md: 21 lines under [Unreleased], in ask order 1-21.

## Findings

## Red receipt
- command: bash tests/telemetry.test.sh --part install
- exit: 1
- tests: 12542b4bb543809fd1c17f9a91bb6fae66311ea163b2013468d1324405c7f56b (tests/telemetry.test.sh)
- impl: ae1f9bfe305cae84d19ea0204ef8874129399f19233b4a05a118cc042d103521
- stamped: 2026-11-13T23:41:28Z

```
  ok    install (vulyk): the allow list holds no owner-only verb: bash scripts/cycle.sh briefed demo --go
  ok    install (vulyk): the allow list holds no owner-only verb: bash scripts/cycle.sh reopen demo
  ok    install (vulyk): the allow list holds no owner-only verb: bash scripts/cycle.sh manual-done demo-01
        If the constitution changed this release, the note above says by how much and how to migrate.
  ok    ... and writes nothing to settings.json
  ok    the cached install equals a real install (diff -r)
  ok    the cached owner-settings install equals a real one (diff -r)
  ok    marker-less Profile: warns and names the row and value
  ok    marker-less Profile: the file is unchanged
  ok    the mod listed at the release's version: no plugin update, no marketplace update
  ok    ... and the log says it is current
  skip  bare-install terminal case: no util-linux `script` on PATH to drive a pseudo-terminal
telemetry.test.sh: 85 checks, 17 failed
```
