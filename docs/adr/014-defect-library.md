# ADR-014: Owner corrections become defect classes with failing checks

- Status: accepted (owner, 2026-09-27: «Одобряю. Собирай сам»)
- Date: 2026-09-27 · Version: 0.19.0
- Evidence:
  - grill `docs/grill/2026-09-27-self-learning-corrections.md` (D1–D16 and its adversarial review);
  - pilot feedback `docs/grill/2026-09-27-self-learning-pilot-feedback.md` (YouTube_AI specs 15–16; video 3
    accepted with no remarks);
  - plan `docs/specs/self-learning/plan.md` and build contract `docs/specs/self-learning/contract.md`.
- Supersedes: the retired `memory/learnings` session-end distillation as VULYK's answer to "learn from
  the owner". Session memory is litopys's job; this ADR covers prescriptive knowledge.

## Context

In YouTube_AI one class of defect, clipped speech, came back in three videos in a row (~10 hours of
owner time). The lesson had been written down on 2026-09-17 twice: in auto memory and in a path-scoped
rule. Three things were wrong, and the pilot confirmed each:

- **The code produced the defect.** `voiceover.py` snapped a clip's end to the next word, so the tail
  came out 0.00 s.
- **The warning did not block.** A check named the defect but exited 0, and a worker wrote it off as
  "не отказ".
- **The detector looked in the wrong place.** `torn_cuts` measured timeline joins, not the ends of
  voice tracks.

Prose was a weak carrier too. Path-scoped rules load only when Claude reads a matching file, never on
Edit, Write or Bash, and they vanish after compaction (code.claude.com/docs/en/memory). But the
decisive failure was a check that did not fail.

The pilot built a defect library and a gate that fails. The owner then accepted video 3 with no
remarks. The pilot also showed where that approach falls short:

- a block catches only the past shape of the defect;
- a timecode-only intake hook fired on harness notifications and pasted text (4 false positives, 0
  useful);
- the council's independent measurement caught a loudness problem that project gates had only warned
  about.

## Decision

- **D1 — a defect class is a card in `docs/defects/<id>.md`.** It holds verbatim owner quotes (date ·
  material · place), cause, never/allowed, `check:`, `fixtures:`, `keys:`, `paths:`, and `status: block |
  text | revoked`. One card per class, not per place.
- **D2 — `block` must be earned.**
  - A card is `block` only with a `check:` and at least two fixtures: the original case and a
    neighbour-form negative (the same complaint in another shape).
  - Every fixture must make the check exit non-zero; a fixture that passes marks the gate blind.
  - Otherwise the card counts as `text`.
  - There is no `warn` status. A check that only warns is not a check.
- **D3 — debt fails the gate.** A class with two or more quotes, not effectively `block`, with a quote
  committed after the library was created (git blame time, not the date in the text), fails
  `scripts/defects-check.sh`. A repeat therefore turns into a failing check without relying on anyone's
  memory.
- **D4 — no warn stage.** The grill proposed warn → block (grill D11). The pilot showed that warn is the
  exact state the 09-17 lesson lived in. False positives are fixed in the same work by normalisation,
  never by an exception list.
- **D5 — intake reads only the human.** The `defect-intake.sh` hook (UserPromptSubmit) strips
  task-notifications, system reminders, cross-session messages, pasted content and code fences. It then
  fires on a timecode, a correction lexicon (RU/UK/EN) or a card's `keys:`, and adds one line of
  context. It never blocks.
- **D6 — `text` cards are pushed before the action.** The `defects-inject.sh` hook (PreToolUse,
  Edit|Write|MultiEdit|NotebookEdit|Bash) matches `paths:` against the file path or the whole command
  line, where a `cmd:` entry is a regex. It injects the card's never-lines once per session and agent,
  and again after compaction or clear. `block` cards are not injected; their check speaks.
- **D7 — review treats a warning as a finding.**
  - `lead-review`: a check that names a defect and exits 0 is a major on the ask.
  - `council-opus`: measures the observable itself; a project gate's green is not its `saw:`.
- **D8 — a manual step is a wave dependency.** `blocked_by: [manual:<id>]` holds a wave until
  `cycle.sh manual-done <spec> <id>`. The driver stops with a named manual state instead of dispatching
  a worker into NEEDS_CONTEXT.
- **D9 — Law 6** in the constitution states D1–D3 in one line. Nothing is added to per-turn context
  beyond the hooks' conditional lines.
- **D10 — litopys is offered, not imposed.** When it is missing and not declined, the session-start
  brief asks the owner once. Consent installs it at project scope; a refusal is recorded as a Profile row.

## Consequences

- VULYK learns by adding checks to the host, not by growing prompts. A host with no `docs/defects/`
  is unaffected: both hooks exit silently.
- Card format is shared with YouTube_AI's library, which keeps working. Its block cards without
  fixtures now count as `text` until fixtures are added.
- A SessionEnd hook that runs `claude -p` is reported as an anomaly: SessionEnd hooks get at most 60 s.
- Rejected:
  - a lesson tree with counters and escalation (grill D6/D8/D9) — the debt rule does the job with one
    mechanism;
  - a personal tree in `~/.claude` (D16) — deferred until hosts show the need;
  - an LLM classifier per prompt — cost plus P 0.43 / R 0.58 in the literature;
  - a warn stage (D4).
