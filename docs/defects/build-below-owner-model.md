---
id: build-below-owner-model
title: A build runs its workers below the model family the owner chose, on a profile switch that outlived its reason
status: text
check:
fixtures: []
keys: [ниже опуса, не надо сюда соннет]
paths: [".claude/commands/vulyk-build.md", ".claude/commands/vulyk-models.md", "scripts/model-profile.sh"]
---

# A build runs its workers below the model family the owner chose, on a profile switch that outlived its reason
The model profile is one file per account. A temporary switch (to `sonnet-builds` while a weekly cap was hit) had no
end date, nobody switched back, and a serious Tier 3 build launched with its workers on Sonnet. The owner saw it only
in the launch line, after a wave had already been written by the wrong family.

## Owner quotes
- 2026-11-08 · VULYK, /vulyk-build ab-run-fixes · the hive launched with Sonnet workers on a profile left from a temporary switch — «Ниже опуса я бы не опускал, тут серьезно и не надо сюда соннет»

## Cause
`scripts/model-profile.sh --set` writes a profile with no reason and no expiry, and the hive launch prints the
families without asking whether the profile is still the one the owner wants for this build.

## Check
None yet. Code cannot know which family the owner wants for a given build; a later story could give `--set` an
optional expiry and make the launch name a profile older than its reason.

## Never
- Launch a hive without first showing the owner the active profile and the family that will write the code.
- Leave a temporary profile switch in place after its reason (a cap, a measurement) is gone.

## Allowed
- A profile chosen by the owner for one build or one measurement (the A/B run of `sonnet-builds`), switched back after
  it and said so before the launch.
