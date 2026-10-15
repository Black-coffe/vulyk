# The watcher

`vulyk-watcher` is VULYK's own Claude Code mod. It ships in every hive in `.claude/mods/vulyk-watcher/` and runs
beside Claude Code's built-in "You should know" mod, not instead of it. `install.sh` installs it, `--upgrade`
replaces the tree, and both keys are wired into the hive's `.claude/settings.json` (`extraKnownMarketplaces.vulyk`
and `enabledPlugins["vulyk-watcher@vulyk"]`).

## What it does
Once per finished turn it asks the session's own model whether that turn broke one of the hive's constitution Laws
or repeated a class from the hive's own `docs/defects/` cards. The bar is high and the default answer is nothing. When
there is something to say it draws one note above the prompt, in the language of your messages.

## When it stays silent
- The turn made no tool call.
- A note is still on screen.
- The session already showed 3 notes.
- The model found nothing, or the question failed (API error, empty reply, abort): no retry, no toast.
- A note with a tag already shown in this project (the last 200 tags are kept) is never shown again.

## Cost
Each question is one forked request over the already cached transcript, at most once per turn and at most 3 notes per
session. Its usage is visible only in the reply the mod gets; the session transcript does not record it.

## The buttons
- **В defects** puts the note into your prompt draft inside a fenced block marked as the watcher's note, not yours.
  You send it, the Queen shows the note and asks whether it is a defect. Only your own words become a card's owner
  quote; the note itself never does.
- **Закрыть** dismisses the note. Labels exist in ru, uk and en; any other language gets English buttons.

## The off switch
Per machine: put `{"enabledPlugins": {"vulyk-watcher@vulyk": false}}` in `.claude/settings.local.json` (it is
gitignored). `/plugin disable` writes user settings, and the project key wins over them. A `false` you set in
`settings.json` is kept by every upgrade.

## How a note becomes a card
The mod writes nothing under `docs/defects/`. After you press «В defects» and confirm in your own words, the Queen
files the card through the normal intake path (`docs/defects/README.md`).

## Known limit
Measured on build 2.1.300 in `claude -p`: the project-scope directory marketplace was reported as not registered, so
the mod may need one approval or a user-scope step in a hive. The rollout checks an interactive start.
