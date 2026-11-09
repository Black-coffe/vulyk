# Mass audit fixes (plan)

**Tier:** 4 · **Spec slug:** `mass-audit-fixes` · **Brief:** [brief.md](brief.md)
**Model profile:** opus-builds
**Governed by:** ADR-032 (proposed, the design of asks 12-14 and the `stamp-red --baseline` escape; this plan
follows it and does not redesign), ADR-025 (red receipt), ADR-001 D1 (stage 02 markers), ADR-013 (scope rule D5,
D7), ADR-015/020 (families, profiles), ADR-029 (gate split); cards `safeguard-bypassable-or-late`,
`host-internals-in-public-repo`, `shell-needs-gnu-or-bash4`, `test-gate-one-long-limit`; `docs/cycle.md`.
**Depends on:** `main` at 6cbcb46 (0.49.0 plus the contributor's P9/P10/X-07 fixes, merged 2026-11-09). Every
story stacks on those commits; none rewrites them.

## Goal
Close every hole the private audit (2026-11-08) left open after the merge, in one release: the per-story gate
stops trusting the file the worker edits (gate blocks come from the story's approved commit, a close is a
commit), a `block` card's check runs on real work and its Never lines are shown again, the Tier 2-4 approval
stop becomes a refusal in `cycle.sh` and ship-check, the hook layer survives a path with a space and a py-only
Windows box, the installer wires every hook into an existing `settings.json` and stops trusting manifest paths,
redaction and the handoff dump lose their known gaps, and the contributor's seven partial fixes are finished.
Fifteen stories in four waves, grouped by the file they must touch (cycle.sh, install.sh, each hook, each test
suite) so that no two stories in a wave share a path. Stories name target behaviour and the failing test; none
describes how to exploit the old behaviour (public repo).

## Assumptions
<!-- Law 1: every assumption the plan rests on, stated so the owner can veto it at the approval stop. -->
- **Ask 15's four files** were filled into story 14 by the Queen from the private list; all four are docs, none
  is named by another story. The name stays out of the spec; `scripts/leak-check.sh` finds it.
- **Ask 16 was added by the Queen at planning**, not by the owner: trace-check found none of the 31 quotes
  because `brief_asks` reads a wrapped `## Asks` item as its first line. The brief's asks were put on one line
  each (same words) so this plan traces; story 15 fixes the parser. The owner confirms or drops ask 16 at approval.
- **Known wave-check noise, accepted:** `verify-gap` on story 13 (prose files; `tests/maintenance.test.sh` reads
  `CLAUDE.md` through `$SRC/`, so wave-check does not see the overlap). wave-check exits 0.
- **Open recon questions closed by the Queen's grep:** the "already done" text is asserted only in
  `tests/council.test.sh` (story 05 owns it); the literal hook command string is asserted only in
  `tests/telemetry.test.sh` (story 04 owns it); `tests/handoff.test.sh` reads the SessionEnd command's last
  path segment, which the quoted form keeps.
- **Three audit findings get no code change, by their own verifiers:** O2 (the step barrier is the gate-split
  contract; only within-step ordering is compatible and it changes no wall time), O7 (ADR-013 D7's documented
  tradeoff; moving constitution sections is architecture, not a fix), O8 (the proposed bash gate skips
  `remember_window`, so it is not behaviour-preserving). Story 13 records all three in `docs/hooks-reference.md`
  / `docs/cycle.md` as measured, accepted costs. The owner may send any of them back as a story.
- **S3 (phrase inside a paste) is a design choice**, taken as: a filing phrase found only inside a paste or quote
  emits the "ask the owner whether these are their words" line, not the write-now line, unless the paste starts
  with the dictation tag. Story 03 carries it; veto here if pasted orders should keep filing verbatim.
- **S6 (mod install pulls the marketplace head):** the Claude CLI's support for a ref on `plugin marketplace add`
  is unverified. Story 11 skips `plugin update` when the installed plugin version already equals the release and
  pins a ref only if the CLI's `--help` offers one; otherwise it prints `mod: marketplace head, not pinned`.
- **I3 (retry family):** when both high families judge the round (Tier 4 under `sonnet-builds`: the top model
  reviews, Opus reviews), no non-judging high family is left; the retry runs on Opus and the driver result
  records `retry_same_family`, which story 13 names as a gap in CLAUDE.md and `docs/model-cascade.md`.
- **D2 reaches every spec:** a `done` story with no `story(<id>):` commit counts as in-progress for `status`.
  Shipped specs are unaffected (`next` is `shipped` first). No unshipped older spec with hand-marked stories is
  known; if `status` shows one after wave 1, the owner closes it through `close-story` or marks it in the plan.
- **Mid-build rule (ADR-032 D1 is live from wave 2):** after story 05 lands, a story in this spec whose
  `## Files`, `## Verification` or `red:` the Queen changes (NEEDS_CONTEXT) must be committed as
  `vulyk(mass-audit-fixes): revised <story-id>` before its worker runs `close-story`, or the close refuses with
  exit 4. The repair story is covered (`repair round N` is a paperwork subject).
- **Verification lines of several test parts pause and resume.** Stories 05, 08 and 10 name four or five parts;
  under the 540 s call budget `close-story` pauses (exit 7) and resumes on rerun. Accepted over splitting the
  stories, which would cost a wave each.
- **The `Defect hooks` row runs three suites in one line** (~170 s measured: defects 44 s, intake functional
  88 s, inject 16 s, plus intake latency). If it crosses 300 s, the row is split in CLAUDE.md as a plan delta.
- **X-07's CI step is not reachable by a `## Commands` cell**; `ship-check`'s `ci` line is its gate (the macOS
  job must be green before release).
- **`.claude/hooks/defects_lib.py` is in story 01's files** in case `--files` needs a path matcher there; it may
  stay untouched.
- **The `Handoff` row and the I7 gap note push CLAUDE.md over 7168 bytes** unless trimmed; story 13 trims
  wording in *Models and effort* without changing a rule, and `tests/cycle.test.sh --part bsd` holds the cap.
- **No scout was sent.** The textual `not shown` counts in symbol-map.txt were resolved by grep on single files
  (Grep over a directory is blind on this box); the open questions are closed above.
- **Coverage (drone-coverage, brief + plan only):** no ask absent. Its partials on asks 1, 3 and 7 are carried in
  stories 01, 10 and 03 (card files only and the no-cards exit; `fm_field` + `blockers_of` and the three
  `status --json` fields; «снова» / "again" stay out), which it does not read. Two audit IDs are both called S5:
  the hooks-finder S5 (= I8) is story 02, the shell-finder S5 (paperwork commits by pathspec) is story 08. Work it
  found with no ask of its own: the G4 regression fixture in story 08 (G4 was closed by the merge; the fixture
  only pins it), `stamp-red --baseline` in story 10 (ADR-032: the ADR-025 stash escape is refused by git-guard,
  so ask 12's design needs a replacement), the CITATION.cff bump in story 13 (audit finding I9, ask 11). Ask 11's
  "every finding is fixed" is narrowed by the O2/O7/O8, S6 and I3 lines above; the owner may send any of them back.

## Stories
<!-- One line per story, grouped by wave; the story files are the truth, this is their index. -->

**Wave 1** (six workers, disjoint files)
- `mass-audit-fixes-01-defect-gate` — asks 1, 13 (hook half + `defects-check.sh --files`), 11 (I1, O3): the
  inject hook exits before Python when no card can match, shows `block` cards as text; the gate grows `--files`.
- `mass-audit-fixes-02-git-guard` — asks 5, 11 (S4, S5/I8, S6, P5, the P10-01 class): launcher list, UTF-8
  stdin, forced `checkout -b`, variable story path, continuation/`env` path/`$()` verb, status timeout = deny.
- `mass-audit-fixes-03-intake-typed-text` — asks 7, 11 (S3): a bare clock time is not a correction; a filing
  phrase only inside a paste asks instead of writing.
- `mass-audit-fixes-04-install-wiring` — asks 6, 11 (I2, S1/P1, P7): every hook wired into an existing
  `settings.json` with its `timeout`, quoted `"$CLAUDE_PROJECT_DIR"` form written and migrated, JSON written LF
  / UTF-8 / trailing newline.
- `mass-audit-fixes-05-close-story-trusts-git` — ask 12 (ADR-032 D1, D2; G1, G2, I6): gate blocks from the
  approved commit, a close is a commit; the cycle and council fixtures get the helper. `model: opus`.
- `mass-audit-fixes-06-model-families` — ask 11 (I3, I7 in `docs/model-cascade.md`, O6): the retry never runs
  on the family that judges it; the model brief runs `top-model.sh` once and prints only what differs.

**Wave 2**
- `mass-audit-fixes-07-redact-and-handoff` — asks 2, 10 (dump guard, `$VULYK_PY`), 11 (S2 rest): the rest of
  the secret names, quoted values to the closing quote, parity with the handoff fallback, no repointing of
  `index.json` away from an enriched handoff.
- `mass-audit-fixes-08-cycle-gates` — asks 14, 13 (close-story call site), 11 (I4, G3, G4 fixture, G8, S5):
  `briefed --go`, `branch`, ship-check stage 02; the block-card gate in `close-story`; same-wave scope rule;
  `red-seals-impl`; paperwork commits by pathspec.
- `mass-audit-fixes-09-update-and-scan` — asks 4, 11 (P3, S2-shell, O4): the update check without `sort -V`,
  a forced tag fetch with an error line, the cache's remote checked against the declared origin, one awk over
  the journals in the SessionEnd scan.

**Wave 3**
- `mass-audit-fixes-10-verify-runner` — asks 3, 8, 9, 11 (G5, G6, ADR-032 D5, I9 whitelist): the resume mark
  hashes expanded entries, `git add` failures refuse, `stamp-red --baseline`, the load sample before the step,
  the macOS branch on CI, quoted front-matter values and `status --json` escapes.
- `mass-audit-fixes-11-install-safety` — ask 11 (S1-shell, S4-shell, S6-shell, S7-shell, O1, O5): manifest
  paths with `..`/`/`/`\` are skipped, the owner's `model` pin is kept, the mod is not refreshed past the
  release, `memory/map/` does not ship, one-pass copy, lazy `shipped_blobs`.
- `mass-audit-fixes-12-hooks-portability` — ask 11 (P4, P6, P8): executable bits in the index for every wired
  hook, UTF-8 output in the two report scripts, LF `skills.json`. `model: haiku`.

**Wave 4**
- `mass-audit-fixes-13-docs-and-adrs` — asks 10 (`## Commands` row), 12, 14, 11 (I5, I7, I9, the three
  accepted costs): ADR-032 accepted, ADR-025 and ADR-001 amended, CLAUDE.md row + gap note, `lead-review`
  loses "cannot occur", worker/build/plan/ship prose follows the new verbs, CITATION.cff bumped.
- `mass-audit-fixes-14-client-name-scrub` — ask 15: the client's folder name leaves the four public files.
  `model: haiku`. `## Files` filled by the Queen before approval.
- `mass-audit-fixes-15-asks-wrapped-items` — ask 16: `brief_asks` joins a wrapped item's indented continuation
  lines, so trace-check and `cycle.sh` read the whole ask. Blocked by story 10 (`lib.sh`, `tests/cycle.test.sh`).

## Contracts
<!-- Interfaces that cross a story boundary, agreed here at plan time. -->
- **D1 (story 05 writes; every later close in this spec obeys).** `approved_rev <story>` walks
  `git log --format=%H%x09%s -- <story>` and returns the first commit whose subject matches
  `^vulyk\(<slug>\): ` or `^chore\(vulyk-<slug>\): ` (the set today: `plan`, `asks revised`, `briefed`,
  `repair round N`, `revised <story-id>`). Compared blocks: `verify_of`, `files_of`, `fm_red` of
  `git show <sha>:<story>` against the working copy. Differ → exit 4
  `story blocks differ from the approved version (<sha7>): <blocks>`. No baseline at Tier 3-4 → exit 2
  `no approved version in git for <story>: commit the plan or a revision first`; Tier 1-2 or no tier → one
  stderr note. Runs in `close-story` after the `returned:` check and in `stamp-red` before anything.
- **D2 (story 05).** The close commit is `story(<id>): <title>` (`chore(story-<id>): ...` conventional).
  `cmd_status` reads `git log --format=%s -- <spec>/` once and counts a `done` story as done only with such a
  subject; otherwise it lists it as in-progress (so `wave_stories` keeps it; the driver is unchanged). A `done`
  story with a clean tree and no close commit takes the self-marked path and, green, commits with
  `--allow-empty`, journal `closed over a hand-committed tree`.
- **D3 (story 01 provides, story 08 consumes).** `bash scripts/defects-check.sh --files <path>...`: for every
  card with `status: block` and a `check:`, run the check once per given file matching one of its glob
  `paths:` (`cmd:`/`tool:` entries match no file). Exit 0 green; 1 red with one line per red
  `<ref> fails on <file>: <first output line>`; 2 no python or no parser. `close-story` calls it after
  `red_gate`, before prompt-check, only when some card file says `status: block`, with `## Files` expanded by
  `git ls-files -co --exclude-standard -- <entry>`; red → exit 4 `defect card <ref> fails on <file>`; 2 →
  exit 2 `defect gate could not run`. The hook treats every non-revoked card as text.
- **D4 (story 08 writes; story 13 documents).** `cycle.sh briefed <spec> [--go] [--commit]`: Tier 2-4 with no
  `**Approved:**` and no `--go` → exit 2 `Tier <N> plan needs **Approved:** or an explicit --go`. With `--go`
  the line reads `**Briefed:** via grill (--go), <owner>, <date>` (or `via grill (assumed, --go), ...`); on an
  existing line `--go` re-stamps it, journal `briefed --go recorded`. `cmd_branch` applies the same rule.
  ship-check stage 02 at Tier 2-4: `**Approved:**`, or a `**Briefed:**` containing `--go`, or any marker when
  `**Shipped:**` is set; else `fail 02 "plan: Tier <N> was briefed without approval or --go - run cycle.sh
  briefed <spec> --go --commit if the owner opted out"`.
- **D5 (story 10 writes; story 13 documents).** `cycle.sh stamp-red <story> --baseline`: copies `RED_IMPL`
  aside, writes each to its `HEAD` content (a file new since HEAD is removed), stamps, restores in a trap on
  every exit. No `git stash`.
- **Hook command form (story 04 writes; story 12's test reads).** Every hook entry in `.claude/settings.json`
  and every entry `install.sh` writes is `"$CLAUDE_PROJECT_DIR"/.claude/hooks/<name>.sh [arg]`; `py_wire`'s
  sibling matcher accepts both the quoted and the old unquoted head, and `--upgrade` rewrites an old-form
  entry in place (`rewire <name>` in the log). A SessionEnd entry carries `"timeout": 30` (added on upgrade when
  missing). `install.sh` into an existing `settings.json` wires every hook `settings.json` ships and prints one
  line per hook: `wire <event> <name>` or `kept <event> <name>`.
- **Python launcher order in hooks (stories 02, 07; already in intake/inject):** `$VULYK_PY` when set, then
  `python3`, `python`, `py`; an interpreter that exits 0 or 1 ran. Hook stdin is read as bytes and decoded
  UTF-8 (BOM tolerated) before `json.loads`.
- **Redaction parity (story 07):** every keyword or shape added to `scripts/redact.sh` is added to
  `handoff.py`'s `_REDACT_FALLBACK` in the same story, and the parity rows in `tests/handoff-hooks.test.py`
  run both on the same fixtures.
- **Retry model (story 06):** `RETRY` = the first of `[TOP, 'opus']` that is not the family judging this
  round (`REVIEW` when passed, else `opus` at Tier 3; `TOP` at Tier 4 for the top reviewer); none left →
  `opus` and the run result gains `retry_same_family: true`.
- **Scope rule (story 08):** scope-check excludes a sibling's declared paths only when the sibling is not
  `done` and has the same `wave:`; both `git diff --name-only` calls pass `--no-renames` (already so after
  P9-08; the story adds the G4 fixture).
- **Rejected alternative:** one story per finding (47 stories, each with its own worker), or one story per
  audit lens. Rejected because the findings pile onto the same seven files (`cycle.sh`, `install.sh`,
  `git-guard.sh`, `cycle.test.sh`, `council.test.sh`, `telemetry.test.sh`, `maintenance.test.sh`); stories are
  cut by file and wave instead so that each wave's `## Files` are disjoint and no file is serialised more than
  the three waves it needs. ADR-032's own rejected options (trust HEAD, merge-base, a sealed hash, a `closed:`
  line, keep injecting block cards) stand as written there.

## Integration gate
`bash tests/full-suite.sh`

## Descoped

*(empty)*

## Plan deltas

- 2026-11-09, owner choice on story 04's reading: ask 18; story 17 (wave 4, after story 11 on the same files) makes
  `--upgrade` name every unwired shipped hook with its wiring command. **Rollout to-do (ship):** per hive, wire the
  hooks the old installer dropped; leave a hook the hive owner removed on purpose.

- 2026-11-09, owner mid-build: «Почини драйвер сразу, не жди конца сборки». Ask 17 added to brief.md; story 16
  (`mass-audit-fixes-16-driver-claim-proof`, wave 2, files `vulyk-cycle.js` + `tests/driver.test.sh`, disjoint from
  story 08) proves a garbled `--claim` line by a short re-claim. The long `status` relay through the Haiku clerk
  stays a follow-up.

- 2026-11-09, story 08 NEEDS_CONTEXT: the D4 `branch` refusal breaks `tests/solo.test.sh`'s Tier 2 fixture (no
  `**Approved:**`), so that suite joins story 08's `## Files` (the `mkfix` line only) and `## Verification`.

- 2026-11-09, story 06 NEEDS_CONTEXT: one `top-model.sh` call for the brief needs a combined mode, so
  `scripts/top-model.sh` joins story 06's `## Files` (additive `--brief`, no other mode changes); the economy
  AC follows the Goal's rule (no family left: retry on opus, `retry_same_family: true`), a second same-family
  case beside Tier 4 under `sonnet-builds` (narrows the I3 assumption the owner saw).

<!--
The lines below are the cycle's confirmation markers (docs/cycle.md); each placeholder is replaced by
the command or script that owns it, and scripts/ship-check.sh reads them all. Approved is the owner's
word, the stop at Tier 2-4; Briefed is written by `cycle.sh briefed` instead, at Tier 1 ("via
mini-brief"), with `--go`, or in no-question mode ("assumed"). Either closes stage 02. Council and
Checked close stages 04+05 together: a GREEN council row is enough on its own, and Checked is the
owner's override in either direction, newest timestamp wins. No line of this comment may start with
a marker: the scripts read the first line that does.

There is no default tier: `cycle.sh open-round` refuses to open a round while the `**Tier:**` line above
is missing or unparsable.
-->
**Approved:** Andrei, 2026-11-09 (ask 16 confirmed; assumptions kept as written)
**Briefed:** <written by scripts/cycle.sh briefed - stage 01+02 on the straight-through path (--go, Tier 1): "via grill, <owner>, <date>" (or "via grill (assumed)" / "via mini-brief"). Alternative to **Approved:** above.>
**Branch:** vulyk/mass-audit-fixes
**Council:** RED round 1, 2026-11-09, at 4560df8, pack 071e42715dbd - red: 18
**Council:** RED round 2, 2026-11-09, at 7b54bf6, pack 69942212bcbb
**Checked:** ACCEPTED by Andrei, 2026-11-09, at 462e6fe - owner picked the option «ACCEPTED без раунда 3 (Рекомендую)» (label written by the Queen; no words of his own) after the repair-19 diff (ce2e90b, 3 test lines) was shown in chat as text
**Checked:** ACCEPTED by Andrei, 2026-11-09, at 9aa72d0 - owner picked «Да, ACCEPTED и пуш (Рекомендую)» (label written by the Queen; no words of his own) after the repair-19 and fixture-scrub diffs (ce2e90b, 9aa72d0) were shown in chat as text
**Checked:** ACCEPTED by Andrei, 2026-11-09, at 1c516d7 - re-ACCEPT after the CI repair (0ab4a86, 1c516d7), diff pasted in chat, branch CI 42687998836 green; owner: «ок, продолжай здесь»
**Checked:** ACCEPTED by Andrei, 2026-11-09, at 1fb3fc5 - re-ACCEPT after the CI repair (0ab4a86, 1c516d7), diff pasted in chat, branch CI 42687998836 green; owner, asked to confirm the release explicitly: «Принимаю» (the earlier «ок, продолжай здесь» was ambiguous)
**Shipped:** 0.50.0, 2026-11-09, at a405d9a - merged to main, publish pending
