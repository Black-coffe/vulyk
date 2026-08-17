---
description: Build or refresh the codebase map for a path using Sonnet scout batches
argument-hint: <path or module name; "." for full breadth-first pass>
---

Map target: "$ARGUMENTS"

1. Resolve the target to concrete directories. For ".", list top-level modules and map breadth-first (load-bearing first).
2. Dispatch `drone-scout` per module, up to 4 in parallel. Existing map files: pass the old file to the scout and ask for a delta-verify rather than a from-scratch rewrite (cheaper, preserves accumulated gotchas).
3. Save reports as `memory/map/<module>.md`, set `last-verified: <today>`. Enforce the ~80-line cap - maps are indexes, not documentation.
4. Update `memory/memory.md` pointers for new modules; keep the index <= 60 lines.
5. Report: modules mapped, modules still unmapped, anything a scout flagged as surprising (those are wiki-note candidates).
