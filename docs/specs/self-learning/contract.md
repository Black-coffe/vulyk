# 0.19 build contract — defect library, hooks, manual wave dependency

Shared by all build packages. Source of truth for formats; the plan is `plan.md` (approved 2026-09-27).
Reference implementation (Russian, project-specific): `D:/YouTube_AI/docs/defects/`, `D:/YouTube_AI/scripts/defects-check.sh`,
`D:/YouTube_AI/.claude/hooks/project-defect-intake.sh`. VULYK generalizes it; it must still read YouTube_AI's existing cards.

## 1. Defect card — `docs/defects/<id>.md` (one file per class; `README.md` is the index, never a card)

```markdown
---
id: speech-cut                      # = file stem
title: Clipped speech               # the class, not the place
status: block                       # block | text | revoked
check: python pipeline/verify_edit.py <arg>   # command run from repo root; the literal token <arg> is replaced
                                    # by the CLI argument / fixture path. Any other <...> token (e.g. <лист>.json)
                                    # is also treated as the placeholder: the first <...> token in the command.
fixtures: [docs/defects/fixtures/speech-cut-original.json, docs/defects/fixtures/speech-cut-neighbour.json]
keys: [clipped, cut off, обрез, оборв, полуслов]   # words that tie an owner remark to this class (intake hook)
paths: ["pipeline/voiceover.py", "EDIT_*.json", "cmd:edit_build\\.py|draft_cut\\.py"]
                                    # where the class lives: path globs (fnmatch, relative to repo root; `**` allowed);
                                    # an entry starting `cmd:` is a regex matched anywhere in a Bash command line
area: edit                          # optional free label (YouTube_AI uses it); ignored by VULYK logic
---

# Clipped speech
<one paragraph: what the defect is>

## Owner quotes          (also accepted: "## Цитаты владельца")
- 2026-09-17 · video 2 · 10:04 — «verbatim owner words»

## Cause
## Never                 (also accepted: "## Нельзя")
- one line per forbidden action
## Allowed               (also accepted: "## Можно") — optional
## Revoked               — optional, for status: revoked: date + owner's words lifting it
```

Frontmatter parsing: simple `key: value` lines; list values are `[a, b, "c"]` (quotes optional, comma-separated).
Missing fields = empty. CRLF must be tolerated.

**Quote line**: under the quotes heading, a line matching `^- \d{4}-\d{2}-\d{2} ·`. Count = number of such lines.

**Effective status**:
- `block` only if `check:` is non-empty AND `fixtures:` lists >= 2 existing files. Otherwise it is reported as
  `text` with the reason (`block without check`, `block with <2 fixtures`).
- `revoked` cards are ignored by everything (no debt, no inject, no intake match).
- Fixtures: the first is the original case, the rest are neighbour-form negatives (the same complaint in a different
  shape). **Every fixture must make `check:` exit non-zero.** A fixture that passes = the gate is blind to it = red.

**Debt**: a card with >= 2 quotes, effective status != block, and at least one **new** quote = debt.
A quote is new if its line was committed after the commit that added `docs/defects/README.md`
(`git log --diff-filter=A --format=%ct -- docs/defects/README.md | tail -1` vs `git blame --line-porcelain` committer-time
of the quote line). Uncommitted quote lines and a library outside git count as new. Debt with no new quote =
"old debt": reported, not failing.

## 2. `scripts/defects-check.sh` (package A)

```
bash scripts/defects-check.sh               # library audit: debt + effective status + fixtures (each block card's
                                            # check run against each of its fixtures must exit != 0)
bash scripts/defects-check.sh <arg>         # the gate before showing work: debt, then every block card's check with <arg>
```
Exit: 0 green · 1 red (debt, a red check, a blind fixture) · 2 usage/no library. Output: one line per finding,
last line a verdict (`GREEN: N blocking checks` / `RED: …`). `DEFECTS_DIR` env overrides `docs/defects`.
Check output goes to a log under `${TMPDIR:-/tmp}`, not into the tree. Messages in English. Uses python for
parsing (python3 or python on PATH); no python → exit 2 with a clear message.

## 3. Hooks (package B)

Common: `bash`, read JSON from stdin with python (python3|python); if python missing or `docs/defects/` absent →
exit 0 silently. Never block (always exit 0). Output via the JSON form
`{"hookSpecificOutput":{"hookEventName":"<Event>","additionalContext":"…"}}`. Latency budget <= 200 ms median on
Windows Git Bash. State under `.claude/state/defects/` (gitignored — package D adds the ignore line).

**`.claude/hooks/defect-intake.sh`** — UserPromptSubmit. Input field `prompt`.
1. Strip harness/pasted blocks before matching: `<task-notification>…</task-notification>`,
   `<system-reminder>…</system-reminder>`, `<cross-session-message …>…</cross-session-message>`,
   `<pasted_content …>…</pasted_content …>` (closing tag may carry attributes), and fenced code blocks.
2. Trigger if the remaining human text has a timecode (`\b\d{1,2}:\d{2}\b`) OR a lexicon word
   (RU/UK/EN: опять, снова, я же говорил, я же казав, знову, не так, переделай, переделать, обрезал, again, I said,
   I told you, why did you, not what I asked) OR any non-revoked card's `keys:` (case-insensitive substring).
3. Output one additionalContext paragraph: "Looks like an owner correction. Matched classes: <ids or none>. Add the
   verbatim quote (date · material · place — «words») to the matching card in docs/defects/, or open a new card.
   If code can check the class, give it a failing `check:` with the original case and a neighbour-form fixture in this
   same work (a Tier 3-4 story that names the file → the next repair story)." Keep it <= 600 chars + ids.
4. No trigger → no output.

**`.claude/hooks/defects-inject.sh`** — PreToolUse, matcher `Edit|Write|MultiEdit|NotebookEdit|Bash`.
1. Candidate target: `tool_input.file_path` / `tool_input.notebook_path` (made relative to repo root), or for Bash
   `tool_input.command` (whole line).
2. Cards considered: effective status `text` (block cards are NOT injected — their check speaks; revoked never).
3. Match: a path glob in `paths:` matches the file path, or (Bash) any path glob matches any whitespace token of the
   command after stripping quotes, or a `cmd:` regex matches anywhere in the command.
4. Dedup key `session_id` + `agent_id` (empty for main) + card id → state file; already injected → skip that card.
   On SessionStart the same script is called with arg `reset` (package D wires it) and clears keys of that
   session_id when the SessionStart `source` is `compact` or `clear`.
5. Output: for each newly matched card: `<id> — <title>` then its Never lines, prefixed `✗ `. Total budget
   4000 chars; beyond it, list remaining card ids with paths `docs/defects/<id>.md`.

## 4. Manual wave dependency (package C)

A story may name `manual:<id>` in `blocked_by:` (e.g. `blocked_by: [manual:music, slug-03]`). It is satisfied when
`docs/specs/<slug>/manual/<id>` exists. `bash scripts/cycle.sh manual-done docs/specs/<slug> <id> [note]` creates
it (content: timestamp + note) and prints one line. When the earliest wave that still has todo stories has none
ready and at least one of them waits on an unsatisfied `manual:` blocker, `cycle.sh next`/`advance` must report a
dedicated state (e.g. `"state":"manual"` with `"manual":["music"]` and a human line "waiting on manual step
'music' - do it, then: bash scripts/cycle.sh manual-done … music") and the Workflow driver must stop cleanly
(stop file / final message) instead of dispatching a worker or skipping to a later wave. `wave-check.sh` must
accept `manual:<id>` entries in `blocked_by` (not report them as unknown story ids).

## 5. Wiring and shipping (package D)

- `install.sh`: `wire_hook <event> <script> [matcher] [arg]` — matcher written into the settings entry's
  `matcher`; arg appended to the command. Existing callers unchanged. Wire: UserPromptSubmit `defect-intake.sh`;
  PreToolUse `defects-inject.sh` matcher `Edit|Write|MultiEdit|NotebookEdit|Bash`; SessionStart
  `defects-inject.sh reset`.
- Ship `docs/defects/README.md` (skeleton, package A writes it): add `docs/defects` to the copy loop and a
  `shippable` rule shipping only `docs/defects/README.md` (VULYK's own cards, if any, never ship). The skeleton is
  install-semantics (never overwrites a host's index).
- `.gitignore` (VULYK's and `ensure_gitignore` for hosts): `.claude/state/`.
- VULYK's own `.claude/settings.json`: the same three wirings.
- `anomaly-scan.sh`: a new code when any SessionEnd hook command in `.claude/settings.json` (or the script it runs)
  calls `claude -p` — SessionEnd hooks get at most 60 s; name the hook. Follow docs/telemetry.md code conventions.
- `session-start-brief.sh`: if `.claude/settings.json` (+ `settings.local.json`) `enabledPlugins` has no key
  starting `litopys@`, and the constitution Profile has no row `Chronicle` with `none`, emit one line:
  "litopys (session chronicle plugin) is not installed here. Ask the owner once: install
  (`claude plugin marketplace add Black-coffe/litopys --scope project` then
  `claude plugin install litopys@litopys --scope project`) or decline (then add Profile row `| Chronicle | none (declined <date>) |`)."
- Installer edits: binary-safe (install.sh contains literal CR bytes — never rewrite it through a text-mode tool that
  normalizes line endings; use the Edit tool or python binary mode). Run `bash tests/telemetry.test.sh` after.
