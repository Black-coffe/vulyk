# Scout report: verification paths, the ESCALATE seam, test sites (drone-scout, 2026-10-25)

A story's `## Verification` is parsed and run by `close-story` (540 s cap); the round's full suite by the `lead-review` seat, where a timeout is a minor today. No file carries a "round-only" notion yet.

## Entry points
- `scripts/lib.sh:130-145` `command_cells`: only the last cell (sed `^|[^|]*|\s*(`...`)\s*|$`) is read; the Purpose column is discarded; output is bare commands, no row identity.
- `scripts/lib.sh:147-178` `command_cell_exists <constitution> <cmd>`: exact or `<placeholder>` match, boolean.
- `scripts/lib.sh:180-189` `verification_segments`: splits on ` && `.
- `scripts/wave-check.sh:216-234` verify-cell check (`report "verify-cell: ..."`); header codes `:31-33`; always exits 0, counts PROBLEMS.
- `scripts/cycle.sh:1957-1991` close-story: same cell check; miss -> `emit false close-story 2 error "verification not in ## Commands: $seg"`, exit 2 (`:1981-1985`). Exit 2 = not fixable here: the worker returns NEEDS_CONTEXT (worker-code.md:37-38, worker-test.md:34-35).
- `scripts/cycle.sh:1999-2032` VULYK_VERIFY_TIMEOUT (540) one shared budget; timeout (124) -> exit 4 `repair "verification timed out after Ns: <cmd>"` (`:2018-2022`); failure exit 4 (`:2023-2027`). Exit 4 = worker retries 3 times, then WALL.
- `.claude/agents/lead-review.md:49-52` full-suite rule: once, `timeout 540`, Bash `timeout: 600000`; "A suite that times out is a minor, never a BLOCK."
- `scripts/cycle.sh:1566-1599` `cmd_record_seat_review`: line 1 `VERDICT: PASS|BLOCK`; a BLOCK needs a line under `## Critical`/`## Major` tagged `[ask N]`, `[regression]` or `[unanchored]` (`:1582`), else MALFORMED: exit 4, re-asked once, then ABSENT.
- `scripts/cycle.sh:1122-1139` judge reads review.md; a BLOCK with no real `[ask N]` and no `[regression]` is downgraded to PASS, note "review BLOCK unanchored".
- `scripts/cycle.sh:1189-1215` verdict rule: BLOCK with review_asks or regression -> RED unless no-progress or ceiling.

## Contracts
- ESCALATE reasons are a closed set `ceiling|half|env|no-progress`: `cmd_escalate` usage (`cycle.sh:1311`, `:1312`, `:1320`), judge rule (`:1194-1202`), ADR-001 D1 table (`:141`, `:161`), D2 verb row (`:63`, `:204`).
- `env` fires only on absent_seats (`:1144-1154`, `:1194`), only when nothing is RED and review is not BLOCK; note built at `:1227` "<seats> ABSENT"; ledger `escalate` null or a reason (`:1221`).
- Exit 6 = ESCALATE (`:1286`); `## Needs a human` written at `:1242-1265` with reason-specific lines.
- `cmd_escalate` (`:1295-1362`) works only on an open round with a seat missing (`:1340`); otherwise falls through to judge (`:1343`).
- Review layout (lead-review.md:76-96) positional: VERDICT, MODEL, `## Critical`, `## Major`, `## Minor`; no escalate signal.
- `CLAUDE.md:74-91` `## Commands` is `| Purpose | Command |`; last row `| Full suite / build | none: no test runner, no build step |` (no backticks, not a cell). Blockquote at `:69`: "A story's `## Verification` must name one."

## Dependencies
- `command_cell_exists` callers: close-story (`cycle.sh:1978`, `:1981`), wave-check (`:223`, `:226`), both through lib.sh.
- Review dispatch: `.claude/workflows/vulyk-cycle.js:25` (review -> lead-review), `:173-178` (two reviewers at Tier 4), `:22`/`:203` TERMINAL includes `escalated`. `.claude/commands/vulyk-build.md:26` dispatches lead-review, `:91` handles `escalated` (prints `## Needs a human`, owner chooses). Both drivers stop on `next: escalated`: no driver change needed for a new reason.
- Hives: `install.sh:291` writes a placeholder Commands block on fresh install; `:1416-1458` restores a missing block only on --upgrade; `:394-424`, `:515-521` carry it over on `--constitution replace`. A hive's table is never overwritten: a new mark reaches existing hives only via bootstrap or by hand.
- CI (`.github/workflows/ci.yml`): bash -n, top-model, cycle (`:114`), council (`:125`), handoff-window, driver/e2e/solo/maintenance (`:147-156`), telemetry (`:165`), token-report, install smoke. CI does NOT run defects, intake, inject, mods, model-profile. maintenance is red on main (`:156`).

## Gotchas
- Purpose is not parsed: the mark needs a new row-aware lib reader, `command_cells` untouched; `command_cell_exists` is boolean, so the refusal needs its own lookup.
- The same command text can sit in a round-only row and an allowed row (council full vs --quick are different texts today); the check must be "is this command in a round-only row", not "is it a cell".
- `env` already means "seat absent" (`:1194`, ADR D4 `:301`): a suite timeout needs its own reason. `escalate`/`reason:` are free strings in code but the `cmd_escalate` usage rejects unknown reasons.
- The reviewer cannot escalate by itself (`cmd_escalate` needs a missing seat). Narrowest seam: a machine-readable line in the review report, parsed positionally like `review_verdict_of`/`review_anchor_asks`/`review_has_regression`, turned by a new judge branch into ESCALATE with a new reason and the time as the note (via `review_note`, `:1228`); it must outrank a BLOCK and not hit the `:1194` `review_v != BLOCK` condition; own `## Needs a human` lines (`:1253-1263` pattern) and `redact_note`; record-seat must not mark it MALFORMED (a PASS with the marker is valid today; a BLOCK needs a tagged finding, `:1582`).
- Failed test = BLOCK already works with `[ask N]`/`[regression]` under Critical/Major; only lead-review.md:49-52 text changes. Unanchored BLOCK is downgraded (`:1130-1131`).
- Round-only refusal in close-story should use exit 2 (worker returns NEEDS_CONTEXT), not exit 4 (three retries then WALL).

## Files by ask
- Ask 1: tests/telemetry.test.sh, tests/council.test.sh (`--part <topic>`), CLAUDE.md:74-91 rows.
- Ask 2: a new runner script (e.g. scripts/full-suite.sh), CLAUDE.md:91, lead-review.md:49-52, templates/plan.md:35-38, .github/workflows/ci.yml (optional), install.sh (manifest/OWNED lists if shipped), tests/maintenance.test.sh (description budget already over by 325 B).
- Ask 3: lead-review.md:49-52 and :72-97, scripts/cycle.sh (record-seat :1566-1599, judge :1122-1139 and :1189-1215, :1242-1265, cmd_escalate usage :1311-1320, stats row :1221-1233), docs/adr/001-cycle-state-contract.md (D1 :141 :161, D2 :63 :204, D4 :296-304, D6 :369, D3 :254 if layout changes; dated amendment as at :110), vulyk-build.md:91 (wording), tests/council.test.sh.
- Ask 4: scripts/lib.sh:130-189, scripts/wave-check.sh:31-33 and :216-234, scripts/cycle.sh:1968-1991, CLAUDE.md:69 and :74, tests/cycle.test.sh:346-363, tests/council.test.sh:1488-1505.
- Ask 5: .claude/commands/vulyk-bootstrap.md:31-37, templates/story.md:69-92, templates/plan.md:35-38, .claude/agents/queen-planner.md:29-31, worker-code.md:24-25, worker-test.md:24-25, install.sh:209 (placeholder comment, print_commands_placeholder).

## Test sites
- tests/cycle.test.sh:346-363 wave-check verify-cell.
- tests/council.test.sh:1488-1505 and :1882 close-story refusal (exit 2).
- tests/council.test.sh:3608, :3981-3994 close-story timeout fixture.
- tests/council.test.sh:624, :1228 (judge env), :2072-2118 (escalate verb), :2495-2530, :3737 (review-ABSENT env), :503, :520, :572, :608 (ceiling, no-progress, half) - where a new judge reason case goes.

## Not read
telemetry/council internals for splitting (see scout-suites.md); write_escalate_row_for_round, review_verdict_of, review_anchor_asks; docs/cycle.md.
