# Horizon: red-receipt

**Date:** 2026-10-28

## Trigger

Terms: "red stamp", "stamp-red", "red_verified", "failing test first", "TDD". Searched with grep in
`memory/memory.md`, `memory/map/`, `scripts/`, `.claude/agents/`, `.claude/commands/`, `templates/`:
zero hits on the capability. The neighbour that exists is static: `verify-gap` (`scripts/wave-check.sh:28,216`)
and the plan-time rule "names the test that fails when that logic breaks" (`.claude/commands/vulyk-plan.md:78`,
`.claude/agents/queen-planner.md:36-38`). Nothing records that a test was ever red. The step ran: three
lenses (altitude, depth, range), all returned.

## Candidates and verdicts

| Lens | Candidate | Verdict | Reason |
|---|---|---|---|
| altitude P1 | receipt: HEAD, test hash, command, exit, failure line; reject syntax/import failures | merged into H1 | same receipt as depth P1, range P2 |
| altitude P2 | `red: required` field by the existing critical list; close the "test story in a later wave" path | dropped as a proposal | it is the request's own scope ("для критичных историй"), asked as an ordinary question |
| altitude P3 | `cycle.sh repair` records the red itself for repair stories | dropped as a proposal | the request names bug fixes itself ("для багфиксов"), asked as an ordinary question |
| depth P1 | receipt with test and implementation hashes, failure class by runner exit/output parsing | merged into H1 | per-runner parsers cut to one stack-free rule: an expected failure text |
| depth P2 | close-story re-runs Verification in a worktree with base implementation files, demands red | merged into H2 | same as range P1 |
| depth P3 | named bypass `red_waived:`, explicit field, repair red by default | partly into H1 (no silent pass); waiver dropped | Law 2: the bypass is the planner not marking a story, visible in plan.md; a worker-side waiver is a second bypass |
| range P1 | `verify-red`: FAIL_TO_PASS on a base worktree plus the story's tests | merged into H2 | sources `не подтверждено` (undated pages) |
| range P2 | `red_reason:` expected failure text; 126/127, syntax, collection errors are not red | merged into H1 | |
| range P3 | seal: sha256 of test files; changed test after stamp refuses close; missing stamp refuses | merged into H1 | |
| all three | a script check banning mocks of unwritten logic | dropped | fragile, not script-checkable; stays a worker prompt rule |
| depth, range | mutation testing (Stryker, mutmut) | dropped | a tool per stack, not "0 tokens in a second" |

## Kept proposals

### H1 - the receipt proves the right red and seals the test
- what: `stamp-red` accepts red only when the output carries the story's declared expected failure text
  and the exit is not a launch failure (126/127); it writes the receipt (test files' hash, the failing
  command, exit code, first failure line). `close-story` refuses a critical story with no receipt, or whose
  test files changed after it (a re-stamp is the way back); and refuses when no implementation file changed
  since the receipt (a green that came from nowhere).
- why: a bare `exit != 0` stamps a typo or a missing import as red, and a test weakened after the stamp
  still closes - the defect class `safeguard-bypassable-or-late`.
- cost: one field in the story template (`red_reason`), hash logic in two verbs; a false refusal when a
  test legitimately changes after red, cured by re-stamping.
- check: cycle.test.sh fixtures: syntax-error test refused; expected failure stamped; test edited after
  stamp refuses close; no stamp refuses close.
- sources: none: repo only
- status: confirmed
- kind: gap - rests on «именно по нужной причине, а не из-за синтаксиса» and «тест реально тестирует новую логику, а не является пустышкой»
- ask line: stamp-red принимает красный только с ожидаемым текстом падения и пишет квитанцию с хешем теста; close-story отказывает без квитанции или если тест правили после неё.

### H2 - close-story checks red itself on the pre-story code (FAIL_TO_PASS)
- what: for a critical story `close-story` builds a temporary worktree at HEAD (the code before the story),
  copies in only the story's test files, runs the red command and demands a failure, then the normal green run.
- why: nothing for a worker to forget or forge; covers tests written after the code and the Queen's solo builds.
- cost: about 2x verification time on critical stories inside the 540 s budget; a fresh worktree lacks
  untracked dependencies (`node_modules`, `.venv`), so in most hives it fails for the wrong reason and
  passes as red.
- check: fixture repo: tautological test refused, real test passes; time measured on VULYK's own suites.
- sources: https://openai.com/index/introducing-swe-bench-verified/ (undated, read 2026-10-28),
  https://huggingface.co/datasets/princeton-nlp/SWE-bench/blob/main/README.md (undated, read 2026-10-28)
- status: не подтверждено
- kind: extension
- ask line: close-story для критичных историй сам прогоняет тест на коде до истории во временной копии и требует падения.
