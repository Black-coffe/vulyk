# Supergrill: weekly-budget — VULYK under weekly limits

<!-- state -->
- status: done
- level: deep (recommended; super was not needed: one sitting, all recon already on disk)
- hardness: medium
- lens: product
- started: 2026-11-02
- next_question: none (asks confirmed; plan next)
- open_branches: success criteria; data source; act vs warn; formula and windows; reserve; Fable policy (share, judges, effort, context, 5.5); two accounts; Pro/Max defaults; delivery surfaces
<!-- /state -->

## Recon (Stage 0, condensed)

- **Limits.** Since 2026-10-30, verified Ultra has a weekly limit only, 10x Pro, with a separate Fable weekly limit of up to 50% of the week. Pro and Max keep the 5h limit too. Fable "draws from regular weekly limits and uses them faster".
- **Data source, `/usage`.** `claude -p "/usage" --output-format stream-json --verbose` costs $0 and takes about 15 s. It returns `weekly_all` 32% and `weekly_scoped` (Fable) 15%, with resets_at and severity, plus a "what's contributing" breakdown. It is the only source of the Fable %. The SDK docs call it "experimental". Recon: recon.md, probe section.
- **Data source, statusline.** The statusline stdin has `rate_limits.seven_day` / `five_hour` with integer % and is updated on events. No hook payload carries limits. VULYK does not own the statusline. Source: research-cc-updates.md §4.
- **Observed re-anchor.** On account 1, resets_at moved from 11-04 to 11-05 and the used share dropped from 64% to 31%. Elapsed time inferred from resets_at − 7 d is therefore unreliable. Source: research-budget-formula.md C5.
- **Spend profile, last 7 d from `/usage`.** worker-code 13%, general-purpose 12%, lead-review 4%, council-opus 2%. The fable-budget study (10-27) found judges were about 82% of Fable spend.
- **VULYK today.** Nothing reads limits. Fable fallback is reactive only. Routing is plan-static. Source: recon.md.
- **Context.** A 1M window is not unlimited. Auto-compaction runs at about 967K, compaction itself costs usage, and there are three hard stops. Source: research-cc-updates.md §2.
- **Fable 5.5.** No official source as of 2026-11-02.

## Q&A

**Q1 (D1, success criteria).** Answer: «Не кончиться + выбрать 85–95%». Success = the week never runs out before the reset AND 85–95% of the weekly limit is used by the reset. Two-sided control: warn on over-pace, boost on under-pace. Closed.

**Q2 (approach fork, data source).** Answer: «/usage с кэшем». VULYK itself runs headless `/usage` in the background:
- at session start, before every batch of agents, and about every 20 min;
- it keeps a separate journal per account;
- the statusline is not used. Closed.

**Owner evidence mid-grill (screenshots, 2026-11-02):**
- Anthropic email: "We've removed the 5-hour limit from your Ultra (formerly Max 20x) plan … your weekly limits still apply … nothing you need to do".
- claude.ai Usage page: Ultra, week 65%, Fable 63% ("до 50% недельного лимита"), reset Wednesday 10:00. The page also shows its own pace verdict: «Всё идёт по плану. К сбросу в среду у вас ещё должен остаться запас».
- Inference (not verified): this is account 2. It read 64% with a Wednesday reset on 10-29, while account 1's `/usage` read 32% with a Thursday reset. So account 2 is verified too.
- Consequence: research-budget-formula C5 ("re-anchor on account 1") most likely mixed the data of the two accounts. Per-account isolation of the journal is a hard requirement.
- The Fable % is a share of Fable's own cap, which is 50% of the week.

**Q3 (approach, act vs warn).** Answer: «Лестница + пометка».
- VULYK warns at once.
- On sustained over-pace it lowers the model of its own dispatches in steps: Fable → Opus first, then Opus → Sonnet for workers.
- Every report says what was lowered and why.
- On under-pace the ladder steps back up.
- It extends fable-fallback and top-model.sh. This adopts horizon H3. Closed.

**Q4 (horizon H2, reserve).** Answer: «Добавить, 10%». Adopted.
- An untouchable reserve of 10% of the week, configurable.
- A "will it last to the reset" check runs before a build and before every batch of agents.
- Below the reserve, the build pauses through the existing PAUSE mechanism.
- The owner lifts the pause with one command, and the lift is journaled.

**Q5 (formula).** Answer: «Два окна: час и сутки».
- Daily budget = (remaining − reserve) / days to reset, recomputed continuously, so it rises on its own when under pace.
- Burn rate comes from the journal over the last 1 h and 24 h. The forecast reads like "the week ends Tue 14:00".
- Warn when both windows forecast exhaustion before the reset.
- Boost when the forecast at the reset is below 85% used (the Q1 target).
- Worked examples: 6 d / 20% is pace ×1.4, then about 11.7%/day; 2 d / 50% is under pace, then 20%/day. Closed.

**Safety requirement (from a side-agent note relayed mid-grill; not an owner quote, recorded as a must under Law 2):**
- Headless `/usage` is free only while Claude Code treats it as its built-in command. In the Git Bash probe, path conversion turned it into a $0.19 Opus call.
- The governor accepts a reading only when `local_command_run.command == "usage"` AND `total_cost_usd == 0`.
- Otherwise it stops background polling and tells the owner.
- It always runs with path conversion off and the cheapest model pinned, which caps the cost of a misfire.

**Q6 (Fable policy).** Answer: «Только финальный суд».
- Fable runs only on the Tier 4 final review, `lead-architect` and the retry of a missed story, at effort high, not xhigh.
- Planner, review and council run on Opus under every profile.
- Fable has its own daily budget by the same formula, against its own 50% cap.
- On over-pace, Fable is the first rung to drop to Opus.
- Version pins (`lib.sh:317` floor `fable 5.1`, `token-report.py:55` `READ_RATE` keyed `fable-5-1`) become version-agnostic, so Fable 5.5 needs no code edit.

🔍 **Consistency (D4).** Q1 targets 85–95% of the all-model week, while Q6 narrows Fable. These do not conflict: Opus fills the all-model week. Proposed resolution, shown to the owner in the final confirm: on BOOST (under-pace), the ladder steps up and gives Fable back to planner/review until the pace is normal.

**Q7 (context).** Answer: «Окно агентов ~400K».
- VULYK agents (workers, judges, scouts) auto-compact at about 400K.
- The main session stays at 1M, with handoff warnings as today.
- The default subagent effort is set via `CLAUDE_CODE_SUBAGENT_EFFORT` (2.1.316).
- Whether a per-agent window is settable is to be measured at plan time (the changelog for 2.1.312 says a subagent's `autoCompactWindow` can lower the window).

**Defaults taken without a question (Law 1; the owner sees them in the final confirm):**
- The 5h window is honoured when present (Pro/Max, unverified Ultra): the window that bites first wins.
- One journal per account, keyed by the Claude config dir.
- The governor has an off switch and an owner override ("today spend more" / "hold"), both journaled.

## Ledger

- **Q8 (surfaces).** Answer: «Старт + баннер + полоса». Q9: the asks are confirmed and the plan stops for approval.
- **Decisions:** Q1–Q9 above. **Defaults:** 5h window where present; one journal per account; off switch plus override.
- **Assumptions:**
  - ✗ a per-agent autoCompactWindow is settable (measure at plan time);
  - ✗ the `/usage` JSON shape stays stable (the SDK calls it experimental): the governor degrades to "no data".
- **Risks:** a `/usage` misfire costs a model call (safety guard); quality drops on downgrade (labelled); the two-account data mix-up (per-account journal).
- **Contradictions:** C5 "re-anchor" explained as a two-account mix (owner screenshot); Q1 vs Q6 Fable resolved by BOOST returning Fable to planner/review.

## Synthesis

VULYK gets a weekly-budget governor:
- **Data:** headless `/usage` (free, includes Fable %), polled and journaled per account, with a misfire guard.
- **Formula:** a forward daily budget (remaining − 10% reserve) / days, with a 1 h + 24 h burn-rate forecast.
- **Actions:** warn, step the model down the ladder, step it back up on under-pace, pause below the reserve.
- **Fable:** narrowed to the final judge, the architect and the retry, at effort high, with its own budget and no version pin.
- **Context:** VULYK agents capped at about 400K.
- **Shown at:** session start, a banner, the pulse band and `/vulyk-status`.

Ambiguity scores: goal 9/10, tree coverage 8/10, evidence 7/10. Next step: plan.md plus stories, for approval.
