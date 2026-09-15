# Telemetry inbox

Anonymized weekly anomaly bundles land here, one file per hive per week:
`telemetry/inbox/<ISO week>/<hive>.jsonl` (e.g. `telemetry/inbox/2026-W38/a1b2c3d4e5f6.jsonl`).
Every file must pass `bash scripts/telemetry.sh check` — CI runs it on every pull request. This
directory is distilled and cleared weekly by `/vulyk-evolve`. See [docs/telemetry.md](../../docs/telemetry.md).
