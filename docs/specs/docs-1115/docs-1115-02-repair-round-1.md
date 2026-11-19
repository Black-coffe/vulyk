---
story: docs-1115-02
status: done
returned: DONE
worker: worker-code
model: opus
wave: 2
blocked_by: []
narrow: true
---

# Repair round 1

## Goal
Make the asks and findings council round 1 left RED pass, and change nothing else.

## Requirements
> 1. Every doc sentence the inventory items T18, T19, T21, T60, T66, T79, T81, T82, T83, T84, T86, T88 (A10), T89, T91, T99 (A11, README only) and the doc halves of T65, T80, T90 name says what the code does at HEAD; nothing else in those pages changes.
> 2. The doc lines `tails-1115` handed on are applied: the `memory/map/` lines of its stories 01, 02, 05 (listed under story 11's `## Findings`), and `.claude/commands/vulyk-bootstrap.md:23` (one blind seat, swapped for `haiku` when *Client path* is filled); `docs/hooks-reference.md` describes the 0.54 guard hooks in the general words of their headers; `docs/token-economy.md:144` matches the code.

## Findings
1. docs/command-reference.md:6 [ask 1] the T81 sentences for `/vulyk-bootstrap` and `/vulyk-models` must say what the commands do at HEAD: `--quick` asks nothing and lists the gaps it defaulted and bootstrap dispatches no scout (`.claude/commands/vulyk-bootstrap.md:15`, `:61`), and `/vulyk-models` puts `sonnet-builds` first on every plan (`.claude/commands/vulyk-models.md:16`, against `docs/command-reference.md:48`), where the story's T81 note records both as "already matched" - repro: `grep -n 'asks for one confirmation\|up to four in parallel\|recommended for the detected plan' docs/command-reference.md` prints lines 6 and 48
2. docs/token-economy.md:146 [ask 2] the narrow-round paragraph must name every case in which the code opens a full round after a repair: its "only when" list leaves out a `half` escalation the owner reopened without `--full`, which `round_scope` answers with `full design` (`scripts/cycle.sh:4730`; `docs/cycle.md:103` and card `full-round-for-a-narrow-fix` both list it) - repro: `sed -n 144,147p docs/token-economy.md; sed -n 4726,4731p scripts/cycle.sh`

## Acceptance criteria
- [ ] The class card under docs/defects/ (its quote, Never line or check:) is added or updated in the same commit as the fix.

## Files
- docs/command-reference.md
- docs/token-economy.md
- docs/defects/*

## Implementation notes
- Finding 1: docs/command-reference.md:6 now says bootstrap reads facts first, `--quick` asks nothing and lists the defaulted gaps, and no scout runs (modules listed unmapped), per .claude/commands/vulyk-bootstrap.md:15, :61; line 48 says `sonnet-builds` goes first and recommended on every plan, `opus-builds` never recommended, per .claude/commands/vulyk-models.md:16. The repro grep prints nothing.
- Finding 2: docs/token-economy.md:146 adds the `half` escalation the owner reopened (scripts/cycle.sh:4730, docs/cycle.md:103).
- Minors inside ## Files: token-economy.md:37, :50 take model-cascade.md:128's list (Fable 5.1 and later, Opus 5.5, Sonnet 5.5, Haiku 5.5); :151 runs token-report through `bash scripts/py.sh`.
- No docs/defects card edited: a reviewer finding, not an owner correction; class claim-not-from-source already covers it.
- No round 2: owner 2026-11-18 «Чиню сам, без раунда 2 (Рекомендую)».

## Findings
Left for the next circle (outside ## Files): templates/memory.md:3 ("always loaded", "Humans welcome too"); docs/memory-system.md:9 writer list vs vulyk-bootstrap.md:63, vulyk-map.md:11; docs/getting-started.md:43 old model list; bare `python scripts/token-report.py` in docs/faq.md:44, docs/self-evolution.md:21, memory/memory.md:37; README.md:48 ("optionally Agent Teams"), README.md:168 ("initial map").

## Verification
`bash tests/maintenance.test.sh --part upkeep`
`bash scripts/defects-check.sh`
