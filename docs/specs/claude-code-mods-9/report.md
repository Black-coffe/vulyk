# Report: 9 Claude Code mods vs VULYK

Study work, 2026-11-05. Brief: [brief.md](brief.md). Evidence: [research-anthropic.md](research-anthropic.md),
[research-budget-memory.md](research-budget-memory.md), [research-ui.md](research-ui.md) (source code read, nothing run),
plus a local probe and VULYK files named below.

## Bottom line

Of the nine mods, one idea is worth building into VULYK now. That idea is Blast Radius's: before a command
destroys work, say what it would destroy. It should not ship as the mod itself. It belongs in VULYK as an ordinary
hook. VULYK's protection against discarding uncommitted work today is words in a prompt (`.claude/agents/worker-code.md:67`),
and it has already failed twice in this owner's history (once a `git checkout --` of runtime ledgers, once a hive build
`git stash`-ing a fix that was not yet committed). Two small items follow from the study. The first is showing the
diff in the reply before the owner's ACCEPTED, which comes from Replay Theater. The second is a false positive of
correction capture on quoted text, met in this very session. That fix comes from comparing VULYK with Reflect. The other
six mods are either already covered by VULYK (pulse, the YSK offer, defect cards, the cache-economy work) or do not fit it
(UI themes, an embedded browser).

## Per mod: what it really is, what VULYK has, verdict

| # | Mod | What the code does (graded in research files) | VULYK today | Verdict |
|---|---|---|---|---|
| 1 | Blast Radius (Anthropic playground, Apache-2.0, one commit 2026-10-01, "shared as-is") | mod `tool.call` on **Bash only**; parses `rm -r/-f`, `git reset --hard`, `git clean`, `git checkout .`/`restore .`, force push, migrations; holds the call with a Proceed/Cancel pane, 10 min timeout -> deny; no model calls. Misses `mv`, `>`, `rm file`, `git checkout <file>`, `git stash`, `bash -c`, PowerShell. Needs `bash`/`find`/`du`. Headless: a held call can only time out. | Prompt rule only: `worker-code.md:43,67-68` "never `git stash`, `git checkout`, `git restore`, `git reset` or `git clean`". No hook. | **Take the idea, build our own hook** (C1) |
| 2 | Cache Tax (karanb192, MIT) | mod; local clock says "cold" after 1 h; at >= 50k context prices a cold send at 1-h write rates (table matches the pricing page) and asks; `/keepwarm` sends a fork "Reply with the single word: warm" every 50 min | `handoff.py` cache countdown (`cache_note`, 60-min TTL), cache-economy study (keepalive rejected), `token-report.py` model-aware read rates, weekly-budget spec approved and not built | **Do not take.** The keepwarm effect on subscription limits is ❓ (no official source); docs put forks in the 5-min bucket, the mod's 1-h refresh rests on one author run. Nit: `handoff.py:383` still says "~0.1x" |
| 3 | Savvy Progress (claude-kit, MIT) | progress depends on the model calling the kit's own `progress`/`step` tools; cost from usage x price table, all writes at the 1-h rate | `vulyk-pulse`: live dots per agent, task timer, weighted tokens, wave/round from `cycle.sh status` | **Do not take.** Pulse covers it without asking the model to report progress |
| 4 | You Should Know (built-in) | side agent, same model, no tools, rereads the conversation during longer tasks, flags one missed thing; not a summariser; several thousand instruction tokens per check | `ysk-offer.sh` offers it 3x, never enables (owner rule 2026-10-16) | **Done already** |
| 5 | Reflect (BayramAnnakov, MIT) | mod sends each short prompt to Haiku, >= 0.7 confidence -> band Save/Edit/Skip; saves a **one-line English paraphrase** into a block in CLAUDE.md; plugin: 63 regexes + later Sonnet pass; author's own backlog: ~16 of 102 captures were reusable | `defect-intake.sh` (lexicon, verbatim quote, «отмени») -> cards in `docs/defects/` with Never/Allowed/How-to and checks (Law 6) | **Do not take the mechanism**: a paraphrase breaks the verbatim rule and CLAUDE.md is at its byte cap. Take one lesson: quoted text is not a correction (C3) |
| 6 | Filetree (data-goblin, MIT) | docked Pane; learns touches from `tool.call` on Read/Edit/Write/Bash (Bash by regex); optional path guards deny Edit/Write | `scope-check.sh` at close-story; a past study found `scope_breach` alerts were noise | **Not for VULYK.** A personal viewer; an edit-time scope guard has no evidence of need |
| 7 | Replay Theater (Anthropic playground) | records Edit/Write/MultiEdit only, per main turn, `/replay` steps diffs (12 lines/step), memory only; Bash edits invisible; background Workflow workers likely outside its turn | the owner's ACCEPTED rests on what he saw; no framework step puts the diff in front of him | **Take the idea** (C2): the pack's diff in the reply text before ACCEPTED |
| 8 | Terminal Browser (zenbu-labs, MIT) | Electron/Chromium offscreen, kitty graphics; Ghostty/kitty-class terminals, macOS/Linux, Windows via WSL; plugin "experimental"; telemetry on | `council-haiku` black-box seat with a Browser MCP | **Do not take** |
| 9 | Claude Skins (hellosverre, MIT) | 16 skins; redraws tool rows, code, diffs; owns `Spinner`, `AbovePrompt`, `TurnDuration` | `vulyk-pulse` owns the same three sites; both replace Spinner/TurnDuration without `next` | **Do not take**; document the collision (C4) |

Platform claims of the post: >= 2.1.287 ✅; VS Code 2.1.299 ✅ (docs; 2.1.304 without feature flags); 1-h main cache on a
subscription ✅; "7000+ mods" ⚠️ (one community scanner: 7351 on 2026-11-01; no official count).

## Local probe (2026-11-05, Claude Code 2.1.318)

A project `PreToolUse` hook on `Bash|PowerShell` returning `permissionDecision: deny`, in `claude -p --permission-mode
bypassPermissions`: the call was blocked (`PreToolUse:Bash hook error: PROBE-DENY ...`, file intact). Inside a subagent
the hook input carried `"agent_type":"general-purpose"`, an `agent_id` and `"permission_mode":"bypassPermissions"`.
Docs: `permissionDecision` allow/deny/ask/defer, precedence deny > defer > ask > allow (code.claude.com/docs/en/hooks);
"PreToolUse hooks run before the permission prompt, for every tool except EndConversation" (…/permissions). Not tested:
`ask` under bypass; PowerShell `tool_name` (inferred `PowerShell` from the docs' matcher example).

## Options, recommended first

C1. **Uncommitted-work guard (recommended).** This is a `PreToolUse` hook on `Bash|PowerShell` in every
hive, with no model calls. This is the design after the grill (see "Cross-model grill" below):
- **The verb list.** It covers the git verbs that throw away work:
  - `stash`, with or without `-u`, plus `drop` and `clear`;
  - `checkout .`, `checkout -f`, and `checkout [<ref>] -- <path>`;
  - `restore`, worktree form;
  - `reset --hard`;
  - `clean -f`;
  - `switch -f` and `switch --discard-changes`;
  - `branch -D`;
  - `worktree remove --force`.

  The read-only forms are excluded: `stash list` and `stash show`, soft and mixed `reset`, `checkout -b`,
  `clean -n`, and `restore --staged` on its own.
- **Subagents** (the hook input carries `agent_id`, confirmed by the probe): any verb on the list is denied,
  with no `git status` call. During a wave the tree is always dirty, and workers never need these verbs
  (`worker-code.md:67-68`). When a git verb is seen but its arguments are unclear, the call is denied too.
- **Main session:** a verb is denied only when the paths it names (or the whole tree, for pathless forms) are
  dirty or untracked in `git status --porcelain`. The refusal names those files, which is Blast Radius's
  "show the radius". It also gives the safe path: commit them as their own commit, leave them, or run the
  command yourself in your own terminal.
- **Bypass.** Agents get no env switch: a worker could set `VAR=1 git stash` inline. The only bypass is the
  owner running the command outside the agent. Whether `!` mode skips PreToolUse is ❓; a logging-hook probe
  settles it.
- **Failure mode.** Fail-open on a hook crash, a missing `git`/`jq`, or an unparseable non-git command. This
  is the platform default and the project precedent (`defect-intake.sh`: "any error -> silent exit 0"). The
  hook denies only on a matched verb.
- **Named as uncovered** (card `safeguard-bypassable-or-late`):
  - `bash -c`, scripts, aliases, `python -c` subprocess;
  - `rm -r` and `Remove-Item -Recurse`, which are best-effort at most.
- **A mod can override the hook.** The docs say so (code.claude.com/docs/en/permissions, "Precedence
  among rules, hooks, and mods", read 2026-11-05): "With neither managed settings nor a Team or
  Enterprise `/login` as the session's credential, the mod can approve a call that a deny rule refuses
  or a `PreToolUse` hook blocked." The ruling comes from a mod's `tool.check` handler, which runs after
  the hooks. This is the owner's setup (personal login), so any installed mod with `tool.check` can lift
  the guard in silence.
  - Today no installed mod on this machine handles `tool.check` (a grep of the plugin dirs on
    2026-11-05; `vulyk-pulse` has none).
  - How to notice: the story adds a line to `/vulyk-status` and the SessionStart brief that names every
    enabled plugin whose hooks module mentions `tool.check`.
  - With managed settings on the machine, the block stays. Whether a minimal local managed-settings file
    is enough for that is ❓; the story checks it before offering it to an owner.
  - Pointed out by a side-agent note the owner forwarded on 2026-11-05, and confirmed in the docs above.

Why ours rather than the mod:
- The mod watches Bash only.
- It needs a UI and a human click, so a Workflow worker would wait 10 minutes and then be refused.
- It does not know git dirtiness.
- It misses `git stash` and `git checkout <file>`, the exact verbs of our two losses.

The story is `red: required` (a parser). Its tests use the two original cases plus neighbours. It also carries
the defect card that the two incidents never got, with its failing `check:` (Law 6). The tier is ⚠️ disputed:
Tier 2 (the precedent of earlier hook specs) or Tier 3 (installer + hook in every hive); see the grill.

C2. **Diff before ACCEPTED (Replay idea).** `human-check.sh --show <spec>` prints the pack's `git diff --stat` and
capped hunks. `/vulyk-build` `escalated` and `/vulyk-ship` paste it into the reply text before asking for ACCEPTED.
Tier 1. A card for the 2026-11-03 lesson (the diff sat in collapsed tool output).

C3. **Quoted text is not a correction.** In `defect-intake.sh`, a correction word inside «…» / "…" quotes,
or inside a typed message made mostly of a forwarded post, goes to the paste branch ("are these your
words?") instead of "file the quote now". This session's own trigger: the post's «нет, не так». Tier 1,
a `check:` fixture with this case plus a neighbour.

C4. **Pulse and other mods on the same rows.** One section in `docs/pulse.md`: Skins (and any mod
replacing Spinner/TurnDuration) and pulse cannot both draw. Whichever is outer wins, and the per-hive off
switch is the way out. Tier 0.

Rejected: keepwarm pings, Savvy-style model-reported progress, Reflect's paraphrase into CLAUDE.md, an edit-time scope
guard, shipping or auto-enabling any third-party mod (owner rule: offer, never enable), Terminal Browser, Skins.

## Cross-model grill (Fable, Opus, Sonnet; two rounds, anonymised; same provider, so blind spots may be shared)

1. C1 is the right #1: ✅ 3/3. It is the only item tied to real, repeated losses, and today's guard is prose only.
2. Firing rule: ✅ 3/3 after round 2 (two reviewers changed their position). Subagents get an unconditional deny of
   the verb list; the main session is gated on dirty paths. The draft's "dirty-only for everyone" was wrong for
   waves: the tree is always dirty there.
3. No env switch for agents; the owner runs the command himself: ✅ 3/3. Whether `!` skips the hook: ❓ (docs:
   `!` runs "directly without going through Claude"; the hooks page is silent).
4. Fail-open on a crash or unparseable input, deny on a matched verb: ✅ 3/3 (values: availability over safety on the edges).
5. C1 tier: ⚠️ 2/3 for Tier 3 (installer + hook across every hive). Minority (Fable) argued that earlier hook specs ran
   at Tier 2 (auto-maintenance, handoff-ownership, upgrade-keeps-host-edits) and that the "every hive" part is rollout,
   not scope. Values; the owner picks when planning. My recommendation: Tier 2, on the precedent.
6. C2-C4 and the rejections: ✅ 3/3. Additions: C3 is a routing tweak (the paste branch exists, `defect-intake.sh:9,143`).
   C2's card needs a `check:`, or it is named as debt.
7. Missed ideas: one minor one (Opus): Filetree-style path guards for other prompt-only rules, such as `status:` lines and
   runtime ledgers. The ledgers are already covered by C1's main-session dirty gate; the rest is an extension.

Panel files are in `.crossgrill/2026-11-05-mods-9/` (git-ignored).

## Candidate stories (for a future `/vulyk-plan`, in the owner's words)

1. **C1 uncommitted-work guard.** Tier 2 or 3, `red: required`. Hook + settings + installer + tests + card
   `work-discarded-by-git-verb`, with a failing check. First, a probe on `!` mode.
2. **C2 diff before ACCEPTED.** Tier 1. `human-check.sh --show`, plus the reply-text rule in `/vulyk-build`
   `escalated` and `/vulyk-ship`, plus a card.
3. **C3 quoted text is not a correction.** Tier 1. `defect-intake.sh` routing + fixtures (this session's case + a neighbour).
4. **C4 pulse coexistence note.** Tier 0. `docs/pulse.md`, plus the `handoff.py:383` "~0.1x" nit.

## Not read or run

Mod code was read, not run; Filetree and Blast Radius on native Windows untested; the real install order of pulse vs
Skins untested; hook `ask` under bypass untested; subscription-limit cost of a cache read or a fork ping has no official
source.
