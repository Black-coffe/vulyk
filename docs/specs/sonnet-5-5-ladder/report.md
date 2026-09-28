# Sonnet 5.5 ladder and the model floor - study report and plan

**Date:** 2026-09-28 · **Owner ask (verbatim, translated):** "Sonnet 5.5 just shipped. Read Anthropic's
official material and the comparisons, see what it does and how it differs from Opus 5.5, and rewrite
the VULYK harness around it - so that next time we do not rewrite it. We do not write 'use Sonnet 5.5',
we write 'never below Sonnet 5.5', the same for Opus: sometimes something happens and it runs Opus 5
or Sonnet 5. Always only the latest Haiku, Opus, Sonnet and Fable. Rebuild who is responsible for
what: where Fable's role ends, where Opus 5.5's ends, where Sonnet 5.5's ends. Haiku stays minimal.
Go, minor release."

**Tier:** framework surgery on VULYK itself, built by the session (the Law 5 exception the owner
granted on 2026-09-22), approved by the owner's "go" in the ask (`--go`). Release: 0.20.0.

## 1. What Sonnet 5.5 is (sources in section 6)

| | Fable 5.1 | Opus 5.5 | **Sonnet 5.5** | Haiku 4.5 |
|---|---|---|---|---|
| Anthropic's line | demanding reasoning, long-horizon agentic work | long-running agentic coding and knowledge work | "the best combination of speed and intelligence" | fastest |
| Price in / out per MTok | $10 / $50 | $4 / $20 | **$2 / $10** | $1 / $5 |
| Cache read per MTok | $0.25 | $0.20 | **$0.20** | $0.10 |
| Latency | slower | moderate | **fast** | fastest |
| Thinking | adaptive, always on | adaptive, always on | **adaptive, can be switched off (`between_tools`)** | extended |
| Default effort | high | medium | **high** | - |
| Context / max out | 1M / 128K | 1M / 128K | 1M / 128K | 200K / 64K |

Anthropic's own benchmark table (launch post, 2026-09-28), Sonnet 5.5 against Opus 5.5:

| Benchmark | Sonnet 5.5 | Opus 5.5 | Reads as |
|---|---|---|---|
| Terminal-Bench 4.0 | **70.6%** | 66.4% | terminal/agentic execution: Sonnet ahead |
| OSWorld 2.1 | 80.1% | 81.8% | computer use: level |
| GDPval-AA v2.1 | 1844 | 1846 | knowledge work: level |
| CursorBench 4.0 | 55.5% | 57.8% | everyday IDE coding: close |
| FrontierCode 1.1 | 46.2% | **54.4%** | hardest coding: Opus clearly ahead |
| Humanity's Last Exam | 64.5% | **67.7%** | hard reasoning: Opus ahead |

Anthropic's guidance: Sonnet 5.5 for "well-scoped everyday tasks, fixing bugs, and creating polished
documents"; Opus 5.5 for "complex work requiring careful judgment"; "for the hardest long-horizon
work, an Opus model is the better choice". The prompting guide names four behaviours a harness must
plan for:
1. At `low`/`medium` effort, on long agentic tasks, it "is more likely to stop and check in" before
   the work is done.
2. At `low` it "can skip verifying a change".
3. It "tends to add tests, documentation, and small supporting files ... even when you don't ask",
   more at higher effort. The requested change itself "stays close to what was asked".
4. At `xhigh`/`max` it starts its own review rounds, "sometimes with subagents".

Anthropic publishes a scope paragraph and a verification paragraph for these, used below.

**Not measured yet:** no independent per-task cost (Artificial Analysis has no Sonnet 5.5 page on
2026-09-28). The one reason the workers left Sonnet in 0.16.0 was Sonnet 5's per-task cost:
370M output tokens, about $4.8 a task. Anthropic claims Sonnet 5.5 is "up to 30% cheaper" per task
than Sonnet 5. CodeRabbit is quoted in the launch post: Sonnet 5's "high token use [is] gone". That is
vendor-reported. The weekly telemetry and `token-report.py` are what will confirm or refute it
(section 5).

## 2. The failure the owner named: aliases do not guarantee the floor

VULYK routes by alias (`opus`, `sonnet`, `fable`, `haiku`) so a new generation arrives without an
edit. But Claude Code's own model-config page shows what an alias resolves to per provider today:

| Provider | `opus` | `sonnet` |
|---|---|---|
| Anthropic API / subscription | Opus 5.5 | Sonnet 5.5 |
| Claude Platform on AWS | Opus 5.5 | **Sonnet 4.6** |
| Amazon Bedrock, Google Cloud | Opus 5.5 | **Sonnet 4.5** |
| Microsoft Foundry | **Opus 4.6** | **Sonnet 4.5** |

On top of that, `ANTHROPIC_DEFAULT_{OPUS,SONNET,HAIKU,FABLE}_MODEL`, `ANTHROPIC_MODEL` and
`CLAUDE_CODE_SUBAGENT_MODEL` can remap an alias to any ID, from the shell or from a settings file's
`env` block. So "it silently runs Opus 5 or Sonnet 5" is a real path. Nothing in VULYK today would
notice it.

## 3. The ladder, re-cut by kind of work (not by budget)

The one rule underneath: **the family that builds never judges.** Sonnet executes well-scoped work.
Opus orchestrates and judges. Fable holds the gate where a miss is dearest and the call is short.
Haiku holds only the one purely mechanical job, and only once a Haiku at or above the floor ships.

| Family | Its job ends at | Agents |
|---|---|---|
| **Fable** (gate; `TOP_MODEL` on Max and premium seats) | short, high-stakes calls. It never writes a first attempt and never orchestrates. | the Tier 4 `lead-review`, `lead-architect`, the Tier 4 `queen-planner`, the retry of a missed story |
| **Opus** (judgment) | orchestrating, planning and judging. At Tier 3-4 it writes no story code on a first attempt. | the Queen (who also builds Tier 1-2 herself), `queen-planner`, `lead-review` at Tier 1-3 and as the Tier 4 second reviewer on Max, `lead-architect` on Pro/API, `council-opus`, the black-box seat `council-haiku`, `drone-coverage`, `librarian` |
| **Sonnet** (execution) | a story, a map, a doc, one verb. It never judges code it or another Sonnet wrote. | `worker-code` and `worker-test` (story default `model: sonnet`), `drone-scout`, `drone-docs`, `cycle-clerk`; the Tier 4 second reviewer on Pro/API (see tradeoffs) |
| **Haiku** (mechanical) | nothing until a Haiku >= 5.5 exists. Then only `cycle-clerk`. | none today. Haiku 4.5 is never dispatched. |

Why each move:
- **Workers to Sonnet.** A VULYK story is well-scoped by construction: named files, quoted asks and a
  `## Verification` line. That is Anthropic's stated Sonnet case. Terminal-Bench, the closest benchmark
  to "edit, run, close", favours Sonnet 5.5 (70.6 vs 66.4), and it costs half per token. It also
  gives two structural wins that are not about money:
  - At Tier 3 the Opus `lead-review` now judges code a different model wrote. That was the tradeoff
    ADR-013 accepted.
  - The retry climbs a rung on every plan. Before, on Pro and API, the gate was `opus` and the workers
    were `opus`, so the retry was the same model reading the same wall. Now it goes Sonnet to Opus
    there, and Sonnet to Fable on Max.
- **Scout and docs drones to Sonnet.** Reading and writing prose to a spec is well-scoped. The scout
  runs read-only, so Sonnet's "skips verification at low" does not apply.
- **Clerk stays on Sonnet, now 5.5.** One verb, `effort: low`, where Sonnet 5.5 "skips thinking on
  most simple requests". Opus cannot turn thinking off.
- **Black-box seat to Opus.** It judges. Workers now write on Sonnet, so a Sonnet seat would judge
  its own family. It was parked on the junior rung "until a Haiku 5.5 ships". The owner's "Haiku
  minimal" retires that plan, so Haiku gets only the clerk.
- **Everything that plans or judges stays Opus.** FrontierCode (54.4 vs 46.2) and HLE favour Opus,
  and so does Anthropic's "careful judgment" line.

Effort, per Anthropic's Sonnet 5.5 guide ("agentic coding: start at `medium` for well-specified tasks,
`high` for harder or longer ones"):
- workers: `medium`;
- scout, docs and clerk: `low`.

The guide's own two remedies go into the worker prompts instead of a higher effort:
- the scope paragraph ("When the work ... is done and checked, stop and report. Don't add features,
  tests, files, docs or refactors that weren't asked for"), which also serves Law 3;
- the verification paragraph.

The early check-in is caught by the existing `agent_empty` telemetry. If that code rises on Sonnet
workers, the fix is `effort: high` on the worker files: one word each.

## 4. The floor: "never below", written once

- **Routing names families, never versions.** Every `model:` in agent frontmatter, story files and
  the driver is an alias. A new generation arrives without an edit, as before.
- **The floor is a few lines of data,** `model_floor` in `scripts/lib.sh`:
  `fable 5.1 · opus 5.5 · sonnet 5.5 · haiku 5.5 unreleased` (`unreleased`: no model meets that line
  yet, so the bare alias counts as below it). It ships with every upgrade, so hosts never keep a
  stale copy in their own constitution. Raising it when a model ships is a one-line diff. Env
  `VULYK_MODEL_FLOOR` overrides it for a hive that deliberately runs lower, for example a Bedrock
  account without 5.5.
- **Before the fact: `scripts/top-model.sh --floor`.** It checks every place an alias can be remapped:
  - the six env vars in the shell;
  - the `env` and `model` keys of the user and project settings files;
  - a `CLAUDE_CODE_USE_*` provider flag with no family pin. Using the docs table above, it says which
    alias falls below the floor there.
  - a pinned ID in agent frontmatter.

  Exit 1 on any finding. The SessionStart brief prints the result every session.
- **After the fact: telemetry code `model_below_floor`.** `scan` reads the model ID each main and
  subagent transcript actually ran on. This is the only ground truth: it catches every path, including
  one nobody has thought of yet. Below the floor, it records a row with the version and the floor. The
  brief counts this week's rows.
- **Rejected:**
  - A self-ratcheting floor, raised to the highest version ever seen in local transcripts. It is
    clever, but a state file and a machine-dependent rule are not worth what they save: the alias
    already brings the newest model, and the floor only has to catch regressions.
  - Pinning full IDs. That is the per-release rewrite the owner asked to end.
  - Claude Code's `availableModels`/`deniedModels`. Those are managed/enterprise settings.

## 5. Tradeoffs recorded, and what would reverse them

1. **The per-task cost of Sonnet workers is vendor-claimed, not measured.** Check: `token-report.py`
   per story on the next Tier 3 spec, against 0.19's Opus-worker stories. If it costs more per closed
   story, `model: opus` goes back into the story template and `cycle.sh` default: two lines.
2. **Pro/API Tier 4 pair.** The gate is `opus` and the second reviewer `sonnet`, the builder's family.
   Fable would bill credits there, and a second Opus would duplicate the gate. The Opus gate is not the
   builder, so the rule "the builder never holds the gate" still holds. The second seat is the
   accepted gap.
3. **Tier 1-2** are unchanged: the Queen (Opus) builds and an Opus `lead-review` reviews in a fresh
   context. Putting a Sonnet reviewer over Opus code would weaken the reviewer to win diversity.
4. **Floor on non-Anthropic providers.** `--floor` warns but never rewrites env. The provider's IDs are
   the owner's to set (`anthropic.claude-sonnet-5-5` on Bedrock), and a hook that edits settings is the
   failure the update check exists to prevent.

## 6. Sources

| # | Claim | Status | Sources (name · date · tier · URL) |
|---|---|---|---|
| 1 | Sonnet 5.5 released 2026-09-28, ID `claude-sonnet-5-5`, $2/$10, 1M context, 128K out, adaptive thinking, default effort `high` | ✅ | Anthropic models overview · 2026-09-28 · T1 · https://platform.claude.com/docs/en/docs/about-claude/models/overview ; Sonnet 5.5 model page · 2026-09-28 · T1 · https://platform.claude.com/docs/en/models/sonnet-5-5/overview ; SiliconANGLE · 2026-09-28 · T2 · https://siliconangle.com/2026/09/28/anthropic-debuts-claude-sonnet-5-5-running-30-faster-than-the-previous-generation-ai-model/ |
| 2 | 30%+ faster than Sonnet 5, up to 30% cheaper per task at the same token price | ✅ (vendor claim, reported by both) | Anthropic launch post · 2026-09-28 · T1 · https://www.anthropic.com/claude-sonnet-5-5 ; SiliconANGLE (above) |
| 3 | Benchmark table (Terminal-Bench 70.6 vs 66.4, FrontierCode 46.2 vs 54.4, GDPval 1844 vs 1846 ...) | ⚠️ one source (Anthropic's own table; SiliconANGLE repeats Terminal-Bench and "two points below Opus 5.5 on GDPval-AA") | Anthropic launch post ; SiliconANGLE |
| 4 | Behaviours: check-ins at low/medium, skipped verification at low, unrequested additions, self-started reviews at xhigh/max | ❓ one source (first-party guide) | Prompting Claude Sonnet 5.5 · 2026-09-28 · T1 · https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5-5 |
| 5 | `sonnet`/`opus` aliases resolve below 5.5 on Bedrock, Vertex, Foundry, AWS Platform; env vars remap aliases | ❓ one source (first-party docs) | Claude Code model config · 2026-09-28 · T1 · https://code.claude.com/docs/en/model-config |
| 6 | Haiku 5.5 "in the coming weeks"; the current Haiku is 4.5 | ✅ | Anthropic launch post ; SiliconANGLE ; models overview |
| 7 | Independent per-task cost for Sonnet 5.5 | ❓ not published on 2026-09-28 | Artificial Analysis search, no Sonnet 5.5 page (only Sonnet 5) |
