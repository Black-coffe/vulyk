<!-- seat: review · model: claude-fable-5-1 · round: 1 · head: 29ba814 · pack: d0e2cbf3d988 · attempt: 1 · recorded: 2026-10-28T11:47:27Z · verdict: PASS -->
VERDICT: PASS
MODEL: claude-fable-5-1
SUITE: ok 375s

## Critical
None.
## Major
None.
## Minor
- docs/adr/025-red-receipt.md:272 `## Named bypasses` omits the receipt-forged-by-hand path (a worker recomputes `sha256sum` and edits `red_verified_at:`/`- impl:` in the story file after changing the sealed test); the template says "never by hand" but nothing catches it and the card `safeguard-bypassable-or-late` asks that every bypass be named.
- scripts/cycle.sh:3115 `cmd_repair` marks the repair story whenever any done story is marked, so a repair whose findings touch only prose (stories 02/03 here) must still produce a red test or spin through `not red: every verification line exits 0` to WALL; the worker prompts route that refusal to "fix the test" with no `NEEDS_CONTEXT` exit for "the findings need no test".
- scripts/cycle.sh:230 `fm_field` and scripts/wave-check.sh:249 `grep -q '^red:' "$f"` read the whole file, so a body line starting `red:` on a story whose frontmatter has no `red:` key would mark it; frontmatter-only matching (as `fm_raw` already does) would close it.
