# Video notes: "Build Your Own AI Software Factory with Claude Code"

Source: https://youtu.be/ctoaIC4LHmI (ZazenCodes, 2026-10-07, 28 min, sponsored by Anthropic).
Source code: https://github.com/zazencodes/zazencodes-season-3/tree/main/src/software-factory-claude-code
Read from a local clone of that folder; frames sampled from the public video at one per 10 s; the transcript from a local speech-to-text of the video. `SF:<path>:<line>` in the study files points into that folder.

## What was on screen (read from frames)

**Mind map, left half (theory).**
- A short history: 1968 Bob Bemer (GE) proposes the software factory: standardized tools plus data for management controls. 1969 Hitachi opens the first one. 2000s: factory as an assembly kit (reusable patterns, models, frameworks). 2010s-2020s: factory as a delivery pipeline (CI/CD, automated tests, security checks). Now: agentic factories, where AI agents plan, write, test and review.
- Agentic software factory 101. Quote: "What's new is automation of relatively unstructured cognitive work between the deterministic stages."
  `trigger -> sandbox -> agent -> checks -> PR -> (human) merge`
  - Triggers: GitHub issues, Linear/Jira tickets, Slack messages, cron schedules; incidents and error alerts (Sentry).
  - Diagnostics pulled in automatically: stack traces, logs, metrics and affected releases handed to the agent (Sentry over MCP).
  - Isolation: a fresh sandbox per run that clones the repo and is destroyed when done, so many agents work in parallel.
  - Verification: the repo's own tests and checks, plus code and secret scanning (the rest of the box is cut off in frame).

**Mind map, right half (the demo).**
- "Our simple agentic software factory": a team of AI agents that takes a feature from idea to merged code. Each agent has one job: write the spec, build it, review it, approve it.
- The factory line: Spec writer (Opus) -> Builder (Opus) -> four parallel reviews: Security (Opus), UX (Sonnet), UI design (Sonnet), Code (Sonnet) -> Approver (Opus) -> low risk: Merge to main | escalate: Needs human. On CHANGES the orchestrator resumes the builder (max 2).
- The orchestrator: one Claude Code session runs the `/factory` skill and becomes the orchestrator. It runs the loop, spawns every agent, and is the only writer of the job state file.
- Files hold the state: agents get context from files, not the conversation; each agent writes only its own file.
- The dashboard: job observability (cards moving across stages), human review enablement.
- Commands: `/factory <feature>` new job · `/factory next` next item in backlog.md · `/factory approve <job-id>` merge a needs-human job · `/factory rework <job-id> <note>` send back to the builder.
- Limitations & next steps (two versions on screen): state is not tracked cleanly yet; resuming the builder only works within a session; Git worktrees for parallel jobs (done in the video); GitHub issues as the intake; Agent teams for direct reviewer-to-builder chat; application metrics (Sentry); infrastructure observability (CPU, memory).

**Terminal and dashboard during the demo.**
- `/factory my obsidian agent setup course pages should not be paywalled` refused at first: "the factory's first precondition, a clean working tree, isn't met." The author commits the factory files himself.
- On screen the orchestrator session asked the owner a question ("User answered Claude's questions": the spec keeps lesson downloads buyer-only, but the owner said ONLY videos are paywalled; should downloads be free too?). The source never tells the spec writer to ask: its only channel is the spec's `## Assumptions`, which the approver escalates at the end (correction by the Opus analyst, checked against the source).
- The dashboard (a static HTML served by `python -m http.server`, polling job.json files) shows columns Spec / Build / Review / Approve / Merged / Needs human, with review chips (security/ux/ui/code) filling in as verdicts land.
- The approver wrote ESCALATE for billing / course-access changes, and for a blog render cache invalidation. The author remarks the guardrails are probably too tight ("Claude is gonna figure out some reason to get me to look at them").
- Three jobs ran at once from three tmux panes, each a separate Claude session; one orchestrator was Sonnet 5.5 at low effort while the subagents stayed Opus. The author's intuition: a smart orchestrator, cheaper subagents where possible.
- An auto-merge failed because main was dirty with backlog edits; the fix exempted `factory/backlog.md` from the clean-tree check.
- Opus wrote three starter backlog items by itself while building the factory.

## Transcript digest (author's claims and reasoning)

- 00:00-03:48 Intro. Feature in, autonomous to the end except the last human approval step. Spec by Opus, builder builds the full feature, separate review agents (security, UX, UI, code), loop until satisfied, approver (Opus) merges or hands to a human.
- 03:48-10:20 Build. Bypass permissions, Opus 5.5, high effort. One prompt (BUILD_PROMPT.md) builds the whole factory: skill + subagents + markdown state + dashboard. "This prompt is general, it will work for your project as well as for mine because it is not adapted to my project." The approver's escalation list is repo-specific (billing, course access) and the agent derived it from the repo.
- 10:20-16:16 First run. Clean-tree precondition; spec writer as background agent; builder on branch `factory/<id>`; build.md written; four reviewers in parallel; approver ESCALATE; `/factory approve <id>` in a new session merges. Free-form after the skill name: "this is not a strict schema". State is markdown/JSON in `factory/`, gitignored, transient; he would back it up to cloud storage.
- 16:16-23:57 Parallel. Added git worktree support; ran three jobs at once in tmux. "You just built this yourself... you're not relying on some dude's factory skill that is all hyped and does a million things." Orchestrator on Sonnet low effort still limited by Opus subagents.
- 23:57-end Next steps: GitHub issues as intake (or Slack); application metrics (Sentry) feeding bugs from production into the factory; infrastructure metrics; post-deployment watching and rollback ("it is not done once it's been pushed to production"). Cost: subagents pass context back and forth and cost more; everything ran on the Claude plan, not API tokens.
