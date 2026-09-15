---
story: anomaly-telemetry-14
spec: anomaly-telemetry
status: done
returned: DONE
tier: 3
worker: worker-code
model: opus
tracer: false
wave: 10
blocked_by: [anomaly-telemetry-13]
---

# Fix (round-5 opus seat, ask 3): the agent token set is fixed in the script, never read from the hive

## Goal
`telemetry.sh agents` builds the agent token set from the hive's own `.claude/agents/*.md` basenames, and ADR-005 names that directory as exactly where owners add their own agents. So an owner-chosen filename is a legal token on the hive side: the seat added `.claude/agents/worker-frontend.md`, ran `record agent_prefix_high 60000 50000 --agent worker-frontend` then `bundle --out`, and the bundle row carried `"agent":"worker-frontend"` verbatim - free text leaving the machine, contradicting the confirmed "Свободного текста в отправляемом файле нет вовсе" - while the VULYK-repo-side `check` rejected the same file (`agent is not in the agent token set`), which would fail the `telemetry-inbox` CI job and abort `telemetry.sh inbox` for every hive that week. After this story the token set is a fixed list baked into `scripts/telemetry.sh` beside the enum (A20), identical on every machine; anything outside it becomes `other` at `record` time and again at `bundle` time (so rows already in a local log with a custom name bundle clean), and `check` rejects anything outside it on both sides.

## Requirements
> Логи максимально обезличены: контекстные аномалии, перебор по времени, избыточность VULYK, никаких личных файлов.
> только коды и числа, хайв как хэш: в строке только код аномалии из фиксированного списка, число, порог, версия VULYK, тир, алиас модели, неделя, и хэш хайва (sha256 от пути, обрезанный, необратимый). Свободного текста в отправляемом файле нет вовсе.

## Files
- scripts/telemetry.sh
- tests/telemetry.test.sh
- docs/telemetry.md
- README.md

## Non-goals
- Do not change either row schema, the key order, the enum, or what `check` rejects beyond the source of the agent set; the 12/10 keys and their order stay (`## Contracts`).
- Do not read `.claude/agents/` anywhere in `telemetry.sh` after this story - not as a fallback, not to "extend" the baked list, not in the VULYK repo either. The suite case (below) is the only place the directory is consulted, and only to prove the list has not drifted.
- Do not touch `record`'s dedupe, `scan`, `detect_agents`, the seen-list, `bundle_emit`'s separator loop (story 13), `publish`, `inbox`, `handoff.py` or the hook. `measure` keeps printing the raw `agentType`; mapping happens in `record`/`bundle` only.
- Do not fold round-5 review Major 2 (`record` writes `"ts":""`) or Minors 3-8 - the verdict was PASS; the Queen routes them.
- `docs/telemetry.md` and `README.md`: change only a sentence that says the agent set is read from `.claude/agents/` or "the hive's agents"; if neither file says so, do not touch them and say so in `## Implementation notes`. No new sections.
- Do not rewrite existing suite cases; add beside them. Do not add a hash or any other encoding of a custom agent name - `other` is the whole answer.

## Map slice
plan.md `## Contracts` ("Agent token set" as amended by A20, "Local row", "Bundle row", `record`/`bundle`/`check` verbs); `council/round-5/opus.md` ASK 3 (the reproduction with `worker-frontend`); story 01 `## Implementation notes` (where `agents` and the enum live) and story 13 notes (US-separated emitter; the heredoc-backslash trap in this suite - build `\t` with `chr(92)`); memory/map/scripts.md "Key types / contracts".

## Acceptance criteria
- [ ] `telemetry.sh agents` prints the baked list - `council-haiku council-opus council-sonnet cycle-clerk drone-coverage drone-docs drone-scout lead-architect lead-review librarian queen-planner worker-code worker-test` and `other`, one per line - identically in a hive with no `.claude/agents/` directory, in a hive with an extra `worker-frontend.md`, and in the VULYK repo; no `ls`/`find`/glob over `.claude/agents` remains in the script.
- [ ] Reproduction closed: in a hive with `.claude/agents/worker-frontend.md`, `record agent_prefix_high 60000 50000 --agent worker-frontend` writes a local row with `"agent":"other"`; a local row hand-written with `"agent":"worker-frontend"` bundles as `"agent":"other"`; a `--agent worker-code` row still records and bundles as `worker-code`; `check` on that bundle exits 0 from the hive and from the VULYK repo alike, and exits 1 with `agent is not in the agent token set` on a bundle line whose `agent` is `worker-frontend`.
- [ ] Suite: one case for the three rows above (`other` at record, `other` at bundle, framework name unchanged) plus `check` both ways; one case run from the VULYK repo asserting `telemetry.sh agents` minus `other` equals the sorted basenames of the repo's `.claude/agents/*.md` (the drift guard - adding a framework agent means editing the list, and this case says so in its failure message). Every pre-existing case unchanged and green.
- [ ] If `docs/telemetry.md` or `README.md` described the set as read from the hive's agents directory, the sentence now says it is a fixed list shipped in `telemetry.sh` and that any other agent is reported as `other`.

## Verification
`bash tests/telemetry.test.sh`

## Implementation notes
- `scripts/telemetry.sh`: `agent_set()` now prints a fixed `AGENTS` string (13 framework names + `other`) baked beside `ENUM`/`MODELS`; the `.claude/agents/*.md` loop is gone. `record`, `bundle_emit` and `check` are untouched - they already mapped through `agent_set`, so `other` at record time, `other` at bundle time and the `check` rejection all fell out of the one change.
- `tests/telemetry.test.sh`: case 19 (a fixture hive carrying `.claude/agents/worker-frontend.md` + a hive with no agents directory: same list; `--agent worker-frontend` records `other`, `--agent worker-code` survives, a hand-written `worker-frontend` local row bundles as `other`, `check` green from both roots, and a `worker-frontend` bundle line red from both roots with the set message) and case 20 (drift guard comparing the baked list minus `other` to this repo's basenames, plus a grep that no non-comment line reads `.claude/agents`). Pre-existing cases untouched; 230 checks, 0 failed.
- `docs/telemetry.md` "The agent token" and `README.md`'s bundle-row paragraph both described the token as a `.claude/agents/*.md` basename; both now say fixed list shipped in `scripts/telemetry.sh`, anything else `other`.
- Surprise: the first attempt at the bundle assertion compared a space-joined `jq -r .agent` line and failed with visually identical strings (a trailing-whitespace artefact of the `tr`/`sed` join under Git Bash); replaced with a per-line `sed -n "Np"` helper, mirroring case 18's `pair()`.
- `scope-check` reports `docs/specs/anomaly-telemetry/plan.md` out of scope: it was already modified in the working tree before this story started, not by me.

## Findings
