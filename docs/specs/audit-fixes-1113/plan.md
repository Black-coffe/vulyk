# Fix the framework-audit findings of 2026-11-13 (plan)

**Tier:** 3 · **Spec slug:** `audit-fixes-1113` · **Brief:** [brief.md](brief.md)
**Model profile:** opus-builds
**Governed by:** ADR-032 (story trust from git; story 09 amends it), ADR-025 (red receipt), ADR-021 (rules tree,
cards), ADR-005 (upgrade keeps host edits), ADR-015 (families); Law 6; cards `owner-words-by-builder`,
`work-discarded-by-git-verb`, `safeguard-bypassable-or-late`, `upgrade-overwrites-host-edits`,
`host-internals-in-public-repo`, `public-release-per-change`, `shell-needs-gnu-or-bash4`; `docs/cycle.md`.
**Depends on:** `main` at 86e15292 (0.52.0 plus the Tier 0 ship fix that ask 3 pins).

## Goal
Carry the 21 asks of the brief in ten stories and three waves, cut by file so that no two stories of a wave share a
path. Waves 1 and 2 land what does not judge this build: one version comparison for the update path, redaction of
more secret forms with a loud failure, the stamp-red re-hash with its parked tests, the ship text (outward-text
review, the pin of the private-origin rule), a stricter leak check with the tree cleaned, defect cards for
PowerShell commands, hooks that stay silent for a subagent, the skills counter kept local, and the installer fixes
(memory skeleton, upgrade base, CI pin). Wave 3 lands every gate that judges this very build, each with a test on
the original case and a neighbour form: git-guard's wider coverage and its no-Python fallback, the guard on the
owner's word, the court guard, the scope check counted from the claim, story approval bound to `cycle.sh`'s own
commit, the narrower paperwork rule, and the installer's allow list. Every story says what the code now does; the
evidence stays in the private audit folder.

## Assumptions
<!-- Law 1: every assumption the plan rests on, stated so the owner can veto it at the approval stop. -->
- **Privacy.** A security item dropped from this spec, or left half done, moves to
  `~/.vulyk/audits/framework-audit-2026-11-13/` and no repo text describes it. Stories name classes of behaviour;
  the exact forms (verbs, keywords, token shapes) are in that folder, and each security story points its worker at
  the section to read. Nothing from it is copied into the repo except as test inputs with synthetic values.
- **Client path** (Answers 3) is for the later docs spec. No story here touches that wording.
- **Publish steps are the owner's.** The GitHub template flag (ask 18) is switched off, and anything is pushed,
  only on the owner's word at the next publish. Story 05 removes the quick start from the docs and does not touch
  the flag.
- **Claude Code facts are verified before a story relies on them:** the `onFailure` hook field (stories 07 and 10),
  the transcript format (story 08: which entries are an owner prompt, which an `AskUserQuestion` answer), and the
  `agent_id` / `agent_type` fields of hook input (stories 05, 07, 08). The check is made against the installed
  Claude Code, and the worker writes what it found in `## Implementation notes`. A fact that does not hold is
  `NEEDS_CONTEXT`, never a guess. Default for `onFailure`: git-guard denies inside its own wrapper, and the settings
  key is added only if verified and harmless on an older Claude Code.
- **Hives get this through the ship rollout** (`/vulyk-ship` step 2a), not through a story.
- **Four steps are the Queen's, outside the stories:**
  1. Before wave 1: `git rm --cached memory/stats/skills.json`, one `.gitignore` line, one commit. A story cannot
     do it: `close-story` commits a story's paths from the working tree, where the file still exists. Story 05's
     test fails until it is done.
  2. Before wave 1: copy the privately recorded open redaction shapes into the private audit folder as
     `redact-open-shapes.md`, where story 02 reads them.
  3. Done before approval: story 04 `## Files` holds the 36 tracked files that name a registered hive root or a Claude temp-folder path (recon question 1, narrowed to those two shapes; the broad drive-path grep matched 281 files, mostly placeholders and historical records).
  4. After wave 3, before the round: check that the two new hook files are 100755 in the index (story 08 sets the
     bit; `close-story` has dropped it before).
- **Ask 2.** The counter keeps its path and is local and gitignored, as the ask says. A hive that already tracks the
  file gets the ignore line on `--upgrade` plus one line naming the untrack command; the installer never touches a
  hive's index. With the clean-tree exceptions gone, such a hive shows the counter as modified until it is
  untracked, so the rollout runs that command in each hive's upgrade commit.
- **Ask 4, the quote rule** (contract O1; split by the owner on 2026-11-13, see `## Plan deltas`). A quote is one
  whole owner message, one whole line of it, or one whole `AskUserQuestion` answer; a fragment cut out of a line
  does not count. Plan approval (`**Approved:**`): the owner's latest message, written after the spec's
  `vulyk(<slug>): plan` commit, of any length («Погнали», «да»). Release acceptance (`human-check.sh
  ACCEPTED|REJECTED`, `**Checked:**`): only the answer to a one-question `AskUserQuestion` that names the spec
  slug (the release question asked alone) or the owner's next message after that question, at least 8 letters
  or digits unless it is a picked option, written after the spec's latest verdict. `briefed --go` carries no
  note: it passes when an owner prompt of this session contains `--go`. A marker line that still holds the
  template placeholder is not a record.
- **Ask 7, failure.** When `redact.sh` cannot do its work, it withholds the text: one marker line on stdout, the
  reason on stderr, exit 1.
- **Ask 8.** At Tier 3-4 a close with no recorded claim head refuses (a missing input is never a pass). Tier 1-2
  keeps today's uncommitted-only check with one stderr note.
- **Ask 9** needs a verb: `cycle.sh revise <story-file>` makes the commit that today is made by hand
  (`vulyk(<slug>): revised <story-id>`). For the binding to hold, git-guard denies a subagent every `cycle.sh` verb
  outside the clerk's and the workers' sets (story 07). That hook rule is this plan's reading, not the ask's words.
- **Ask 10 is read for `brief.md` and `plan.md`**, the two files the ask names. `VERSION`, `CHANGELOG.md`,
  `CITATION.cff` and `memory/stats/*.jsonl` stay paperwork, so a release commit after GREEN does not stale the
  verdict. In the two files only the lines a cycle script writes are paperwork (contract P1). Say so if the literal
  reading (nothing but `cycle.sh`'s own files) is wanted.
- **Ask 11.** The allow list holds six verbs: `advance`, `status`, `release`, `suite` (clerk), `stamp-red`,
  `close-story` (workers). No `ask` or `deny` rule is added: their behaviour under `bypassPermissions` is unverified.
- **Ask 14.** "Absolute" means a drive path, a Git Bash or WSL drive path, or a home path. `~/...`, system
  locations (`/usr/bin/env`, `/dev/null`, `/tmp/x`) and a path whose first segment is a `<placeholder>` pass.
- **Ask 18.** A template copy is told from the VULYK source by having no `v*` tag (a template copy starts from one
  fresh commit). A shallow clone of the source with no tags would get the line too.
- **Ask 19.** When the installed version's tag is missing from the source, no hive file counts as a release copy:
  every differing file is kept, with the new one beside it.
- **Ask 21.** The reviewer is `lead-review`, dispatched by the publish step; flagged lines move to a file under
  `~/.vulyk/`, outside the repo.
- **Self-hosting.** This repo closes its stories with the scripts being edited. Wave 3's `claim` runs under the old
  `cycle.sh`, so story 09's new records do not exist when the wave's stories close: a close can refuse with `no
  claim head recorded` or `no approved record`. The planned recovery is one relaunch of the driver, whose
  `advance --claim` runs the new code and writes the records. A wave-mate's close can also meet a script or a test
  suite mid-edit (`tests/maintenance.test.sh` reads the whole tree): that red is a rerun, not a repair.
- **Shared files, one owner per wave.** `CHANGELOG.md` is named by story 10 alone, which writes the `## [Unreleased]`
  lines for the whole spec; every other story leaves one `CHANGELOG:` line per ask in its notes.
  `docs/defects/INDEX.md` is named by one story per wave (03, 06, 08). `docs/hooks-reference.md` is story 10's.
- **Size.** Ten stories for 21 asks is over the usual eight; the owner chose one spec (Answers 1). No story is
  routine enough for `model: haiku`: each carries a parser, a gate branch or a security check. Stories 06 and 09
  carry `model: opus` with the reason under their `## Goal`.
- **Coverage check (drone-coverage, plan only).** No ask absent. Partials it saw in plan.md are carried in the story
  files: ask 2 (ship step and `vulyk-*` counting: stories 03, 05), ask 5 (open forms in the header, alias and heredoc
  forms: story 07), ask 8 (worker prompts: story 07), ask 13 (seat prompts: story 08), ask 17 (CI index check: story
  06), ask 18 (recovery line: story 05), ask 19 (fixtures and `block`: story 06), ask 21 (reading set: story 03).
  Ask 14's cleanup covers the two shapes above; other drive and home paths in old spec records are flagged only when
  a later change touches that file. Readings the owner did not answer, for veto at approval: ask 4 `--go` (no note
  exists, so it needs an owner prompt of this session carrying `--go`); ask 8 at Tier 1-2; ask 10 (`VERSION`,
  `CHANGELOG.md`, `CITATION.cff`, stats stay paperwork); ask 14 (system paths pass); the `cycle.sh revise` verb and
  the subagent `cycle.sh` verb rule (no ask behind them; needed for ask 9 to hold).
- **Verification of several lines pauses and resumes** (540 s call budget, exit 7); accepted.
- **No scout ran.** Test homes and part names come from earlier specs' closed stories.

### Recon questions for `drone-scout` (each may widen a `## Files` or move a line)
1. Which tracked files under `docs/`, `memory/`, `tests/` and `CHANGELOG.md` hold a drive path, a home path or a
   Claude temp-folder path (`grep -rnE '[A-Za-z]:[\\/][A-Za-z]|/(home|Users)/[^/<]|Temp/claude'`)? Every hit joins
   story 04's `## Files`; a hit in a file another wave-1 story names goes to that story instead.
2. Does any test pin the full `telemetry.sh enum` output or a count of codes? A hit in `tests/telemetry.test.sh`
   moves story 02 behind story 01 or hands that line to story 01.
3. Which tests pin the clean-tree exception for `skills.json` (cycle parts `gates` / `ship`, council, solo,
   maintenance)? A hit outside `tests/cycle.test.sh` joins story 03 or 05.
4. Which hooks does `.claude/settings.json` wire on SessionStart and PreCompact? Story 05 names five scripts and
   `handoff.py`; a sixth joins its `## Files`.
5. Which files does `human-check.sh` write its record to, besides the `**Checked:**` line of `plan.md`, and does it
   commit? Story 08 guards each.
6. Which fixtures close a Tier 3-4 story with no `claim` or `branch` before it, and which hand-edit `plan.md` or
   `brief.md` inside an open round (cycle parts `close`, `gates`, `ship`; council `verbs`, `close`, `advance`;
   `tests/solo.test.sh`, `tests/e2e.test.sh`, `tests/driver.test.sh`)? Each joins story 09.
7. Which tests pin the blindness sentence of `council-opus.md` / `council-haiku.md`, and the worker prompts' git
   line? A pin outside `tests/inject.test.sh` / `tests/maintenance.test.sh` joins story 08 or 07.
8. Every `cycle.sh` verb the driver sends through `cycle-clerk`, and every verb the worker prompts run: is the set
   exactly the six of contract W1?
9. The file name of ADR-032 under `docs/adr/` (story 09 names it by glob).
10. Measured duration against the 210 s line: `tests/maintenance.test.sh`; the defect-hooks row; cycle `close`,
    `gates`, `ship`, `red`; council `verbs`, `close`; telemetry `install`, `install-xp`, `wiring`.

## Stories
<!-- One line per story, grouped by wave; the story files are the truth, this is their index. -->

**Wave 1**
- `audit-fixes-1113-01-version-order` — ask 1: one comparison for the update check and `vulyk-update.sh`; a target that is not newer is refused
- `audit-fixes-1113-02-redact` — ask 7: non-English keywords, credentials in arguments, more token shapes; a failing `redact.sh` withholds the text and records `redact_degraded`
- `audit-fixes-1113-03-ship-and-cycle-tails` — asks 20, 3, 21, 2: stamp-red re-hash and the parked tests; the pin of the private-origin rule; the outward-text review; the `skills.json` clean-tree exceptions removed
- `audit-fixes-1113-04-leak-check-and-powershell-cards` — asks 14, 12: the leak check catches any outside path and the tree is cleaned; defect cards reach PowerShell commands

**Wave 2**
- `audit-fixes-1113-05-session-hooks` — asks 16, 18, 6, 2: SessionStart and PreCompact hooks silent for a subagent; the brief names a missing Python and a template copy; the template quick start leaves the docs; the counter counts VULYK's own skills
- `audit-fixes-1113-06-install` — asks 19, 17, 15, 2, 12: upgrade base is the installed tag; a fresh install gets the memory skeleton; CI actions pinned; `skills.json` not shipped; the installer's inject matcher (`model: opus`)

**Wave 3** (the gates that judge this build)
- `audit-fixes-1113-07-git-guard` — asks 5, 6, 8, 9: wider verb coverage, the no-Python fallback, no subagent commit under a DRIVER, the Queen's verbs closed to a subagent
- `audit-fixes-1113-08-owner-word-and-court-guards` — asks 4, 13: only the owner's quoted words record an acceptance or `--go`; a blind seat stays inside its court
- `audit-fixes-1113-09-cycle-gates` — asks 8, 9, 10: scope counted from the claim head; approval bound to `cycle.sh`'s own commit; hand edits of `brief.md` / `plan.md` are not paperwork (`model: opus`)
- `audit-fixes-1113-10-install-wiring-and-allow-list` — asks 11, 4, 13: the six-verb allow list, the two new hooks wired, the hooks reference, the CHANGELOG

**Wave 4** (cut mid-build, plan delta 2026-11-13)
- `audit-fixes-1113-11-redact-leaves-ordinary-text` — ask 7: no false masks on ordinary text (every brief and journal byte-identical); callers refuse when `redact.sh` fails

## Contracts
<!-- Interfaces that cross a story boundary, agreed here at plan time. -->
- **V1, version order (story 01).** `scripts/version-order.sh` is sourced. `version_newer <a> <b>` exits 0 when `a`
  is strictly newer; `version_newest` prints the newest of the versions on stdin. A leading `v` is dropped; numeric
  fields compare as numbers; `X.Y.Z` is newer than `X.Y.Z-dev.N`; `dev.10` is newer than `dev.3`. No `sort -V`.
- **R1, redact failure (story 02).** stdout is the one line `[VULYK:REDACT-FAILED]`, stderr `redact: degraded:
  <why>`, exit 1, and `telemetry.sh record redact_degraded` runs (the code is appended to `ENUM`). Every mask added
  to `redact.sh` is added to `handoff.py` `_REDACT_FALLBACK` in the same story (parity rows).
- **H1, subagent input (stories 05, 07, 08).** A hook call is a subagent's when its stdin JSON has a non-empty
  top-level `agent_id`. A SessionStart or PreCompact hook then exits 0 with no output and no write.
- **K1, leak rule (story 04; every later story with a `docs/` path is checked by it at `close-story`).** Flagged: a
  drive path (`<letter>:/` or `<letter>:\` plus a segment), a Git Bash or WSL drive path, a home path
  (`/home/<user>/`, `/Users/<user>/`), a Claude temp-folder path, and every root in `${VULYK_HIVES_FILE:-~/.vulyk/hives}`
  (no registry: one stderr note, the rule has nothing to match). Passing: a path under the repo root, `~/...`,
  system locations (including `<drive>:/Program Files/` and `<drive>:/Windows/`, which `CHANGELOG.md` names today),
  a `<placeholder>` first segment.
- **M1, inject matcher (story 04 writes `.claude/settings.json`, story 06 the installer).** The `defects-inject.sh`
  entry's matcher is the existing one with `PowerShell` added (Read, NotebookEdit, `mcp__.*` and the rest stay).
- **U1, upgrade base (story 06).** A hive file is a release copy only when it equals the blob of that path in tag
  `v<.claude/vulyk-version>`. Anything else is merged three-way with that blob as the base; a conflict keeps the
  hive's file and writes `<file>.vulyk-new`. The card's check is `bash scripts/upgrade-base-check.sh <arg>`, `<arg>`
  an installer to judge; it must finish in seconds, because `close-story` runs it on `install.sh`.
- **S1, claim head (story 09).** `claim` writes `head=<sha>` for the wave into the cycle's run state, once per
  wave. `close-story` at Tier 3-4 counts scope from it: files changed between that head and the working tree, plus
  untracked ones, less the story's `## Files`, paperwork, and same-wave siblings' declared paths and story files.
  No record: exit 2 `no claim head recorded for wave <W>`.
- **A1, approved record (story 09; story 07 guards the verbs).** The run state holds `<story-id>=<sha>`, the commit
  `cycle.sh` itself made: `branch` (every story of the spec, at its own commit; a story file untracked or differing
  from HEAD is exit 2 `commit the plan first`), `revise <story-file>` (commits the story with a changed `plan.md` /
  `brief.md`, subject `vulyk(<slug>): revised <story-id>`), `repair` (the repair story). `close-story` and
  `stamp-red` compare with `git show <sha>:<story>` and read no commit subject. No record at Tier 3-4: exit 2 `no
  approved record for <story>`. A spec built before this release is seeded once, by `claim` or `branch` only, from
  today's rule, with a journal line; a record lost after that line is a refusal.
- **P1, paperwork (story 09).** `is_paperwork_path` no longer answers yes for `<spec>/brief.md` and
  `<spec>/plan.md`. A change to either is paperwork only when the changed lines are the ones a cycle script writes:
  in `plan.md` the marker lines (`**Briefed:**`, `**Branch:**`, `**Council:**`, `**Checked:**`, `**Shipped:**`) and
  the `## Needs a human` block; in `brief.md` what `reopen` appends under `## Answers`. Any other changed line is a
  hand edit: dirty or committed since the claim head, `close-story` exits 4 naming the file; committed after
  `ROUND.head`, the round is stale and `status` names the file and the commit. A `revise` commit is the accepted
  way to change either file during a build. Every cycle commit stages its named files, never the spec folder.
- **G1, git-guard (story 07).** One verb list feeds the Python part and the bash fallback; a test compares them.
  With no Python the fallback denies every listed verb, for any caller, in Bash and PowerShell, and lets other git
  through. An interpreter that ends with a status other than 0 or 1 on a command naming git: denied. For a subagent:
  `git commit` and `git add` are denied while any `docs/specs/*/DRIVER` exists, and so is every `cycle.sh` verb
  outside `advance`, `status`, `release`, `suite`, `stamp-red` (never `--baseline`), `close-story`.
  `git update-index --chmod` stays allowed.
- **O1, owner guard (story 08).** `.claude/hooks/owner-guard.sh`, PreToolUse. Guarded: a command running
  `human-check.sh <spec> ACCEPTED|REJECTED`; `cycle.sh briefed ... --go`; an Edit, Write or shell command that adds
  or changes a `**Approved:**` or `**Checked:**` line of a `docs/specs/*/plan.md` (a line holding the template
  placeholder is no record). A subagent: denied. The main session: allowed only under the quote rule of
  `## Assumptions`, read from `transcript_path`; whitespace runs are collapsed on both sides. No Python, or an
  unreadable transcript: denied, with a message that says why and what the owner can do. `--check <file>` judges a
  hook-input fixture (a `transcript` field stands in for the file), exit 1 on a deny, exit 0 for a file that is no
  hook input.
- **C1, court guard (story 08).** `.claude/hooks/court-guard.sh`, PreToolUse. It acts only when `agent_type` is
  `council-opus` or `council-haiku`. Read, Grep, Glob: a path that resolves outside `<project>/.vulyk/court/` is
  denied. Bash, PowerShell: a path argument leaving the court is denied, and a git command that reads objects is
  denied unless every pathspec lies outside `docs/specs/`; an unreadable command is denied. `--check <file>` as O1.
- **W1, wiring and allow list (story 10).** `.claude/settings.json` and the installer wire `owner-guard.sh` on
  `Bash|PowerShell|Edit|Write|MultiEdit` and `court-guard.sh` on `Read|Grep|Glob|Bash|PowerShell`, in the quoted
  `"$CLAUDE_PROJECT_DIR"` form; `--upgrade` wires each once, only when `v$PREV` did not ship the script. The allow
  list holds `Bash(bash scripts/cycle.sh <verb>:*)` for the six verbs and no rule for `human-check.sh`; `--upgrade`
  replaces the broad `cycle.sh` rule it once wrote and logs `narrowed allow: cycle.sh`.
- **Red labels.** Each `red_reason` is text the story's failing test prints: 01 `a release is newer than its dev
  builds`; 02 `masks a non-English secret keyword`; 03 the label of the parked stamp-red case that fails today; 04
  `a PowerShell command gets the card`; 05 `a subagent session start prints nothing`; 06 `an edit equal to an older
  release is merged, not replaced`; 07 `a discarding verb fed to a shell is denied`; 08 `a subagent cannot record an
  acceptance`; 09 `an edit committed before the close is out of scope`; 10 `the allow list holds no owner-only
  verb`. A story with several fixes makes every other new case fail on HEAD too and says so in its notes.
- **Rejected alternative.** A ledger of every commit `cycle.sh` makes, read by the scope check, the approval lookup
  and the paperwork rule alike. Rejected: today a cycle verb run without `--commit` leaves its lines for a hand
  commit, so a commit-based paperwork rule would stale a round on the cycle's own writes, and a local ledger lost
  with the run state would stale every open verdict. Three smaller records (claim head, approved sha, changed
  lines) fail closed one at a time. Also rejected: one story per ask (21 workers, most serialised on `cycle.sh`,
  `install.sh`, `git-guard.sh` and three test suites), and putting the two new guards inside `git-guard.sh` (one
  file for three wave-3 stories).

## Integration gate
`bash tests/full-suite.sh`

## Descoped

*(empty)*

## Plan deltas

- 2026-11-13, wave 1 relaunch, the Queen's rulings:
  - 04 NEEDS_CONTEXT: the close-story block gate runs a block card's check on that card's own new fixtures, which
    fail by design. The two fixtures leave story 04's `## Files` and the Queen commits them; the gate defect
    (card framework-defect-deferred-mid-build) joins story 09 (`scripts/defects-check.sh`), the gates wave.
  - New story 11, wave 4 (ask 7): `redact.sh` leaves ordinary text alone (corpus of every brief and journal
    byte-identical, same-shape neighbours) and its callers refuse when it fails. From story 02's worker concerns
    and a side-agent note the owner forwarded.

- 2026-11-13, wave 1 NEEDS_CONTEXT (stories 02, 03, 04), the Queen's rulings:
  - 02: the red line was a 140-char line in `memory/map/scripts-hooks.md` from before the spec; the Queen
    wrapped it (ca9ae757). Story unchanged.
  - 03: removing `skills.json` from paperwork flips two cases in `tests/council.test.sh` (parts `seats`,
    `escalate`) and cases in cycle parts `close`, `hooklog`: the file and the four parts join story 03.
  - 04: the 26 further tracked files the new leak rule flags join story 04 and are scrubbed the same way, real
    and synthetic alike (ask 14: today's hits replaced with stand-ins); `memory/map/scripts.md` was fixed by the
    Queen (ca9ae757). M1 now reads: the existing matcher plus `PowerShell` (the worker's finding), story 06 too.
- 2026-11-13, owner decision on the quote rule (option label, the agent's wording; cross-checked with Fable):
  «План — одним словом, выпуск — строже (Рекомендую)». Plan approval takes the owner's latest message after the
  plan commit, any length; release acceptance takes only the answer to the release question asked alone or the
  owner's next message after it, 8+ letters or digits unless a picked option. Story 08 revised.

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
**Approved:** Andrei, 2026-11-13 («Погнали»)
**Briefed:** <written by scripts/cycle.sh briefed - stage 01+02 on the straight-through path: Tier 1 "via grill, <owner>, <date>" (or "via grill (assumed)" / "via mini-brief"); Tier 2-4 only with `cycle.sh briefed <spec> --go`, "via grill (--go), <owner>, <date>". Alternative to **Approved:** above.>
**Branch:** vulyk/audit-fixes-1113
**Checked:** <written by scripts/human-check.sh after the owner has looked - stage 05, and the override for stage 04+05. /vulyk-ship refuses without either this or a GREEN **Council:** line.>
**Council:** <written by scripts/cycle.sh judge/escalate - stages 04+05: "<GREEN|RED|ESCALATE|STALE> round <N>, <date>, at <sha7>, pack <fp12>[ - red: 2,5]", appended once per round.>
**Shipped:** <written by scripts/ship-check.sh --record - stage 06: the published version, and where>
