---
story: anomaly-telemetry-10
spec: anomaly-telemetry
status: done
returned: DONE
tier: 3
worker: worker-code
model: sonnet
tracer: false
wave: 7
blocked_by: [anomaly-telemetry-08, anomaly-telemetry-05, anomaly-telemetry-07]
---

# Fix (review minors routed **worker**/**plan**): ADR-005 exception, the installer's silent drop, and the docs say only what runs

## Goal
Round 1 finding 11: plan A6 carves one exception to ADR-005's "never touches a filled Profile block" (the `Telemetry` row) and `ci.yml` already renames the case, but the ADR is not amended. Finding 10: `install.sh` `ensure_telemetry_row` returns silently when the Profile block has no markers, dropping an answer the owner just typed (ADR-005 D4.9 says warn). Findings 9, 10 (round 2) and 12 (round 1): `docs/telemetry.md` asserts the PR recipe "ends in an open PR when pasted as they are" though nobody pasted it, is silent on `bundle --out` holding two weeks, and story 05 claims the pseudo-terminal case "runs in the telemetry-inbox CI job" with no run on the branch. After this story the ADR records the exception, the installer warns with the row and the value it would have written, the public page describes the detectors as story 08 left them and claims nothing unobserved, and the empty learnings stub from `1a91924` is gone.

## Requirements
> При апдейте вулика либо при первой установке нужно, чтобы он в терминале спрашивал у пользователя, хочет ли он включить телеметрию, и объяснить, что это, и сказать, что по умолчанию она выключена.
> В публичном репозитории на GitHub написано, что логи собираются для улучшения VULYK, их можно запушить как pull request, раз в неделю логи чистятся и выходит апдейт.
> Правильно завернуто в фреймворк VULYK, чтобы не потерялось.

## Files
- docs/adr/005-installer-upgrade-contract.md
- install.sh
- .github/workflows/ci.yml
- tests/telemetry.test.sh
- docs/telemetry.md
- docs/specs/anomaly-telemetry/anomaly-telemetry-05-consent-profile-install.md
- memory/learnings/2026-09-14_222936.md

## Non-goals
- Do not change A10's precedence, the `/dev/tty` rule, `wire_hook`, or any install-smoke case except the one added below. The warning is the only behaviour change in `install.sh`.
- Do not rewrite a marker-less Profile (D4.9 stays); warn, never write.
- Do not touch `scripts/telemetry.sh`, the hook, `README.md`, `telemetry/inbox/README.md`, `vulyk-evolve.md`, `CLAUDE.md`; `ci.yml` only inside install-smoke.
- Do not run the PR recipe against a real fork (no push right, no network in the suite): the docs sentence is restated as not yet exercised, per the review's alternative condition.
- In story 05's file edit one sentence in `## Implementation notes` only; no other story file.
- Delete `memory/learnings/2026-09-14_222936.md` only if it is still an empty stub (frontmatter, no body); otherwise leave it and say so.

## Map slice
plan.md A6, A10, A15, A17 and `## Contracts` (`bundle`, installer prompt, consent row); ADR-005 D4.7-D4.11; `council/round-1/review.md` findings 9-12, `council/round-2/review.md` findings 9, 10, 12; story 05 `## Implementation notes` (`ensure_telemetry_row`, `telemetry_row()`); story 08 `## Implementation notes` (final `agent_empty` / `scope_breach` semantics, bounded-scan shape).

## Acceptance criteria
- [ ] ADR-005 gains a dated amendment (2026-09-15, spec `anomaly-telemetry`) stating the single exception to "filled marked blocks are untouched": the `| Telemetry |` row is appended when missing and its first value token replaced when the installer's question was answered (A6/A10); marker-less blocks stay D4.9 (warn only). Status line unchanged otherwise.
- [ ] `install.sh`: when the Telemetry row cannot be written because the constitution's Profile block has no `VULYK:PROFILE` markers, it prints one stderr line naming the row and the value (`warning: Profile block has no markers - not writing | Telemetry | <on|off> |; add the row by hand`) and exits as before. Suite (`tests/telemetry.test.sh`, install section): marker-less hive + `VULYK_TELEMETRY=on` asserts the warning text and an unchanged file; `ci.yml` install-smoke gains the same no-terminal case.
- [ ] `docs/telemetry.md`: (a) the cross-machine sentence no longer claims the nine lines were pasted; it says the recipe is generated and not yet exercised against a real fork; (b) one sentence states that `bundle --out` without `--week` writes both default weeks into the one file and `--week` is required to get a single-week file for hand copying; (c) the detector table describes `agent_empty` as recorded on `SessionEnd` only and `scope_breach` as one row per story, matching story 08's notes; (d) the `VULYK_ANOMALY_*` table from story 07 is unchanged.
- [ ] Story 05 `## Implementation notes`: the "it runs in the telemetry-inbox CI job" sentence is restated as "not observed green on this branch; skipped locally".
- [ ] `memory/learnings/2026-09-14_222936.md` is deleted if empty (see Non-goals).

## Verification
`bash tests/telemetry.test.sh`

## Implementation notes
- `docs/adr/005-installer-upgrade-contract.md`: appended `## Amendments` with a dated
  2026-09-15 entry naming the Telemetry-row exception inside already-marked Profile blocks;
  Status line left as `proposed`.
- `install.sh` `ensure_telemetry_row`: the two silent `grep ... || return 0` marker checks
  became one `if` that also prints `warning: Profile block has no markers - not writing |
  Telemetry | <on|off> |; add the row by hand` to stderr before returning; write path,
  `--check` path and every other case unchanged.
- `tests/telemetry.test.sh`: new case between the `--check` case and the no-terminal block -
  installs a hive, strips the Profile markers, runs `--upgrade` with `VULYK_TELEMETRY=on`, and
  asserts the warning text and a byte-identical file.
- `.github/workflows/ci.yml`: new install-smoke step right after the existing D4.9 marker-less
  warning step, same shape but non-interactively driven (`VULYK_TELEMETRY=on`, no `script`/tty)
  to match the "no-terminal case" the acceptance criterion names.
- `docs/telemetry.md`: `agent_empty` row now says "recorded on `SessionEnd` only"; `scope_breach`
  row says "one row per story (first breach wins)"; added a sentence on `bundle --out` covering
  both default weeks without `--week`; the PR-recipe sentence now says "meant to end in an open
  PR ... not yet exercised against a real fork (no push right, no network in the suite)" instead
  of asserting it was run. `VULYK_ANOMALY_*` table (story 07) untouched.
- Story 05 `## Implementation notes`: the "it runs in the telemetry-inbox CI job" clause
  replaced with "not observed green on this branch - skipped locally"; no other line touched.
- `memory/learnings/2026-09-14_222936.md` deleted - it held only frontmatter and the stub
  comment, no body.
- Verified: `bash tests/telemetry.test.sh` - 189 checks, 0 failed. Also green:
  `git ls-files '*.sh' | xargs -n1 bash -n`, `python -m py_compile .claude/hooks/*.py`,
  `git ls-files '*.json' | xargs -n1 jq -e .`, and `.github/workflows/ci.yml` parses as valid
  YAML (`yaml.safe_load`); the new install-smoke step itself was not run (no GH Actions runner
  here) - it mirrors the suite case verified above line for line.

## Findings
