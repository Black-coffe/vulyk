# Telemetry inbox

Anonymized weekly anomaly bundles land here, one file per hive per week:
`telemetry/inbox/<ISO week>/<hive>.jsonl` (e.g. `telemetry/inbox/2026-W38/a1b2c3d4e5f6.jsonl`).
Every file must pass `bash scripts/telemetry.sh check` — CI runs it on every pull request. Weekly,
`/vulyk-evolve` in this repo runs `bash scripts/telemetry.sh inbox`: it distils every bundle
here into per-week, per-code counts for that run's CHANGELOG entry and stages the emptied week
directories for deletion (this README stays) in the same changeset a maintainer commits.
See [docs/telemetry.md](../../docs/telemetry.md).
