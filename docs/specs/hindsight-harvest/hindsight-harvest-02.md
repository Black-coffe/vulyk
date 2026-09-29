---
story: hindsight-harvest-02
spec: hindsight-harvest
status: todo
returned:
tier: 2
worker: worker-code
model: sonnet
wave: 1
blocked_by: []
---

# redact.sh masks nine more token shapes, handoff.py mirrors them

## Goal
`scripts/redact.sh` masks nine more token shapes that pass unmasked today: Telegram bot, GitLab `glpat-`, npm `npm_`, PyPI `pypi-`,
HuggingFace `hf_`, Groq `gsk_`, SendGrid `SG.x.y`, Stripe `sk_live_`/`rk_live_`, and Slack webhook URLs. `handoff.py`'s
`_REDACT_FALLBACK` gets the same list, as its header demands. `tests/maintenance.test.sh` pipes one sample per shape
through `redact.sh` and expects the mask. It also pipes four near-miss strings and expects them untouched.

## Requirements
> 2. redact.sh и handoff.py ловят токены Telegram, npm, PyPI, GitLab, HF, Groq, SendGrid, Stripe, Slack webhook

## Files
- scripts/redact.sh
- .claude/hooks/handoff.py
- tests/maintenance.test.sh

## Non-goals
- No card numbers, no PII, no entropy-based detection.
- Do not change the degrade-to-cat contract or the BSD-sed-safe style (no `I` flag, no GNU-only escapes).
- Do not create a new test file or CI job.

## Map slice
memory/map/scripts.md: the `redact.sh` section.

## Acceptance criteria
- [ ] Each of the nine shapes, embedded mid-sentence, comes out as `[VULYK:REDACTED]`. The Telegram shape is `<8-10 digits>:AA<33 [A-Za-z0-9_-]>`.
- [ ] These stay unmasked: a 40-hex git sha, a 30-char base64-looking word, the word `sk-learn`, and an ISO timestamp `2026-09-29T20:30:00+03:00`.
- [ ] `printf '' | sed "${SED_ARGS[@]}"` still succeeds, so the script does not degrade to `cat` on this box.
- [ ] `handoff.py` compiles, and its fallback masks the same nine shapes.

## Verification
`bash tests/maintenance.test.sh`
`python -m py_compile .claude/hooks/*.py`

## Implementation notes

## Findings
