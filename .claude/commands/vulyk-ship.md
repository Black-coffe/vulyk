---
description: Stage 06 of the cycle - fix history, publish the version, open the next circle. Refuses without the owner's check.
argument-hint: [spec slug; defaults to the newest spec with a human check recorded]
---

Ship: "$ARGUMENTS" (default: the newest spec under `docs/specs/` whose plan.md carries a `**Checked:** ACCEPTED` line).

1. **Run the gate first - it is free and it decides whether you are here at all.** `bash scripts/ship-check.sh docs/specs/<slug>` and show its output. `NOT READY` is a refusal, not a warning: name the open stage and stop. The two refusals worth expecting are stage 05 — nobody has looked, or they looked at a commit that is no longer HEAD — and stage 04 stale, because a repair round moved the pack after the blind gate judged it. Both are cured by going back, never by shipping around them. The owner can override a `NOT READY` — it is their release — but the override is said out loud and quoted into the `--record` note, so the ledger reads "shipped unchecked, by decision" rather than green.

2. **Fix history.** The spec branch (`**Branch:**` in plan.md) holds one commit per story. Do not squash them — each is a rollback point and the review unit, and the story ids in their messages are what joins `scope.jsonl` to the code. What the release paperwork adds is one more commit, on the same branch: the version bump and the CHANGELOG entry, in this project's convention (`## Profile`, *Release / deploy* row; the commit convention row for its message). This is release paperwork, not story code — Law 5 does not apply to it, and it does not need a worker. Then merge into the default branch the way the Profile row says the project merges: a local merge is reversible and yours to run; **a PR, a push, a tag pushed to a remote is outward-facing — show the exact commands and ask before running any of them.**

3. **Publish — the human presses.** No agent in the hive deploys, publishes, pays or sends, and neither do you here. Print the publish step exactly as the *Release / deploy* row names it (tag + push, `npm publish`, a CI run on merge, a deploy script) and the version it will carry, then stop and wait. When the owner says it is out, ask for the one thing that closes the stage: **where the published version can be seen** — a URL, a registry entry, a tag name.

4. **Record it.** `bash scripts/ship-check.sh --record docs/specs/<slug> <version> "<where it was published, in the owner's words>"`. That writes the `**Shipped:**` line beside `**Approved:**` and `**Checked:**`, and a row in `memory/stats/ship.jsonl`. Commit the record (`vulyk(<slug>): shipped <version>`). The cycle for this spec is closed on disk, not in this conversation.

5. **Open the next circle.** In one message, dispatch `drone-docs` with the merged diff to refresh map and wiki, and `librarian` for the ADR harvest from `## Plan deltas` (proposed-only; accepting one is the owner's). Then gather what this circle left behind and hand it to the owner as the draft of the next brief — verbatim, not summarised, because the next `brief.md` quotes it: the `UNASKED` line from the acceptance report, every `## Descoped` entry in plan.md, and any worker `CONCERNS` review ranked minor and nobody fixed. Do not open a spec for them; deciding what the next circle is belongs to the human.

6. **Close the session cleanly.** Recommend `/vulyk-handoff` and `/clear`: everything this spec needed is in git, and the context that built it is the most expensive thing still in the room.
