# Agent guidance bridge

This repository is orchestrated by VULYK (see CLAUDE.md - the constitution - which imports this file).
Non-Claude agents reading AGENTS.md: respect the same contract.

- Routing: classify task tier per the matrix in CLAUDE.md before working.
- Boundaries: touch only files your story names; no silent assumptions; surface tradeoffs.
- Memory: start at memory/memory.md; treat pointers as hints to verify; never edit memory/ directly
  (drone-docs and librarian own it).
- Specs: plans and stories in docs/specs/ are the source of truth; decisions go to docs/adr/.
