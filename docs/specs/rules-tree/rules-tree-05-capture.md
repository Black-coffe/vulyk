---
story: rules-tree-05
spec: rules-tree
status: done
returned: DONE
tier: 4
worker: worker-code
wave: 2
blocked_by: [rules-tree-01]
---

# Capture: the explicit phrase in every channel, pastes, the question window, side-agent notes

## Goal
After this story `.claude/hooks/defect-intake.sh` reads cards through `defects_lib.py` and hears the owner in every
channel. The explicit phrase «внеси в запрет / правило / разрешение» (RU/UK/EN, plan contract regex) is found in the raw
prompt before stripping, pastes included, and the hook tells the session to write the card now, verbatim. A correction
found in typed text is filed at once with a report line and «отмени»; one found only inside a paste gets a one-line
"are these your words?" instruction, unless the paste starts with `$VULYK_DICTATION_TAG`. A side-agent note
(`Here is a note offered by a side agent`) is stripped before every pass. A new `answer` mode runs on PostToolUse
`AskUserQuestion`: a chosen option prints a decision line, free text goes through the phrase and auto passes as the
owner's words. Wiring ships in `.claude/settings.json` and `install.sh` (PostToolUse block; the PreToolUse inject
matcher widened by unwire + rewire); `docs/hooks-reference.md` lists both defect hooks.

## Requirements
> Файлы должны попадать автоматически в разрешения, запреты, исходя из диалога, и также пополняться прямым текстом, когда пользователь говорит: «Вот это внеси в запрет, вот это внеси в правило, вот это внеси в разрешение».
> Они-то как будут фиксировать? Надо механику, наверное, усовершенствовать и улучшить.
> 7. Фраза «внеси в запрет / правило / разрешение» (RU/UK/EN) в любом канале, включая вставки, — сессия сразу пишет карточку дословно; автонаходка без фразы — пишет сразу со строкой-отчётом и «отмени».
> 8. Автонаходка во вставке становится цитатой только после «да» владельца; метка программы диктовки — необязательная настройка, убирающая переспрос.
> 9. Ответы владельца в окнах-вопросах слышны: дописанный текст — цитата, выбранный вариант — решение, не цитата.
> 10. Заметки бокового агента («Here is a note offered by a side agent») никогда не считаются словами владельца.

## Files
- .claude/hooks/defect-intake.sh
- tests/intake.test.sh
- .claude/settings.json
- install.sh
- docs/hooks-reference.md
- tests/telemetry.test.sh

## Non-goals
- Do not write cards from the hook: it prints one line; the session writes. Do not invent an owner quote for a card
  about side-agent notes (none exists; ask 10 is confirmed model text).
- Do not touch `defects-inject.sh` (story 04) or `defects_lib.py`; a missing function is `NEEDS_CONTEXT`.
- Do not add a config file for the dictation tag: the env var is the setting.
- Do not block or change exit codes: the hook stays silent on no library and fails open without python3.

## Map slice
- docs/specs/rules-tree/scout-machinery.md: Gotcha 5 (BLOCKS `113-122` stripped at `157-159`, triggers, ≤600-char
  message, no-library return `:155`, paste tests `intake.test.sh:124-126, 143-144`), Entry points (settings.json
  blocks; AskUserQuestion needs its own PostToolUse block), Tests (intake.test.sh fires/silent/stub/latency).
- docs/specs/rules-tree/scout-distribution.md: `wire_hook :825`, `unwire_hook :925`, wiring calls `:1358-1379`,
  `py_wire` idempotency ignores the matcher `:683-686`; shipped settings.json gets the entry too.
- docs/grill/2026-10-19-rules-tree.md Synthesis 3 (the AskUserQuestion probe: `tool_response.answers`, `tool_input`
  options; free text = answer parts matching no option label).
- docs/specs/rules-tree/plan.md `## Contracts`: Capture.

## Acceptance criteria
- [ ] Phrase: `внеси в запрет: …` typed, `запиши в правило …` inside `<pasted_content>`, UK `додай до дозволу …`, EN
      `add this to never: …` each print the "owner asks to file a <branch> card" line with the branch named; a prompt
      with the lexicon but no phrase does not print it.
- [ ] Typed auto-capture prints the "file the quote now … «отмени»" line (replacing today's "looks like a correction"
      context line); a correction only inside a paste prints the "ask the owner … whether these are their words" line;
      with `VULYK_DICTATION_TAG=[VoiceDrop]` a paste starting with `[VoiceDrop]` is treated as typed.
- [ ] Side-agent note: a prompt whose only correction word («опять») sits inside `Here is a note offered by a side
      agent: …` is silent (original case, today's two misfires); the neighbour form, the same preamble wrapping the
      explicit phrase and a card key, is silent too; the owner's own «опять» outside the note still fires.
- [ ] `defect-intake.sh answer` on a PostToolUse payload: an answer equal to an option label prints `[VULYK] decision:
      «<label>» on «<question>»` and nothing else; an answer with free text containing the phrase prints the file line
      with that text; free text with only lexicon prints the typed-auto line; a payload without `answers` is silent.
- [ ] `.claude/settings.json`: PostToolUse block matcher `AskUserQuestion` → `defect-intake.sh answer`; PreToolUse
      inject matcher = the plan's widened list; `jq -e .` passes.
- [ ] `install.sh`: `wire_hook PostToolUse defect-intake.sh AskUserQuestion answer` after `:1378`; the inject wiring
      is `unwire_hook` + `wire_hook` with the new matcher so an upgraded hive gets it; a scratch hive with the old
      matcher upgraded by `bash install.sh --upgrade` ends with the new matcher and the PostToolUse block
      (`tests/intake.test.sh` case; if `--upgrade` cannot run on a scratch hive, say so in `## Findings`).
- [ ] `docs/hooks-reference.md` gains rows for `defect-intake.sh` (UserPromptSubmit + PostToolUse `answer`) and
      `defects-inject.sh` (SessionStart `reset` + PreToolUse, matcher, 12-line budget).
- [ ] `tests/intake.test.sh` gains failing-first cases for each bullet above; the paste-stripping cases at `:124-126,
      143-144` are updated to the new paste behaviour, not deleted; latency case still green.

## Verification
`python -m py_compile .claude/hooks/*.py`
`git ls-files '*.sh' | xargs -n1 bash -n`
`git ls-files '*.json' | xargs -n1 jq -e . > /dev/null`
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh`
`bash tests/telemetry.test.sh`

## Implementation notes
- `.claude/hooks/defect-intake.sh`: Python half rewritten; cards via `defects_lib.load_cards` (local parser copy removed); phrase pass, typed/paste auto passes, side-agent strip, `answer` mode; output stays `hookSpecificOutput.additionalContext`, capped at 600 chars.
- Decision: the phrase scan reads the prompt with side-agent notes and harness blocks (task-notification, system-reminder, cross-session-message) cut, pastes and fences kept: harness text is model text, not an owner channel.
- Decision: the paste pass uses correction words and card keys, not timecodes, so a pasted log stays silent (`intake.test.sh` paste case at the old :143-144 kept, relabelled); typed text wins over a paste.
- Decision: several phrases in one prompt print one line per distinct branch; the phrase line takes precedence over the auto lines.
- `answer`: an option label found in the answer is removed and printed as a decision; the leftover free text (quotes and separators trimmed) goes through phrase then typed passes; the phrase line carries the owner's text.
- `.claude/settings.json`: inject matcher widened per plan; PostToolUse `AskUserQuestion` -> `defect-intake.sh answer`.
- `install.sh`: unwire + rewire of the inject only when settings.json still holds the exact 0.19 matcher (keeps hand-set matchers, second upgrade byte-identical, telemetry suite's "no second unwiring" holds); `wire_hook PostToolUse defect-intake.sh AskUserQuestion answer` after ysk-offer.
- `tests/intake.test.sh`: capture, side-agent, answer and `install.sh --upgrade` scratch-hive cases (upgrade case lives here, not in telemetry.test.sh); every new case fails against the HEAD hook (checked with a copy of the suite pointed at it).
- `docs/hooks-reference.md`: rows for `defect-intake.sh` and `defects-inject.sh`.
- `tests/telemetry.test.sh` (Queen ruling): `PRE_M` is the widened matcher; the broken-quote fixture and its `--check` repair count are 4 (the PostToolUse `answer` entry joins).

## Findings
- NEEDS_CONTEXT (worker, 2026-10-19): `tests/telemetry.test.sh` (not in `## Files`) pins the old wiring, so the
  verification line `bash tests/telemetry.test.sh` fails 12 checks after this story's intended change:
  `:1392` `PRE_M='Edit|Write|MultiEdit|NotebookEdit|Bash'` (used at `:1396`, `:1404`, `:1638`, `:1688`) must become the
  widened matcher `Edit|Write|MultiEdit|NotebookEdit|Bash|WebFetch|WebSearch|Agent|mcp__.*`; `:1722` and the
  `--check` count after it expect 3 defect entries to lose their closing quote, now 4 because the new PostToolUse
  `defect-intake.sh answer` entry also matches `/defect/`. Question: add `tests/telemetry.test.sh` to `## Files`
  (or a follow-up story) so these assertions move to the new wiring? Everything else is green: intake 67/67,
  defects/inject suites, syntax rows. Note: the whole verification exceeds the default 540 s budget
  (telemetry alone ~9 min); a close needs `VULYK_VERIFY_TIMEOUT` raised (1800 used).
- Queen ruling, 2026-10-19: `tests/telemetry.test.sh` joins `## Files` (plan delta). Move only its assertions that pin
  the old wiring (`PRE_M`, the defect-entry count) to the new matcher and the added `answer` entry; nothing else in it.
