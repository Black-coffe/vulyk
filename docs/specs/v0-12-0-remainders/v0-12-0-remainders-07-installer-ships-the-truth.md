---
story: v0-12-0-remainders-07
spec: v0-12-0-remainders
status: todo
returned:
tier: 4
worker: worker-code
tracer: false
wave: 2
blocked_by: [v0-12-0-remainders-02]
---

# The installer ships no ADRs or wiki, and carries missing Profile/Commands blocks into an upgraded constitution

## Goal
ADR-005 D1 and D3 built: `shippable()` denies `docs/adr/*` and `docs/wiki/*` (README allowed); on `--upgrade` a new `ensure_marked_block` inserts a missing `VULYK:PROFILE`/`VULYK:COMMANDS` section at the source's position in `CLAUDE.md` and in the sidecar `CLAUDE.vulyk.md`, warns instead of writing when markers are half-present or a hand-written heading exists, and every `--upgrade` prints which rows still hold `<fill in`. The two placeholder texts move out of `reset_commands_table` into print functions shared by reset and insert. `ensure_gitignore` ships the `docs/specs/*/DRIVER` entry story 11 needs. `install-smoke` gains ADR-005 D4 assertions 1, 7, 8, 9, 10 and 11's block half.

## Requirements
> Инсталлер не отгружает docs/adr и docs/wiki, и его фразы «not touched» становятся правдой.

> При апгрейде конституция получает недостающие блоки Profile/Commands, заполненные не трогаются.

> Второй драйвер на том же спеке получает отказ — семафор DRIVER через cycle.sh claim/release (M-7, решено в дельте 6).

## Files
- install.sh
- .github/workflows/ci.yml

## Non-goals
- No manifest, no removal, no `would remove`/`would write` (story 10); do not add the manifest arm to `shippable()` here.
- Never write between existing markers, never touch a block with one marker or a marker-less `## Profile` heading (WARNING only), never open the foreign `CLAUDE.md` beside a sidecar.
- Do not touch the fresh-install copy path beyond routing its reset through the shared print functions; do not touch `wire_session_hook`, `wire_permissions`, `top-model.sh --apply`, `scripts/vulyk-update.sh`.
- No job other than `install-smoke`; existing steps stay (including filled-Profile-untouched at `ci.yml:206-214` and the row-count check at `:170-173`, which must now cover the shared printers).
- Never run `install.sh` against this repository or a real directory; smoke in `mktemp -d` only.

## Map slice
`docs/adr/005-installer-upgrade-contract.md` D1 (the exact case arm), D3 (the four-row action table, the `still hold <fill in` line, the print functions), D4 items 1, 7, 8, 9, 10, 11 · `recon/install-and-update.md` (flow order, `shippable()` `:49-65`, `reset_marked_block` `:103-125`, `reset_commands_table` `:127-153`, constitution branches `:362-416`, `ensure_gitignore` `:320-345`, header `:10`, footer `:452`, dry-run line shapes) · `recon/tests-ci-hooks-driver.md` §2 (`install-smoke`) · `plan.md` K7, K3 (gitignore entry), `## Assumptions` (the one addition to the ADR: the closing line names an insertion).

## Acceptance criteria
- [ ] `shippable()` has ADR-005 D1's arm verbatim; `--check` prints no `would copy docs/adr/` or `would copy docs/wiki/` line; after a real install `docs/adr/` and `docs/wiki/` exist and hold no `001-*.md`.
- [ ] `ensure_marked_block <file> <MARKER> <label>` implements D3's four rows for both markers in both constitution branches; `would insert`/`insert` lines as D3 names them; per-block `  profile: ...`/`  commands: ...` fill-in line printed on every `--upgrade`; the placeholder heredocs live in two print functions used by both reset and insert.
- [ ] When a block was inserted, the closing line at `install.sh:452` says so (plan `## Assumptions`); otherwise the wording at `:10`/`:452` is unchanged.
- [ ] `ensure_gitignore`'s `wanted` list gains `docs/specs/*/DRIVER`, written literally.
- [ ] `install-smoke`: D4 assertion 1 (no ADR/wiki), 7 (missing Profile restored, row count, `## Profile` before `## Commands`, `Client path` named), 8 (missing Commands lands before `## Compact instructions`), 9 (marker-less heading: WARNING, byte-identical), 10 (sidecar restored, foreign `CLAUDE.md` byte-identical), 11 (`--upgrade --check` after 7 changes nothing: tree checksum), plus `docs/specs/*/DRIVER` present in the target `.gitignore`.
- [ ] Hand smoke in `mktemp -d` of D4 items 1, 7-11; results in the notes. `bash -n install.sh` passes.

## Verification
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
