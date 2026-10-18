# The owner picks who builds and who judges, once per machine (plan)

**Tier:** 3 · **Spec slug:** `model-profiles` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-015 (the ladder, "the family that builds never judges", the model floor), ADR-013 D3 (the gate
model), ADR-016 (the constitution byte budget); owner rules "offer, never auto-enable" and "upgrade keeps host edits"
**Depends on:** v0.29.0 (`baa5219`)

## Goal
VULYK gets three model profiles, named by family only: `opus-builds` ("Opus пишет, Fable судит"), `sonnet-builds`
("как сейчас", today's ADR-015 ladder and the default) and `economy` (no Fable). The choice is one word in one file per
machine, in the user's Claude config folder, which the installer and upgrades never touch. A new resolver,
`scripts/model-profile.sh`, is the only reader of that file. It tells every launch point which family takes each role,
and it recommends a profile from the plan `top-model.sh` already detects. The driver, the build/review/plan commands and
the planner pass a model only when a profile is chosen that differs from today's. With no file, behaviour is unchanged
byte for byte. A new `/vulyk-models` quiz asks once, in the owner's language, with the recommended option first and the
reason; every option states what Fable / Opus / Sonnet / Haiku do and what it costs in limits, and on a non-Max plan
`opus-builds` says that Fable bills credits on top of the subscription. The first-run line in the SessionStart brief offers the quiz and never chooses for the owner. The owner's "Opus
writes 70%, Haiku 30%" becomes a split by kind of story, not a ratio. The planner marks routine and reusable stories
`model: haiku`, and Opus writes everything else.

## Assumptions
- **Release mechanics.** The CHANGELOG 0.30.0 entry is story 04; the `VERSION` bump, tag and publish are `/vulyk-ship`
  plus the release run after a green council, in this same session.
- **Tier 4 under `economy`: the second reviewer is `sonnet`.** Opus is the top reviewer, as the ask says; the second
  must differ from it and Fable is excluded, so the builders' family sits beside Opus. ADR-020 records this gap.
- **Split by story kind, no ratio.** The owner's 70/30 is a split by kind of story, not a ratio. Under `opus-builds` and
  `economy` the planner marks routine/reusable stories `model: haiku`, and nothing counts or enforces a share (the
  Queen's simplest reading; the owner was not asked about a counter).
- **No arguments under `sonnet-builds`.** A launch passes `worker_model` / `review_model` / `seat_model` only when the
  active profile is not `sonnet-builds`. The solo reviewer gets `model:` only when `--role review` differs from the
  shipped frontmatter. Passing `sonnet`/`opus` explicitly under the default would override a hive that pinned its worker
  or reviewer frontmatter, which breaks the 2026-10-16 amendment to ADR-015 D2 and the "byte-for-byte today" promise.
- **Change to the Queen's design (item 4): `seat_model` also reaches the black-box seat.** Under `opus-builds` the
  `council-haiku` seat (frontmatter `opus`, dispatched only when *Client path* is filled) would otherwise judge code Opus
  wrote. That breaks "the family that builds never judges", which ADR-020 promises holds in every profile. So the driver
  applies `seat_model` to both blind seats. Under `economy` the seat role is `opus`, the same as the frontmatter, so
  nothing changes there.
- **The quiz returns after a garbled file.** A garbled or unknown file reads as `sonnet-builds` (fail open), and
  `--chosen` exits 1 for it, so the quiz is offered again. Only a known name counts as chosen.
- **No state for the first-run line.** The line prints in every session until a choice is stored: no show counter, no
  "declined" state. Every quiz answer stores a profile, and "как сейчас" is a valid answer. If the session cannot ask
  (`claude -p`, no AskUserQuestion), the quiz writes nothing and prints one line of advice.
- **Shared roles come from `top-model.sh`.** `architect`, `gate` and `review-second` print what `top-model.sh`
  resolves, and `top-model.sh` now honours the profile after the env and constitution pins. `top-model.sh` gets the
  profile by running `model-profile.sh` with no arguments, so the file has one parser. A hive missing
  `model-profile.sh` reads as `sonnet-builds`.
- **The second reviewer under `economy` is `sonnet`, the builders' family.** This is the gap ADR-015 already accepts on
  Pro and API. ADR-020 records it again for `economy` on every plan.
- **`/vulyk-build` can refuse a launch that has Haiku stories.** A `model: haiku` story is checked by
  `top-model.sh --floor`; per `memory/map/scripts.md`, haiku needs Claude Code >= 2.1.293. On an older Claude Code,
  `/vulyk-build` refuses the launch as it already does. That is the floor working, not a new guard.
- **Kept from the Queen's design, with a known plan-time finding: the new test file and its `## Commands` row.**
  `CLAUDE.md` sits at its 7168-B budget. The 2026-10-16 memory note says 7167 B; this plan did not measure it. Story 01
  pays for the new row and the pointer line with trims. The row lands in story 01, the only story whose
  `## Verification` names `bash tests/model-profile.test.sh`. Until 01 is closed, `wave-check.sh` reports that segment
  as `verify-cell`. `close-story` reads the constitution at close time, so 01 passes there. The rejected option: fold the
  cases into `tests/telemetry.test.sh`, as `handoff-ownership` did. That costs no row, but it puts the resolver's cases
  in the installer's suite.
- **A hive sees the profile only after it upgrades.** The file is per machine, so one quiz answer covers every hive on
  that machine. A hive still on 0.29 or older keeps today's ladder until it moves to 0.30.0. Carrying the upgrade to
  live hives is release work after `/vulyk-ship`, not a story here.
- The release number 0.30.0 is the owner's (ask 8). `VERSION` and the release commit stay with `/vulyk-ship`.

## Stories

**Wave 1**
- `model-profiles-01` — `scripts/model-profile.sh` (storage, roles, `--set/--chosen/--recommend/--explain`),
  `top-model.sh --plan` plus profile-aware gate and second reviewer, the profile in `top-model-brief.sh`'s line, the new
  `tests/model-profile.test.sh`, and the `CLAUDE.md` pointer plus the `## Commands` row, byte-neutral.
- `model-profiles-02` — the driver's `worker_model` / `review_model` / `seat_model` with `driver.test.sh` cases;
  `/vulyk-build`, `/vulyk-review` and `/vulyk-plan` pass them from the resolver; the planner's `model: haiku` rule for
  routine stories in `queen-planner.md` and the story template.

**Wave 2**
- `model-profiles-03` — the `/vulyk-models` quiz command (voice triggers in ru/uk/en, one AskUserQuestion, recommended
  first) and the first-run `[VULYK]` line in `session-start-brief.sh`, with its case in `tests/maintenance.test.sh`.
- `model-profiles-04` — ADR-020 (amends ADR-015), an amendment note on ADR-015, a profiles section in
  `docs/model-cascade.md`, the ladder paragraph in the README, a command-reference entry, and the CHANGELOG 0.30.0 entry.

## Contracts
- **Profile file.** `${CLAUDE_CONFIG_DIR:-<home>/.claude}/vulyk-model-profile`. `<home>` falls back from `HOME` to
  `USERPROFILE` the way `top-model.sh`'s `profile_path` does. The file holds one line: `opus-builds`, `sonnet-builds` or
  `economy`. On read, surrounding whitespace and a CR are ignored. Anything else, or no file, reads as `sonnet-builds`.
  Only `model-profile.sh --set` writes it.
- **`scripts/model-profile.sh`** (exit 2 on usage errors, exit 0 otherwise unless stated):
  - no arguments prints the active profile;
  - `--chosen` exits 0 when the file holds a known name, else exits 1, and prints nothing;
  - `--set <name>` writes the file, creating the config folder if missing, and prints `<name>`; an unknown name is exit 2
    with nothing written;
  - `--role <r>` prints one family alias; an unknown role is exit 2;
  - `--recommend` prints `<profile> <plan>`: `opus-builds` when `top-model.sh --plan` says `premium`, else
    `sonnet-builds`; `<plan>` is that command's first field;
  - `--explain [<name>]` prints a human table, role by role, with the family for the active (or named) profile;
  - it writes nothing outside the config folder.
- **Roles** (`queen` is `opus` in every profile; `gate` and `architect` are what `top-model.sh` prints; `review-second`
  is `top-model.sh`'s second reviewer):

  | role | sonnet-builds | opus-builds | economy |
  |---|---|---|---|
  | planner (Tier 3) | opus | fable | opus |
  | review (Tier 1-3 `lead-review`) | opus | fable | opus |
  | seat (both blind seats) | opus | fable | opus |
  | worker | sonnet | opus | sonnet |
  | routine | sonnet | haiku | haiku |
  | gate / architect | today's plan rule | fable | opus |
  | review-second (Tier 4) | today's rule | sonnet | sonnet |

- **`scripts/top-model.sh`.**
  - Gate order: `VULYK_TOP_MODEL`, then the constitution `TOP_MODEL` pin (not `auto`), then the profile (`opus-builds`
    gives `fable`, `economy` gives `opus`, `sonnet-builds` falls through), then the plan, then `opus`. When the profile
    decides, the `--explain` line reads `decided by: profile <name>`.
  - Second reviewer: `sonnet` under `opus-builds` and `economy`, today's rule under `sonnet-builds`.
  - New `--plan` prints `<plan> <premium|standard>`. `<plan>` is the value `--explain` shows after `plan      : `.
    `premium` means the Max/premium-seat branch that picks `fable` today.
  - Every existing `--explain` label stays as `top-model-brief.sh` parses it. `QUEEN` stays `opus`.
- **`.claude/workflows/vulyk-cycle.js` args.** `{spec, stamp, top_model, second_model, worker_model?, review_model?,
  seat_model?}`.
  - Worker: `retry ? TOP : (story.model || A.worker_model || undefined)`.
  - Tier 1-3 `lead-review`: `A.review_model || undefined`.
  - `council-opus` and `council-haiku`: `A.seat_model || undefined`.
  - The Tier 4 pair is unchanged (`TOP`/`SECOND`).
- **First-run line** (`session-start-brief.sh`, printed only while `model-profile.sh --chosen` exits 1): `[VULYK] model
  profile not chosen: after the owner's current task, tell the owner and run /vulyk-models (Skill tool) once; until then
  sonnet-builds runs.`
- **`top-model-brief.sh`** adds ` · models <profile>` to its line, plus ` (not chosen)` while `--chosen` exits 1.
- **Planner dispatch** (`/vulyk-plan`, Tier 3). `queen-planner` gets `model: <--role planner>` only when that is not
  `opus`. When `--role routine` prints `haiku`, the Queen adds one line to the brief: `routine stories: model: haiku`.

## Rejected alternative
- **The choice stored in the hive** (a `MODEL_PROFILE = ` line in the constitution, like `TOP_MODEL`, or a key in
  `.claude/settings.json`). Rejected: the owner chose one choice per machine for all hives (answer 2). A constitution
  line costs bytes the 7168-B budget does not have, travels in git to other people's clones, and would have to be
  merged on every upgrade.

## Integration gate
`git ls-files '*.sh' | xargs -n1 bash -n` · `git ls-files '*.json' | xargs -n1 jq -e . > /dev/null` ·
`bash tests/model-profile.test.sh` · `bash tests/driver.test.sh` · `bash tests/e2e.test.sh` · `bash tests/cycle.test.sh` ·
`bash tests/solo.test.sh` · `bash tests/telemetry.test.sh` · `bash tests/maintenance.test.sh` ·
`bash tests/council.test.sh --quick` · `bash scripts/defects-check.sh`

## Descoped

*(empty)*

## Plan deltas

**Approved:** Andrei, 2026-10-18 («Да, строить на Opus (Рекомендую)»: stories 01-03 on `model: opus`, 04 on the worker frontmatter)
**Briefed:** <written by scripts/cycle.sh briefed>
**Branch:** vulyk/model-profiles
**Checked:** <written by scripts/human-check.sh after the owner has looked>
**Council:** GREEN round 1, 2026-10-18, at 6b4fab3, pack 9fa4077d3f8e
**Shipped:** <written by scripts/ship-check.sh --record>
