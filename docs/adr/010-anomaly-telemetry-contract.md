# ADR-010: Anomaly telemetry - row schemas, anonymization, consent, and the print-never-send rule

- Status: proposed
- Date: 2026-09-15
- Spec: docs/specs/anomaly-telemetry (v0.14.0)

## Context

`docs/specs/anomaly-telemetry/plan.md` built one script, `scripts/telemetry.sh`, that records
local anomalies, bundles a week of them into an anonymized file, and prints (never runs) the
command that carries the bundle into the VULYK repository. Six of its decisions constrain code
that does not exist yet - the row shapes future detectors must fill, the anonymization rule any
new field must honour, the consent gate any new surface must read, the print-never-send
invariant any future automation must not cross, the Stop-hook scan bound any new detector must
stay inside, and who is allowed to commit the hook-written log. Each is recorded below with the
plan's own words.

**Not covered here:** the `install.sh` marked-block exception that lets `ensure_telemetry_row`
write the `| Telemetry |` row inside an already-marked Profile block. That decision already has
an ADR home - it is recorded as the "2026-09-15 (spec `anomaly-telemetry`)" amendment at the foot
of `docs/adr/005-installer-upgrade-contract.md` - and is not restated here.

## Decision

### A. Row schemas and the closed enum

Plan §Contracts, "Anomaly code enum" (`plan.md:70-80`) and "Local row" (`plan.md:85-87`):

> `{"v":1,"ts":"<UTC ISO-8601>","code":"<enum>","value":<number>,"threshold":<number>,"vulyk":"<semver>","tier":<0-4>,"model":"<fable|opus|sonnet|haiku|"">","agent":"<agent token|other|"">","spec":"<slug|"">","story":"<slug-NN|"">","ref":"<opaque dedupe id|"">"}`
> No `note`, no free text. `ref` is the idempotency key: `record` appends nothing when a row
> with the same `code` and a non-empty equal `ref` already exists. [...] **The log holds
> anomalies only (A18): no "measured, no anomaly" rows, no new code for them.**

Plan §Contracts, "Bundle row" (`plan.md:89-91`):

> `{"v":1,"code":"<enum>","value":<number>,"threshold":<number>,"vulyk":"<semver>","tier":<0-4>,"model":"<fable|opus|sonnet|haiku|"">","agent":"<agent token|other|"">","week":"<YYYY-Www>","hive":"<12 hex>"}`
> `week` = ISO week of `ts` [...]; `hive` = first 12 hex of sha256 of the repo toplevel path.
> `ts`, `spec`, `story`, `ref` are dropped.

The eight-code enum (`context_high`, `agent_prefix_high`, `agent_empty`, `council_rounds_high`,
`stage_long`, `driver_refused`, `driver_relaunched`, `scope_breach`) is fixed and printed by
`telemetry.sh enum`; `check` rejects any `code` outside it, on both the local and the bundle
side (`plan.md:91`).

**Options:** none recorded - the delta states the chosen shape only.

### B. Anonymization - codes and numbers only, hive hash, fixed agent token set

Plan §Consent row (`plan.md:121`):

> `on = /vulyk-evolve prints the send command, never sends`, and the row itself: "anonymized
> weekly anomaly bundle (codes and numbers only, docs/telemetry.md)".

Plan A20 (`plan.md:30`), the agent-token decision:

> the agent token set becomes a fixed list baked into `telemetry.sh` [...] instead of the hive's
> `.claude/agents/*.md` basenames, so an owner-added agent name can never travel: `record` and
> `bundle` both map anything outside the list to `other`, `check` rejects it on both sides, a
> repo-side suite case guards the list against drift [...]. Rejected: keeping runtime resolution
> and filtering at `bundle` against the repo's list - a hive has no copy of it. Rejected:
> hashing the custom name - still a per-owner value in the bundle, and unreadable by
> `/vulyk-evolve`.

Plan §Tradeoffs, round 6 (`plan.md:138`):

> **Rejected:** dropping the `agent` field from the bundle - the confirmed answer's enumerated
> fields do not name it, but A12 exists so `/vulyk-evolve` can tell a `cycle-clerk` at 55k from a
> `worker-code` at 55k, and `other` already covers every non-framework caste without text.

The `hive` token is `A4` (`plan.md:14`): `git rev-parse --show-toplevel` as printed, hashed -
"stable per machine, not portable", never a path or slug.

**Options:**
1. Fixed agent-token list baked into the script - chosen; identical on every machine, never read
   from disk, guarded against drift by a repo-side suite case.
2. Runtime resolution from the hive's own `.claude/agents/*.md` - rejected; the round-5 defect
   (an owner-added agent name is free text that leaves the hive and fails repo-side `check`).
3. Hash the custom agent name instead of dropping it - rejected; still a per-owner value, and
   `/vulyk-evolve` cannot read a hash.

### C. Consent - Profile row, default off, installer precedence, `/dev/tty` never stdin

Plan A10 (`plan.md:20`), the installer question rule (precedence, first match wins):

> (1) `--check` never asks and never writes the row; (2) `--telemetry on|off` flag, else
> `VULYK_TELEMETRY=on|off` env, sets the row without asking; (3) `--telemetry ask` /
> `VULYK_TELEMETRY=ask` asks even when the row already holds an explicit value; (4) on upgrade, a
> row already `on` or `off` is left as is, no question; (5) the row is missing [...]: when a
> terminal is reachable the explanation and one `Enable telemetry? [y/N]` question are printed,
> empty/EOF/anything but `y`/`yes` = `off`; when no terminal is reachable [...] no prompt, row =
> `off`. **Terminal access:** [...] the prompt reads from `/dev/tty`, guarded by
> `[ -t 0 ] || [ -r /dev/tty ]`, never from a stdin those pipelines consume.

Plan §Consent row (`plan.md:120-122`) and §Installer prompt (`plan.md:124-126`) fix the row
itself (`| Telemetry | off - ... |`, default `off`) and the exact prompt text and precedence.

Plan §Tradeoffs (`plan.md:131`):

> **Chosen for ask 6:** the question lives in `install.sh` (the one surface both fresh install
> and upgrade pass through) and reads `/dev/tty`, bootstrap only reports. **Rejected:** asking in
> both installer and bootstrap - two questions for one row, and the second one would silently
> overwrite an answer the owner already gave. **Rejected:** reading stdin - the installer's own
> pipelines consume it, and a piped `curl | bash` install would swallow the answer.

**Options:**
1. Single question in `install.sh`, read from `/dev/tty`, default `off` on any non-`y` answer or
   no terminal - chosen.
2. Ask in both `install.sh` and `/vulyk-bootstrap` - rejected; a second silent overwrite risk.
3. Read the answer from stdin - rejected; the installer's own pipeline loops already consume
   stdin, and a piped install would silently answer for the owner.

### D. Publish never sends

Plan §Goal (`plan.md:8`): "printing (never running) the command that carries the bundle into
the VULYK repository". Plan A1 (`plan.md:11`):

> `~/.vulyk/src` is deliberately NOT a copy target: it is `vulyk-update.sh`'s pull-only release
> cache, usually detached at a tag, so a commit there goes nowhere. If neither matches, the PR
> recipe is printed.

Plan §`publish` verb (`plan.md:102`): consent `off` prints and does nothing; consent `on` writes
the bundle locally, runs `check`, then either prints the local commit command or the fork/PR
recipe - "The script never executes `git push`, `git commit`, `git clone`, `gh repo fork` or
`gh pr create`." Plan §Tradeoffs (`plan.md:130`):

> **Rejected:** automatic push or a scheduler - forbidden by `vulyk-ship.md:11` and the brief's
> own "print the command" answer.

**Options:**
1. Print the local-commit or fork/PR recipe, execute nothing - chosen; matches the ship rule
   (`vulyk-ship.md:11`, "print the command, then stop; never wait") reused verbatim.
2. Automatic push or a scheduled sender - rejected; forbidden by the same ship rule and by the
   brief's own answer.
3. Copy into `~/.vulyk/src` as a send target - rejected; it is a pull-only, usually-detached
   release cache, so a commit there is unreachable.

### E. Stop-hook scan bound - a per-session seen-list, not a tombstone row

Plan A18 (`plan.md:28`), replacing A17's ledger rejection:

> a subagent is measured once per lifetime: `detect_agents` keeps `.vulyk/telemetry/seen/<sid>`
> [...], one line per subagent file [...], and skips python for any file whose byte size is
> unchanged, feeding the cached JSON to the same detectors [...]. Byte size is exact and
> content-derived, not an age guard. Why not a "measured, no anomaly" row in the log [...]: the
> log is committed and shared across worktrees and machines, while the subagent transcripts it
> would describe exist on one machine only; ~70 non-anomaly rows per session would dwarf the
> anomalies, need a new enum code, a `check` exception and a `bundle` filter, and skew
> `/vulyk-evolve`'s counts.

Plan §Contracts, "Seen-list" (`plan.md:93-94`): per-machine, per-session, gitignored under
`.vulyk/` (A5); TSV of `<basename>\t<byte size>\t<measure JSON>`; "Nothing under `.vulyk/` is
ever staged." Plan §Tradeoffs, round 4 (`plan.md:136`):

> **Chosen for round 4 (stories 11-12):** a per-session seen-list under `.vulyk/telemetry/seen/`
> caching `measure` output keyed by byte size (A18) [...]. **Rejected:** a "measured, no anomaly"
> tombstone row in the log - ~70 rows per session in a shared file, a new enum code, and
> `check`/`bundle`/evolve exceptions to hide it.

**Options:**
1. Gitignored per-session, per-machine seen-list keyed by byte size, under `.vulyk/telemetry/seen/`
   - chosen; the committed log stays anomalies-only.
2. A "measured, no anomaly" tombstone row in the committed log - rejected; would dwarf real
   anomaly rows, needs a new enum code, and new `check`/`bundle`/evolve exceptions.
3. A per-machine "last scanned" marker file (A17's original proposal) - rejected; does not bound
   an individual under-threshold subagent, only a session.

### F. Hook-written log ownership

Plan §Contracts, "Hook-written log ownership" (`plan.md:114-116`):

> `memory/stats/anomalies.jsonl` is written by the hook and committed only by `cycle.sh`: every
> verb that takes `--commit` [...] stages the log when it is modified or untracked, in the same
> commit. `ship-check` stage 03 reports `clean (hook-written stats pending: ...)` and passes when
> that is the only dirty path [...]. `scope-check` excludes only `memory/stats/anomalies.jsonl`
> from `out_of_scope` unless the story names it; `memory/stats/skills.json` counts like any other
> file (A18).

Plan §Descoped, round-3 Major 3 (`plan.md:157`):

> `memory/stats/skills.json` is written by the `PostToolUse` hook in every hive and is NOT
> cycle-owned: no `cycle.sh` verb stages it, `is_paperwork_path` does not list it, `ship-check`
> stage 03 fails on it like any other dirty path, and `scope-check` counts it. Consequence on the
> record: a session that used a skill leaves the ship gate NOT READY until the owner commits
> `skills.json` by hand.

**Options:**
1. `cycle.sh` stages `anomalies.jsonl` on every `--commit` verb; `skills.json` stays outside
   cycle ownership and under the scope gate - chosen (owner: "skills.json back under the scope
   gate", `plan.md:28`).
2. Make `skills.json` cycle-owned too (the round-3 review's option (a)) - rejected by the owner;
   contrary to the decision recorded in A18.

## Consequences

- **Easier:** a future detector or field reuses the closed enum, the fixed agent-token set, and
  the two row schemas without re-deriving what is allowed to leave a hive; a future publish path
  inherits print-never-send without re-litigating it against the ship rule.
- **Harder / accepted debt:** a new anomaly code, a new agent caste, or a new row field is a
  breaking schema change guarded by `check` on both sides - it cannot be added by a hive alone,
  only by a script change that ships to every hive. The seen-list is per-machine state with no
  retention policy yet (`plan.md:164`, round-4 Minor 7, still open).

## Invariants created

- Every local and bundle row has exactly the keys and order in §A; `check` rejects any other key
  set, any `code` outside the fixed enum, and any `agent` outside the fixed token set.
- No row, local or bundle, ever carries a path, a slug, a story name, an email, or free text -
  only enum codes, numbers, the fixed agent token set, and the hashed `hive` token.
- Telemetry defaults to `off`; the only place that asks is `install.sh`, reading `/dev/tty`,
  never stdin; `/vulyk-bootstrap` reports the value and never asks.
- `telemetry.sh` never executes `git push`, `git commit`, `git clone`, `gh repo fork`, or
  `gh pr create` - it only prints the command; `~/.vulyk/src` is never a copy or send target.
- A subagent transcript is measured for anomalies at most once per lifetime, via a gitignored
  per-session seen-list under `.vulyk/telemetry/seen/`, never via a "no anomaly" row in the
  committed log.
- `memory/stats/anomalies.jsonl` is staged only by `cycle.sh --commit` verbs; `memory/stats/skills.json`
  stays outside cycle ownership and under `scope-check`.

## Revisit when

- A new detector needs a field the local or bundle row does not carry: the schema change ships
  through this ADR's amendment, not a silent field addition in `telemetry.sh`.
- The owner asks for opt-out-by-default telemetry, or for an automatic send path: both cross an
  invariant recorded here and need a new decision, not a story-level change.
- The seen-list under `.vulyk/telemetry/seen/` grows unbounded across many sessions (round-4
  Minor 7, `plan.md:164`) and a retention rule is added.

## Amendments

(none yet)
