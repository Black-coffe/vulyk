# Session 2026-09-14 - lean-cascade (v0.13.0)

- **Owner feedback, verbatim intent:** v0.12.0 on other hives (FIBI, YouTube AI) "does simple
  things for too long" and, asked to validate/monitor a project and produce a spec-as-plan, wrote
  scripts and spent the subscription limit. Validated against the framework's own text: true by
  design - `/vulyk-plan` step 10 launched the build with no approval stop; the routing matrix had
  no document deliverable; recon dispatched up to seven agents before code; the suite ran up to
  four times per story. ADR-008 records each fix.
- **Owner rule, verbatim intent:** lead = Fable, senior = Opus, mid = Sonnet, junior = Haiku
  only from generation 5 - Haiku 4.5 is never dispatched. ADR-007. When a Haiku 5 ships, flip
  `council-haiku.md`, `cycle-clerk.md`, `session-end-learnings.sh`.
- **Lesson:** a request whose result is a document must never reach `cycle.sh`. Ask the
  deliverable before the tier, every time, and never guess "code".
- **Lesson:** an approval that nobody reads is the expensive kind; the plan stop is the default
  again and `--go` is the opt-in. ADR-002 already carried the owner's earlier ask in the same
  direction ("покрасить кнопку - 1-2 сабагента, а не 10") - the second time the same complaint
  arrives, the fix has to remove the mechanism, not shrink it.
- **Mechanics:** this spec was built by the Queen's own hands on the owner's explicit
  instruction ("only Fable"), in a separate worktree (`../vulyk-lean`, branch
  `vulyk/lean-cascade`) while the v0-12-0-remainders driver held the main tree; Law 5 exception
  recorded in the plan.
