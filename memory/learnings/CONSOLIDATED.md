# Consolidated learnings

<!-- Maintained by librarian (/vulyk-gc). At most 40 entries, newest evidence wins. Sources merged
     2026-09-29: 2026-07-27-opus-5-migration, 2026-09-12-human-gates-rework,
     2026-09-14-fable-review-remainders, 2026-09-14-lean-cascade. Model-ladder claims from those
     files are superseded by ADR-015 (2026-09-28: Sonnet executes, Opus judges) and not kept. -->

## Human in the loop
1. The only mandatory human stops are at the start: the grill in `/vulyk-plan` and the plan
   approval (default since v0.13.0; `--go` is the opt-in skip, ADR-008). Never reintroduce
   "owner looks" as a mandatory mid-cycle stage for any tier (v0.11.0 did; owner reverted it a
   week later). After the start: agent gates with evidence, or escalation with a round ceiling.
   (2026-09-12, 2026-09-14; full reasoning `docs/grill/2026-09-12-autonomous-cycle-council.md`)
2. Irreversible outward actions (publish/deploy) stay with the human, but are not waited on: print
   the command, continue. (2026-09-12)
3. Before adding any mandatory human participation, ask: did the owner request this stop, or does
   it only feel right to us? (2026-09-12)
4. When the same owner complaint arrives a second time (e.g. "too many subagents for a small
   task", ADR-002 then ADR-008), remove the mechanism; do not shrink it. (2026-09-14)

## Routing
5. A request whose deliverable is a document must never reach `cycle.sh`. Ask the deliverable
   before the tier, every time; never assume "code". (2026-09-14, ADR-008)

## Worker / council contracts
6. When a worker reports a contract gap mid-build, check the ruling against the existing ADR
   invariants, not just the ask: story 07 of fable-review-remainders satisfied the letter of C3 but
   made the driver read worker chat prose, violating ADR-006 / ADR-001 C11, and was BLOCKed.
   (2026-09-14, ADR-009)
7. A worker's mid-story finding is appended under `## Findings`; it never replaces the story's
   structural sections. If a diff shows missing story headers, restore the body from git before
   trusting the rewrite. (2026-09-14)
8. Report-by-file (`record-seat --file <path>`, report written as the agent's last Bash action)
   held for both council rounds with no lost report; no separate `test -s` probe is needed.
   (2026-09-14, ADR-009)

## Gates and commit order
9. A release-paperwork commit (version bump, changelog) after the last validated code commit
   stales `ship-check.sh`: it sees a HEAD it did not validate. Order paperwork accordingly.
   (2026-09-14)
10. Recurring friction: the build journal entry lands in a commit after the code it describes,
    leaving the tree dirty between them. Unfixed as of 2026-09-14; verify before relying on it.

## Claude Code platform
11. `effort:` in `.claude/agents/*.md` frontmatter was silently ignored (Claude Code 2.1.220,
    measured: inverted token spread, no error even for `effort: banana`), while `model:` is
    honoured. Effort is session-level (`/effort`, `--effort`, `effortLevel` in settings). Re-test
    after Claude Code upgrades; this is a parser gap and may close. (2026-07-27)
12. A schema found in a binary proves a field exists somewhere, not that your code path reads it.
    Behavioural probe, or it did not happen. (2026-07-27)
13. Native `agent-memory` is keyed by `agentType`; the main session (the Queen) is not an agent, so
    removing `memory/learnings/` for native memory would leave the Queen with none. (2026-07-27)

## Planning
14. Before importing someone else's fix ("simplify the scaffolding"), verify you have their
    problem: VULYK had no accumulated tuning to undo. (2026-07-27)
15. A plan that deletes must state how many references the deletions touch (the "8 docs" were
    112 references in 38 files, incl. `install.sh`, bootstrap interview, SVGs) and which event
    the replacement mechanism fires on. (2026-07-27)
