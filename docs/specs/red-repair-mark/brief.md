# Repair mark follows the findings (brief)

**Date:** 2026-10-28 · **Tier:** 1

## Request
<!-- The Queen's wording, passed to /vulyk-plan; it is not an owner quote. The owner's own words are the decision line below. -->
> Hotfix 0.40.1 for the red receipt (0.40.0). (1) cmd_repair (scripts/cycle.sh ~3116) marks the repair story red: required whenever ANY done story in the spec is marked; a repair whose RED findings touch only prose (prompts, docs) can never produce a red, stamp-red answers "not red: every verification line exits 0", the worker is told to fix the test, misses twice, the driver stops. Fix: the repair inherits the mark only when the RED round's findings/asks touch an implementation file of a marked story; otherwise unmarked. (2) fm_field (cycle.sh:230) and wave-check.sh:249 `grep -q '^red:'` read the whole story file, so a body line starting `red:` marks an unmarked story; read the frontmatter only, as fm_raw does. Both from lead-review minors of red-receipt round 1 (docs/specs/red-receipt/council/round-1/review.md). Owner chose: hotfix now, before any hive upgrades to 0.40.0.

Owner decision, 2026-10-28: «Хотфикс 0.40.1 сейчас (Рекомендую)».
Owner decision, 2026-10-28, on a finding with no file: «Оставлять пометку (Рекомендую)».

## Asks
1. A repair of a spec with a marked story is written unmarked, as before 0.40.0, only when every one of its RED findings names a file and none names a file from a marked story's `## Files`; a finding that names no file keeps the mark.
2. A `red:` line in a story's body, outside its frontmatter, neither marks the story for `stamp-red`/`close-story` nor raises a `wave-check` red line.
