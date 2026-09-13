---
story: v0-12-0-remainders-12
spec: v0-12-0-remainders
status: done
returned: DONE
tier: 4
worker: worker-code
tracer: false
wave: 4
blocked_by: [v0-12-0-remainders-10]
---

# The session brief stops spawning the CLI for a gate it cannot decide

## Goal
`.claude/hooks/top-model-brief.sh` no longer runs `claude --version`; its Workflow line says the driver is decided in-session by the Workflow tool's presence, and CI proves the hook never spawns the CLI.

## Requirements
> Сессионный бриф не запускает CLI ради гейта, который не может определить (m-11).

## Files
- .claude/hooks/top-model-brief.sh
- .github/workflows/ci.yml

## Non-goals
- Do not touch the three `top-model.sh` calls, the pin warning, or the `[VULYK] top model:` line's other fields; do not read any new env var or cache file as a substitute CLI-version source.
- Do not edit `/vulyk-build` step 1 (it already detects the `Workflow` tool itself), `docs/architecture.md:76` (LR35, next circle) or `session-start-brief.sh`.
- No job other than `top-model`; existing assertions at `ci.yml:83-86` stay, adjusted only where they grep the old CLI text.
- Set `returned: DONE` in this story's own frontmatter before returning (story 08's gate is live).

## Map slice
`recon/tests-ci-hooks-driver.md` §3 (the hook's flow; lines 41-58 spawn `claude --version`; no alternative source exists) and §2 (`top-model` job, hook assertions `:83-86`) · `plan.md` `## Next circle` of the previous spec m-11 · `memory/map/agents-and-commands.md` (`/vulyk-build` resolves driver mode from the tool list).

## Acceptance criteria
- [ ] `grep -n 'claude --version\|command -v claude' .claude/hooks/top-model-brief.sh` is empty; the `2.1.154` literal and the `sort -V` compare are gone.
- [ ] The brief's Workflow fragment reads `Workflow driver: decided in-session (Workflow tool present -> vulyk-cycle.js, else fallback loop)` or a one-line equivalent that makes no claim about the CLI version.
- [ ] `top-model` job: a fake `claude` executable placed first on `PATH` that writes a sentinel file; the hook runs; the sentinel is asserted absent and the output line is asserted to contain `Workflow driver:` and not `CLI`.
- [ ] Hook still exits 0 with `scripts/top-model.sh` missing and with `VULYK_TOP_MODEL_BRIEF=0`; `bash -n` passes.

## Verification
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->
- `.claude/hooks/top-model-brief.sh`: removed the `claude --version`/`sort -V` block entirely; `WORKFLOW` is now the static one-line equivalent named in the acceptance criteria - no CLI spawn, no version literal.
- `.github/workflows/ci.yml` (`top-model` job): added a fake `claude` on `PATH` writing a sentinel; asserted the sentinel stays absent and the hook's output line contains `Workflow driver:` and not `CLI`. Used `printf` instead of a heredoc for the fake script's contents - a heredoc inside YAML's `run: |` block scalar breaks the block's indentation and fails YAML parsing.

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
