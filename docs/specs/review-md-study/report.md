# Study: what VULYK takes from the REVIEW.md / six-layer review video (report)

Date: 2026-10-21 · Brief: [brief.md](brief.md) · Source: Recall #9119 (YouTube, Switch Dimension), checked against
Anthropic's own post "How the Claude Code team does code review" (claude.dev/blog/solving-code-review-at-anthropic,
2026-10-15) and the Code Review docs (code.claude.com/docs/en/code-review).

## Bottom line

Yes, we build, but only two things, plus one fix that is the owner's call. Of the 14 review mechanisms in the
video, VULYK already has 9: proof before review, a fresh-context reviewer, fixing a repeated finding at its source,
a cap on nits, the round ceiling, re-reviewing only the delta, approval tied to one commit, the merge check against
main, and no agent approval standing in for the owner.

## Findings

1. **The reviewer does not see the project's own rules (the REVIEW.md gap).** Cards in `docs/defects/` reach an
   agent only through `.claude/hooks/defects-inject.sh`. It matches a card's `paths:` against an Edit-family path or
   a path token in a Bash line (`.claude/hooks/defects-inject.sh:5-7`, matcher in `.claude/settings.json:34`,
   which has no Read). `lead-review` reads the diff with a bare `git diff <base>..<head>` (`.claude/agents/lead-review.md:33-35`)
   and judges asks, correctness, warn-only checks and defect debt (`:13-24`), never a card's Never or How-to line.
   Probe run this session: `git diff f8e4fdc~3..f8e4fdc -- install.sh` delivered three cards, while the same diff
   without `-- <path>` delivered none. A text card (no `check:`) therefore guards the writer and nobody after them.
   Anthropic's REVIEW.md is this exact thing: "written by code owners, tells the reviewer what matters in their part
   of the code" (the post).
2. **A finding names one place, not its class.** `lead-review.md:58-60` asks for one condition per finding. Round 2
   reads only the delta (`:35-38`), so a sibling of a fixed finding that the diff leaves alone waits for the next
   circle. The post's fix: "flag the whole class of bug, not one line".
3. **A new security hole cannot block (found by the panel).** `lead-review.md:20` counts "security holes" as
   correctness, yet BLOCK holds only on `[ask N]` or `[regression]` (`:49-55`). A hole in new code that no ask names,
   and that is not a regression, ends as `[unanchored]` and `cycle.sh:1131` records the round PASS. The constitution's
   Law 2 says the simplest thing "never drops ... security checks". The video's layer 3 is a hard gate on open
   security findings.

Already covered (not rebuilt): M1 `## Verification` via close-story, M2 fresh-context review, M3 Law 6 cards and a cap
of five minors, M6 the suites, M8 `human-check.sh` and card owner-words-by-builder, M9 STALE after a new commit
(`docs/cycle.md:82`), M10 strict merge-tree (`scripts/ship-check.sh`, 0.31.0), M13 the ceiling, the delta-only
re-review, anchors and new-by-blame (ADR-018), M14 the evolve council numbers. M7 (risk set by the change) is
already queued as `owner-at-ship` (`docs/specs/software-factory-study/report.md`, Recommended work 2).

Rejected: a separate security seat, a per-finding vote (M4), a revert circuit breaker (M12), and a daily replay of
past incidents against the reviewer (M11). Each adds agents or token spend every round, which Law 2 and the token
budget rule out. VULYK also has no revert data to drive a breaker. Law 6's `check:` already turns a repeated miss
into a gate the reviewer runs.

## Validation

Three-model crossgrill (Fable, Opus and Sonnet, two rounds, anonymized). The run files sit in
`.crossgrill/2026-10-21-review-md/`, which git ignores. Findings 1 and 2 are 3/3. The panel unanimously
overruled the Queen's first idea, a new `[card]` anchor that could BLOCK: a card finding stays non-blocking
(`[unanchored]` major, which reaches the owner at `/vulyk-ship`, `.claude/commands/vulyk-ship.md:45-46`), and a card
broken again earns a `check:` under Law 6. Finding 3 came from the panel. Its fix (below) is the Queen's proposal and
was not put to the panel's vote. Fact-check: the REVIEW.md mechanism and the post are confirmed by the two primary
pages above. "The local /code-review ignores REVIEW.md" is unconfirmed and is not used.

## Not read or run

The live hives' review records: how often workers break text cards is unmeasured. The council-opus seat runs in a
court worktree, and whether the hook fires there was not checked.

## Options (recommended first)

1. **Build A + B + C as one Tier 1 change to `lead-review.md` (recommended).** A: read the diff file by file so the
   hook delivers the cards, and a broken Never/How-to line becomes an `[unanchored]` major naming the card. B: a round-1
   finding names every place in the diff where its condition fails, and a sibling outside the diff gets one `[unanchored]`
   line. C: a security hole or data-loss path the diff adds breaks the ask whose code carries it, so it is anchored
   `[ask N]`. Zero script code, no new anchor, cycle.sh untouched.
2. A + B only: if the owner wants new-code security holes to keep waiting for the next circle.
3. Nothing: only if the owner judges the unmeasured card gap not worth a reviewer instruction.

## Candidate stories

- `review-md-01`: `lead-review.md` A + B (+ C if chosen), and a CHANGELOG line.
