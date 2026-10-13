# Grill brief: два постоянных агента-надзирателя в VULYK

<!-- supergrill-state
status: done
level: deep
hardness: medium
lens: product
stage: 0
stage_level: deep
questions_asked: 12
requested_inputs: []
open_branches: []
next_question: ""
web_policy: generic-only
updated: 2026-10-09
-->

Date: 2026-10-08 | deep | medium | product | Claude Code (workspace, E:/Projects/vulyk)

## Recon (what was known before the first question)

**What VULYK already has at stage 05 (council), per `docs/cycle.md`, `.claude/agents/lead-review.md`, `council-opus.md`:**
- `lead-review` (Opus, fresh context) judges the round's diff against `brief.md` `## Asks` and for correctness; BLOCK needs a finding anchored `[ask N]` or `[regression]` with a repro. Runs at every Tier 1+.
- Tier 3-4 add blind seats in a court worktree that holds only `brief.md`: `council-opus` (intent, edge cases, runs every ask) and `council-haiku` (black-box walk, only with a *Client path*). Green = unanimity.
- Rounds converge (spec `convergent-judge`, v0.17): RED → repair story; ceiling 1/2/3 RED rounds by tier; `no-progress` and "≥ 50 % asks RED" escalate at once.
- Strictness already scales with tier (ADR-002, ADR-013), but tier is assigned by **size** (one file / one module / cross-cutting / architecture), not by **risk** (`CLAUDE.md` routing table, `vulyk-plan.md` step 1). A one-file change to auth is Tier 0-1: no blind seat, one reviewer or none.
- `lead-review.md` contract, verbatim: *"Style, naming, a structure you would have chosen differently, or hardening for a configuration the Profile's Configurations that exist today does not list: leave it out, or make it a minor. A reviewer asked to find gaps finds some in sound work, and chasing them costs rounds and buys nothing."*
- Defect library (ADR-014, `docs/defects/README.md`): an owner's correction becomes a class card with a failing `check:`; this is the recorded mechanism for "what escaped". VULYK itself holds no cards yet.

**Numbers on disk:**
- `memory/stats/council.jsonl` (VULYK, 25 rows, 12 specs): 12 GREEN / 9 RED / 4 ESCALATE. Of 13 RED+ESCALATE rounds, 9 carried a `lead-review` BLOCK; a blind seat (opus) was RED in 4. The reviewer is the gate that catches; blind seats rarely add a RED.
- `council-sonnet` was removed in 0.18.0: 0 RED in 16 VULYK rows, GREEN in 80 of 101 rounds across 20 hives (CHANGELOG, `docs/model-cascade.md`). A seat that never says RED was judged dead weight.
- `docs/token-economy.md` (measured v0.17): review machinery = 30.7 % of a spec's spend; 82 % of specs took 2+ rounds; extra rounds took 29.5 % of the spend of the tasks that had them.
- Owner, 2026-09-23 (`docs/specs/convergent-judge/brief.md`, verbatim): *"Так зачем было три цикла гонять и сотни тысяч токенов тратить?"* → the judge was rebuilt to converge, not to count to three.

**Rules already decided (not to re-litigate without new evidence):**
- *"Two copies of one model are blind in the same places, and adversarial framing does not fix that"* — `docs/model-cascade.md`, with the CodeRabbit measurement (Opus 5 recall 61.1 % → 55.2 %, ~4× more nitpicks). Grill 2026-09-12 rejected 2×Haiku for the same reason.
- Council input is `brief.md` only; the seats are blind to the hive's own account (grill 2026-09-12, decision 3, Act 2 enforcement via worktree).
- Minors and `[unanchored]` findings never block; they go to `## Next circle` (ADR-001 amended by convergent-judge).

**Platform facts:**
- A subagent is dispatched per call; `SendMessage` can continue a spawned agent with its context intact inside one session, the Workflow driver dispatches per phase. A "constantly observing" agent = an agent whose context grows with every story it sees — the opposite of the fresh context the council buys.

**Contradictions in the sources vs the proposal, already visible:**
1. "Two identical overseers that compare notes" vs the model-diversity rule and the dead `council-sonnet` seat.
2. "Is it optimal / could it be better / modern architecture?" vs the reviewer contract that excludes that axis on purpose, and the owner's own 2026-09-23 complaint about rounds burning tokens.
3. "Constantly observing, independent context" vs "fresh context per round is what makes a verdict carry information".
4. "Per task, when an agent finishes" vs "the council judges the spec per round, never per story" (decision 4, 2026-09-12).
5. "One improvement per spec" vs ceilings of 1/2/3 RED rounds — the proposal is *stricter* on count than the current cycle.

**Connected source (Recall, read-only):** recording "Влад про его AI", 2026-10-05, 12:32, the owner: *"тройная валидация … на каком-то важном событии просишь запустить в чистом контексте Fable 5.1, Sonnet 5.5 и Opus 5.5 … одинаковые знания, одинаковую задачу … чтобы они пришли с результатом и устроили друг другу перекрёстные грилевания … Они друг друга заставляют думать … я уже это запаковал как скилл — перекрёстный гриль."* The owner's own lived practice is three **different** models in a **clean** context, cross-grilling each other on a result — not two identical persistent agents.

**Traces:** none missing. Prior grills: 2026-09-12 council (hard, closed), 2026-09-23 convergent-judge (brief), 2026-10-07 SDD course (queue; next steps: constitution-merge → fast/full tests → queue).

## Q&A transcript
Q1 (D1): What have you seen slip past lead-review + the council that the two overseers would have caught? Name a case, or say there is none.
A1: "Случая нет, это ощущение пробела." — triage: opinion. The proposal rests on a felt gap (the craft/optimality axis), not on an escaped defect.
Q2 (D2): Where did "could have been better" actually change your result: before the code (approach fork, where your triple validation runs) or after?
A2: "Не думал про момент." — triage: not yet thought through; counter once (medium): think it through now via the three bins a post-story finding can land in.
Q3 (D2): A worker closes story N; the overseer reads story + diff and says "could be better". Three bins: a different approach / code quality within the approach / security. Which bin are the overseers for?
A3 (reframe, verbatim core): "эти надзиратели должны работать во время выполнения задачи … один работает, а второй сбоку смотрит … даёт уточняющие вопросы, заставляя работника принимать правильные решения … как прораб или бригадир … не мешая. … чтоб эти советы не удлиняли задачу, не сжирали токены и не делали хуже." — triage: opinion + design change. The proposal moved from a post-hoc judge to an in-flight foreman. Constraint recorded: no longer task, no token burn, no harm.
Verification before Q4 (load-bearing platform facts, 2026-10-08/09): see fact ledger F1-F4.
Q4 (D2→D3): The foreman speaks only on a worker event, each word a model call. Which event: once per story before the first edit / every edit / on the worker's request / at SubagentStop?
A4: "Раз на сторю, перед первой правкой." — triage: decision. The worker writes a 3-5 line approach into the story; one foreman call reads story + approach (+ map) and returns ≤ 5 lines of questions; the worker proceeds. Cost: one dispatch per story.
Q5 (D4): "Two identical agents that compare" vs your triple validation (three different models), the model-diversity rule and the dead council-sonnet seat. At one call per story: how many foremen, and what makes them different?
A5: "Два разных: Opus + топ-модель, консенсус." — triage: decision (owner overrode the recommended single Opus foreman). Two foremen on different families; the nudge reaches the worker only where both agree.

Q6 (D2): Two foremen return two lists; who compares them without a third hop?
A6: "Скриптом, по адресу замечания." — triage: decision. Each foreman line = address (file or acceptance-criterion number) + question; a script keeps only addresses both named; no overlap → silence. Zero tokens on the merge, same principle as `cycle.sh judge` (a script counts, no model judges).

Q7 (D4, words vs recon): On a Pro/API hive `auto` makes the pair Opus + Opus, which the model-cascade forbids. What does the foreman do there?
A7: "Один Opus, без пары и сверки." — triage: decision. The pair exists only where two judging families exist (Max: Fable + Opus); elsewhere one Opus voice goes to the worker as is. C3 resolved.

Q8 (D2): What may the foreman say, and what must the worker do with it?
A8: "Только вопросы; воркер отвечает письменно." — triage: decision. ≤ 5 addressed questions; the worker answers each in one line in the story before the first edit, "no, because" allowed; nothing binds. The written answers are the only trace by which lead-review and /vulyk-evolve can see whether a nudge changed anything.

Q9 (D3): Who decides a story is critical, and when?
A9: "Планировщик, строкой risk: в сторе." — triage: decision. `risk: low | normal | high` in the story frontmatter at plan time (precedent: per-story `model:` per ADR-015); paths named by `docs/defects` cards raise it to `high` automatically; `low` = no foreman; `high` = security lens + a higher question cap.

Q10 (D3): Where does the foreman live by tier; defaults stated: the Queen is absent mid-story, Q&A lives in the story file, the hook never blocks (timeout or garbage = silence).
A10: "Воркеры Tier 3-4 хуком; Tier 1-2 — только risk: high." — triage: decision; defaults accepted. At Tier 1-2 the Queen dispatches the foreman once before her first edit, only on `risk: high`, report ≤ 5 lines.

Q11 (D3→D5): Which number says after a month that the foreman pays, and which removes it?
A11: "Два числа в foreman.jsonl + правило сноса." — triage: decision. Per story: uptake (share of questions answered "changed approach") and lead-review BLOCK rate on stories with a foreman vs without, same tier. Removal rule: after 30 stories, uptake < 20 % or BLOCK rate not lower → remove, the way council-sonnet went.

Q12 (D5): Starting from zero today, same choice? What makes you remove the foreman without waiting for the ledger?
A12: "Бригадир как пилот на самом VULYK, до раскатки." — triage: decision. Build here only, under the removal rule; roll out to the hives only once `foreman.jsonl` shows uptake. Immediate removal triggers: a story got longer, or a worker went NEEDS_CONTEXT because of a foreman question.

### Wave 2 ledger (after Q10)
- 🎯 D5 Script merges by address, no third hop (A6). D6 One Opus foreman where the top model resolves to Opus (A7). D7 Questions only; the worker answers each in writing before the first edit (A8). D8 `risk:` written by the planner; defect-card paths raise it (A9). D9 Tier 3-4 workers via a frontmatter hook; Tier 1-2 only `risk: high`, one dispatch by the Queen (A10). Defaults accepted at A10: the Queen is absent mid-story; the hook never blocks; the post-hoc judge is dropped (A3); "one rework per spec" became "one intervention per story, no rework" (A4).
- 🅰 ✗ A frontmatter `agent`/`prompt` hook can read the story file and return ≤ 5 lines at a tolerable latency; `agent` hooks are experimental (docs) — check: a dry run on one story; fallback: the driver dispatches the foreman as a phase between "approach written" and "first edit". ✗ The address-overlap rule yields non-empty output often enough to matter — check: dry-run on 10 stories, count overlaps. ✗ Worker answers are honest, not pro-forma — check: read 10. ✗ The planner sets `risk:` reliably — check: compare with lead-review BLOCKs by story after a month.
- ⚠️ `agent` hook experimental → may change (mitigation above). Latency per story (bounded: one call). A security lens asking for hardening the Profile's *Configurations that exist today* excludes — the foreman carries the reviewer's Profile bound (C6). Pro-forma answers. Telemetry needs a `foreman` agent token and a `foreman.jsonl`.
- ❓ Success metric and kill criterion (Q11). Starting-from-zero check (Q12). Anti-scope: lead-review and council contracts untouched.
- 🔍 C5 resolved by the A10 default (the Queen is absent mid-story). C6 words vs recon: A9 "high = security lens" vs `lead-review.md` "hardening for a configuration the Profile does not list: leave it out" — resolved as a rule: the foreman reads the same Profile clause and asks nothing beyond it. C7 words vs words: A3 "not lengthen the task" vs A8 "the worker answers in writing before the first edit" — accepted as a bounded cost (≤ 5 one-line answers).

- ✅ Facts: F1-F5; council numbers (recon).
- 🎯 D1 No escaped case: the gate is bought on belief in a craft axis, not on a defect. D2 Foreman during the work, not a judge after it (reframe at A3). D3 One intervention per story, before the first edit, on the worker's written approach. D4 Two foremen, different families (Opus + top model), consensus before the nudge reaches the worker.
- 🅰 ✗ A Sonnet worker's 3-5 line approach, written before the first edit, carries enough to judge (check: 5 stories by hand). ✗ Foreman questions improve the result without lengthening the story (check: tokens per story and rounds to green on the next 10 stories, with vs without). ✗ Consensus of two models is reachable without a third model call (check: define the overlap rule and dry-run on 5 stories). ✓ On non-Max plans `auto` resolves the top model to Opus (docs/model-cascade.md, CLAUDE.md).
- ⚠️ Tokens per story +2 dispatches + merge; worker latency on the hook; a nudge that widens scope collides with worker-code's "nothing beside it"; a nudge that contradicts the story = NEEDS_CONTEXT loop.
- ❓ Consensus mechanics (who merges); what the foreman may say (questions only?); must the worker answer in writing; strictness by criticality (the original ask, untouched); "one rework per spec" (still meaningful?); the Queen's role (original: she decides rework); which tiers (Tier 1-2: the Queen builds herself); is the post-hoc judge fully dropped.
- 🔍 C1 words vs words: "two identical agents" → A5 "two different families" — resolved by A5. C2 words vs words: A3 "not lengthen, not burn tokens" vs A5 two calls + consensus per story — open (Q6). C3 words vs recon: Opus + top model on a Pro/API hive = Opus + Opus = two copies of one model, which `docs/model-cascade.md` forbids — open. C4 prompt "after the agent finishes, overseers get the solution" vs A3 "during" — resolved: post-hoc dropped. C5 prompt "the Queen decides whether to force rework" vs A4 "the nudge goes to the worker before the first edit" — open: where is the Queen now.

## Ledger (kept current at every wave)
### ✅ Facts — with source
- F1 ✅ Settings/plugin hooks fire inside subagents; `PreToolUse`/`PostToolUse` input carries `agent_id`/`agent_type` — code.claude.com/docs/en/hooks + /sub-agents (read 2026-10-09); locally confirmed by `.claude/hooks/defects-inject.sh`, whose state is keyed by session_id + agent_id.
- F2 ✅ Hook types `prompt` (single-turn model call, JSON decision, optional `model`) and `agent` (experimental; subagent with Read/Grep/Glob verifies a condition) exist; `additionalContext` is inserted at the point the hook fired; PreToolUse may deny with a reason shown to Claude — hooks doc (2026-10-09).
- F3 ✅ No mechanism lets one subagent observe another's tool calls in real time; the parent sees only the final report (partial output only on cutoff/maxTurns); only the launcher can send a mid-task correction; a finished subagent can be resumed by `SendMessage` with full history — sub-agents doc (2026-10-09).
- F4 ✅ A subagent's frontmatter `hooks:` run only while that subagent is active — sub-agents doc (2026-10-09). A foreman can be scoped to `worker-code` alone.
- F5 ✅ VULYK already has a static edit-time whisperer: `defects-inject.sh` (PreToolUse on Edit|Write|MultiEdit|NotebookEdit|Bash, `## Never` lines of `text` cards, once per session+agent, 4000-char budget, never blocks) — repo.
### 🎯 Decisions — with why
### 🅰 Assumptions — ✓ verified (how) / ✗ unverified (cheapest check)
### ⚠️ Risks — with the user's chosen mitigation
### ❓ Open branches
### 🔍 Contradictions — found / resolved how

## Synthesis

1. **Verdict.** The proposal survived by changing shape. Two post-hoc overseers judging "was it done optimally" would have reopened the nitpick axis the reviewer contract excludes on purpose and the owner cut on 2026-09-23 for cost, with no escaped defect behind it (A1). What stays is a **foreman**: once per story, before the first edit, a worker writes a 3-5 line approach; one Opus call (a pair Opus + top model only where two judging families exist, merged by a script on the address of each remark) returns ≤ 5 addressed questions; the worker answers each in one line and proceeds. Nothing binds, nothing blocks, no rework path, the Queen is absent mid-story. Strictness follows a planner-set `risk:` line (defect-card paths raise it); `low` skips the foreman; Tier 1-2 get it only on `high`. It ships as a pilot on VULYK itself behind a removal rule measured in `foreman.jsonl`.
2. **Decision log.** D1 no escaped case, gate bought on belief (A1) · D2 during the work, not after (A3) · D3 once per story before the first edit, on a written approach (A4) · D4 two foremen of different families, consensus (A5, owner overrode a single foreman) · D5 script merge by address, no third hop (A6) · D6 one Opus where the top model is Opus (A7) · D7 questions only, written answers (A8) · D8 planner-set `risk:` + defect paths (A9) · D9 Tier 3-4 via frontmatter hook, Tier 1-2 only `risk: high` by the Queen (A10) · D10 uptake + BLOCK-rate in `foreman.jsonl`, removal after 30 stories at uptake < 20 % or BLOCK rate not lower (A11) · D11 pilot on VULYK first; instant removal on a longer story or a foreman-caused NEEDS_CONTEXT (A12).
3. **Assumption ledger.** ✓ hooks fire in subagents, prompt/agent hook types exist, no real-time observation of another agent (F1-F4, docs 2026-10-09) · ✓ `auto` resolves the top model to Opus on non-Max plans (repo) · ✗ a Sonnet worker's 3-5 line approach carries enough to judge — read 5 · ✗ foreman questions change outcomes without lengthening — the ledger after 30 stories · ✗ address-overlap of two foremen is non-empty often enough — dry-run 10 stories · ✗ written answers are not pro-forma — read 10 · ✗ the planner sets `risk:` reliably — compare with BLOCKs after a month · ✗ a frontmatter `agent` hook returns in tolerable time; it is experimental — one dry run; fallback: a driver phase between "approach written" and "first edit".
4. **Fact ledger.** ✅ F1-F5 (hooks/sub-agents docs, repo) · ✅ council.jsonl: 25 rows, 12 GREEN / 9 RED / 4 ESCALATE; 9 of 13 RED+ESCALATE rounds carried a lead-review BLOCK, a blind seat was RED in 4 (computed 2026-10-08) · ✅ council-sonnet: 0 RED in 16 rows, GREEN 80/101 across 20 hives (CHANGELOG 0.18.0) · ✅ review machinery 30.7 % of spend, 82 % of specs 2+ rounds (docs/token-economy.md, v0.17 measurement) · ✅ owner's "тройная валидация" = three families, clean context, cross-grill, before code (Recall transcript 7285, 2026-10-05, 12:32) · ⚠️ CodeRabbit Opus 5 precision/recall numbers — as recorded in docs/model-cascade.md; the benchmark was not reopened this session.
5. **Contradiction log.** C1 two identical agents vs two families — resolved A5 · C2 "no token burn" vs two calls + consensus per story — resolved A6/A7 (script merge, pair only on Max-class plans) · C3 Opus + top model = Opus + Opus on Pro — resolved A7 · C4 "after the agent finishes" vs "during" — resolved A3, post-hoc dropped · C5 "the Queen decides rework" vs nudge-before-first-edit — resolved A10 default, the Queen is absent · C6 security lens vs the Profile bound in lead-review.md — resolved as a rule: the foreman carries the same bound · C7 "not lengthen" vs written answers — accepted as bounded (≤ 5 lines).
6. **Risk register.** Agent hook experimental → prompt-hook or driver-phase fallback · latency per story → one call, hard cap, silent on timeout · nudges widen scope → questions only, worker-code's "nothing beside it" unchanged · pro-forma answers → read a sample at /vulyk-evolve · cost drift → `foreman` agent token in telemetry, tokens per story in foreman.jsonl · a second gate that never dissents → the removal rule (D10).
7. **Residual ambiguity.** goal clarity **7/10** (the gap is felt, not evidenced; the goal is now "a cheap, measured nudge at the approach moment") · decision-tree coverage **8/10** (hook vs driver-phase implementation, the report contract and the `risk:` vocabulary are plan-time details) · evidence strength **6/10** (platform facts verified; the benefit is unmeasured by construction; agent hooks experimental).
8. **Next step.** Put `foreman` into the owner's ordered queue behind constitution-merge → fast/full tests → queue (order fixed 2026-10-07/08). When its turn comes: `/vulyk-plan` with this synthesis as the brief, Tier 3 (agents, hooks, cycle.sh, telemetry, planner template), pilot on VULYK only.

## Test plan before any rollout (owner's question after synthesis, 2026-10-09)

Interpreted as "before rolling out to the hives". Three stages; the first costs no code.

- **Stage 0, retrospective on git.** 8-10 closed VULYK stories (9 RED rounds carry anchored lead-review findings `file:line [ask N]`). Per story: check out the pre-edit commit, have Sonnet write the 3-5 line approach, dispatch two foremen (Opus, Fable) by hand on story + approach, apply the address-overlap by hand. Measure: non-empty overlaps; a question that hits an address lead-review later BLOCKed on ("would have caught"); questions the real diff refutes as noise. ~20 dispatches, one hour, zero repo changes. No overlaps or no hits → the spec is not built.
- **Stage 1, contract tests** in the style of `tests/inject.test.sh`: fixture worker + story; the hook fires once per agent and stays silent on repeat; timeout or garbage = silence, never a block; the "address + question" line format validates; the merge script: two lists → overlap, disjoint → empty, malformed → empty; a test for the driver-phase fallback (agent hooks are experimental).
- **Stage 2, live pilot with `foreman.jsonl`.** Two traps to settle now: (a) *control* — `normal` vs `low` stories are not comparable; during the pilot the driver stamps `foreman: on|off` per story at random, the `risk:` rule takes over after; (b) *sample* — VULYK specs hold 1-3 stories, so 30 stories is two to three months here; either accept the slow pilot or add one hive with a real Client path after Stage 0 (this argues with "pilot on VULYK only", A12; the owner decides).
- **Uptake cross-check:** the worker's "changed approach" is self-reported; diff the `## Approach` text before/after the answers, and check whether lead-review named the same address.

## Rejected alternatives (with why)
- Post-hoc overseers judging optimality/architecture after the story — the reviewer contract excludes that axis for cost; no escaped case justifies it (A1, A3).
- Foreman on every edit — N model calls per story, nitpicks on half-done code (Q4).
- Foreman on the worker's request — a confident Sonnet is the one that errs silently (Q4).
- Foreman at SubagentStop with a veto — the post-hoc judge again, and a hook deny is the interference the owner excluded (Q4, Q8).
- A single Opus foreman on Max — the owner chose the pair for diversity (Q5); kept as the Pro/API form (A7).
- Two copies of one model — the model-cascade rule; a filter that agrees with itself (Q5, Q7).
- Sequential filter, Haiku merge, unmerged lists — anchoring, a third hop, the worker judging judges (Q6).
- Directives instead of questions — a second planner mid-story, NEEDS_CONTEXT loops (Q8).
- Self-graded or tier-only or fixed strictness — the system grading itself; tier is size not risk; the original ask dropped (Q9).
- All tiers always / plan-call at Tier 1-2 — the Queen's context is the most expensive place; a plan call is not "during the work" (Q10).
- Rounds-only, owner's feeling, tokens-only as the metric — too coarse, unmeasurable, cost without benefit (Q11).
- Plan-time cross-grill *instead of* the foreman — judges the plan, not the worker's approach; kept as a separate future spec that mirrors the owner's own "тройная валидация" (Q12).
