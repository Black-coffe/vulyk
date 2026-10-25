# Study: a horizon step in `/vulyk-plan` (report)

Date: 2026-10-25 · Brief: [brief.md](brief.md) · Sources: Recall #9120 (transcript, read in full); Felix Rieseberg,
"How to be more ambitious: A tutorial for humans with models", felixrieseberg.com, published 2026-10-13 (read via
Exa fetch); its depth prompt cross-checked word for word against learnaiwithmariah.com/guides/be-more-ambitious-with-ai;
YouTube comments under k9x8dH1199g (20 of 57 threads loaded and read, 2026-10-25).

## Bottom line

Yes, build it, but narrowly. Add one step between recon and the grill that runs only on new ground at Tier 2-4.
Three read-only agents each look at the request through one lens: altitude, depth or range. The Queen, who belongs to
another model family, judges what they bring back. At most three proposals reach the owner, and they go inside the
grill round VULYK already has. Only what the owner picks becomes an ask. Tasks inside existing code are unchanged.

## Findings

1. **Today the grill forbids exactly this.** `templates/grill.md:24-27`: "Ask only what the recon left ambiguous...
   options from the recon, never invented". That rule is right for a change inside mapped code. On new ground it
   fails: recon has nothing to draw options from (`memory/` has no pointer and the map has no slice), so the round
   asks about details and misses the bigger question. This is the "box" the owner describes. It is one line of
   one file, not the framework as a whole.
2. **The essay gives a ready, tested shape for the step.** Rieseberg splits ambition into speed, altitude ("the goal
   beyond the goal"), depth ("the way a field-leading expert would": their tools, raw data, challenging what you
   believe) and range (other fields: "replace the nouns with verbs", "assemble the crew"). His depth prompt ends with
   "Then rewrite my prompt to ask for exactly that". That is the owner's «усилить промпт» almost word for word.
   Speed is VULYK's normal job and needs no lens.
3. **The essay also gives two guard rails that VULYK already believes in.**
   - "Do not ask the model to judge itself... insist on outside validation". This is the constitution's "the family
     that builds never judges" (`CLAUDE.md:35`). The proposals need a judge from another family.
   - On role-play: "Don't ask the model to write like a short seller, ask it to do what a short seller does". So the
     three agents are lenses with a task, not personas ("you are a marketer").
4. **The risk is the owner's own 2026-09-14 complaint ("does too much").** ADR-008 cut recon that "dispatched up to
   four scouts at every tier" (`docs/adr/008-approval-stop-and-study-work.md:24`). Law 2 forbids unrequested
   features (`CLAUDE.md:9`). A step that runs on every plan, or that turns proposals into asks without the owner
   choosing them, repeats that complaint. Hence the gate and the rule "picked, never assumed".
5. **Where the proposals must not go.** The council's court holds only `brief.md` (`.claude/agents/council-opus.md:16`).
   `drone-coverage` reads `brief.md`'s `## Asks` (`.claude/agents/drone-coverage.md:18`). If proposals the owner
   rejected sat in `brief.md`, the blind seats and the coverage drone would judge the build against them. They belong
   in their own file, outside the court.
6. **No VULYK agent can search or fetch the web today.** The `tools:` lines in `.claude/agents/*.md` are local, and
   `drone-scout` has `Read, Grep, Glob`. The one exception is `council-haiku`, which gets browser MCP for the Client
   path only (`.claude/agents/council-haiku.md:4`). The depth and range lenses need WebSearch/WebFetch to name current tools,
   prices, rules and facts. That brings a new kind of input: web text is data, never instructions.
7. **The video and comments.** Worth the time for the essay, not for the presenter. He skipped "use an outside
   judge" ("про це я не сильно зрозумів"), which is the part that matters most for VULYK. Two comments add something:
   - Run the evaluator as a subagent, better on another model.
   - Only rules or hooks can force a step.
   One skeptic calls it "a retelling of marketing", and one asks how a model can know more than its training data.
   That second question is fair, and the fact-marking rule below is the answer. The thesis that "old skills are now
   redundant" is not in this video or the essay. The closest is "models seem to be able to operate at higher levels
   of abstraction the more capable they become".

## Not read or run

- No live run: nothing here has been tried on a real new-ground request in a hive (card `done-without-real-run`).
- Token cost is not measured. For scale, the `rules-tree` spec ran 37 dispatches (`python scripts/token-report.py .
  --spec rules-tree`). Three more read-only agents on a new-ground plan is a small share of that, but this is an
  estimate, not a measurement.
- Not checked: whether WebFetch inside a subagent raises a per-domain permission prompt in a hive running in default
  permission mode. The owner's machine runs bypassPermissions, so the probe recipe in the auto-memory note
  "permission probe" applies.
- Not checked: how often a hive's requests are new ground. Scanning the hives' `docs/specs/` would tell.
- `/vulyk-bootstrap` on an empty repo (`bootstrap/interview.md`) was read but is out of scope. Bootstrap asks about
  the project, not about a feature.

## Options (recommended first)

**A. (Рекомендую) Gated horizon step inside the existing grill round.** Why: it adds at most three questions to a
round that already exists and is already capped at 7 (`templates/grill.md:19,44`). It spends three read-only
dispatches only when recon finds no ground. It keeps every gate VULYK has.

1. *Signal.* After recon, at Tier 2-4 and in an interactive session, the Queen fires the step when the request's area
   has no `memory/` pointer, no map slice and no code hit, or when the repo is empty. She announces it in one line,
   with the reason taken from recon. `--horizon` forces the step and `--no-horizon` skips it. No-question mode, study
   work and Tier 0-1 never run it: nobody would be there to pick, so the agents would be paid for nothing.
2. *Proposers.* One new agent, `drone-horizon`, dispatched three times in parallel with `lens: altitude | depth |
   range`.
   - Tools: Read, Grep, Glob, WebSearch, WebFetch. No Write, no Bash.
   - Model: `sonnet` in its frontmatter (Sonnet executes research, like the scout).
   - Each returns at most three proposals in a fixed shape: what, why for this goal, cost, how the result would be
     checked by something other than the model, and sources with URL and date. An external fact with fewer than two
     sources is marked «не подтверждено».
   - Personas are forbidden: the brief tells each agent to do what the field does, not to talk like it.
3. *Judge.* The Queen (Opus, another family than the proposers in the default profile) merges the nine candidates.
   She drops duplicates, anything that contradicts the constitution's Profile (*Configurations that exist today*)
   or the repo, and anything not tied to the owner's goal. She keeps at most three, written to
   `docs/specs/<slug>/horizon.md` together with the verdict on every candidate.
4. *Owner.* Each surviving proposal becomes one grill question.
   - The first option is the recommended one, «(Рекомендую)», with its reason. «Не добавлять» is always an option,
     and the free-text Other stays.
   - The owner's words, including «как рекомендуешь», decide the question. Silence never adds scope.
   - The fixed last question also shows the upgraded prompt (Rieseberg's "rewrite my prompt") as candidate ask lines
     marked `(horizon)`. An ask enters `## Asks` only when the owner confirms it. It is the owner's choice, not an
     owner quote (auto-memory "model text is not an owner quote").

**B. Same as A, but each lens on a different family (Sonnet / Opus / Fable).** It gives more variety of blind spots,
which is the crossgrill idea. Rejected for now: Fable is the gate model, and its use is profile- and plan-dependent
(`scripts/model-profile.sh --explain`). It also adds a profile role to maintain. Revisit if A's proposals turn out
same-y in the first real runs.

**C. A separate interview round before the grill.** Rejected: it breaks "exactly one round" (`templates/grill.md:19`)
and re-opens the cost complaint of ADR-008.

**D. Run it at every Tier 3-4 plan.** Rejected: Tier 3 cross-cutting work inside existing code is exactly the case
the owner says must ask nothing extra (brief ask 4).

**E. Call the owner's own `supergrill` / `crossgrill` skills.** Rejected: VULYK is public, and `templates/grill.md:6`
already forbids personal skills. The default path must work for an owner who installed VULYK today.

## Candidate stories (Tier 2, for the owner to approve next time)

1. `drone-horizon` agent: the lens contract, the output shape, web text as data, no personas, the fact-marking rule,
   `maxTurns` small (about 15).
2. Intake wiring: the step and its signal in `.claude/commands/vulyk-plan.md` (after step 3), the `--horizon` /
   `--no-horizon` flags, `templates/grill.md` rules for horizon questions (cap stays 7; silence never adopts; the
   `(horizon)` ask lines), and `horizon.md` staying out of the court. Check that nothing else in `brief.md`
   parsing breaks: `trace-check.sh` and `drone-coverage` read only `## Asks`.
3. Docs and proof: ADR-022, `docs/command-reference.md`, `docs/architecture.md`, CHANGELOG. Then one real run on a
   new-ground request in one hive, with its token cost read from `token-report.py` and the WebFetch permission
   behaviour observed in default mode, before the release note calls it done.
