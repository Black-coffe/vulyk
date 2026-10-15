# The watcher

`vulyk-watcher` is VULYK's own Claude Code mod. It runs beside Claude Code's built-in "You should know" mod, not
instead of it. Its source lives in `.claude/mods/vulyk-watcher/`, and VULYK's root `.claude-plugin/marketplace.json`
publishes it as marketplace `vulyk`.

## Install: once per machine
The mod is installed at user scope, so one install covers every hive on the machine. `install.sh` does it when
`claude` is on PATH and the mod is not installed yet:

    claude plugin marketplace add Black-coffe/vulyk
    claude plugin install vulyk-watcher@vulyk --scope user

On a machine that has it already, every run (a fresh install or `--upgrade`) brings it up to the release's mod, since a
user-scope GitHub install never refreshes itself:

    claude plugin marketplace update vulyk
    claude plugin update vulyk-watcher@vulyk --scope user

The mod's `plugin.json` version equals VULYK's `VERSION` (a test asserts it). `--check` prints `would install` or
`would update`; with no `claude` on PATH, or when the install or update fails, the installer prints a NOTE with the
commands and carries on. A hive's settings get no key for
the mod. Outside a VULYK hive (no `CLAUDE.vulyk.md` and no `scripts/cycle.sh` at the project root) the mod stays
silent: no question to the model, no note.

## What it does
Once per finished turn it asks the session's own model whether that turn broke one of the hive's constitution Laws
or repeated a class from the hive's own `docs/defects/` cards. The bar is high and the default answer is nothing. When
there is something to say it draws one note above the prompt. The model writes the note in the language you type in
and names that language in its reply; it judges by your own words, not by code, identifiers, tool output or an
expanded slash command.

## When it stays silent
- The project is not a VULYK hive.
- The turn made no tool call.
- A note is still on screen.
- The session already showed 3 notes.
- The session already asked 30 questions (forks): past that, no question and no note.
- The model found nothing, or the question failed (API error, empty reply, abort): no retry, no toast.
- A note with a tag already shown in this project (the last 200 tags are kept) is never shown again.

## Cost
Each question is one forked request over the already cached transcript, at most once per turn, at most 30 per session
and at most 3 notes per session. Its usage is visible only in the reply the mod gets; the session transcript does not
record it, so after every question the mod appends one row to the hive's `memory/stats/watcher.jsonl`: `ts`,
`session`, the four usage counts (`input_tokens`, `output_tokens`, `cache_read_input_tokens`,
`cache_creation_input_tokens`), `answered`, and `reason` when it was not. `scripts/token-report.py` prints the total
as its own `watcher:` line, every session in the window.

## The buttons
- **В defects** puts the note into your prompt draft inside a fenced block marked as the watcher's note, not yours.
  You send it, the Queen shows the note and asks whether it is a defect. Only your own words become a card's owner
  quote; the note itself never does.
- **Закрыть** dismisses the note. Labels exist in ru, uk and en; any other language gets English buttons.

## The off switch
One hive, one machine: put `{"enabledPlugins": {"vulyk-watcher@vulyk": false}}` in the hive's
`.claude/settings.local.json` (it is gitignored). The same key in `.claude/settings.json` turns it off for everyone
who works in that hive. Both outrank the user-scope install (measured on 2.1.300: the plugin reads `enabled=false` and
its hooks module is not loaded). The installer never writes this key and keeps your `false` on every upgrade. Off on
the whole machine: `claude plugin disable vulyk-watcher@vulyk`.

## How a note becomes a card
The mod writes nothing under `docs/defects/`. After you press «В defects» and confirm in your own words, the Queen
files the card through the normal intake path (`docs/defects/README.md`).

## Known limit
The GitHub marketplace serves what is on VULYK's default branch: a machine gets the mod only once a release carrying
`.claude-plugin/marketplace.json` is pushed there.
