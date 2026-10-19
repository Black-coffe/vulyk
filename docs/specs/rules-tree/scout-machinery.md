# Scout: defect-library machinery (2026-10-19, drone-scout, condensed by the Queen)

Files read: .claude/hooks/defects-inject.sh, .claude/hooks/defect-intake.sh, scripts/defects-check.sh, .claude/settings.json,
tests/defects.test.sh, tests/intake.test.sh, tests/inject.test.sh, docs/defects/README.md, ADR-014, ADR-018.
Not searched: other consumers of docs/defects (install.sh, lead-review, evolve, litopys) — Grep is blind on this box.

## Entry points
- defects-inject.sh:18-25 launcher, Python 28-297, main() 193-289, `reset` = SessionStart mode.
- defect-intake.sh:17-24 launcher, main() 142-188, `--lexicon` 143-145.
- defects-check.sh: bash 35-60, 283-327; Python plan 67-282 emits D/U/O/E/I/R records; R loop 288-313.
- settings.json: SessionStart:11 `defects-inject.sh reset`; UserPromptSubmit:28 intake; PreToolUse:34-36 matcher
  `Edit|Write|MultiEdit|NotebookEdit|Bash` → inject; PostToolUse:47-54 only `Skill` → skill-usage-counter.sh. AskUserQuestion needs its own block.

## Gotchas
1. Card discovery is flat in three places: inject:92, intake:89 (`os.listdir`, skip non-.md and readme case-insensitive),
   check:158-160 (`README.md` case-sensitive). Cards in sub-folders are silently invisible. `fixtures/` must stay excluded.
2. Gate git calls use the bare filename relative to `-C d`: blame(name) :93, `git log -- name` :232; README add-commit :81
   must stay at library root. Sub-folders → name must become `area/x.md`.
3. Parser duplicated: inject:34-113 and intake:31-110 share a "kept identical" block (fixpath, fm_scalar, fm_list, load_cards),
   no test asserts sameness; defects-check.sh has its own parser (listval :85-89 naive comma split; frontmatter loop 163-174).
   Section parsing: `never_lines` only in inject 181-190, regex `^##[ \t]+(?:Never|Нельзя)\b`, first match only.
   `## Allowed/## Можно` recognised nowhere (inject.test.sh:186). Gate knows only QUOTE_HEADS (:72, 187-188); any other `## `
   closes the quotes section (escape test defects.test.sh:242 `## История`).
4. Inject matching 221-238: Bash → tool_input.command; else file_path/notebook_path. Code branches only on tool_name=='Bash';
   tool-name scope is new code. Command split on `[\s;|&<>()]+`, quote strip, after `=`; `cmd:` = re.search over the line; else glob
   (glob_rx 128-151, `*` crosses `/`, basename match for globs without `/`, case-insensitive on Windows).
   Dedup state `$root/.claude/state/defects/inject-<session>.txt` (:199), `agent\tcid` lines (:251, :285); listed-only cards also
   recorded as shown (:281). Reset 200-217: compact/clear delete; startup prunes >7 days; resume nothing.
   Output: header + `<cid> — <title>` + `✗ <line>`; card with no Never lines → "read docs/defects/<cid>.md" (:274, flat path).
   Block-with-check and revoked skipped (injected_as 116-125). BUDGET = 4000 chars (:31, :275), cards in sorted(listdir) order;
   overflow listed with flat path (:276). No line cap, no narrowest-scope ordering.
5. Intake: BLOCKS 113-122 stripped at 157-159; triggers TIMECODE, LEXICON (124-127), card keys (170-177, revoked skipped).
   One fixed message ≤600 chars. Phrase trigger must scan the raw prompt (before stripping) as a second pass. No-library early
   return at :155 precedes all triggers. Paste-stripping tests intake.test.sh:124-126, 143-144 change if pastes can fire.
6. Gate: debt 208-227 (≥2 quotes, not effective block, new by blame vs README add-commit). "Counts only Never/How-to" has no
   hook in the code — new logic. Undeliverable 231-238 (text card without paths) — a tools-only scope would be flagged unless
   updated. Overlap 256-281; escape 241-254 (block only). README `## Cards` table (README:105-119) is hand-written, never read,
   already inconsistent; a generated-index check is new code and, per ADR-018, needs a new/old-by-blame cut or its own ADR.
7. Tests: ok/bad ledgers printing `  ok    label` / `::error::label`. defects.test.sh: mkrepo, `cm <date> paths`, `card id status
   check fixtures quotes...` (paths `src/<id>/**`, `## Never`), `run`, `has`; sections listed; no sub-folder, no README table test.
   inject.test.sh: fixture library in $D, `edit`/`bashcall` payloads, `ctx`, expect/expect_absent/expect_silent; budget, latency
   (median ≤200 ms), python3 stub. intake.test.sh: fires/silent/stub/latency/--lexicon.

## Missing today (all new work)
Tool-name scope; per-action line budget (today 4000 chars); scope-specificity order; generated README + check; debt counting only
Never/How-to; PostToolUse AskUserQuestion hook; phrase trigger; sub-folder discovery in three loaders (+ blame paths, flat
fallback paths, id collisions across areas).
