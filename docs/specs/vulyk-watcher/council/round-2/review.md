<!-- seat: review · model: claude-opus-5-5 · round: 2 · head: 65c0faa · pack: caa94daaf588 · attempt: 1 · recorded: 2026-10-15T19:39:07Z · verdict: BLOCK -->
VERDICT: BLOCK
MODEL: claude-opus-5-5

## Critical
None.
## Major
1. install.sh:1046 [ask 5] a VULYK `--upgrade` (or a release) must bring the machine's installed vulyk-watcher@vulyk up to the release's mod, or the loss of "обновляет" must be recorded in plan `## Descoped` with the owner's decision; today a listed plugin returns at once, so the machine keeps the first-installed copy forever while the hive only receives a `.claude/mods/vulyk-watcher` tree that nothing loads (plugin.json stays `0.1.0`, plan `## Descoped` is `(empty)`) - repro: stub `claude` whose `plugin list` prints `vulyk-watcher@vulyk`, `VULYK_CLAUDE=<stub> bash install.sh <hive> --upgrade` logs only `plugin list` (no marketplace update, no `plugin update`); local evidence that a user-scope GitHub install does not refresh itself: `jq -c '.plugins["litopys@litopys"][]|{scope,version}' ~/.claude/plugins/installed_plugins.json` shows user scope at 0.2.1 while `~/.claude/plugins/marketplaces/litopys/.claude-plugin/plugin.json` is 0.4.0.
## Minor
- Round-1 finding 1 (mod never loads) is fixed by the owner's machine-wide ruling: root `.claude-plugin/marketplace.json` validates, install/--check/no-claude/failed-install/kept-false paths behave as described (checked with a stub `claude`, real `marketplace list` format incl. CR), and the load and off-switch measurement is recorded in story -04; I did not re-run it against the real plugin registry.
- tests/telemetry.test.sh hit `timeout 540` again inside the new watcher block (last ok: "... the marketplace is added, then the plugin installed at user scope"); the idempotent, kept-false and failed-install assertions after it were not reached in this run.
- .claude/mods/vulyk-watcher is still OWNED and copied into every hive (tests and fixtures included), yet the copy that runs is the GitHub marketplace's; the hive tree is now dead weight that can drift from what runs.
- .claude/mods/vulyk-watcher/hooks/core.test.ts:54 the three ask-6 repros prove only the reply contract (`lang:` parsed, labels mapped), not that the model picks ru/de for those conversations; acceptable as recorded in story -04, untestable without the model.
- Ask 7 (release + rollout) is deferred to `/vulyk-ship` after GREEN by plan `## Plan deltas`; not judged here.
