<!-- seat: review · model: claude-fable-5-2 · round: 1 · head: 5b4ce8be · pack: 48c9ac58f82d · attempt: 1 · recorded: 2026-11-18T11:26:38Z · verdict: BLOCK -->
VERDICT: BLOCK
SUITE: ok 1521s
MODEL: claude-fable-5-2

## Critical
None.
## Major
1. docs/command-reference.md:6 [ask 1] the T81 sentences for `/vulyk-bootstrap` and `/vulyk-models` must say what the commands do at HEAD: `--quick` asks nothing and lists the gaps it defaulted and bootstrap dispatches no scout (`.claude/commands/vulyk-bootstrap.md:15`, `:61`), and `/vulyk-models` puts `sonnet-builds` first on every plan (`.claude/commands/vulyk-models.md:16`, against `docs/command-reference.md:48`), where the story's T81 note records both as "already matched" - repro: `grep -n 'asks for one confirmation\|up to four in parallel\|recommended for the detected plan' docs/command-reference.md` prints lines 6 and 48
2. docs/token-economy.md:146 [ask 2] the narrow-round paragraph must name every case in which the code opens a full round after a repair: its "only when" list leaves out a `half` escalation the owner reopened without `--full`, which `round_scope` answers with `full design` (`scripts/cycle.sh:4730`; `docs/cycle.md:103` and card `full-round-for-a-narrow-fix` both list it) - repro: `sed -n 144,147p docs/token-economy.md; sed -n 4726,4731p scripts/cycle.sh`
## Minor
- templates/memory.md:3 still says "always loaded" and "Humans welcome too" and seeds the index of every fresh install; the story names it as not done (outside `## Files`), with no `## Descoped` line needed since T91 does not list it
- docs/memory-system.md:9 names only drone-docs and librarian as writers of `memory/memory.md`, while `.claude/commands/vulyk-bootstrap.md:63` and `.claude/commands/vulyk-map.md:11` have the command's own session write it (the writer half of T91 is still two answers)
- docs/token-economy.md:37, docs/token-economy.md:50 and docs/getting-started.md:43 keep the older effort-and-cache model list that docs/model-cascade.md no longer carries (not named by T83, so left for the next circle)
- memory/memory.md:37, docs/faq.md:44 and docs/token-economy.md:151 still spell a bare `python scripts/token-report.py` beside the corrected `bash scripts/py.sh` lines
- README.md:48 ("optionally Agent Teams") and README.md:168 ("initial map") sit beside the corrected FAQ and bootstrap wording and now disagree with it
