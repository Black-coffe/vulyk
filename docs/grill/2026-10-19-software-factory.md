# Grill: software-factory ideas into VULYK

```
status: done
level: quick
hardness: medium
lens: product
evidence: docs/specs/software-factory-study/ (report.md, research-*.md, council-*.md)
```

## Questions and answers

1. When to study a worktree per spec? Recommended: after specs 1-2. **Owner: after specs 1-2.**
2. A ship touches an owner-named escalate path: warn or a second stop? Recommended: warn. **Owner: warn.**
3. VULYK's own escalate list? Recommended: install.sh, cycle.sh + lib.sh, CLAUDE.md, .github/workflows/. **Owner: all four.**
4. Spec branches after ship? Recommended: delete with `-d`, refuse reuse, clean the 24 merged ones. **Owner: yes.**
5. Hives that need npm/pip install for their tests? Recommended: assume yes. **Owner: yes.** Recon confirmed: most Node/Python hives carry `N/A ... environment:` seat files.

## Decisions

See `docs/specs/software-factory-study/report.md` § Owner decisions.

## Synthesis

- Verdict: adopt the factory's git hygiene and its owner-escalation idea; keep VULYK's script state machine and blind court; study parallel specs later.
- Assumptions: ✓ every load-bearing VULYK claim re-checked in code (report cites lines). ✗ `EnterWorktree` behaviour not checked (study 4).
- Contradictions: the video notes said the spec writer asks questions; the source shows only `## Assumptions` (fixed). Sonnet's "seats are fresh each round" contradicted by `lead-review.md:35-38` (dropped).
- Residual ambiguity: goal 9/10, decision coverage 8/10, evidence 8/10.
- Next step: `/vulyk-plan ship-safety` in the owner's words.
