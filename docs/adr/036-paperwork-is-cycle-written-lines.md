# ADR-036: In `brief.md` and `plan.md`, paperwork is only the lines a cycle script writes

- Status: proposed
- Date: 2026-11-14
- Spec: docs/specs/audit-fixes-1113 (ask 10, story 14; contract P1)

## Context
Plan delta, 2026-11-14 (the cut that gave this rule its own story):

> story 09 missed twice at the turn cap (both workers built in a scratchpad copy).
> lead-architect (Fable) cut it by ask into three serial stories, each alone in its wave because each
> rewrites `close-story`/`claim`: 09 (ask 8, wave 3), 13 (ask 9, wave 5), 14 (ask 10, wave 6); the
> own-fixtures gate item moved to story 12. Contracts S1/A1/P1 unchanged.

The rule is contract P1: "`is_paperwork_path` no longer answers yes for `<spec>/brief.md` and `<spec>/plan.md`. A
change to either is paperwork only when the changed lines are the ones a cycle script writes: in `plan.md` the
marker lines (`**Briefed:**`, `**Branch:**`, `**Council:**`, `**Checked:**`, `**Shipped:**`) and the
`## Needs a human` block; in `brief.md` what `reopen` appends under `## Answers`. [...] A `revise` commit is the
accepted way to change either file during a build. Every cycle commit stages its named files, never the spec
folder." Its scope, from `## Assumptions` (ask 10): "`VERSION`, `CHANGELOG.md`, `CITATION.cff` and
`memory/stats/*.jsonl` stay paperwork, so a release commit after GREEN does not stale the verdict."

## Options
1. Judge the changed lines of the two files against what a cycle script writes (chosen).
2. A commit-based rule over a ledger of `cycle.sh` commits. Rejected in `## Contracts`: "today a cycle verb run
   without `--commit` leaves its lines for a hand commit, so a commit-based paperwork rule would stale a round on
   the cycle's own writes".
3. The literal reading, nothing but `cycle.sh`'s own files is paperwork. Named in `## Assumptions` for the owner's
   veto; not taken, because a release commit after GREEN would stale the verdict.

## Decision
A change to `brief.md` or `plan.md` is paperwork only when every changed line is one a cycle script writes. Any
other changed line is a hand edit: dirty or committed since the claim head, `close-story` exits 4 naming the file;
committed after `ROUND.head`, the round is stale and `status` names the file and the commit. During a build either
file changes through a `cycle.sh revise` commit. Cycle commits stage their named files only.

## Consequences
Not recorded beyond the contract: a hand edit of either file during a build is named and stales the round.

## Invariants created
- `is_paperwork_path` never answers yes for a whole `<spec>/brief.md` or `<spec>/plan.md`.
- A new marker line or block a cycle script writes into either file must be added to the paperwork line set, or
  it stales the round.
- A cycle commit stages the files it names, never a whole spec folder.

## Revisit when
Not recorded.
