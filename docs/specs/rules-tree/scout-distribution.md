# Scout: shipping, constitution budget, memory commands (2026-10-19, drone-scout, condensed by the Queen)

- install.sh: shippable() :69-94; OWNED :54 (.claude/hooks owned → new hook files ship and sync automatically); copy_tree :174;
  tree loop :1276; wire_hook :825 / py_wire :687 / unwire_hook :925; wiring calls :1358-1379 — a new hook = one
  `wire_hook <Event> <script> [matcher] [arg]` line after :1378 AND an entry in the shipped .claude/settings.json (fresh installs
  get it whole). py_wire idempotency ignores the matcher (:683-686).
- docs/defects: only README.md ships (:77); not OWNED → on a host the existing README is skipped, never updated. A generated
  per-hive index must not be README.md (collision with the shipped format contract).
- .claude/rules: not OWNED → copied only if absent, never updated on upgrade (:10, :194-195); a new shipped rules file needs no code.
- Upgrade contract (ADR-005 amendment 2026-10-16): release copies replaced, host-edited files three-way merged (upgrade_edited
  :140-172), host deletions respected (:197-200).
- Constitution: plain upgrade never writes CLAUDE.md (print_migrate_hint :469); `--constitution replace` (:491). Law 6 reaches a
  hive only through a constitution merge — owner rule: merge, never replace a host constitution.
- Budget: tests/maintenance.test.sh :31-32 CONSTITUTION_MAX_BYTES=7168, MAX_LINES=120 (CRs stripped :35), checked on CLAUDE.md
  (:81) and the shipped render (:84-88); DESCRIPTIONS_MAX_BYTES=4983 (:33). CLAUDE.md 109 lines.
  tests/constitution.test.sh is listed in CLAUDE.md ## Commands but does not exist.
- Law 6 is quoted in prose by vulyk-evolve.md:83; no test greps it.
- /vulyk-gc (vulyk-gc.md:6-23) → librarian over memory/learnings, map, snapshots, index; librarian has no shell (librarian.md:13-24).
  Nothing touches ~/.claude/projects/<slug>/memory today (only token-report.py reads ~/.claude/projects). Triage of private memory
  must run in the main session (librarian cannot read ~).
- /vulyk-evolve step 1 (vulyk-evolve.md:14-33): lexicon from `defect-intake.sh --lexicon`, finds litopys bin, `corrections --since 7d
  --lexicon`, prints `corrections (7d): n by lexicon · m in records · u not in docs/defects`, never blocks.
- docs/memory-system.md Layers table :4-12 says path rules load "on touch" — a path-less always-loaded file needs that row updated.
- Map pointers: scripts.md install :78-94, defects-check :53-57; agents-and-commands.md evolve :70-81, gc :82-85, librarian :36-38.
- Not read: ADR-005/016/017, the full upgrade-keeps-host-edits spec, shipped .claude/settings.json, docs/hooks-reference.md.
