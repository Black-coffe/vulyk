# Plan review brief: handoff-ownership (VULYK)

You are an independent reviewer of a plan, chosen by the owner (Andrei) together with two other models who review
the same plan separately. You do not see their reviews and must not look for them (do not open other files in this
`plan-review/` folder besides this brief). The owner asked for exactly this: study the plan, then either AGREE,
propose AMENDMENTS, or REFUTE parts of it - with a clear, strong, evidence-backed position. Agreement is a legitimate
answer; manufactured disagreement is not. Disagreement must be argued from evidence (file:line, binary strings, probe
output), not taste.

## What happened (the owner's report)
In VULYK hives (projects with VULYK installed) the owner runs `/vulyk-handoff` and gets:

    Shell command failed for pattern "!`bash scripts/state.sh`": [stderr]
    bash: scripts/state.sh: No such file or directory

Then, mid-session, the owner asked: when a hive can also see another handoff (e.g. the owner's user-level
`~/.claude/commands/handoff.md`), both answer "/handoff" and "запусти handoff" - a conflict. VULYK must own the
handoff in its hive: the installer should detect any other handoff and OFFER to switch it off for this project only.
Then: "В проекте AI хендоффы разложены по направлениям (<client> и другие), а хендофф VULYK направлений не знает. Если
отключить там глобальный, такая раскладка пропадёт."

## The plan under review (read all four, in full)
- E:/Projects/vulyk/docs/specs/handoff-ownership/brief.md (request verbatim, reproduction, recon, owner answers, asks)
- E:/Projects/vulyk/docs/specs/handoff-ownership/plan.md
- E:/Projects/vulyk/docs/specs/handoff-ownership/handoff-ownership-01.md
- E:/Projects/vulyk/docs/specs/handoff-ownership/handoff-ownership-02.md

Rules of the house: E:/Projects/vulyk/CLAUDE.md (Laws 1-6, tiers). Law 2 (no overengineering) and Law 3 (no
out-of-scope edits) matter here.

## Why the planner (the Queen, Opus 5.5) decided what it decided
1. Diagnosis. Transcripts of E:/Projects/AI sessions 465c0602 (2026-10-12) and cf1d2449 (2026-10-13) under
   `~/.claude/projects/E--Projects-AI/` record `cwd` at the failing /vulyk-handoff as subfolders
   (`docs/specs/<client>/...`), reached by the model's own Bash `cd /e/Projects/AI/docs/specs/<client>/... && ...`. In the
   installed Claude Code 2.1.296 binary the cwd-reset function reads roughly
   `h=oVn(); if(h || r!==s && !Kg(r,n)) { reset to original }`, where `oVn()` reads env
   `CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR`: a `cd` that stays inside the project is KEPT, one that leaves it is
   reset ("Shell cwd was reset to ..."). `.claude/commands/vulyk-handoff.md:9,13` use relative paths
   (`bash scripts/state.sh`, `bash .claude/hooks/handoff.sh dump`).
2. Second, hidden bug: `.claude/hooks/handoff.py` `project_root()` (~line 84) reads env `CLAUDE_PROJECT_DIR`, then the
   payload cwd, then `os.getcwd()`; in dump mode (~lines 995-1003) the payload cwd = `os.getcwd()` and the transcript
   is looked up by the slug of that cwd. The Bash tool environment has NO `CLAUDE_PROJECT_DIR` (checked: unset), so
   from a drifted cwd the handoff would land in `<subfolder>/.claude/handoff/` with no transcript.
3. Why `${CLAUDE_PROJECT_DIR}` in the command: the binary substitutes `${CLAUDE_PROJECT_DIR}` in a skill/command body
   (before `!` injections run) with the project root, and in `allowed-tools` entries. Probed headlessly in a throwaway
   project: ``!`bash "${CLAUDE_PROJECT_DIR}/scripts/state.sh"` `` ran; ``!`echo "${CLAUDE_PROJECT_DIR}"` `` printed
   `C:/...` with forward slashes. Rejected: `$(git rev-parse --show-toplevel)` inside the injection (command
   substitution, harder permission matching); a `cd X &&` prefix (compound command); env `CLAUDE_PROJECT_DIR` (absent
   in the Bash env).
4. Considered and NOT put in the plan: setting `CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR=1` (in hive settings env or the
   owner's global settings) to stop cwd drift at the source. Reason: could not verify it interactively (headless
   sessions never keep a `cd`, with or without it), it changes every Bash call in every session (resets are silent
   when the env is set), and fixing the consumer is enough. You may argue the opposite.
5. Why `skillOverrides` and not shadowing: probe - a project `.claude/commands/handoff.md` did NOT shadow the
   user-level one; `/handoff` still ran the user's command. Probe - `"skillOverrides": {"handoff": "off"}` in the
   project's `.claude/settings.local.json` (and in `settings.json`): `handoff` gone from the slash list, typed
   `/handoff` returns `Skill "handoff" is disabled via skillOverrides. Remove the override from your settings to run
   it.`, a natural-language "Запусти handoff" found no such skill; /vulyk-handoff unaffected.
6. Owner decisions from the question round (brief.md `## Answers`): (1) user-level hooks that write handoffs (the
   owner's `~/.claude/hooks/context_guard.py`, wired in `~/.claude/settings.json`) are only REPORTED - Claude Code
   cannot switch off one user hook per project; (2) the switch-off goes to `.claude/settings.local.json` (this
   machine), never the committed `settings.json`; (3) a hive whose `.claude/context-guard.json` has
   `subproject_globs` ("directions", used by E:/Projects/AI) gets a warning and "keep" as default; teaching VULYK's
   handoff directions is the NEXT spec. These are owner decisions - challenge them only with a strong reason.
7. Why a separate `scripts/handoff-owner.sh` instead of an installer flag: three callers - `install.sh` on a terminal,
   `/vulyk-update` run by the Queen (no tty, asks in chat), and a manual run. The installer already has one consent
   question pattern (telemetry, `install.sh` ~457-530: `/dev/tty`, `--check` never writes, no tty = no question).
8. Tier 2, two stories: 01 (cwd fix + Law 6 defect card + test in `tests/maintenance.test.sh`) is independent; 02
   (`handoff-owner.sh`, installer, `/vulyk-update`, test, ADR-005 amendment) waits for the approved-but-unbuilt spec
   `docs/specs/constitution-merge/`, which owns `install.sh`, `scripts/vulyk-update.sh`,
   `.claude/commands/vulyk-update.md`. Ships as 0.28.0 after constitution-merge (0.27.0).
9. Known unverified: the quoted `allowed-tools` match outside bypass mode (headless `!` injections were not
   permission-gated at all, and in that scratch path even `--allowedTools "Bash(echo:*)"` let a `bash ...` call run,
   so permission probes there are inconclusive); the interactive drifted-cwd scenario end to end.

## What to examine (suggestions, not limits)
- Is the diagnosis right and complete? Any other relative-path or cwd-dependent piece the fix misses (other commands;
  hooks wired in `.claude/settings.json` use `$CLAUDE_PROJECT_DIR/...`; `state.sh`; `handoff.sh`)?
- Is `${CLAUDE_PROJECT_DIR}` the best fix? Edge cases: a session started in a hive subfolder, worktrees, paths with
  spaces, the Windows drive form, the `allowed-tools` quoting.
- `handoff.py`: is "root = the hive the hook file lives in" correct for dump/status; does it break the hook modes or
  the tests? Transcript lookup by slug: is the launch-dir slug right? Parallel sessions in one project (it takes the
  newest transcript)?
- Should `CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR` be in the plan after all?
- Story 02: detection by a name containing "handoff" - too narrow or too broad? `skillOverrides` on plugin skills?
  Merging into `settings.local.json` safely (Windows CRLF, BOM, Claude Code rewriting the file)? The no-tty and
  `--check` paths? Is `handoff-owner.sh` overengineering for the request? Is "typed /handoff answers disabled"
  acceptable for the ask "должен работать только один"?
- Sequencing and scope: should 01 ship alone, sooner, as a patch? Is Tier 2 right? The Law 6 defect card: is an
  inline grep check sound, can it go blind, are `paths:` right?
- Anything the plan promises that the stories do not carry, or the other way round.

## Evidence you can use
- Repo: E:/Projects/vulyk (git). `.claude/hooks/handoff.py`, `.claude/hooks/handoff.sh`, `scripts/state.sh`,
  `install.sh`, `scripts/vulyk-update.sh`, `.claude/commands/vulyk-update.md`,
  `docs/adr/005-installer-upgrade-contract.md`, `docs/defects/README.md`, `scripts/defects-check.sh`,
  `tests/maintenance.test.sh`, `tests/telemetry.test.sh`, `docs/specs/constitution-merge/plan.md`.
- The owner's global tools: `~/.claude/commands/handoff.md`, `~/.claude/hooks/context_guard.py`,
  `~/.claude/settings.json`.
- Claude Code binary:
  `C:/Users/Andrei/AppData/Roaming/npm/node_modules/@anthropic-ai/claude-code/bin/claude.exe` (minified JS inside;
  use `grep -aoE '.{0,300}PATTERN.{0,300}'` on e.g. `skillOverrides`, `CLAUDE_PROJECT_DIR`,
  `CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR`, `Shell cwd was reset`). Minified names are reused across modules: read
  carefully.
- Transcripts (6-7 MB each, grep only):
  `~/.claude/projects/E--Projects-AI/cf1d2449-0fb3-4678-a5f5-7dd561c83cac.jsonl`,
  `~/.claude/projects/E--Projects-AI/465c0602-dae5-453c-ac93-106f236abbe2.jsonl`.

## Tooling rules on this machine
- The Grep and Glob tools return "No files found" for files that exist on this Windows box. Use `grep -rn`, `ls`,
  `sed -n`, `cat` through Bash, with absolute paths. Do not `cd` into project subfolders.
- READ-ONLY: do not edit any file in the repo or under `~/.claude`, except your own review file.
- Optional live probes with `claude -p` are allowed: at most 3, always `--model haiku`, only inside your own fresh dir
  `C:/Users/Andrei/AppData/Local/Temp/claude/E--Projects-vulyk/555c8811-72e5-4a4c-8e84-d5ec863d8f7c/scratchpad/<your-dir>/`.
  Afterwards delete that dir, its transcript dir `~/.claude/projects/<slug>/` (slug = the dir's absolute Windows path
  with every non-alphanumeric character replaced by `-`), and `~/.claude/handoff/index/<slug>.json` if the owner's
  global hook wrote one. Known headless quirks: a `cd` never survives between Bash calls in `-p`; `!` injections are
  not permission-gated in `-p`. Useful pattern: pipe stream-json user messages into
  `claude -p --input-format stream-json --output-format stream-json --verbose`.

## Output
Write your review to your review file (path given in your task) in Russian, in plain words, as you go: create it
within your first few steps with a skeleton, then fill it in, so an interruption does not lose the work. Structure:
1. **Вердикт** - one line: СОГЛАСЕН / СОГЛАСЕН С ПРАВКАМИ / ОПРОВЕРГАЮ (часть X), and the single most important reason.
2. **По пунктам** - for each point you take a position on: the position (agree / amend / refute), the argument, the
   evidence (file:line, binary snippet, probe output), and for an amendment the exact change (which spec file, which
   line or criterion to add or replace).
3. **Чего не хватает** - risks or asks the plan misses, ranked by impact.
4. **Уверенность** - what you verified yourself and what you take on trust.

Keep it under ~1200 words. Your final message back must be the content of the file (or a faithful summary if long)
plus the file path.
