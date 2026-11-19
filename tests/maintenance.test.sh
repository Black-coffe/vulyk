#!/usr/bin/env bash
# Self-maintenance contract (docs/specs/auto-maintenance): the always-loaded text stays inside its byte
# budget. No model calls, no network.
#
#   Usage: bash tests/maintenance.test.sh                  # every part, from the VULYK repo root
#          bash tests/maintenance.test.sh --part <name>    # one part
#          bash tests/maintenance.test.sh --list-parts     # the part names, one per line
#
# Parts (card test-gate-one-long-limit: each well under 70% of the 300 s part cap): upkeep (the budget, due
# maintenance, the offers, the brief, the evolve ledger), redact (redact.sh and the hooks and scripts after it, up
# to handoff.sh), guards (portability-check, the git guard, hives-behind and the command prose checks).
#
# Budget (ADR-013 D7, report rrsi-self-improvement §5.3). The caps are numbers here on purpose:
# raising one is a visible diff the owner reviews, paid only by an owner quote or an accepted ADR.
# Sizes are measured CR-stripped, which equals the git blob on every platform.
set -u
PARTS="upkeep
redact
guards"
PART=""
while [ $# -gt 0 ]; do
  case "$1" in
    --list-parts) printf '%s\n' "$PARTS"; exit 0 ;;
    --part)
      if [ -z "${2:-}" ] || ! printf '%s\n' "$PARTS" | grep -qxF -- "$2"; then
        echo "maintenance.test.sh: --part needs one of:" >&2; printf '%s\n' "$PARTS" >&2; exit 1
      fi
      PART="$2"; shift 2 ;;
    *) echo "maintenance.test.sh: unknown argument: $1" >&2; exit 1 ;;
  esac
done
part_on() { # part_on <name> - true when no part was named or this one was
  [ -z "$PART" ] || [ "$PART" = "$1" ]
}
SRC="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fail=0
# shellcheck source=scripts/lib.sh
. "$SRC/scripts/lib.sh"
vulyk_python || { echo "maintenance.test.sh: needs python 3 (python3, python or py)"; exit 1; }
PYBIN="$(command -v "$VULYK_PY")"   # a full path: the counting python3 stub below execs it by PATH otherwise
LEDGER="$T/checks"; FAILS="$T/fails"; : > "$LEDGER"; : > "$FAILS"
ok()  { printf 'x\n' >> "$LEDGER"; echo "  ok    $1"; }
bad() { printf 'x\n' >> "$LEDGER"; printf 'x\n' >> "$FAILS"; echo "::error::$1"; }
expect() { # expect <label> <needle>   (reads the output to judge from stdin)
  local label="$1" needle="$2" out; out="$(cat)"
  if printf '%s' "$out" | grep -qF -- "$needle"; then ok "$label"
  else bad "$label - expected '$needle' in:"; printf '%s\n' "$out" | sed 's/^/        /'; fi
}
expect_absent() { # expect_absent <label> <needle>   (reads the output to judge from stdin)
  local label="$1" needle="$2" out; out="$(cat)"
  if printf '%s' "$out" | grep -qF -- "$needle"; then
    bad "$label - did NOT expect '$needle' in:"; printf '%s\n' "$out" | sed 's/^/        /'
  else ok "$label"; fi
}

CONSTITUTION_MAX_BYTES=7168
CONSTITUTION_MAX_LINES=120
RULES_ALWAYS_MAX_LINES=40      # a .claude/rules/*.md without paths: loads in every session (rules-tree, ADR-021)
DESCRIPTIONS_MAX_BYTES=4983     # agents 2 907 + commands 1 716, measured 2026-09-29; +360 /vulyk-models voice triggers (model-profiles requirement 6, approved plan)

size_of() { tr -d '\r' < "$1" | wc -c | tr -d ' '; }
lines_of() { tr -d '\r' < "$1" | wc -l | tr -d ' '; }

within_budget() { # within_budget <file> <max-bytes> <max-lines> - 0 when both hold, else prints why
  local b l; b="$(size_of "$1")"; l="$(lines_of "$1")"
  if [ "$b" -gt "$2" ]; then echo "$b bytes > $2"; return 1; fi
  if [ "$l" -gt "$3" ]; then echo "$l lines > $3"; return 1; fi
  return 0
}

# shipped_render <constitution> <out> - what a host receives: both marked blocks swapped for the
# installer's own placeholders (install.sh print_commands_placeholder / print_profile_placeholder).
shipped_render() {
  local fns="$T/placeholders.sh"
  sed -n '/^print_commands_placeholder()/,/^}/p;/^telemetry_row()/,/^}/p;/^print_profile_placeholder()/,/^}/p' \
    "$SRC/install.sh" > "$fns"
  ( . "$fns"; print_commands_placeholder > "$T/cmd.txt"; print_profile_placeholder > "$T/prof.txt" )
  "$PYBIN" - "$1" "$T/cmd.txt" "$T/prof.txt" "$2" <<'PY'
import sys
b = open(sys.argv[1], 'rb').read().decode('utf-8').replace('\r\n', '\n')
def swap(b, m, new):
    s = b.index('<!-- %s:START -->' % m); s = b.index('\n', s) + 1
    e = b.index('<!-- %s:END -->' % m)
    return b[:s] + new + b[e:]
cmd = open(sys.argv[2], 'rb').read().decode('utf-8')
prof = open(sys.argv[3], 'rb').read().decode('utf-8')
open(sys.argv[4], 'wb').write(swap(swap(b, 'VULYK:COMMANDS', cmd), 'VULYK:PROFILE', prof).encode('utf-8'))
PY
}

if part_on upkeep; then
echo "--- budget: the checker itself"
git -C "$SRC" show d519f22:CLAUDE.md > "$T/original.md" 2>/dev/null
if [ -s "$T/original.md" ]; then
  if why="$(within_budget "$T/original.md" "$CONSTITUTION_MAX_BYTES" "$CONSTITUTION_MAX_LINES")"; then
    bad "the original case (v0.20.0 CLAUDE.md, 8 531 B) passed the budget"
  else ok "the original case (v0.20.0 CLAUDE.md) fails: $why"; fi
else ok "the original case skipped: commit d519f22 not in this clone"; fi
{ for i in $(seq 1 121); do echo "line $i"; done; } > "$T/neighbour.md"
if why="$(within_budget "$T/neighbour.md" "$CONSTITUTION_MAX_BYTES" "$CONSTITUTION_MAX_LINES")"; then
  bad "the neighbour form (121 short lines, bytes in budget) passed the budget"
else ok "the neighbour form (121 short lines) fails: $why"; fi
printf 'a\r\nb\r\n' > "$T/crlf.md"
[ "$(size_of "$T/crlf.md")" -eq 4 ] && ok "CR bytes are not counted (working copy = git blob)" \
  || bad "size_of counts CR bytes: $(size_of "$T/crlf.md")"

echo "--- budget: this tree"
if why="$(within_budget "$SRC/CLAUDE.md" "$CONSTITUTION_MAX_BYTES" "$CONSTITUTION_MAX_LINES")"; then
  ok "CLAUDE.md within $CONSTITUTION_MAX_BYTES B / $CONSTITUTION_MAX_LINES lines ($(size_of "$SRC/CLAUDE.md") B, $(lines_of "$SRC/CLAUDE.md") lines)"
else bad "CLAUDE.md over budget: $why"; fi
# tests/model-profile.test.sh holds the constitution at its baa5219 size too: the tighter of the two caps binds
if git -C "$SRC" show baa5219:CLAUDE.md > "$T/claude.baa5219" 2>/dev/null; then
  [ "$(size_of "$SRC/CLAUDE.md")" -le "$(size_of "$T/claude.baa5219")" ] \
    && ok "CLAUDE.md no bigger than at baa5219 ($(size_of "$SRC/CLAUDE.md") <= $(size_of "$T/claude.baa5219") B)" \
    || bad "CLAUDE.md grew past its baa5219 size"
else ok "the baa5219 size comparison skipped: baa5219 not in this clone"; fi
if shipped_render "$SRC/CLAUDE.md" "$T/shipped.md" 2>"$T/render.err"; then
  if why="$(within_budget "$T/shipped.md" "$CONSTITUTION_MAX_BYTES" "$CONSTITUTION_MAX_LINES")"; then
    ok "shipped constitution within budget ($(size_of "$T/shipped.md") B, $(lines_of "$T/shipped.md") lines)"
  else bad "shipped constitution over budget: $why"; fi
else bad "could not render the shipped constitution: $(cat "$T/render.err")"; fi
for m in VULYK:PROFILE:START VULYK:PROFILE:END VULYK:COMMANDS:START VULYK:COMMANDS:END; do
  [ "$(grep -c "<!-- $m -->" "$SRC/CLAUDE.md")" -eq 1 ] && ok "marker $m once" || bad "marker $m missing or repeated"
done
grep -q '^| Owner language | ' "$T/shipped.md" && tr -d '\r' < "$SRC/CLAUDE.md" | grep -q 'Write to the owner in \*Owner language\*' \
  && ok "the shipped Profile has an Owner language row and the constitution says to use it" || bad "Owner language row or its rule missing"
# Law 2's floor: a trim to fit the byte cap must not take it out (a bare "be simple" prompt drops guards)
grep -qF 'Simplest never drops trust-boundary validation, data-loss handling or security checks.' "$T/shipped.md" \
  && ok "the shipped Law 2 keeps its safety floor" || bad "Law 2 lost its safety floor"
# a hive's /vulyk-update read a stamp an uncommitted upgrade had written and said "nothing to do"
grep -qF 'git show HEAD:.claude/vulyk-version' "$SRC/.claude/commands/vulyk-update.md" \
  && ok "/vulyk-update compares the committed stamp, not only the one on disk" || bad "/vulyk-update reads only the stamp on disk"
# /vulyk-update is the owner's to run: its frontmatter keeps the model from invoking it (tails-1115)
owner_only() { # owner_only <command.md> - 0 when its frontmatter holds disable-model-invocation: true
  tr -d '\r' < "$1" | sed -n '1{/^---$/!q;d;};/^---$/q;p' | grep -qx 'disable-model-invocation: true'
}
owner_only "$SRC/.claude/commands/vulyk-update.md" \
  && ok "/vulyk-update is owner-only: its frontmatter has disable-model-invocation: true" \
  || bad "/vulyk-update lost disable-model-invocation: true from its frontmatter"
tr -d '\r' < "$SRC/.claude/commands/vulyk-update.md" | grep -vx 'disable-model-invocation: true' > "$T/update-open.md"
owner_only "$T/update-open.md" \
  && bad "the neighbour form (/vulyk-update without disable-model-invocation) passed the owner-only check" \
  || ok "the neighbour form (/vulyk-update without disable-model-invocation) fails the owner-only check"
desc="$(cat "$SRC"/.claude/agents/*.md "$SRC"/.claude/commands/*.md | tr -d '\r' | grep '^description:' | wc -c | tr -d ' ')"
if [ "$desc" -le "$DESCRIPTIONS_MAX_BYTES" ]; then ok "agent + command descriptions within $DESCRIPTIONS_MAX_BYTES B ($desc B)"
else bad "agent + command descriptions $desc B > $DESCRIPTIONS_MAX_BYTES B"; fi

# rules_always_over <dir> - prints each path-less rules file over RULES_ALWAYS_MAX_LINES (one with paths: is exempt)
rules_always_over() {
  local f
  for f in "$1"/*.md; do
    [ -f "$f" ] || continue
    tr -d '\r' < "$f" | sed -n '1{/^---$/!q;d;};/^---$/q;/^paths:/{p;q;}' | grep -q . && continue
    [ "$(lines_of "$f")" -gt "$RULES_ALWAYS_MAX_LINES" ] && echo "$(basename "$f") $(lines_of "$f") lines"
  done
  return 0
}
mkdir -p "$T/rules"; { for i in $(seq 1 41); do echo "- rule $i"; done; } > "$T/rules/always.md"
cp "$SRC/.claude/rules/README.md" "$T/rules/README.md"; { for i in $(seq 1 41); do echo "- scoped $i"; done; } >> "$T/rules/README.md"
over="$(rules_always_over "$T/rules")"
case "$over" in "always.md 41 lines") ok "a 41-line path-less rules file fails the $RULES_ALWAYS_MAX_LINES-line cap; paths: is exempt" ;;
  *) bad "the always-loaded rules cap misjudged the fixture: '$over'" ;; esac
over="$(rules_always_over "$SRC/.claude/rules")"
[ -z "$over" ] && ok "path-less rules files within $RULES_ALWAYS_MAX_LINES lines" || bad "always-loaded rules over $RULES_ALWAYS_MAX_LINES lines: $over"

fi # upkeep

# --- due maintenance: the SessionStart brief (auto-maintenance-02) ---------------------------------
# These helpers serve the upkeep and guards parts both: defined outside the parts.
BRIEF_HOOK="$SRC/.claude/hooks/session-start-brief.sh"
iso_ago() { date_shift -"$1" +%Y-%m-%dT%H:%M:%SZ; }
hive() { # hive <name> - a fresh fixture hive: git repo on main with one commit, empty memory
  local h="$T/$1"
  mkdir -p "$h/memory/learnings" "$h/memory/stats" "$h/memory/map"
  echo "# learnings" > "$h/memory/learnings/README.md"
  git -C "$h" init -q -b main 2>/dev/null || { git -C "$h" init -q; git -C "$h" checkout -q -b main; }
  git -C "$h" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  echo "$h"
}
# The config folder is a temp one, so the owner's real model profile file decides nothing here.
brief_of() { echo '{}' | CLAUDE_PROJECT_DIR="$1" CLAUDE_CONFIG_DIR="${BRIEF_CONF:-$T/conf-none}" bash "${2:-$BRIEF_HOOK}" 2>&1; }
stub()   { printf '# Session x\n<!-- Stub captured by VULYK. Replace with 1-6 bullets -->\n' > "$1"; }
council_row() { printf '{"ts":"%s","spec":"s","round":1,"verdict":"GREEN"}\n' "$2" >> "$1/memory/stats/council.jsonl"; }
run_row()     { printf '{"ts":"%s","kind":"run","proposals":0}\n' "$2" >> "$1/memory/stats/evolve.jsonl"; }

if part_on upkeep; then
echo "--- the learnings chain is retired (tails-1115-10, T96): the brief reads nothing in memory/learnings/"
H="$(hive gc-retired)"; stub "$H/memory/learnings/2026-09-14_090058.md"
for i in 1 2 3 4 5 6 7 8 9 10; do echo "- real $i" > "$H/memory/learnings/l$i.md"; done
echo "- merged" > "$H/memory/learnings/CONSOLIDATED.md"
before="$(cd "$H/memory/learnings" && cksum ./*.md)"
out="$(brief_of "$H")"
printf '%s' "$out" | expect_absent "a stub and 10 raw learnings: no gc line (the chain is retired)" "learnings"
printf '%s' "$out" | expect_absent "a stub and 10 raw learnings: nothing due" "maintenance due"
[ "$(cd "$H/memory/learnings" && cksum ./*.md)" = "$before" ] && ok "the learnings files are byte-identical after a brief run" \
  || bad "a brief run changed memory/learnings/"
for p in .claude/agents/librarian.md .claude/commands/vulyk-gc.md .claude/commands/vulyk-evolve.md; do
  grep -n 'memory/learnings\|CONSOLIDATED' "$SRC/$p" | expect_absent "$p names no step that reads, consolidates or deletes memory/learnings/" ":"
done
LIB_PROMPT="$(tr -d '\r' < "$SRC/.claude/agents/librarian.md")"
printf '%s' "$LIB_PROMPT" | expect_absent "librarian (no shell) is not told to compare file modification times" "modification time"
printf '%s' "$LIB_PROMPT" | expect_absent "librarian (no shell) is not told to delete" "you have no shell, so"
sed -n '/^## GC pass/,/^## ADR harvest/p' "$SRC/.claude/agents/librarian.md" | tr '\n' ' ' \
  | expect "librarian: the stale-map list comes from its caller" "from your dispatch"
tr '\n' ' ' < "$SRC/.claude/commands/vulyk-gc.md" | expect "vulyk-gc hands the librarian the map dates it cannot read" "git log -1 --format=%cs"
EVO="$(tr -d '\r' < "$SRC/.claude/commands/vulyk-evolve.md" | tr '\n' ' ')"
for s in insight-harvester skill-gardener; do
  printf '%s' "$EVO" | expect "vulyk-evolve reads the meta-skill $s by path (T70)" "Read \`.claude/skills/_meta/$s/SKILL.md\`"
  [ -f "$SRC/.claude/skills/_meta/$s/SKILL.md" ] && ok "the path vulyk-evolve names for $s exists" || bad "no .claude/skills/_meta/$s/SKILL.md"
done

echo "--- due maintenance: evolve"
H="$(hive ev-never)"; council_row "$H" "$(iso_ago 3)"
brief_of "$H" | expect "never run + a council round: evolve due" "evolve (never run; 1 council rounds on record)"
H="$(hive ev-quiet)"
brief_of "$H" | expect_absent "never run, no council round: nothing to learn from" "evolve ("
H="$(hive ev-fresh)"; run_row "$H" "$(iso_ago 2)"; council_row "$H" "$(iso_ago 1)"
brief_of "$H" | expect_absent "last run 2 days ago: not due" "evolve ("
H="$(hive ev-week)"; run_row "$H" "$(iso_ago 8)"; council_row "$H" "$(iso_ago 1)"
brief_of "$H" | expect "last run 8 days ago + a newer council round: due" "council rounds since)"
H="$(hive ev-idle)"; council_row "$H" "$(iso_ago 9)"; run_row "$H" "$(iso_ago 8)"
brief_of "$H" | expect_absent "last run 8 days ago, no council round since: not due" "evolve ("
H="$(hive ev-over)"; run_row "$H" "$(iso_ago 30)"; council_row "$H" "$(iso_ago 1)"
brief_of "$H" | expect "last run 30 days ago: overdue, the sunset question" "overdue: ask the owner once whether to retire it"
printf '{"ts":"%s","kind":"proposal","branch":"b"}\n' "$(iso_ago 1)" >> "$H/memory/stats/evolve.jsonl"
brief_of "$H" | expect "a proposal row is not a run" "overdue"
H="$(hive ev-pending)"; council_row "$H" "$(iso_ago 1)"
git -C "$H" branch vulyk/evolve-2026-09-20
git -C "$H" checkout -q vulyk/evolve-2026-09-20
git -C "$H" -c user.email=t@t -c user.name=t commit -q --allow-empty -m change
git -C "$H" checkout -q main
out="$(brief_of "$H")"
printf '%s' "$out" | expect "an unmerged evolve branch waits for review" "vulyk/evolve-2026-09-20 waits for the owner's review"
printf '%s' "$out" | expect_absent "a pending changeset is not due again" "evolve (never run"
git -C "$H" -c user.email=t@t -c user.name=t merge -q --ff-only vulyk/evolve-2026-09-20
out="$(brief_of "$H")"
printf '%s' "$out" | expect_absent "a merged evolve branch is not pending" "waits for the owner's review"

echo "--- due maintenance: map, quiet hive, size"
H="$(hive map-stale)"; date +%Y-%m-%dT%H:%M:%S > "$H/memory/map/.stale"
brief_of "$H" | expect "the post-merge flag makes map due" "map (flagged stale after a merge"
brief_of "$H" | expect "the due line names the Skill to run" "Skill tool (vulyk-map)"
H="$(hive quiet)"; echo "- one real" > "$H/memory/learnings/a.md"
git -C "$SRC" show d519f22:.claude/hooks/session-start-brief.sh > "$T/old-brief.sh" 2>/dev/null
out="$(brief_of "$H")"
printf '%s' "$out" | expect_absent "a quiet hive gets no maintenance line" "maintenance due"
if [ -s "$T/old-brief.sh" ]; then
  new_b="$(printf '%s' "$out" | wc -c | tr -d ' ')"; old_b="$(brief_of "$H" "$T/old-brief.sh" | wc -c | tr -d ' ')"
  if [ "$new_b" -le "$old_b" ]; then ok "quiet brief no longer than v0.20.0's ($new_b <= $old_b B)"
  else bad "quiet brief grew: $new_b > $old_b B"; fi
fi
printf '%s' "$out" | expect_absent "the false learnings counter is gone" "awaiting GC"
printf '%s' "$out" | expect_absent "a hive without a constitution gets no bootstrap offer" "vulyk-bootstrap now"

# --- the native auto memory index (auto-memory-subagent-start-02) ------------------------------------
# Claude Code loads the first 200 lines / 25 KB of MEMORY.md; at 80% (160 lines or 20480 bytes) triage is due.
echo "--- due maintenance: native MEMORY.md size"
automem() { # automem <hive> <conf> -> the private memory dir Claude Code uses for that hive
  local top; top="$(git -C "$1" rev-parse --show-toplevel)"
  printf '%s/projects/%s/memory' "$2" "$(printf '%s' "$top" | LC_ALL=C.UTF-8 sed 's#[^0-9A-Za-z]#-#g')"
}
lines_of() { # lines_of <n> <width> -> n lines of width characters (newline included)
  awk -v n="$1" -v w="$2" 'BEGIN { s = sprintf("%" (w - 1) "s", ""); gsub(/ /, "m", s); for (i = 0; i < n; i++) print s }'
}
MC="$T/conf-mem"
H="$(hive mem-under)"; M="$(automem "$H" "$MC")"; mkdir -p "$M"
{ lines_of 158 128; lines_of 1 255; } > "$M/MEMORY.md"   # 159 lines, 20479 bytes
BRIEF_CONF="$MC" brief_of "$H" | expect_absent "159 lines and 20479 bytes: memory triage not due" "memory triage"
lines_of 160 10 > "$M/MEMORY.md"
BRIEF_CONF="$MC" brief_of "$H" | expect "memory triage due at 160 lines" "memory triage (MEMORY.md 160 lines, 1 KB of 200 lines / 25 KB)"
BRIEF_CONF="$MC" brief_of "$H" | expect "the due line names /vulyk-gc memory" "vulyk-gc memory"
# 0.41.1: the triage reads every private memory file, so it is offered to the owner, never run as maintenance.
BRIEF_CONF="$MC" brief_of "$H" | expect_absent "memory triage is offered on its own line, not in maintenance due" "maintenance due"
BRIEF_CONF="$MC" brief_of "$H" | expect "the owner is asked once before the triage runs" "ask them once whether to run /vulyk-gc memory"
BRIEF_CONF="$MC" brief_of "$H" | expect "a no leaves a mark" "On a no, run bash scripts/memory-triage.sh --mark"
{ lines_of 159 10; printf 'mmmmmmmmm'; } > "$M/MEMORY.md"   # 160 lines, the last with no newline
BRIEF_CONF="$MC" brief_of "$H" | expect "a last line without a newline still counts" "memory triage (MEMORY.md 160 lines"
lines_of 80 256 > "$M/MEMORY.md"                           # 80 lines, 20480 bytes
BRIEF_CONF="$MC" brief_of "$H" | expect "memory triage due at 20480 bytes in fewer lines" "memory triage (MEMORY.md 80 lines, 20 KB of 200 lines / 25 KB)"
rm "$M/MEMORY.md"
BRIEF_CONF="$MC" brief_of "$H" | expect_absent "no MEMORY.md: nothing due" "memory triage"
H="$(hive mem-none)"
BRIEF_CONF="$MC" brief_of "$H" | expect_absent "no private memory dir: nothing due" "maintenance due"
# After a triage the signal waits for growth (plan delta, story 04): 20 lines or 2048 bytes past the mark.
HM="$(hive mem-mark)"; M="$(automem "$HM" "$MC")"; mkdir -p "$M"; MK="$HM/.claude/state/memory-triage.txt"
mark() { (cd "$HM" && CLAUDE_CONFIG_DIR="$MC" bash "$SRC/scripts/memory-triage.sh" --mark); }
lines_of 170 10 > "$M/MEMORY.md"
BRIEF_CONF="$MC" brief_of "$HM" | expect "no mark: due at the threshold" "memory triage (MEMORY.md 170 lines"
mark
expect_file() { if [ "$(cat "$MK" 2>/dev/null)" = "$2" ]; then ok "$1"; else bad "$1 - mark is '$(cat "$MK" 2>/dev/null)', expected '$2'"; fi; }
expect_file "--mark writes the lines and bytes" "170 1700"
BRIEF_CONF="$MC" brief_of "$HM" | expect_absent "a triaged size stays quiet until it grows" "memory triage"
lines_of 189 10 > "$M/MEMORY.md"
BRIEF_CONF="$MC" brief_of "$HM" | expect_absent "19 lines past the mark: quiet" "memory triage"
lines_of 190 10 > "$M/MEMORY.md"
BRIEF_CONF="$MC" brief_of "$HM" | expect "20 lines past the mark: due" "memory triage (MEMORY.md 190 lines"
{ lines_of 169 10; lines_of 1 2057; } > "$M/MEMORY.md"     # 170 lines, 1700 + 2047 bytes
BRIEF_CONF="$MC" brief_of "$HM" | expect_absent "2047 bytes past the mark: quiet" "memory triage"
{ lines_of 169 10; lines_of 1 2058; } > "$M/MEMORY.md"     # 170 lines, 1700 + 2048 bytes
BRIEF_CONF="$MC" brief_of "$HM" | expect "2048 bytes past the mark: due" "memory triage (MEMORY.md 170 lines"
rm "$M/MEMORY.md"
if mark >/dev/null 2>&1; then ok "--mark without MEMORY.md exits 0"; else bad "--mark without MEMORY.md failed"; fi
expect_file "... and leaves the mark alone" "170 1700"
got="$(cd "$H" && CLAUDE_CONFIG_DIR="$MC" bash "$SRC/scripts/memory-triage.sh" --dir)"
listed="$(cd "$H" && CLAUDE_CONFIG_DIR="$MC" bash "$SRC/scripts/memory-triage.sh")"
if [ "$got" = "$(automem "$H" "$MC")" ] && [ "$listed" = "no private memory: $got" ]; then
  ok "memory-triage.sh --dir prints the dir the listing reads"
else bad "memory-triage.sh --dir: got '$got', listing said '$listed'"; fi

# --- the bootstrap offer (next-circle-0-22-03) -----------------------------------------------------
echo "--- bootstrap offered once in an unfilled hive"
UNFILLED='| Stack | `<fill in>` |'; FILLED='| Stack | bash |'
profile() { # profile <hive> <file> <row>... - a constitution with a Profile block holding the rows
  local h="$1" f="$2"; shift 2
  { echo "# c"; echo "<!-- VULYK:PROFILE:START -->"; echo "| Field | Value |"; echo "|---|---|"
    printf '%s\n' "$@"; echo "<!-- VULYK:PROFILE:END -->"; } > "$h/$f"
}
H="$(hive boot-unfilled)"; profile "$H" CLAUDE.md "$UNFILLED"
brief_of "$H" | expect "a <fill in Profile gets the offer" "run /vulyk-bootstrap now"
brief_of "$H" | expect "the offer tells how a decline is recorded" "| Bootstrap | declined <date> |"
H="$(hive boot-crlf)"; profile "$H" CLAUDE.md "$UNFILLED"
awk '{ printf "%s\r\n", $0 }' "$H/CLAUDE.md" > "$H/crlf.tmp" && mv "$H/crlf.tmp" "$H/CLAUDE.md"
brief_of "$H" | expect "a CRLF constitution with <fill in gets the offer" "run /vulyk-bootstrap now"
H="$(hive boot-filled)"; profile "$H" CLAUDE.md "$FILLED"
brief_of "$H" | expect_absent "a filled Profile gets no offer" "vulyk-bootstrap now"
H="$(hive boot-outside)"; profile "$H" CLAUDE.md "$FILLED"; echo "see \`<fill in>\` in the template" >> "$H/CLAUDE.md"
brief_of "$H" | expect_absent "<fill in outside the Profile block is not an offer" "vulyk-bootstrap now"
H="$(hive boot-vulyk-repo)"; profile "$H" CLAUDE.md "$UNFILLED"; mkdir -p "$H/telemetry/inbox"
brief_of "$H" | expect_absent "VULYK's own repo (telemetry/inbox/) gets no offer" "vulyk-bootstrap now"
H="$(hive boot-declined)"; profile "$H" CLAUDE.md "$UNFILLED" '| Bootstrap | declined 2026-09-29 |'
brief_of "$H" | expect_absent "a Bootstrap declined row silences the offer" "vulyk-bootstrap now"
H="$(hive boot-vulyk-md)"; profile "$H" CLAUDE.md "$UNFILLED"; profile "$H" CLAUDE.vulyk.md "$FILLED"
brief_of "$H" | expect_absent "CLAUDE.vulyk.md is read before CLAUDE.md (filled: no offer)" "vulyk-bootstrap now"
H="$(hive boot-vulyk-md-open)"; profile "$H" CLAUDE.md "$FILLED"; profile "$H" CLAUDE.vulyk.md "$UNFILLED"
brief_of "$H" | expect "CLAUDE.vulyk.md is read before CLAUDE.md (unfilled: offer names it)" "Profile in CLAUDE.vulyk.md is not filled in"
brief_of "$SRC" | expect_absent "this repo's own brief has no offer" "vulyk-bootstrap now"

# --- the model profile first-run line (model-profiles-03) ------------------------------------------
echo "--- model profile offered while this machine has no choice"
MP_LINE="[VULYK] model profile not chosen: after the owner's current task, tell the owner and run /vulyk-models (Skill tool) once; until then sonnet-builds runs."
H="$(hive mp-unchosen)"; mkdir -p "$H/scripts"; cp "$SRC/scripts/model-profile.sh" "$H/scripts/"
export BRIEF_CONF="$T/mp-conf"
n="$(brief_of "$H" | grep -cxF -- "$MP_LINE")"
[ "$n" = 1 ] && ok "no profile file: the first-run line, exactly once" || bad "no profile file: first-run line printed $n times"
CLAUDE_CONFIG_DIR="$BRIEF_CONF" bash "$H/scripts/model-profile.sh" --set sonnet-builds > /dev/null
brief_of "$H" | expect_absent "after --set sonnet-builds: no first-run line" "model profile not chosen"
unset BRIEF_CONF
H="$(hive mp-noscript)"
brief_of "$H" | expect_absent "no model-profile.sh: nothing about models" "model profile"
H="$(hive mp-broken)"; mkdir -p "$H/scripts"; printf 'exit 3
' > "$H/scripts/model-profile.sh"
out="$(brief_of "$H")"; rc=$?
printf '%s' "$out" | expect_absent "a failing model-profile.sh: nothing about models" "model profile"
[ "$rc" = 0 ] && ok "a failing model-profile.sh: the hook still exits 0" || bad "a failing model-profile.sh: hook exit $rc"
H="$(hive mp-usage)"; mkdir -p "$H/scripts"; printf 'exit 2
' > "$H/scripts/model-profile.sh"
brief_of "$H" | expect_absent "a usage error (exit 2) is not 'not chosen'" "model profile"

# --- the litopys offer reads the user's settings too (ab-run-fixes-06) -----------------------------
# upgrade-findings-06 (D2): on 0.50.x the offer is quiet at all three scopes (litopys enabled in user, project or
# local settings), so the finding is not reproducible here; a brief from a hook older than 0.49 read the project files only.
echo "--- litopys offer: user, project, local and no scope"
LIT_LINE="litopys (session chronicle plugin) is not installed here"
brief_home() { echo '{}' | env -u CLAUDE_CONFIG_DIR HOME="$2" CLAUDE_PROJECT_DIR="$1" bash "$BRIEF_HOOK" 2>&1; }
H="$(hive lit-user)"; LH="$T/lit-home"; mkdir -p "$LH/.claude"
printf '{\n  "enabledPlugins": {\n    "litopys@litopys": true\n  }\n}\n' > "$LH/.claude/settings.json"
if brief_home "$H" "$LH" | grep -qF "$LIT_LINE"; then bad "brief: no litopys offer when the plugin is enabled at user scope"
else ok "brief: no litopys offer when the plugin is enabled at user scope"; fi
H="$(hive lit-project)"; LN="$T/lit-home-none"; mkdir -p "$LN/.claude" "$H/.claude"
printf '{"enabledPlugins":{"litopys@litopys":true}}\n' > "$H/.claude/settings.json"
brief_home "$H" "$LN" | expect_absent "brief: project scope still silences the offer" "$LIT_LINE"
H="$(hive lit-local)"; mkdir -p "$H/.claude"
printf '{\n  "enabledPlugins": {\n    "litopys@litopys": true\n  }\n}\n' > "$H/.claude/settings.local.json"
brief_home "$H" "$LN" | expect_absent "brief: local scope (settings.local.json) silences the offer" "$LIT_LINE"
H="$(hive lit-none)"
brief_home "$H" "$LN" | expect "brief: neither scope, the offer still shows" "$LIT_LINE"

# --- H1: SessionStart and PreCompact hooks stay silent for a subagent (audit-fixes-1113-05, ask 16) -------
# Every command .claude/settings.json wires on the two events runs in a scratch project, the way Claude Code
# runs it, with an input carrying agent_id: no output, exit 0, no file created or changed, no network call.
echo "--- H1: a subagent's SessionStart and PreCompact hooks print and write nothing"
SP="$T/h1-proj"; H1C="$T/h1-conf"; H1B="$T/h1-bin"; H1L="$T/h1-curl.log"
mkdir -p "$SP/.claude/hooks" "$SP/.claude/state/defects" "$SP/.claude/handoff" "$SP/scripts" \
  "$SP/memory/map" "$SP/memory/stats" "$SP/docs/specs" "$H1C" "$H1B" "$T/h1-home"
cp "$SRC"/.claude/hooks/*.sh "$SRC"/.claude/hooks/*.py "$SP/.claude/hooks/"
cp -R "$SRC/scripts/." "$SP/scripts/"
cp "$SRC/.claude/settings.json" "$SP/.claude/settings.json"
echo "# index" > "$SP/memory/memory.md"; echo "0.1.0" > "$SP/.claude/vulyk-version"
echo "seen" > "$SP/.claude/state/defects/inject-h1-s.txt"
echo "old" > "$SP/.claude/state/defects/inject-old.txt"
touch -t "$(date_shift -9 +%Y%m%d%H%M)" "$SP/.claude/state/defects/inject-old.txt"
printf -- '---\nhandoff: true\n---\n\n# Handoff\n\nH1-SEED\n' > "$SP/.claude/handoff/seed.md"
printf '{"path": "%s", "session_id": "prev", "reason": "sessionend-clear", "ts": %s}\n' \
  "$({ cygpath -w "$SP/.claude/handoff/seed.md" 2>/dev/null || printf '%s' "$SP/.claude/handoff/seed.md"; } | sed 's#\\#\\\\#g')" "$(date +%s)" > "$SP/.claude/handoff/index.json"
cat > "$H1B/curl" <<'SH'
#!/usr/bin/env bash
echo call >> "$H1_CURL_LOG"
printf '%s\n' '[{"name":"v99.0.0"}]'
SH
chmod +x "$H1B/curl" "$SP"/.claude/hooks/*.sh
"$PYBIN" -c '
import json, sys
s = json.load(sys.stdin)
for ev in ("SessionStart", "PreCompact"):
    for g in s.get("hooks", {}).get(ev, []):
        for h in g.get("hooks", []):
            print(ev + "\t" + h["command"])' < "$SRC/.claude/settings.json" | tr -d '\r' > "$T/h1-cmds"
h1_tree() { # every file and folder under the scratch project and the config dir, with its checksum
  ( cd "$T" && find h1-proj h1-conf -type d | LC_ALL=C sort && find h1-proj h1-conf -type f -exec cksum {} + | LC_ALL=C sort )
}
h1_run() { # h1_run <command> <payload> -> stdout in $T/h1.out, exit code in $T/h1.rc
  ( cd "$SP" && printf '%s' "$2" | env -u VULYK_YSK_OFFER -u VULYK_UPDATE_CHECK -u VULYK_TOP_MODEL_BRIEF \
      -u DISABLE_TELEMETRY -u CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC -u CLAUDE_CODE_USE_BEDROCK \
      -u CLAUDE_CODE_USE_VERTEX -u CLAUDE_CODE_USE_FOUNDRY -u VULYK_REPO \
      CLAUDE_PROJECT_DIR="$SP" CLAUDE_CONFIG_DIR="$H1C" HOME="$T/h1-home" USERPROFILE="$T/h1-home" \
      H1_CURL_LOG="$H1L" PATH="$H1B:$PATH" bash -c "$1" > "$T/h1.out" 2>/dev/null; echo "$?" > "$T/h1.rc" )
}
SUB='"agent_id":"a1b2c3d4","agent_type":"worker-code"'
if [ "$(grep -c '^SessionStart' "$T/h1-cmds")" -ge 6 ] && [ "$(grep -c '^PreCompact' "$T/h1-cmds")" -ge 1 ]; then
  ok "H1: the SessionStart and PreCompact commands come from .claude/settings.json ($(grep -c . "$T/h1-cmds"))"
else bad "H1: too few SessionStart/PreCompact commands read from .claude/settings.json:"; sed 's/^/        /' "$T/h1-cmds"; fi
h1_tree > "$T/h1-before"; : > "$H1L"
while IFS="$(printf '\t')" read -r ev cmd; do
  case "$ev" in
    SessionStart) payloads="startup clear" ;;
    *) payloads="auto" ;;
  esac
  for src in $payloads; do
    if [ "$ev" = SessionStart ]; then pl="{\"session_id\":\"h1-s\",\"hook_event_name\":\"SessionStart\",\"source\":\"$src\",$SUB}"
    else pl="{\"session_id\":\"h1-s\",\"hook_event_name\":\"PreCompact\",\"trigger\":\"$src\",$SUB}"; fi
    h1_run "$cmd" "$pl"
    name="${cmd##*/}"
    if [ "$(cat "$T/h1.rc")" = 0 ] && [ ! -s "$T/h1.out" ]; then
      ok "H1 $ev $name ($src) with agent_id: a subagent session start prints nothing"
    else
      bad "H1 $ev $name ($src) with agent_id: a subagent session start prints nothing - exit $(cat "$T/h1.rc"), stdout:"
      sed 's/^/        /' "$T/h1.out" | head -5
    fi
  done
done < "$T/h1-cmds"
h1_tree > "$T/h1-after"
if cmp -s "$T/h1-before" "$T/h1-after"; then
  ok "H1: a subagent session start prints nothing and writes nothing under the scratch project or the config dir"
else
  bad "H1: a subagent session start prints nothing - but it wrote files:"; diff "$T/h1-before" "$T/h1-after" | sed 's/^/        /' | head -12
fi
[ -s "$H1L" ] && bad "H1: a subagent session start prints nothing - but the update check called the network ($(grep -c . "$H1L"))" \
  || ok "H1: a subagent's update check makes no network call (curl stub)"
# The same inputs without agent_id behave as before.
SS="$(grep '^SessionStart' "$T/h1-cmds" | cut -f2-)"; PC="$(grep '^PreCompact' "$T/h1-cmds" | cut -f2-)"
pl_main='{"session_id":"h1-s","hook_event_name":"SessionStart","source":"startup"}'
h1_run "$(printf '%s\n' "$SS" | grep 'session-start-brief.sh')" "$pl_main"
expect "H1: without agent_id the brief still prints its line" "[VULYK]" < "$T/h1.out"
h1_run "$(printf '%s\n' "$SS" | grep 'vulyk-update-check.sh')" "$pl_main"
expect "H1: without agent_id the update check still reports a newer tag" "update available" < "$T/h1.out"
[ -s "$H1L" ] && ok "H1: ... through the network (curl stub called)" || bad "H1: the main session's update check made no call"
h1_run "$(printf '%s\n' "$SS" | grep 'ysk-offer.sh')" "$pl_main"
expect "H1: without agent_id the You should know offer still shows" "systemMessage" < "$T/h1.out"
h1_run "$(printf '%s\n' "$SS" | grep 'defects-inject.sh reset')" "$pl_main"
[ ! -e "$SP/.claude/state/defects/inject-old.txt" ] && ok "H1: without agent_id the reset still prunes a week-old inject file" \
  || bad "H1: the main session's reset left a 9-day-old inject file"
h1_run "$(printf '%s\n' "$SS" | grep 'handoff.sh')" '{"session_id":"h1-m","hook_event_name":"SessionStart","source":"clear"}'
expect "H1: without agent_id a /clear still restores the pending handoff" "H1-SEED" < "$T/h1.out"
# tails-1115-06 (T97): the PreCompact snapshot is retired - no command runs context-guard.sh; the handoff dump stays.
[ "$(printf '%s\n' "$PC" | grep -c 'context-guard.sh')" = 0 ] && ok "H1: no PreCompact command runs the retired snapshot (context-guard.sh)" \
  || bad "H1: a PreCompact command still runs the retired snapshot: $(printf '%s\n' "$PC" | grep 'context-guard.sh')"
[ "$(printf '%s\n' "$PC" | grep -c 'handoff.sh precompact')" = 1 ] && ok "H1: the PreCompact handoff entry stays, once" \
  || bad "H1: expected one PreCompact handoff.sh precompact command, got: $PC"

# --- the brief: no Python 3, a GitHub template copy, the skill counter (audit-fixes-1113-05, asks 6, 18, 2) -----
echo "--- brief: one line when no Python 3 answers"
NP="$T/nopy-bin"; mkdir -p "$NP"
for n in python3 python py; do printf '#!/bin/sh\nexit 49\n' > "$NP/$n"; chmod +x "$NP/$n"; done
H="$(hive nopy)"
out="$(echo '{}' | VULYK_PY= PATH="$NP:$PATH" CLAUDE_PROJECT_DIR="$H" CLAUDE_CONFIG_DIR="$T/conf-none" bash "$BRIEF_HOOK" 2>&1)"
n="$(printf '%s\n' "$out" | grep -c '^\[VULYK\] no Python 3 found')"
[ "$n" = 1 ] && ok "brief: stubs that fail to launch and no VULYK_PY print exactly one 'no Python 3 found' line" \
  || { bad "brief: expected one '[VULYK] no Python 3 found' line, got $n:"; printf '%s\n' "$out" | sed 's/^/        /'; }
brief_of "$H" | expect_absent "brief: with Python present, no Python line" "no Python 3 found"

echo "--- brief: a GitHub template copy is named once"
H="$(hive tpl-copy)"; : > "$H/install.sh"; mkdir -p "$H/docs/specs/auto-maintenance"
out="$(brief_of "$H")"
n="$(printf '%s\n' "$out" | grep -c 'template copy')"
[ "$n" = 1 ] && ok "brief: a template copy (VULYK's specs, install.sh, no stamp, no v* tag) gets one line" \
  || { bad "brief: expected one template-copy line, got $n:"; printf '%s\n' "$out" | sed 's/^/        /'; }
printf '%s' "$out" | expect "brief: the template-copy line points at the recovery text" "Started from the GitHub template"
H="$(hive tpl-hive)"; : > "$H/install.sh"; mkdir -p "$H/docs/specs/auto-maintenance" "$H/.claude"
echo "0.52.0" > "$H/.claude/vulyk-version"
brief_of "$H" | expect_absent "brief: a hive with .claude/vulyk-version is no template copy" "template copy"
H="$(hive tpl-clone)"; : > "$H/install.sh"; mkdir -p "$H/docs/specs/auto-maintenance"; git -C "$H" tag v0.1.0
brief_of "$H" | expect_absent "brief: a source clone with a v* tag is no template copy" "template copy"
for f in README.md docs/getting-started.md; do
  if grep -qiE 'Use this template|GitHub template \(button above\)|new project from template' "$SRC/$f"; then
    bad "$f still offers the GitHub template as a way to start: $(grep -niE 'Use this template|GitHub template \(button above\)|new project from template' "$SRC/$f" | head -2 | tr '\n' ' ')"
  else ok "$f no longer offers the GitHub template as a way to start"; fi
  grep -qF "Started from the GitHub template" "$SRC/$f" && ok "$f carries the recovery line for a template copy" \
    || bad "$f carries no recovery line ('Started from the GitHub template') for a template copy"
done

echo "--- skill counter: VULYK's own skills and vulyk-* commands only"
SK="$T/skc"; mkdir -p "$SK/.claude/skills/own-skill" "$SK/.claude/commands" "$SK/memory/stats"
echo "x" > "$SK/.claude/skills/own-skill/SKILL.md"; echo "x" > "$SK/.claude/commands/vulyk-plan.md"
printf '{"foreign-skill":{"count":4,"last_used":"2026-01-01"},"own-skill":{"count":1,"last_used":"2026-01-01"}}\n' \
  > "$SK/memory/stats/skills.json"
skill_ev() { printf '{"tool_name":"Skill","tool_input":{"skill":"%s"}}' "$1" |
  CLAUDE_PROJECT_DIR="$SK" bash "$SRC/.claude/hooks/skill-usage-counter.sh"; }
skill_ev own-skill; skill_ev vulyk-plan; skill_ev some-plugin:other; skill_ev other-skill
got="$("$PYBIN" -c '
import json, sys
d = json.load(sys.stdin)
print(" ".join("%s=%d" % (k, d[k]["count"]) for k in sorted(d)))' < "$SK/memory/stats/skills.json" 2>&1 | tr -d '\r')"
[ "$got" = "own-skill=2 vulyk-plan=1" ] && ok "skill counter: a project skill and a vulyk-* command counted, others not written, a foreign key dropped" \
  || bad "skill counter: expected 'own-skill=2 vulyk-plan=1', got '$got'"
grep -q "$(printf '\r')" "$SK/memory/stats/skills.json" && bad "skill counter: skills.json has CR bytes" \
  || ok "skill counter: skills.json stays LF"
[ -z "$(git -C "$SRC" ls-files memory/stats/skills.json)" ] && git -C "$SRC" check-ignore -q memory/stats/skills.json \
  && ok "memory/stats/skills.json is untracked and gitignored" || bad "memory/stats/skills.json is tracked or not ignored"
grep -q 'skills.json' "$BRIEF_HOOK" && bad "the brief still special-cases memory/stats/skills.json" \
  || ok "the brief no longer special-cases memory/stats/skills.json"

# --- the evolve ledger (auto-maintenance-03) ------------------------------------------------------
echo "--- evolve ledger"
EL="$SRC/scripts/evolve-ledger.py"
H="$(hive ledger)"
gitc() { git -C "$H" -c user.email=t@t -c user.name=t "$@"; }
led() { "$PYBIN" "$EL" "$H" "$@"; }
add() { led add --branch "$1" --component "${3:-rule}" --file "${4:-.claude/rules/x.md}" --hypothesis "$2" --evidence "n=3 specs" --bytes-delta -40; }
# changeset A: accepted (merged, then the branch deleted); B: rejected (deleted unmerged); C: pending
for b in A B C; do
  gitc branch "vulyk/evolve-$b"; gitc checkout -q "vulyk/evolve-$b"; gitc commit -q --allow-empty -m "change $b"
  tip="$(git -C "$H" rev-parse HEAD)"; gitc checkout -q main
  add "vulyk/evolve-$b" "hypothesis $b"; led run --branch "vulyk/evolve-$b" --commit "$tip" --proposals 1
done
gitc merge -q --ff-only vulyk/evolve-A; gitc branch -q -d vulyk/evolve-A; gitc branch -q -D vulyk/evolve-B
led pending | expect "pending lists the unmerged branch" "vulyk/evolve-C"
led pending | expect_absent "pending skips a merged or deleted branch" "vulyk/evolve-A"
out="$(led resolve --reason-for 'vulyk/evolve-B=owner: not now')"
printf '%s' "$out" | expect "resolve: merged then deleted = accepted" "accepted  vulyk/evolve-A"
printf '%s' "$out" | expect "resolve: deleted unmerged = rejected" "rejected  vulyk/evolve-B"
printf '%s' "$out" | expect "resolve: still on its branch = pending, no row" "pending   vulyk/evolve-C"
led resolve | expect_absent "resolve is idempotent: a decided branch is not re-decided" "vulyk/evolve-A"
out="$(led window)"
printf '%s' "$out" | expect "window shows the accepted proposal" "accepted rule"
printf '%s' "$out" | expect "window shows the rejection with its reason" "why: owner: not now"
printf '%s' "$out" | expect "window shows the pending one" "pending  rule"
for i in $(seq 1 45); do add "vulyk/evolve-N$i" "filler $i" doc docs/x.md; done
out="$(led window)"
printf '%s' "$out" | expect "past 40 proposals, an old rejection stays visible as one line" "rejected .claude/rules/x.md: hypothesis B"
printf '%s' "$out" | expect_absent "the window itself holds only the last 40" "hypothesis A |"
[ "$(led last)" = "$(grep '"kind":"run"' "$H/memory/stats/evolve.jsonl" | tail -1 | sed 's/.*"ts":"\([^"]*\)".*/\1/')" ] \
  && ok "last prints the newest run ts" || bad "last: '$(led last)'"
led add --branch b --component nonsense --file f --hypothesis h --evidence e --bytes-delta 0 2>&1 \
  | expect "an unknown component is refused" "component must be one of"
brief_of "$H" | expect "the brief reads the ledger the script writes (C still pending)" "vulyk/evolve-C waits for the owner's review"
H="$(hive ledger-clock)"; council_row "$H" "$(iso_ago 1)"
brief_of "$H" | expect "before the script's run row: evolve due" "evolve (never run"
led run --proposals 0
grep -q '"kind":"run"' "$H/memory/stats/evolve.jsonl" && ok "the script writes compact JSON the brief can grep" \
  || bad "run row not compact: $(tail -1 "$H/memory/stats/evolve.jsonl")"
brief_of "$H" | expect_absent "after the script's run row: evolve not due" "evolve ("

# --- tails-1115-10: a sidecar hive's constitution, control bytes, the map offer (T56, T27, T54, T59) ---------
echo "--- telemetry consent and the brief read the sidecar constitution (T56)"
sidecar() { # sidecar <hive> <CLAUDE.md text> <CLAUDE.vulyk.md row> - a hive whose VULYK constitution is the sidecar
  printf '%s\n' "$2" > "$1/CLAUDE.md"
  printf '# VULYK Constitution\n\n| Field | Value |\n|---|---|\n%s\n' "$3" > "$1/CLAUDE.vulyk.md"
}
consent_of() { VULYK_HIVE="$1" bash "$SRC/scripts/telemetry.sh" consent 2>&1; }
H="$(hive tel-sidecar)"; sidecar "$H" '@CLAUDE.vulyk.md' '| Telemetry | on - anonymized weekly bundle |'
[ "$(consent_of "$H")" = on ] && ok "telemetry consent: the consent line is read from the sidecar constitution" \
  || bad "telemetry consent: the consent line is read from the sidecar constitution - got '$(consent_of "$H")'"
H="$(hive tel-plain)"; printf '| Telemetry | on - x |\n' > "$H/CLAUDE.md"
[ "$(consent_of "$H")" = on ] && ok "telemetry consent: a plain hive's CLAUDE.md row still reads on" \
  || bad "telemetry consent: a plain hive's CLAUDE.md row - got '$(consent_of "$H")'"
H="$(hive tel-none)"
[ "$(consent_of "$H")" = off ] && ok "telemetry consent: no constitution at all reads off" \
  || bad "telemetry consent: no constitution - got '$(consent_of "$H")'"
H="$(hive lit-sidecar)"; sidecar "$H" '@CLAUDE.vulyk.md' '| Chronicle | none (declined 2026-11-01) |'
brief_of "$H" | expect_absent "brief: a litopys decline in the sidecar constitution is honoured (T59)" "litopys (session chronicle plugin)"
H="$(hive lit-plain-declined)"; printf '| Chronicle | none (declined 2026-11-01) |\n' > "$H/CLAUDE.md"
brief_of "$H" | expect_absent "brief: a litopys decline in a plain hive's CLAUDE.md still silences it" "litopys (session chronicle plugin)"
H="$(hive lit-sidecar-open)"; sidecar "$H" '@CLAUDE.vulyk.md' '| Stack | bash |'
brief_of "$H" | expect "brief: a sidecar hive with no decline still gets the litopys offer" "litopys (session chronicle plugin)"

echo "--- brief: a sidecar hive whose CLAUDE.md does not import it (T54)"
IMP="does not import CLAUDE.vulyk.md"
H="$(hive imp-missing)"; sidecar "$H" '# my project' '| Stack | bash |'
n="$(brief_of "$H" | grep -c "$IMP")"
[ "$n" = 1 ] && ok "brief: a sidecar without the import gets one line" || bad "brief: a sidecar without the import got $n lines naming '$IMP'"
H="$(hive imp-nofile)"; sidecar "$H" '' '| Stack | bash |'; rm -f "$H/CLAUDE.md"
n="$(brief_of "$H" | grep -c "$IMP")"
[ "$n" = 1 ] && ok "brief: a sidecar with no CLAUDE.md at all gets the line" || bad "brief: a sidecar with no CLAUDE.md got $n lines"
H="$(hive imp-ok)"; sidecar "$H" "$(printf '# my project\r\n@CLAUDE.vulyk.md\r')" '| Stack | bash |'
brief_of "$H" | expect_absent "brief: a sidecar imported by CLAUDE.md (CRLF) gets no import line" "$IMP"
H="$(hive imp-plain)"; printf '# VULYK Constitution\n' > "$H/CLAUDE.md"
brief_of "$H" | expect_absent "brief: a plain hive gets no import line" "$IMP"

echo "--- brief: no map yet when memory/map/ holds no slice (T59)"
H="$(hive map-readme)"; printf '# Map\n' > "$H/memory/map/README.md"
brief_of "$H" | expect "brief: a map folder with only a README is no map" "no map yet"
printf -- '- a slice\n' > "$H/memory/map/module.md"
brief_of "$H" | expect_absent "brief: one slice silences the no-map line" "no map yet"
brief_of "$H" | expect "brief: the slice is named, not the README" "newest map slice: module.md"

echo "--- telemetry record: every control byte is dropped from --spec, --story, --ref (T27)"
H="$(hive tel-ctl)"; TL="$H/memory/stats/anomalies.jsonl"
rec() { VULYK_HIVE="$H" bash "$SRC/scripts/telemetry.sh" record scope_breach 1 0 "$@" >/dev/null 2>&1; tail -n 1 "$TL" 2>/dev/null; }
fields() { printf '%s' "$1" | jq -r '[.spec, .story, .ref] | join("|")' 2>/dev/null | tr -d '\r'; }
line="$(rec --spec "a$(printf '\001')b" --story "c$(printf '\037')d" --ref "e$(printf '\033')f")"
if printf '%s' "$line" | jq -e . >/dev/null 2>&1; then ok "telemetry record: control bytes 0x01, 0x1f, 0x1b leave a JSON line"
else bad "telemetry record: a control byte broke the line: $(printf '%s' "$line" | od -c | head -3 | tr '\n' ' ')"; fi
[ "$(fields "$line")" = "ab|cd|ef" ] && ok "telemetry record: the control bytes are dropped, the rest kept" \
  || bad "telemetry record: control-byte fields are '$(fields "$line")', expected 'ab|cd|ef'"
line="$(rec --spec "$(printf 'g\th')" --story "$(printf 'i\rj')" --ref "$(printf 'k\nl')")"
[ "$(fields "$line")" = "gh|ij|kl" ] && ok "telemetry record: tab, CR and LF are still dropped" \
  || bad "telemetry record: tab/CR/LF fields are '$(fields "$line")', expected 'gh|ij|kl'"
line="$(rec --spec "tails-1115" --story "tails-1115-10" --ref "scope:x y")"
[ "$(fields "$line")" = "tails-1115|tails-1115-10|scope:x y" ] && ok "telemetry record: ordinary text is unchanged" \
  || bad "telemetry record: ordinary text became '$(fields "$line")'"

# --- a green build asks to ship (next-circle-0-22-02) ---------------------------------------------
echo "--- green terminal asks «Выпускаем?» and ships on yes"
green_of() { # every `- \`green\`:` bullet of a command, with its continuation lines
  tr -d '\r' < "$SRC/.claude/commands/$1.md" \
    | awk '/^ *- `green`:/{on=1; print; next} on && (/^ *- `/ || NF==0){on=0} on{print}'
}
for c in vulyk-build vulyk-review; do
  green_of "$c" | expect "$c green asks through AskUserQuestion" "AskUserQuestion"
  green_of "$c" | expect "$c green asks «Выпускаем?»" "Выпускаем?"
  green_of "$c" | expect "$c green runs vulyk-ship with the Skill tool on yes" "run \`vulyk-ship\` with the Skill"
  green_of "$c" | expect "$c green keeps the one-line fallback" "recommend \`/vulyk-ship\` in one line"
done
fi # upkeep

if part_on redact; then
# --- redact.sh masks the token shapes Hindsight's list names (hindsight-harvest-02) ----------------
echo "--- redact.sh and the handoff.py fallback mask nine more token shapes"
rep() { printf "%${1}s" '' | tr ' ' "$2"; }   # rep <n> <char> - samples are built, never literal tokens
TOKENS=(
  "telegram 123456789:AA$(rep 33 b)"
  "gitlab glpat-$(rep 20 c)"
  "npm npm_$(rep 36 d)"
  "pypi pypi-$(rep 60 e)"
  "huggingface hf_$(rep 34 f)"
  "groq gsk_$(rep 52 g)"
  "sendgrid SG.$(rep 22 h).$(rep 43 i)"
  "stripe s""k_live_$(rep 24 j)"
  "slack https://hooks.slack.com/services/T0$(rep 9 K)/B0$(rep 9 L)/$(rep 24 m)"
)
KEEP=(
  "git-sha $(rep 40 a)"
  "base64-word QmFzZTY0V29yZEhlcmVJc05vdEFTZWNyZXQ"
  "prose sk-learn"
  "timestamp 2026-09-29T20:30:00+03:00"
)
printf '' | sed -E -e 's|a|b|' >/dev/null 2>&1 && ok "this sed takes -E, so redact.sh does not degrade to cat" \
  || bad "sed -E is refused here: redact.sh passes text through unmasked"
for t in ${TOKENS[@]+"${TOKENS[@]}"}; do
  label="${t%% *}"; tok="${t#* }"
  out="$(printf 'note %s end\n' "$tok" | bash "$SRC/scripts/redact.sh")"
  case "$out" in *"$tok"*|*"[VULYK:REDACTED]"*"[VULYK:REDACTED]"*) bad "redact.sh $label: not masked once: $out" ;;
    *"[VULYK:REDACTED]"*) ok "redact.sh masks a $label token" ;; *) bad "redact.sh $label: no mask: $out" ;; esac
done
for t in ${KEEP[@]+"${KEEP[@]}"}; do
  label="${t%% *}"; s="${t#* }"
  out="$(printf 'note %s end\n' "$s" | bash "$SRC/scripts/redact.sh")"
  [ "$out" = "note $s end" ] && ok "redact.sh leaves a $label alone" || bad "redact.sh $label changed: $out"
done
printf '%s\n' ${TOKENS[@]+"${TOKENS[@]}"} ${KEEP[@]+"${KEEP[@]}"} > "$T/samples"
PYTHONIOENCODING=utf-8 "$PYBIN" - "$SRC/.claude/hooks/handoff.py" "$T/samples" "$T" <<'PY' > "$T/fallback"
import importlib.util, sys
spec = importlib.util.spec_from_file_location('handoff', sys.argv[1]); h = importlib.util.module_from_spec(spec)
spec.loader.exec_module(h)
for line in open(sys.argv[2], encoding='utf-8').read().splitlines():
    label, s = line.split(' ', 1)
    print(label, 'masked' if '[VULYK:REDACTED]' in h.redact_text(sys.argv[3], 'note ' + s + ' end') else 'kept')
PY
for t in ${TOKENS[@]+"${TOKENS[@]}"}; do expect "handoff.py fallback masks a ${t%% *} token" "${t%% *} masked" < "$T/fallback"; done
for t in ${KEEP[@]+"${KEEP[@]}"}; do expect "handoff.py fallback leaves a ${t%% *} alone" "${t%% *} kept" < "$T/fallback"; done

# --- redact.sh audit P9-04: shapes it missed, values it cut short, a key block that ate the rest -------
echo "--- redact.sh P9-04: Basic auth, camelCase and bare token keys, quoted values, PGP and broken key blocks"
M='[VULYK:REDACTED]'
redact_is() { # redact_is <label> <input> <expected output>
  local out; out="$(printf '%s\n' "$2" | bash "$SRC/scripts/redact.sh")"
  [ "$out" = "$3" ] && ok "redact.sh $1" || bad "redact.sh $1: got '$out', want '$3'"
}
b64="dXNlcjpw$(rep 16 Y)=="; val="$(rep 10 q)42$(rep 8 Z)"
redact_is "masks Authorization: Basic" "Authorization: Basic $b64" "Authorization: Basic $M"
redact_is "masks a quoted Authorization: token header" "-H \"Authorization: token $val\"" "-H \"Authorization: token $M\""
redact_is "masks a camelCase apiKey" "apiKey = \"$val\"" "apiKey = $M"
redact_is "masks a camelCase accessToken" "accessToken: $val" "accessToken: $M"
redact_is "masks a refresh_token" "refresh_token=$val" "refresh_token=$M"
redact_is "masks a bare TOKEN" "TOKEN=$val" "TOKEN=$M"
redact_is "masks an env-style GH_TOKEN" "export GH_TOKEN=$val" "export GH_TOKEN=$M"
redact_is "masks a JSON \"token\"" "{\"token\": \"$val\"}" "{\"token\": $M}"
redact_is "masks a Stripe test key" "key s""k_test_$(rep 24 j) end" "key $M end"
redact_is "masks a URL password holding a /" "postgres://app:pa/ss$val@db/x" "postgres://$M@db/x"
redact_is "masks the whole quoted value, not its first word" "password = \"correct horse battery staple\" tail" "password = $M tail"
redact_is "masks a single-quoted value with spaces" "secret='two words here' tail" "secret=$M tail"
redact_is "leaves a token counter alone" "max_tokens: 4096000, input_tokens=123456" "max_tokens: 4096000, input_tokens=123456"
redact_is "leaves token_budget and tokenizer alone" "token_budget=200000 tokenizer: cl100k_base" "token_budget=200000 tokenizer: cl100k_base"
redact_is "leaves prose about a token alone" "the token: see below, a token = \`agentType\`" "the token: see below, a token = \`agentType\`"
redact_is "leaves a code constant alone" "SLUG_TOKEN = re.compile(r'^[a-z]')" "SLUG_TOKEN = re.compile(r'^[a-z]')"
redact_is "leaves Rust paths alone" "let k = token::Identifier; secret::Name" "let k = token::Identifier; secret::Name"
redact_is "leaves a port before an @scope path alone" "https://registry.npmjs.org:443/@scope/pkg" "https://registry.npmjs.org:443/@scope/pkg"
redact_is "leaves prose Authorization and basic alone" "Authorization: required. Basic auth is a basic understanding" "Authorization: required. Basic auth is a basic understanding"
redact_is "leaves a git remote alone" "git@github.com:owner/repo.git ssh://git@host:22/x@y" "git@github.com:owner/repo.git ssh://git@host:22/x@y"
nl='
'
redact_is "masks a PGP private key block and keeps what follows" \
  "a${nl}-----BEGIN PGP PRIVATE KEY BLOCK-----${nl}Version: GnuPG v2${nl}${nl}lQOYBF$(rep 40 x)+/=${nl}=AbCd${nl}-----END PGP PRIVATE KEY BLOCK-----${nl}after" \
  "a${nl}${M}${nl}after"
redact_is "an unterminated PEM block ends at the first non-key line" \
  "a${nl}-----BEGIN RSA PRIVATE KEY-----${nl}MIIE$(rep 60 x)${nl}$(rep 20 y)==${nl}next line of prose${nl}more" \
  "a${nl}${M}${nl}next line of prose${nl}more"
redact_is "a one-line JSON key with its END on the BEGIN line does not open a block" \
  "{\"private_key\": \"-----BEGIN PRIVATE KEY-----\\nMIIE\\n-----END PRIVATE KEY-----\\n\",${nl}\"client_email\": \"x@y\"}" \
  "${M}${nl}\"client_email\": \"x@y\"}"

# --- redact.sh mass-audit S2: the secret names P9-04 left open, short quoted values; parity with handoff.py --
echo "--- redact.sh S2: PASS, PWD, PASSWD, a credentialed DSN, CREDENTIALS, short quoted values - and the fallback agrees"
S2=(
  "masks a bare PASS key (SMTP_PASS)|SMTP_PASS=$val|SMTP_PASS=$M"
  "masks a DB_PWD|DB_PWD=$val|DB_PWD=$M"
  "masks an exported PASSWD|export PASSWD=$val|export PASSWD=$M"
  "masks a DSN that carries a key|SENTRY_DSN=https://$(rep 32 k)@o1.ingest.example.io/1|SENTRY_DSN=$M"
  "masks a quoted two-word CREDENTIALS|CREDENTIALS=\"two words\" tail|CREDENTIALS=$M tail"
  "masks a JSON secret with spaces|\"secret\": \"my very long passphrase\", \"x\": 1|\"secret\": $M, \"x\": 1"
  "masks a short quoted value to its closing quote|secret=\"my pw\" tail|secret=$M tail"
  "leaves password_reset_count alone|password_reset_count=3|password_reset_count=3"
  "leaves pass in prose alone|we pass the test and bypass: nothing|we pass the test and bypass: nothing"
  "leaves pwd as a shell command alone|cd /tmp && pwd && ls|cd /tmp && pwd && ls"
  "leaves dsn_timeout alone|dsn_timeout=30 dsn_pool=connections|dsn_timeout=30 dsn_pool=connections"
  # redact-gaps: the names round 2 found open (passphrase, *_KEY, a session cookie, OTP, a bare ssh key, a userless URL)
  "masks a passphrase|passphrase=$val|passphrase=$M"
  "masks an ENCRYPTION_KEY|ENCRYPTION_KEY=$val|ENCRYPTION_KEY=$M"
  "masks a quoted exported SIGNING_KEY|export SIGNING_KEY=\"$val\"|export SIGNING_KEY=$M"
  "masks a camelCase appKey in JSON|\"appKey\": \"$val\"|\"appKey\": $M"
  "masks a SESSION_COOKIE|SESSION_COOKIE=$val|SESSION_COOKIE=$M"
  "masks a Cookie header value|Cookie: session=$val|Cookie: $M"
  "masks an OTP|OTP=482913|OTP=$M"
  "masks an SMS_OTP|SMS_OTP: 482913|SMS_OTP: $M"
  "masks a bare ssh-rsa key|ssh-rsa AAAAB3NzaC1yc2E$(rep 24 Q) me@host|ssh-rsa $M me@host"
  "masks a URL password with no user|redis://:$val@cache:6379/0|redis://$M@cache:6379/0"
  "leaves footprint alone|footprint=482913|footprint=482913"
  "leaves a short primary_key alone|primary_key=True foreign_key: users.id|primary_key=True foreign_key: users.id"
  "leaves prose about a key alone|the key: value here|the key: value here"
  # redact-gaps-2: the mask minors of the redact-gaps round-1 review, and *_AUTH
  "masks a whole Cookie header|Cookie: a=1; sessionid=$val|Cookie: $M"
  "masks a Set-Cookie header|Set-Cookie: sid=$val; Path=/; HttpOnly|Set-Cookie: $M"
  "masks a base64 APP_KEY|APP_KEY=base64:$val$val=|APP_KEY=$M"
  "masks a glued ENCRYPTIONKEY|ENCRYPTIONKEY=$val|ENCRYPTIONKEY=$M"
  "masks a dotted encryption.key|encryption.key=$val|encryption.key=$M"
  "masks a TOTP|TOTP=482913|TOTP=$M"
  "masks an otp_code|otp_code: 482913|otp_code: $M"
  "masks a TWILIO_AUTH|TWILIO_AUTH=$val|TWILIO_AUTH=$M"
  "leaves prose about cookies alone|cookie: see the policy|cookie: see the policy"
  "leaves an otpauth URL key alone|otpauth_url=otpauth://totp/x|otpauth_url=otpauth://totp/x"
  "leaves a short basic_auth alone|basic_auth=true oauth_flow=pkce|basic_auth=true oauth_flow=pkce"
  "leaves lower-case glued words alone|monkey business, turkey=sandwich_with_cheese|monkey business, turkey=sandwich_with_cheese"
)
: > "$T/s2-in"
for row in ${S2[@]+"${S2[@]}"}; do
  IFS='|' read -r label input want <<EOF
$row
EOF
  redact_is "$label" "$input" "$want"
  printf '%s\n' "$input" >> "$T/s2-in"
done
bash "$SRC/scripts/redact.sh" < "$T/s2-in" > "$T/s2-sh"
PYTHONIOENCODING=utf-8 "$PYBIN" - "$SRC/.claude/hooks/handoff.py" "$T/s2-in" "$T" <<'PY' > "$T/s2-py"
import importlib.util, sys
spec = importlib.util.spec_from_file_location('handoff', sys.argv[1]); h = importlib.util.module_from_spec(spec)
spec.loader.exec_module(h)
for line in open(sys.argv[2], encoding='utf-8').read().splitlines():
    print(h.redact_text(sys.argv[3], line))
PY
i=0
for row in ${S2[@]+"${S2[@]}"}; do
  i=$((i + 1)); label="${row%%|*}"
  sh_out="$(sed -n "${i}p" "$T/s2-sh" | tr -d '\r')"; py_out="$(sed -n "${i}p" "$T/s2-py" | tr -d '\r')"
  [ "$sh_out" = "$py_out" ] && ok "handoff.py fallback agrees with redact.sh: $label" \
    || bad "handoff.py fallback differs from redact.sh ($label): py '$py_out', sh '$sh_out'"
done

# --- redact.sh audit-fixes-1113: ru/uk keywords, command-argument credentials, service tokens; a failure is loud --
echo "--- redact.sh 1113: non-English keywords, argument credentials, token shapes - parity, and a failed filter withholds"
aws="$(rep 10 a)/$(rep 9 B)+$(rep 9 c)7$(rep 9 D)"   # 40 chars, the bare cloud secret-key shape
R13=(
  "masks a non-English secret keyword (пароль:)|пароль: $val|пароль: $M"
  "masks a Russian пароль=|пароль=$val|пароль=$M"
  "masks a Ukrainian гасло|Гасло: $val|Гасло: $M"
  "masks a токен|токен: $val|токен: $M"
  "masks a Russian секретный ключ|секретный ключ: $val|секретный ключ: $M"
  "masks a quoted Ukrainian секретний ключ|секретний ключ = \"two words\" tail|секретний ключ = $M tail"
  "masks a password stated in prose|the password is hunter2x tail|the password is $M tail"
  "masks a bare key=|key=$val|key=$M"
  "masks a pwd=|pwd=$val|pwd=$M"
  "masks a JSON pwd|{\"pwd\": \"short1\"}|{\"pwd\": $M}"
  "leaves ru/uk keywords with no value alone|пароль: см. хранилище, токен не нужен, гасло:|пароль: см. хранилище, токен не нужен, гасло:"
  "leaves prose about a password alone|the password is required and the secret is safe|the password is required and the secret is safe"
  "leaves the shell PWD alone|PWD=/home/user/project|PWD=/home/user/project"
  "leaves a short key= alone|key=short, sort key: name|key=short, sort key: name"
  "masks a curl -u password|curl -u alice:$val https://x|curl -u alice:$M https://x"
  "masks a --user password|curl --user 'alice:$val' x|curl --user 'alice:$M' x"
  "masks a glued mysql -p password|mysql -u root -p$val db|mysql -u root -p$M db"
  "masks an sshpass -p password|sshpass -p '$val' ssh host|sshpass -p $M ssh host"
  "masks a docker login -p password|docker login -u bob -p $val reg.io|docker login -u bob -p $M reg.io"
  "masks a --password argument|tool --password $val --x|tool --password $M --x"
  "leaves look-alike flags alone|docker run -u 1000:1000 -p 8080:80 x && mkdir -pv /tmp/a && ssh -p22 h|docker run -u 1000:1000 -p 8080:80 x && mkdir -pv /tmp/a && ssh -p22 h"
  "leaves --password-stdin and a prompting mysql -p alone|docker login --password-stdin -u bob r && mysql -u root -p db|docker login --password-stdin -u bob r && mysql -u root -p db"
  "masks an app-level chat token|note xa""pp-1-A0$(rep 8 B)-$(rep 12 c) end|note $M end"
  "masks a webhook signing secret|note wh""sec_$(rep 32 d) end|note $M end"
  "masks an OAuth client secret|note GOC""SPX-$(rep 28 e) end|note $M end"
  "masks a refresh token|note 1//0$(rep 40 f) end|note $M end"
  "masks an access token|note ya""29.$(rep 40 g) end|note $M end"
  "masks a shop admin token|note sh""pat_$(rep 32 a) end|note $M end"
  "masks an age secret key|note AGE-SECRET-""KEY-1$(rep 58 Q) end|note $M end"
  "masks a cloud API token|note do""p_v1_$(rep 64 a) end|note $M end"
  "masks a mail API key of any part length|note SG.$(rep 16 h).$(rep 20 i) end|note $M end"
  "masks a chat webhook|post https://discord.com/api/webhooks/123456789012345678/$(rep 68 j) now|post https://discord.com/api/webhooks/$M now"
  "masks an OAuth code in a URL|https://x.io/cb?code=4/0A$(rep 30 k)&state=1|https://x.io/cb?code=$M&state=1"
  "masks a bare cloud secret key|note $aws end|note $M end"
  "masks a URL password holding : and @|smtp://user:p@ss:word@mail.host:25|smtp://$M@mail.host:25"
  "leaves short prefix-sharing words alone|wh""sec_short xa""pp-short GOC""SPX-x ya""29.x 1//x shp""at_x ?code=200 $(rep 38 B)7|wh""sec_short xa""pp-short GOC""SPX-x ya""29.x 1//x shp""at_x ?code=200 $(rep 38 B)7"
  "masks only the URL password, not a later @ in the path|https://u:pw1@host/a@b|https://$M@host/a@b"
  "masks a lower-case set-cookie header|set-cookie: a=1; Path=/|set-cookie: $M"
  "masks a cookie after a valueless first token|Cookie: a; sessionid=$val|Cookie: $M"
  "masks a camelCase otpCode|otpCode=482913|otpCode=$M"
  "masks a bare AUTH|AUTH=$val|AUTH=$M"
  "masks a dotted x.auth|x.auth=$val|x.auth=$M"
  "leaves oauth and author words alone|oauth=pkce author: someone_long_name_here|oauth=pkce author: someone_long_name_here"
)
: > "$T/r13-in"
for row in ${R13[@]+"${R13[@]}"}; do
  IFS='|' read -r label input want <<EOF
$row
EOF
  redact_is "$label" "$input" "$want"
  printf '%s\n' "$input" >> "$T/r13-in"
done
bash "$SRC/scripts/redact.sh" < "$T/r13-in" > "$T/r13-sh"
PYTHONIOENCODING=utf-8 "$PYBIN" - "$SRC/.claude/hooks/handoff.py" "$T/r13-in" "$T" <<'PY' > "$T/r13-py"
import importlib.util, sys
spec = importlib.util.spec_from_file_location('handoff', sys.argv[1]); h = importlib.util.module_from_spec(spec)
spec.loader.exec_module(h)
for line in open(sys.argv[2], encoding='utf-8').read().splitlines():
    print(h.redact_text(sys.argv[3], line))
PY
i=0
for row in ${R13[@]+"${R13[@]}"}; do
  i=$((i + 1)); label="${row%%|*}"
  sh_out="$(sed -n "${i}p" "$T/r13-sh" | tr -d '\r')"; py_out="$(sed -n "${i}p" "$T/r13-py" | tr -d '\r')"
  [ "$sh_out" = "$py_out" ] && ok "handoff.py fallback agrees with redact.sh: $label" \
    || bad "handoff.py fallback differs from redact.sh ($label): py '$py_out', sh '$sh_out'"
done
# A filter tool that fails: the text is withheld, the failure is said and recorded.
for tool in sed awk; do
  mkdir -p "$T/stub-$tool" "$T/hive-$tool"; printf '#!/bin/sh\nexit 1\n' > "$T/stub-$tool/$tool"; chmod +x "$T/stub-$tool/$tool"
  out="$(printf 'secret=%s\n' "$val" | PATH="$T/stub-$tool:$PATH" VULYK_HIVE="$T/hive-$tool" bash "$SRC/scripts/redact.sh" 2>"$T/rd-err")"; rc=$?
  [ "$out" = "[VULYK:REDACT-FAILED]" ] && [ "$rc" = 1 ] && ok "redact.sh with a failing $tool prints only the failure mark, exit 1" \
    || bad "redact.sh with a failing $tool: rc $rc, stdout '$out'"
  head -n 1 "$T/rd-err" | grep -q '^redact: degraded:' && ok "redact.sh with a failing $tool says so on stderr" \
    || bad "redact.sh with a failing $tool: stderr '$(cat "$T/rd-err")'"
  grep -qF '"code":"redact_degraded"' "$T/hive-$tool/memory/stats/anomalies.jsonl" 2>/dev/null \
    && ok "redact.sh with a failing $tool records redact_degraded" || bad "redact.sh with a failing $tool: no redact_degraded record"
done
[ "$(bash "$SRC/scripts/telemetry.sh" enum | tail -n 1 | tr -d '\r')" = redact_degraded ] \
  && ok "telemetry.sh enum ends with redact_degraded" || bad "telemetry.sh enum does not end with redact_degraded"
grep -q '^| `redact_degraded` |' "$SRC/docs/telemetry.md" && ok "docs/telemetry.md lists redact_degraded" \
  || bad "docs/telemetry.md has no redact_degraded row"

# --- redact.sh leaves ordinary text alone; its callers refuse when it fails (audit-fixes-1113-11) -----------
echo "--- redact.sh 1113-11: the repo's briefs and journals pass unchanged, ordinary neighbours beside their secrets"
# Corpus: every tracked brief and journal is the owner's words or the cycle's record; a mask there rewrites them.
# CR is stripped first: the git blob is LF, and Git Bash's sed drops CR on its own.
corpus_bad=""; corpus_n=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  corpus_n=$((corpus_n + 1))
  tr -d '\r' < "$SRC/$f" > "$T/corpus-in"
  bash "$SRC/scripts/redact.sh" < "$T/corpus-in" > "$T/corpus-out" 2>/dev/null
  cmp -s "$T/corpus-in" "$T/corpus-out" || corpus_bad="$corpus_bad $f"
done <<EOF
$(git -C "$SRC" ls-files 'docs/specs/*/brief.md' 'docs/specs/*/journal.md')
EOF
[ "$corpus_n" -gt 0 ] && [ -z "$corpus_bad" ] && ok "a brief of the repo passes redact.sh unchanged ($corpus_n files)" \
  || bad "a brief of the repo passes redact.sh unchanged: $corpus_n files read, changed:${corpus_bad:- none read}"
ck="$(rep 10 a)7$(rep 9 B)$(rep 10 c)$(rep 10 D)"   # 40 chars: upper, lower and a digit - the cloud secret-key shape
R11=(
  "leaves a password length in prose alone|the password is 8 chars and the token was 2 days old|the password is 8 chars and the token was 2 days old"
  "masks a password stated in prose beside it|the secret was 8chars! long|the secret was $M long"
  "leaves a 40-letter identifier alone|call ReadTheConfigurationFileAndValidateItNow now|call ReadTheConfigurationFileAndValidateItNow now"
  "leaves a 40-char absolute path alone|open /home/someone/Projects/App2/src/mainfile now|open /home/someone/Projects/App2/src/mainfile now"
  "leaves a 40-char path with an extension alone|see docs/Specs/audit2/stories/one/storyfiles.md now|see docs/Specs/audit2/stories/one/storyfiles.md now"
  "masks a bare cloud key beside them|note $ck end|note $M end"
  "masks a bare cloud key ending a sentence|the key is $ck.|the key is $M."
  "leaves docker -u name:group alone, masks curl -u beside it|docker run -u app:staff img && podman exec -u www:www-data c sh && curl -u alice:$val https://x|docker run -u app:staff img && podman exec -u www:www-data c sh && curl -u alice:$M https://x"
  "masks every credential -p on a line and no other -p|sshpass -p $val ssh -p 2222 host && docker login -u bob -p $val reg.io && docker run -p 8080:80 x && mysql -u root -P 3306 -p$val -h db|sshpass -p $M ssh -p 2222 host && docker login -u bob -p $M reg.io && docker run -p 8080:80 x && mysql -u root -P 3306 -p$M -h db"
  "masks the login -p, not a later -p in the same command|docker login -p $val reg.io then docker run -p 8080:80 x|docker login -p $M reg.io then docker run -p 8080:80 x"
  "masks an sshpass -p after its -P prompt option|sshpass -P assword -p $val ssh -p 22 h|sshpass -P assword -p $M ssh -p 22 h"
)
: > "$T/r11-in"
for row in ${R11[@]+"${R11[@]}"}; do
  IFS='|' read -r label input want <<EOF
$row
EOF
  redact_is "$label" "$input" "$want"
  printf '%s\n' "$input" >> "$T/r11-in"
done
# Parity with the built-in pass alone (no redact.sh run first), so the fallback is judged on its own.
bash "$SRC/scripts/redact.sh" < "$T/r11-in" > "$T/r11-sh"
PYTHONIOENCODING=utf-8 "$PYBIN" - "$SRC/.claude/hooks/handoff.py" "$T/r11-in" <<'PY' > "$T/r11-py"
import importlib.util, sys
spec = importlib.util.spec_from_file_location('handoff', sys.argv[1]); h = importlib.util.module_from_spec(spec)
spec.loader.exec_module(h)
for line in open(sys.argv[2], encoding='utf-8').read().splitlines():
    print(h.redact_builtin(line))
PY
i=0
for row in ${R11[@]+"${R11[@]}"}; do
  i=$((i + 1)); label="${row%%|*}"
  sh_out="$(sed -n "${i}p" "$T/r11-sh" | tr -d '\r')"; py_out="$(sed -n "${i}p" "$T/r11-py" | tr -d '\r')"
  [ "$sh_out" = "$py_out" ] && ok "handoff.py built-in pass agrees with redact.sh: $label" \
    || bad "handoff.py built-in pass differs from redact.sh ($label): py '$py_out', sh '$sh_out'"
done
# Callers: a redact.sh that fails (exit 1, the marker on stdout) - no record is written, no marker becomes a note.
RF="$T/redact-fail"; mkdir -p "$RF/scripts" "$RF/docs/specs/demo"
cp "$SRC/scripts/lib.sh" "$SRC/scripts/state.sh" "$SRC/scripts/human-check.sh" "$SRC/scripts/acceptance-log.sh" "$RF/scripts/"
printf '#!/usr/bin/env bash\ncat >/dev/null\necho "[VULYK:REDACT-FAILED]"\necho "redact: degraded: stub" >&2\nexit 1\n' > "$RF/scripts/redact.sh"
cp "$SRC/templates/plan.md" "$RF/docs/specs/demo/plan.md"
printf -- '---\nstory: demo-01\nspec: demo\nstatus: done\nwave: 1\n---\n# S1\n' > "$RF/docs/specs/demo/demo-01-first.md"
( cd "$RF" && git init -q . && git config user.email t@t && git config user.name "Test Owner" && git config core.autocrlf false \
  && git add -A && git commit -qm init ) >/dev/null 2>&1
cp "$RF/docs/specs/demo/plan.md" "$T/rf-plan"
for tool in human-check acceptance-log; do
  ( cd "$RF" && bash "scripts/$tool.sh" docs/specs/demo ACCEPTED "looked at it" ) >"$T/rf-out" 2>&1; rc=$?
  [ "$rc" -ne 0 ] && ok "$tool.sh refuses when redact.sh fails (exit $rc)" || bad "$tool.sh exit 0 with a failing redact.sh: $(cat "$T/rf-out")"
  cmp -s "$RF/docs/specs/demo/plan.md" "$T/rf-plan" && ! ls "$RF/memory/stats/"*.jsonl >/dev/null 2>&1 \
    && ok "$tool.sh writes no record when redact.sh fails" || bad "$tool.sh wrote a record with a failing redact.sh"
  grep -q 'redact' "$T/rf-out" && ok "$tool.sh names redact.sh in its refusal" || bad "$tool.sh refusal does not name redact.sh: $(cat "$T/rf-out")"
done
# tails-1115-14 (ask 4): no redact.sh to run - the original case, the file missing; the neighbour, a directory in its
# place - refuses the same way: no record, the secret in the note written nowhere (journal.sh and ship-check.sh agree).
mv "$RF/scripts/redact.sh" "$T/rf-redact-stub"
for form in missing directory; do
  [ "$form" = directory ] && mkdir "$RF/scripts/redact.sh"
  for tool in human-check acceptance-log; do
    ( cd "$RF" && bash "scripts/$tool.sh" docs/specs/demo ACCEPTED "looked at it secret=$val" ) >"$T/rf-out" 2>&1; rc=$?
    [ "$rc" -ne 0 ] && ok "$tool.sh refuses with no redact.sh ($form, exit $rc)" || bad "$tool.sh exit 0 with no redact.sh ($form)"
    cmp -s "$RF/docs/specs/demo/plan.md" "$T/rf-plan" && ! ls "$RF/memory/stats/"*.jsonl >/dev/null 2>&1 \
      && ! grep -rqF -- "$val" "$RF/docs" "$RF/memory" 2>/dev/null \
      && ok "$tool.sh writes no record with no redact.sh ($form)" || bad "$tool.sh wrote a record with no redact.sh ($form)"
    grep -q 'redact' "$T/rf-out" && ok "$tool.sh names redact.sh when it is missing ($form)" \
      || bad "$tool.sh refusal does not name redact.sh ($form): $(cat "$T/rf-out")"
    cmp -s "$RF/docs/specs/demo/plan.md" "$T/rf-plan" || cp "$T/rf-plan" "$RF/docs/specs/demo/plan.md"
    rm -rf "$RF/memory"
  done
done
rmdir "$RF/scripts/redact.sh"; mv "$T/rf-redact-stub" "$RF/scripts/redact.sh"
sed -n '/^redact_note() {/,/^}/p' "$SRC/scripts/cycle.sh" > "$T/redact-note.sh"
note_out="$(HERE="$RF/scripts"; . "$T/redact-note.sh"; redact_note "secret=$val" 2>/dev/null)"
[ -s "$T/redact-note.sh" ] && case "$note_out" in *REDACT-FAILED*|*"$val"*) false ;; *) true ;; esac \
  && ok "cycle.sh redact_note passes on neither the marker nor the text when redact.sh fails" \
  || bad "cycle.sh redact_note with a failing redact.sh returned '$note_out'"
grep -q 'redact.sh always exits 0' "$SRC/scripts/cycle.sh" && bad "cycle.sh still says redact.sh always exits 0" \
  || ok "cycle.sh no longer says redact.sh always exits 0"

# --- redact.sh tails-1115-03: long flags, inflected ru/uk keywords, a Cyrillic value, -u/-a user:pass; parity --
echo "--- redact.sh tails-1115-03: argument flags, inflected keywords, non-ASCII values, more user:pass commands"
R15=(
  "masks a long token flag with a spaced value|curl --token $val https://x|curl --token $M https://x"
  "masks a long api-key flag|tool --api-key $val run|tool --api-key $M run"
  "masks a long client-secret flag|tool --client-secret $val|tool --client-secret $M"
  "masks a long secret flag|tool --secret $val --x|tool --secret $M --x"
  "masks a long auth-token flag|tool --auth-token $val|tool --auth-token $M"
  "masks a long access-token flag|tool --access-token '$val' x|tool --access-token $M x"
  "masks a long key flag|tool --key $val|tool --key $M"
  "leaves a long flag with no value alone|gh auth login --token --hostname x.io; tool --token \$TOKEN|gh auth login --token --hostname x.io; tool --token \$TOKEN"
  "leaves look-alike long flags alone|tool --token-file ./tok.txt --keyboard us-international-layout --keep-alive 1234567890123456|tool --token-file ./tok.txt --keyboard us-international-layout --keep-alive 1234567890123456"
  "leaves a short long-flag value and a key path alone|tool --key abc123 --secret short1 && curl --key /etc/ssl/private/client.key x|tool --key abc123 --secret short1 && curl --key /etc/ssl/private/client.key x"
  "masks an inflected Russian keyword in prose|нет пароля hunter2x тут|нет пароля $M тут"
  "masks an instrumental keyword in prose|вход паролем hunter2x|вход паролем $M"
  "masks an inflected keyword with a colon|токена: $val|токена: $M"
  "masks an inflected Ukrainian keyword with a colon|значення гасла: $val|значення гасла: $M"
  "leaves inflected keywords in prose alone|нет пароля, вход паролем из хранилища, токена нет, токенов 8 штук|нет пароля, вход паролем из хранилища, токена нет, токенов 8 штук"
  "leaves a keyword before an ordinary word alone|пароль сменили вчера, гасло змінено, токен устарел|пароль сменили вчера, гасло змінено, токен устарел"
  "masks a Cyrillic value with digits|пароль: Сонце2024|пароль: $M"
  "masks a Ukrainian Cyrillic value with digits|гасло: Київ2024x|гасло: $M"
  "leaves a Cyrillic word or a count after a keyword alone|пароль: Сонце, гасло: від адміна, токен: 8 символов|пароль: Сонце, гасло: від адміна, токен: 8 символов"
  "masks an ftp -u password|ftp -u admin:$val host|ftp -u admin:$M host"
  "masks an httpie -a password|httpie -a admin:$val GET x.io|httpie -a admin:$M GET x.io"
  "masks an http -a password|http -a admin:$val x.io|http -a admin:$M x.io"
  "leaves rsync -a host:path, ftp -u uid:gid and a prompting http -a alone|rsync -a backup:data/ /srv && ftp -u 1000:1000 h && http -a alice x.io|rsync -a backup:data/ /srv && ftp -u 1000:1000 h && http -a alice x.io"
)
: > "$T/r15-in"
for row in ${R15[@]+"${R15[@]}"}; do
  IFS='|' read -r label input want <<EOF
$row
EOF
  redact_is "$label" "$input" "$want"
  printf '%s\n' "$input" >> "$T/r15-in"
done
# Parity both ways: through redact_text (redact.sh, then the built-in pass) and the built-in pass alone.
bash "$SRC/scripts/redact.sh" < "$T/r15-in" > "$T/r15-sh"
PYTHONIOENCODING=utf-8 "$PYBIN" - "$SRC/.claude/hooks/handoff.py" "$T/r15-in" "$T" <<'PY' > "$T/r15-py"
import importlib.util, sys
spec = importlib.util.spec_from_file_location('handoff', sys.argv[1]); h = importlib.util.module_from_spec(spec)
spec.loader.exec_module(h)
for line in open(sys.argv[2], encoding='utf-8').read().splitlines():
    print(h.redact_text(sys.argv[3], line) + '\t' + h.redact_builtin(line))
PY
i=0
for row in ${R15[@]+"${R15[@]}"}; do
  i=$((i + 1)); label="${row%%|*}"
  sh_out="$(sed -n "${i}p" "$T/r15-sh" | tr -d '\r')"; py_line="$(sed -n "${i}p" "$T/r15-py" | tr -d '\r')"
  py_text="${py_line%%	*}"; py_bi="${py_line#*	}"
  [ "$sh_out" = "$py_text" ] && ok "handoff.py redact_text agrees with redact.sh: $label" \
    || bad "handoff.py redact_text differs from redact.sh ($label): py '$py_text', sh '$sh_out'"
  [ "$sh_out" = "$py_bi" ] && ok "handoff.py built-in pass agrees with redact.sh: $label" \
    || bad "handoff.py built-in pass differs from redact.sh ($label): py '$py_bi', sh '$sh_out'"
done
# Writers: with redact.sh missing or failing, journal.sh and ship-check.sh --record write nothing and exit non-zero.
JR="$T/journal-refuse"
for st in missing failing working; do
  mkdir -p "$JR/$st/scripts" "$JR/$st/spec"; cp "$SRC/scripts/journal.sh" "$JR/$st/scripts/"
  printf '# Journal: spec\n\n- earlier line\n' > "$JR/$st/spec/journal.md"
done
cp "$RF/scripts/redact.sh" "$JR/failing/scripts/redact.sh"; cp "$SRC/scripts/redact.sh" "$JR/working/scripts/redact.sh"
for st in missing failing; do
  cp "$JR/$st/spec/journal.md" "$T/jr-before"
  bash "$JR/$st/scripts/journal.sh" "$JR/$st/spec" 03-building "note secret=$val" next >"$T/jr-out" 2>&1; rc=$?
  [ "$rc" -ne 0 ] && cmp -s "$JR/$st/spec/journal.md" "$T/jr-before" && ! grep -q "$val" "$T/jr-out" \
    && ok "a journal line is refused when masking cannot run (redact.sh $st, exit $rc)" \
    || bad "a journal line is refused when masking cannot run (redact.sh $st): exit $rc, journal $(tail -n 1 "$JR/$st/spec/journal.md")"
done
bash "$JR/working/scripts/journal.sh" "$JR/working/spec" 03-building "note secret=$val" next >"$T/jr-out" 2>&1; rc=$?
[ "$rc" = 0 ] && tail -n 1 "$JR/working/spec/journal.md" | grep -qF "note secret=$M · next: next" \
  && ok "journal.sh with a working redact.sh writes the masked line" \
  || bad "journal.sh with a working redact.sh: exit $rc, last line $(tail -n 1 "$JR/working/spec/journal.md")"
SR="$T/ship-refuse"; mkdir -p "$SR/scripts" "$SR/docs/specs/demo"
cp "$SRC/scripts/lib.sh" "$SRC/scripts/ship-check.sh" "$SR/scripts/"
cp "$SRC/templates/plan.md" "$SR/docs/specs/demo/plan.md"
( cd "$SR" && git init -q . && git config user.email t@t && git config user.name "Test Owner" && git config core.autocrlf false \
  && git add -A && git commit -qm init ) >/dev/null 2>&1
cp "$SR/docs/specs/demo/plan.md" "$T/sr-plan"
for st in missing failing; do
  rm -f "$SR/scripts/redact.sh"; [ "$st" = failing ] && cp "$RF/scripts/redact.sh" "$SR/scripts/redact.sh"
  ( cd "$SR" && bash scripts/ship-check.sh --record docs/specs/demo v9.9.9 "note secret=$val" ) >"$T/sr-out" 2>&1; rc=$?
  [ "$rc" -ne 0 ] && cmp -s "$SR/docs/specs/demo/plan.md" "$T/sr-plan" && [ ! -e "$SR/memory/stats/ship.jsonl" ] \
    && ok "ship-check.sh --record refuses when masking cannot run (redact.sh $st, exit $rc)" \
    || bad "ship-check.sh --record with redact.sh $st: exit $rc, plan $(tail -n 1 "$SR/docs/specs/demo/plan.md")"
done
cp "$SRC/scripts/redact.sh" "$SR/scripts/redact.sh"; cp "$T/sr-plan" "$SR/docs/specs/demo/plan.md"
( cd "$SR" && bash scripts/ship-check.sh --record docs/specs/demo v9.9.9 "note secret=$val" ) >"$T/sr-out" 2>&1; rc=$?
[ "$rc" = 0 ] && grep -qF "**Shipped:** v9.9.9" "$SR/docs/specs/demo/plan.md" && grep -qF "note secret=$M" "$SR/docs/specs/demo/plan.md" \
  && ! grep -q "$val" "$SR/docs/specs/demo/plan.md" && ok "ship-check.sh --record with a working redact.sh writes the masked line" \
  || bad "ship-check.sh --record with a working redact.sh: exit $rc, $(cat "$T/sr-out")"

# --- /vulyk-gc commits the index alone (hindsight-harvest-03; tails-1115-10: the learnings chain is retired) ------
echo "--- /vulyk-gc commit line commits the memory index, nothing in memory/learnings/"
GC_LINE="$(tr -d '\r' < "$SRC/.claude/commands/vulyk-gc.md" | sed -n "s/^\`\(git add ':(icase)memory\/memory\.md'.*\)\`$/\1/p")"
[ -n "$GC_LINE" ] && ok "vulyk-gc.md carries the index commit line" || bad "no index commit line in vulyk-gc.md"
gc_case() { # gc_case <dir> [index name] - runs the line in a repo with a changed index and a changed learning
  local g="$T/$1" idx="memory/${2:-memory.md}"; mkdir -p "$g/memory/learnings" && cd "$g" || return 1
  git init -q -b main . && git config user.name t && git config user.email t@t && git config core.autocrlf false
  printf '# index\n' > "$idx"; printf -- '- an old lesson\n' > memory/learnings/CONSOLIDATED.md
  git add -A && git commit -q -m base
  printf -- '- a pointer gc added\n' >> "$idx"; printf -- '- an edit nobody asked gc for\n' >> memory/learnings/CONSOLIDATED.md
  bash -c "$GC_LINE" >/dev/null 2>&1; echo "commits=$(git rev-list --count HEAD)"
  echo "committed: $(git diff --name-only HEAD~1 HEAD 2>/dev/null | paste -sd' ' -)"
  echo "left: $(git diff --name-only | paste -sd' ' -)"
  cd "$SRC" || return 1
}
gc_case gc-lower > "$T/gc-lower.out"
expect "the index memory.md is committed" "commits=2" < "$T/gc-lower.out"
expect "only the index is committed" "committed: memory/memory.md" < "$T/gc-lower.out"
expect "a learnings file is left as it is" "left: memory/learnings/CONSOLIDATED.md" < "$T/gc-lower.out"
gc_case gc-upper MEMORY.md > "$T/gc-upper.out"   # a hive whose index is memory/MEMORY.md failed every gc run
expect "an index named MEMORY.md: committed" "commits=2" < "$T/gc-upper.out"
expect "an index named MEMORY.md: committed alone" "committed: memory/MEMORY.md" < "$T/gc-upper.out"

echo "--- /vulyk-handoff runs from any folder of the hive (handoff-cwd)"
# Claude Code keeps a Bash `cd` that stays inside the project, so `dump` can run from any subfolder,
# with no CLAUDE_PROJECT_DIR. The transcript sits in a folder whose name is NOT the hive's slug (a long
# path's slug is shortened), so only the session id can find it. HOME and USERPROFILE both point at a
# temp home: Python on Windows reads USERPROFILE, never HOME.
W() { cygpath -w "$1" 2>/dev/null || printf '%s' "$1"; }
H="$T/hive"; TH="$T/handoff-home"; SID="0000aaaa-1111-2222-3333-444455556666"
mkdir -p "$H/.claude/hooks" "$H/sub/deep" "$TH/.claude/projects/a-shortened-slug-1a2b3c"
cp "$SRC/.claude/hooks/handoff.py" "$SRC/.claude/hooks/handoff.sh" "$H/.claude/hooks/"
printf '%s\n' \
  '{"type":"user","message":{"role":"user","content":"marker prompt"},"timestamp":"2026-10-13T10:00:00Z"}' \
  '{"type":"assistant","message":{"role":"assistant","model":"claude-test","content":[{"type":"text","text":"hi"}],"usage":{"input_tokens":1234,"output_tokens":0}},"timestamp":"2026-10-13T10:00:01Z"}' \
  > "$TH/.claude/projects/a-shortened-slug-1a2b3c/$SID.jsonl"
# A decoy: another session's transcript under the hive's own slug - the one a lookup by folder finds.
HSLUG="$("$PYBIN" -c 'import re, sys; print(re.sub(r"[^A-Za-z0-9]", "-", sys.argv[1]))' "$(W "$H")")"
mkdir -p "$TH/.claude/projects/$HSLUG"
printf '%s\n' '{"type":"assistant","message":{"role":"assistant","model":"claude-test","content":[],"usage":{"input_tokens":777,"output_tokens":0}},"timestamp":"2026-10-13T11:00:00Z"}' \
  > "$TH/.claude/projects/$HSLUG/decoy-session.jsonl"
dump_from_deep() { ( cd "$H/sub/deep" && env -u CLAUDE_PROJECT_DIR -u CLAUDE_CONFIG_DIR HOME="$(W "$TH")" USERPROFILE="$(W "$TH")" \
  bash "$H/.claude/hooks/handoff.sh" dump "$@" 2>&1 ) ; }
dump_from_deep "$SID" > "$T/dump-sid"
echo "files=$(ls "$H/.claude/handoff/"*.md 2>/dev/null | wc -l | tr -d ' ')" > "$T/dump-files"
expect "dump from a subfolder writes into the hive's .claude/handoff/" "files=1" < "$T/dump-files"
[ -d "$H/sub/deep/.claude" ] && echo "subfolder got a .claude/" > "$T/dump-sub" || echo "no .claude/ in the subfolder" > "$T/dump-sub"
expect "dump from a subfolder leaves the subfolder alone" "no .claude/ in the subfolder" < "$T/dump-sub"
expect "dump <session-id> reads that session's transcript, whatever its folder's slug" "context_tokens=1234" < "$T/dump-sid"
cat "$H/.claude/handoff/"*.md > "$T/dump-doc" 2>/dev/null
expect "the handoff names the session it was given" "session_id: $SID" < "$T/dump-doc"
rm -rf "$H/.claude/handoff"
dump_from_deep > "$T/dump-nosid"
expect "dump without a session id looks the transcript up under the hive's slug, not the cwd's" "context_tokens=777" < "$T/dump-nosid"
grep -h '^cwd: ' "$H/.claude/handoff/"*.md > "$T/dump-cwd" 2>/dev/null
expect "dump without a session id writes into the hive" "cwd: " < "$T/dump-cwd"
expect_absent "dump without a session id records the hive, not the subfolder, as its cwd" "deep" < "$T/dump-cwd"
dump_from_deep "ffff0000-no-such-session" > "$T/dump-miss"
expect "an unknown session id never borrows another session's transcript" "context_tokens=0" < "$T/dump-miss"
PYTHONIOENCODING=utf-8 "$PYBIN" - "$(W "$H/.claude/hooks/handoff.py")" "$(W "$T/clash")" <<'PY' > "$T/clash-out" 2>&1
import importlib.util, os, sys
spec = importlib.util.spec_from_file_location("handoff", sys.argv[1]); h = importlib.util.module_from_spec(spec)
spec.loader.exec_module(h)
os.makedirs(sys.argv[2])
a = h.create_unique(sys.argv[2], "20261013-100000-0000aaaa", "first")
b = h.create_unique(sys.argv[2], "20261013-100000-0000aaaa", "second")
print("distinct" if a != b else "same path", "|", open(a).read(), "|", os.path.basename(b))
PY
expect "a taken handoff name gets a new file beside it" "distinct | first | 20261013-100000-0000aaaa-2.md" < "$T/clash-out"

echo "--- no command or skill injection names its script relative to the cwd (Law 6 card)"
for f in "$SRC"/.claude/commands/*.md $(find "$SRC/.claude/skills" -name SKILL.md 2>/dev/null); do
  bash "$SRC/scripts/injection-check.sh" "$f" > "$T/inj" 2>&1 && echo "clean" >> "$T/inj"
  expect "injection-check: ${f#"$SRC"/}" "clean" < "$T/inj"
done
bash "$SRC/scripts/injection-check.sh" "$SRC/docs/defects/command-injection-follows-cwd.md" > "$T/inj-card" 2>&1 && echo "clean" >> "$T/inj-card"
expect "injection-check ignores a non-command file that quotes the bad form" "clean" < "$T/inj-card"
PYTHONIOENCODING=utf-8 "$PYBIN" - "$SRC/.claude/commands/vulyk-handoff.md" <<'PY' > "$T/grants" 2>&1
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
grants = re.findall(r"Bash\((.+?):\*\)", re.search(r"^allowed-tools:(.*)$", text, re.M).group(1))
for cmd in re.findall(r"(?:^|(?<=\s))!`([^`]+)`", text):
    print(("granted" if any(cmd.startswith(g) for g in grants) else "NOT GRANTED"), cmd)
PY
expect "vulyk-handoff: the state view injection has its allowed-tools prefix" 'granted bash "${CLAUDE_PROJECT_DIR}/scripts/state.sh"' < "$T/grants"
expect "vulyk-handoff: the dump injection has its allowed-tools prefix" 'granted bash "${CLAUDE_PROJECT_DIR}/.claude/hooks/handoff.sh" dump' < "$T/grants"
expect_absent "vulyk-handoff: no injection lacks a grant" "NOT GRANTED" < "$T/grants"

echo "--- memory-triage.sh lists private memory and writes nothing (rules-tree ask 11)"
MC="$T/mtcfg"; MSLUG="$(git -C "$SRC" rev-parse --show-toplevel | LC_ALL=C.UTF-8 sed 's#[^0-9A-Za-z]#-#g')" # memory-triage.sh's own rule
MD="$MC/projects/$MSLUG/memory"; mkdir -p "$MD"
printf -- '---\nname: a\nmetadata:\n  type: feedback\n---\n\n# Push only after the remote check\nbody\n' > "$MD/fb-push.md"
printf '# A loose note\n\ntype: not-frontmatter\n' > "$MD/loose.md"
printf -- '- [Push](fb-push.md) - push rule\n- [Loose](loose.md) - a note\n- [Other](other.md) - kept\n' > "$MD/MEMORY.md"
( cd "$SRC" && CLAUDE_CONFIG_DIR="$MC" bash scripts/memory-triage.sh ) > "$T/mt" 2>&1
expect "memory-triage: a feedback file lists with its type and heading" "$(printf 'fb-push.md\tfeedback\tPush only after the remote check')" < "$T/mt"
expect "memory-triage: a file without frontmatter lists with type -" "$(printf 'loose.md\t-\tA loose note')" < "$T/mt"
expect_absent "memory-triage: MEMORY.md is not a row" "MEMORY.md" < "$T/mt"
[ "$(grep -c . "$T/mt")" -eq 2 ] && ok "memory-triage: exactly two rows" || bad "memory-triage: expected 2 rows, got $(cat "$T/mt")"
bash "$SRC/scripts/memory-triage.sh" "$T/no-such-dir" > "$T/mt-absent" 2>&1; echo "exit=$?" >> "$T/mt-absent"
expect "memory-triage: an absent dir says so" "no private memory: $T/no-such-dir" < "$T/mt-absent"
expect "memory-triage: an absent dir exits 0" "exit=0" < "$T/mt-absent"
bash "$SRC/scripts/memory-triage.sh" --index-lines "$MD/MEMORY.md" "$MD/fb-push.md" loose.md > "$T/mt-idx" 2>&1
expect "memory-triage --index-lines: names the moved file's line" "[Push](fb-push.md)" < "$T/mt-idx"
expect "memory-triage --index-lines: takes a bare file name" "[Loose](loose.md)" < "$T/mt-idx"
expect_absent "memory-triage --index-lines: leaves other lines out" "other.md" < "$T/mt-idx"
[ "$(ls "$MD" | wc -l | tr -d ' ')" -eq 3 ] && ok "memory-triage: writes nothing" || bad "memory-triage wrote into $MD: $(ls "$MD")"

echo "--- prompt-check.sh: agent and command prose against the scripts and agents it names (docs/specs/prompt-check)"
# Each case runs the checker of a fixture copy, whose root is the copy: the repo's own prompts, scripts and
# architecture page, with one drift seeded. The repo itself must hold none.
bash "$SRC/scripts/prompt-check.sh" > "$T/pc-repo" 2>&1; echo "exit=$?;" >> "$T/pc-repo"
expect "prompt-check: today's repo exits 0" "exit=0;" < "$T/pc-repo"
expect "prompt-check: today's repo prints ok" "prompt-check: ok (" < "$T/pc-repo"
PCB="$T/pcbase"; mkdir -p "$PCB/.claude" "$PCB/docs"
cp -r "$SRC/.claude/agents" "$SRC/.claude/commands" "$PCB/.claude/"
cp -r "$SRC/templates" "$SRC/scripts" "$PCB/"
cp "$SRC/docs/architecture.md" "$PCB/docs/"; cp "$SRC/install.sh" "$PCB/"
pc_case() { # pc_case <name> - a fresh fixture copy at $T/pc-<name>, its path in PCD
  PCD="$T/pc-$1"; rm -rf "$PCD"; cp -r "$PCB" "$PCD"
}
pc_run() { # pc_run [args...] - run the fixture's checker into $T/pc-out, exit code appended
  bash "$PCD/scripts/prompt-check.sh" "$@" > "$T/pc-out" 2>&1; echo "exit=$?;" >> "$T/pc-out"
}
pc_bites() { # pc_bites <label> <rule> - the seeded drift exits 1 naming the rule
  expect "prompt-check: $1 exits 1" "exit=1;" < "$T/pc-out"
  expect "prompt-check: $1 names rule $2" ": $2: " < "$T/pc-out"
}
CMDF=".claude/commands/vulyk-plan.md"
pc_case nomaxturns; sed_inplace '/^maxTurns:/d' "$PCD/.claude/agents/drone-scout.md"; pc_run
pc_bites "an agent without maxTurns" frontmatter
pc_case omitbad; sed_inplace 's/^omitClaudeMd: true/omitClaudeMd: yes/' "$PCD/.claude/agents/drone-scout.md"; pc_run
pc_bites "omitClaudeMd: yes" omit-claude-md
pc_case omitrule; sed_inplace 's/^maxTurns:/omitClaudeMd: true\
maxTurns:/' "$PCD/.claude/agents/lead-review.md"; pc_run
pc_bites "omitClaudeMd: true on lead-review, which keeps the constitution" omit-claude-md
pc_case verb; printf '\nRun `bash scripts/cycle.sh no-such-verb docs/specs/x`.\n' >> "$PCD/$CMDF"; pc_run
pc_bites "a backticked cycle.sh verb the dispatcher lacks" verb
pc_case flag; printf '\nRun `bash scripts/cycle.sh close-story <file> --no-such-flag`.\n' >> "$PCD/$CMDF"; pc_run
pc_bites "a backticked flag the script lacks" flag
pc_case commentflag; printf '# --ghost-flag was removed\n' >> "$PCD/scripts/cycle.sh"
printf '\nRun `bash scripts/cycle.sh close-story <file> --ghost-flag`.\n' >> "$PCD/$CMDF"; pc_run
pc_bites "a flag left only in a comment line" flag
pc_case script; printf '\nRun `bash scripts/gone.sh --x`.\n' >> "$PCD/.claude/agents/drone-docs.md"; pc_run
pc_bites "a backticked scripts/ path that does not exist" script
pc_case nofile; rm "$PCD/.claude/agents/drone-coverage.md"; pc_run
pc_bites "a telemetry.sh AGENTS name without its file" telemetry
pc_case ghost; printf '\nDispatch `drone-ghost` here.\n' >> "$PCD/$CMDF"; pc_run
pc_bites "a backticked agent name without a file" agent
pc_case neighbours
printf '\ncycle.sh no-such-verb in prose, the `worker` field, `cycle.sh <verb>`, `council-sonnet` (retired), `npm.sh --x`.\n' >> "$PCD/$CMDF"
pc_run
expect "prompt-check: neighbour forms (prose, a field, a placeholder, a retired agent, a host tool) exit 0" "exit=0;" < "$T/pc-out"
printf -- '---\nname: my-helper\ndescription: a hive agent\ntools: Read\nmodel: sonnet\nmaxTurns: 5\n---\n\nBody.\n' > "$T/my-helper.md"
pc_case framework; cp "$T/my-helper.md" "$PCD/.claude/agents/"; pc_run
pc_bites "an agent file outside AGENTS in the VULYK repo" telemetry
pc_case hive; cp "$T/my-helper.md" "$PCD/.claude/agents/"; echo 0.42.0 > "$PCD/.claude/vulyk-version"; pc_run
expect "prompt-check: a hive's own agent exits 0" "exit=0;" < "$T/pc-out"
expect "prompt-check: a hive's own agent is a warn line" "prompt-check: warn " < "$T/pc-out"
pc_case touched; printf '\nRun `bash scripts/cycle.sh close-story <file> --no-such-flag`.\n' >> "$PCD/$CMDF"
pc_run --touched README.md
expect "prompt-check --touched: a finding outside the touched files exits 0" "exit=0;" < "$T/pc-out"
expect "prompt-check --touched: it prints as warn" "prompt-check: warn $CMDF" < "$T/pc-out"
pc_run --touched "$CMDF"
expect "prompt-check --touched: a finding in a touched prompt exits 1" "exit=1;" < "$T/pc-out"
pc_run --touched scripts/cycle.sh
expect "prompt-check --touched: a finding naming a touched script exits 1" "exit=1;" < "$T/pc-out"
pc_run --touched "./$CMDF"
expect "prompt-check --touched: a ./-prefixed touched prompt still owns its finding (round 1 major 1)" "exit=1;" < "$T/pc-out"
pc_run --touched .claude/commands/
expect "prompt-check --touched: a directory entry owns the findings beneath it (P9-17)" "exit=1;" < "$T/pc-out"
pc_case hivedel; rm "$PCD/.claude/agents/worker-test.md"; echo 0.42.0 > "$PCD/.claude/vulyk-version"; pc_run
expect "prompt-check: a framework agent a hive deleted exits 0 (upgrade keeps host deletions)" "exit=0;" < "$T/pc-out"
expect "prompt-check: the hive deletion is a warn line" "prompt-check: warn scripts/telemetry.sh:1: telemetry: AGENTS names worker-test" < "$T/pc-out"
pc_case agentspan; printf '\nDispatch it with `Agent drone-ghost` here.\n' >> "$PCD/$CMDF"; pc_run
pc_bites "an agent name inside a longer span (post-043-tails)" agent
pc_case noverbs; sed_inplace 's/^case "\$VERB" in/case "$CMD" in/' "$PCD/scripts/cycle.sh"; pc_run
expect "prompt-check: a cycle.sh without a verb dispatcher exits 0" "exit=0;" < "$T/pc-out"
grep -c '^prompt-check: warn scripts/cycle.sh:1: verb: ' "$T/pc-out" > "$T/pc-nv" 2>&1
expect "prompt-check: a cycle.sh without a verb dispatcher is one warn line, not a silent skip" "1" < "$T/pc-nv"
# tails-1115-05 (T65, cc-facts F4 confirmed): an agent that may spawn subagents nests them; the tool is Agent, Task its old name
for spawn in 'Read, Agent' 'Task, Read' 'Read, Agent(worker-code)' '[Read, Task]'; do
  pc_case spawn; sed_inplace "s/^tools: .*/tools: $spawn/" "$PCD/.claude/agents/drone-scout.md"; pc_run
  pc_bites "an agent whose tools hold the spawning tool ($spawn)" tools
done
pc_case nospawn; sed_inplace 's/^tools: .*/tools: Read, TaskList, AgentOutput/' "$PCD/.claude/agents/drone-scout.md"; pc_run
expect "prompt-check: tool names that only start with Agent or Task exit 0" "exit=0;" < "$T/pc-out"

echo "--- human-check.sh --show: code paths first, spec paperwork after, inside the one cap (tails-1115-05, T16)"
(
  mkdir -p "$T/hshow" && cd "$T/hshow" || exit 1
  git init -q -b main . && git config user.email t@t && git config user.name t && git config core.autocrlf false
  mkdir -p scripts docs/specs/s src && cp "$SRC"/scripts/lib.sh "$SRC"/scripts/human-check.sh "$SRC"/scripts/redact.sh scripts/
  printf 'v1\n' > src/app.txt && printf 'plan\n' > docs/specs/s/plan.md && git add -A && git commit -qm base
  git checkout -q -b vulyk/s
  i=0; while [ "$i" -lt 400 ]; do i=$((i + 1)); echo "paper $i"; done > docs/specs/s/notes.md
  git add -A && git commit -qm paper
  git checkout -q -b vulyk/paper-only   # the neighbour: only paperwork changed
  bash scripts/human-check.sh --show docs/specs/s > "$T/hshow-paper"
  base="$(git merge-base main HEAD)"
  { echo "human-check: s - the change from $(printf '%s' "$base" | cut -c1-7) to HEAD"
    git -c core.quotePath=false diff --stat "$base" HEAD
    git -c core.quotePath=false diff "$base" HEAD | head -n 300
    echo "... $(( $(git diff "$base" HEAD | wc -l) - 300 )) more lines cut; the rest: git diff $(printf '%s' "$base" | cut -c1-7) HEAD"
  } > "$T/hshow-today"
  git checkout -q vulyk/s
  i=0; while [ "$i" -lt 20 ]; do i=$((i + 1)); echo "code $i"; done > src/app.txt
  git add -A && git commit -qm code
  bash scripts/human-check.sh --show docs/specs/s > "$T/hshow-out"
)
expect "human-check --show: 400 paperwork lines leave the 20-line code diff whole" "+code 20" < "$T/hshow-out"
awk '/^\+code 1$/ { c = NR } /^\+paper 1$/ { p = NR } END { exit !(c && p && c < p) }' "$T/hshow-out" \
  && ok "human-check --show: the code diff comes before the paperwork" || bad "human-check --show: the code diff comes before the paperwork"
expect "human-check --show: paperwork past the cap is cut" "more lines cut; the rest: git diff" < "$T/hshow-out"
nb="$(awk '/^diff --git / { on = 1 } on && !/^\.\.\. / { n++ } END { print n + 0 }' "$T/hshow-out")"
[ "$nb" -eq 300 ] && ok "human-check --show: code and paperwork share the 300-line cap" || bad "human-check --show: $nb diff lines, want 300 inside the cap"
cmp -s "$T/hshow-paper" "$T/hshow-today" && ok "human-check --show: only paperwork changed prints as today" \
  || bad "human-check --show: only paperwork changed prints as today - diff: $(diff "$T/hshow-today" "$T/hshow-paper" | head -n 5)"

echo "--- handoff.sh: a python3 that is a stub (the Windows Store alias, exit 49) is passed over (post-043-tails)"
FB="$T/fakepy"; mkdir -p "$FB"
printf '#!/bin/sh\necho "Python was not found; run without arguments to install from the Microsoft Store" >&2\nexit 49\n' > "$FB/python3"
chmod +x "$FB/python3"
( cd "$T" && PATH="$FB:$PATH" bash "$SRC/.claude/hooks/handoff.sh" status > /dev/null 2>&1; echo "exit=$?;" ) > "$T/hs-stub"
expect "handoff.sh status with a stub python3 first on PATH reaches a working Python or exits 0" "exit=0;" < "$T/hs-stub"
# A real python3 starts once per call: telemetry.sh's scan bounds its python starts through this hook (round 1 major 1).
CB="$T/countpy"; mkdir -p "$CB"; : > "$T/hs-calls"
printf '#!/usr/bin/env bash\nprintf "py\\n" >> "%s"\nexec "%s" "$@"\n' "$T/hs-calls" "$PYBIN" > "$CB/python3"
chmod +x "$CB/python3"
( cd "$T" && PATH="$CB:$PATH" bash "$SRC/.claude/hooks/handoff.sh" status > /dev/null 2>&1 )
echo "starts=$(grep -c . "$T/hs-calls");" > "$T/hs-count"
expect "handoff.sh starts a working python3 once per call, never a probe beside it" "starts=1;" < "$T/hs-count"
fi # redact

if part_on guards; then
echo "--- portability-check.sh: the static gate of card shell-needs-gnu-or-bash4 (cross-platform-05)"
# Each case is one line in a temp file under `set -u`: `hit <rule>` must exit 1 naming the rule, `ok -` exit 0.
# The cases live in a heredoc, whose body the gate does not read, so this file stays clean on the tree run.
PG="$SRC/scripts/portability-check.sh"
pg_run() { bash "$PG" "$@" < /dev/null > "$T/pg-out" 2>&1; echo "exit=$?;" >> "$T/pg-out"; }
( cd "$SRC" && pg_run )
expect "portability-check: the tree exits 0" "exit=0;" < "$T/pg-out"
expect "portability-check: the tree prints its ok line" "portability-check: ok (" < "$T/pg-out"
n=0
while read -r want rule code; do
  n=$((n + 1)); printf '#!/usr/bin/env bash\nset -u\n%s\n' "$code" > "$T/pg-$n.sh"; pg_run "$T/pg-$n.sh"
  if [ "$want" = hit ]; then
    expect "portability-check: $code exits 1" "exit=1;" < "$T/pg-out"
    expect "portability-check: $code names rule $rule" ": $rule: " < "$T/pg-out"
  else expect "portability-check: $code is not a hit" "exit=0;" < "$T/pg-out"; fi
done <<'CASES'
hit bash4 declare -A seen
hit bash4 lower="${name,,}"
hit bash4 make 2>&1 |& tee build.log
hit sed-i sed -i 's/^\*\*Approved:\*\* <.*/**Approved:** owner, 2026-09-12/' docs/specs/status1/plan.md
hit sed-i sed -E -i 's/a+/b/' "$f"
hit sed-bre printf '%s' "$first" | sed -n 's/^VERDICT: \(PASS\|BLOCK\).*/\1/p'
hit sed-bre v="$(sed 's/ \+$//' "$f")"
hit grep-P grep -oP '(?<=id: )\w+' "$f"
hit grep-P grep --perl-regexp 'x' "$f"
hit stat-c stat -c %s "$f"
hit stat-c m="$(stat --format=%Y "$f")"
hit date-d date -d "$ts" +%s
hit date-d now="$(date -u -Iseconds)"
hit pct-n ns="$(date +%s%N)"
hit pct-n t="$(date +%H:%M:%S.%3N)"
hit readlink-f readlink -f "$0"
hit readlink-f dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
hit find-printf find . -type f -printf '%T@ %p\n'
hit find-printf find "$d" -name '*.md' -fprintf out '%p'
hit xargs-r git ls-files | xargs -r rm
hit xargs-r ls | xargs --no-run-if-empty -n1 echo
hit timeout timeout 30 bash x.sh
hit timeout out="$(gtimeout -k 5 10 cmd)"
hit python python -m py_compile .claude/hooks/*.py
hit python PY="$(command -v python3 || command -v python)"
hit python if python3 -c 'print(1)'; then :; fi
hit array FETCHED="$(curl -fsSL -m 4 "${AUTH[@]}" "$url")"
hit array for f in "${files[*]}"; do :; done
ok - ts="$(date -u -d "$x" +%s 2>/dev/null || date -ju -f '%Y-%m-%d' "$x" +%s)"
ok - sed -i.bak 's/a/b/' "$f" && rm -f "$f.bak"
ok - sed -E 's/(a|b)+/c/' "$f"
ok - n="${#a[@]}"
ok - for x in "$@"; do :; done
ok - for x in ${a[@]+"${a[@]}"}; do :; done
ok - for p in python3 python py; do :; done
ok - bash scripts/py.sh -m py_compile x.py
ok - sed -i 's/a/b/' "$f" # portable: this line runs only on the GNU CI image
hit paste-s echo "$(comm -13 "$T/tree.before" "$T/tree.after" | paste -sd'|')"
hit paste-s grep x "$LOG" | paste -s -d ' ' > out.txt
hit case-in-subst x="$(case "$b" in plan.md|brief.md) echo y ;; esac)"
hit case-in-subst x=$(case "$b" in *.md) echo y ;; esac)
ok - echo "$(comm -13 "$T/tree.before" "$T/tree.after" | paste -sd'|' -)"
ok - paste -s -d, list.txt
ok - x="$(case "$b" in (plan.md|brief.md) echo y ;; esac)"
ok - case "$b" in plan.md|brief.md) continue ;; esac
ok - x="$(f "$b")"; case "$x" in a) echo y ;; esac
hit sort-V ls -d "$HOME"/c/*/bin/x 2>/dev/null | sort -rV
hit sort-V v="$(printf '%s\n' "$a" "$b" | sort -t. --version-sort | tail -n 1)"
ok - printf '%s\n' "$a" | sort -t. -k1,1n -k2,2n -k3,3n | tail -n 1
ok - echo "the newest without sort -V"
CASES
echo "--- portability-check.sh: every hit line ends with its rule's fix (tails-1115-05, T6, T90)"
bash "$PG" --rules < /dev/null > "$T/pg-rules" 2>&1; echo "exit=$?;" >> "$T/pg-rules"
expect "portability-check --rules exits 0" "exit=0;" < "$T/pg-rules"
nr=0; nf=0
while IFS= read -r rl; do
  case "$rl" in exit=*) continue ;; esac
  nr=$((nr + 1)); fx="${rl#*: }"
  if [ "$fx" = "$rl" ] || [ -z "$(printf '%s' "$fx" | tr -d '[:space:]')" ]; then nf=$((nf + 1)); bad "portability-check: rule '${rl%%:*}' has no fix text"; fi
done < "$T/pg-rules"
[ "$nr" -ge 17 ] && ok "portability-check --rules lists every rule ($nr)" || bad "portability-check --rules lists $nr rules, want 17 or more"
[ "$nf" -eq 0 ] && ok "portability-check: every rule has a fix text" || bad "portability-check: $nf rule(s) without a fix text"
grep -qx 'sort-V: .*scripts/version-order.sh.*' "$T/pg-rules" && ok "portability-check: the sort-V rule names scripts/version-order.sh" \
  || bad "portability-check: the sort-V rule names scripts/version-order.sh"
pg_run "$SRC/docs/defects/shell-needs-gnu-or-bash4.sed-i.fixture"
expect "portability-check: the card's sed-i fixture is a sed-i hit" ": sed-i: " < "$T/pg-out"
grep -q ': sed-i: .* - fix: .*sed_inplace' "$T/pg-out" && ok "portability-check: the sed-i hit line ends with the sed_inplace fix" \
  || bad "portability-check: the sed-i hit line ends with the sed_inplace fix - got: $(cat "$T/pg-out")"
printf '#!/usr/bin/env bash\ntimeout 30 bash x.sh\n' > "$T/pg-to.sh"; pg_run "$T/pg-to.sh"
grep -q ': timeout: .* - fix: .*run_capped' "$T/pg-out" && ok "portability-check: a bare timeout hit line ends with the run_capped fix" \
  || bad "portability-check: a bare timeout hit line ends with the run_capped fix - got: $(cat "$T/pg-out")"
n_hit="$(grep -c '^portability-check: .*:[0-9]*: ' "$T/pg-out")"; n_fix="$(grep -c ' - fix: ' "$T/pg-out")"
[ "$n_hit" -gt 0 ] && [ "$n_hit" = "$n_fix" ] && ok "portability-check: each hit line carries a fix" \
  || bad "portability-check: $n_hit hit line(s), $n_fix with a fix"
for fx in sort-v sort-v-neighbour; do
  pg_run "$SRC/docs/defects/shell-needs-gnu-or-bash4.$fx.fixture"
  expect "portability-check: the card's $fx fixture is a sort-V hit" ": sort-V: " < "$T/pg-out"
done
cat > "$T/pg-case.sh" <<'EOF'
#!/usr/bin/env bash
ALL_QUOTES="$(for story in "$SPEC"/*.md; do
  base="$(basename "$story")"
  case "$base" in plan.md|brief.md) continue ;; esac
  awk '/^>/ { print }' "$story" 2>/dev/null
done | grep -v '^$')"
EOF
pg_run "$T/pg-case.sh"
expect "portability-check: trace-check's case inside a multi-line \$( ) is a hit on its line" "pg-case.sh:4: case-in-subst: " < "$T/pg-out"
cat > "$T/pg-case-ok.sh" <<'EOF'
#!/usr/bin/env bash
ALL_QUOTES="$(for story in "$SPEC"/*.md; do
  base="$(basename "$story")"
  case "$base" in
    (plan.md|brief.md) continue ;;
    (*) : ;;
  esac
  awk '/^>/ { print }' "$story" 2>/dev/null
done | grep -v '^$')"
case "$ALL_QUOTES" in
  *x*) echo y ;;
esac
EOF
pg_run "$T/pg-case-ok.sh"
expect "portability-check: the (pat) form inside a multi-line \$( ) is not a hit" "exit=0;" < "$T/pg-out"
cat > "$T/pg-hd.sh" <<'EOF'
#!/usr/bin/env bash
plan="$(PYTHONIOENCODING=utf-8 "$PY" - "$MODE" "$DIR" <<'PY'
print("it's")
PY
)" || exit 2
EOF
pg_run "$T/pg-hd.sh"
expect "portability-check: defects-check's heredoc inside a multi-line \$( ) exits 1" "exit=1;" < "$T/pg-out"
expect "portability-check: defects-check's heredoc inside a multi-line \$( ) names rule heredoc-in-subst" "pg-hd.sh:2: heredoc-in-subst: " < "$T/pg-out"
cat > "$T/pg-hd-ok.sh" <<'EOF'
#!/usr/bin/env bash
read_cards() {
  PYTHONIOENCODING=utf-8 "$PY" - "$MODE" "$DIR" <<'PY'
print("it's")
PY
}
plan="$(read_cards)" || exit 2
"$PY" - "$(pwd)" <<'PY'
print(1)
PY
EOF
pg_run "$T/pg-hd-ok.sh"
expect "portability-check: the heredoc in a function called from \$( ) is not a hit" "exit=0;" < "$T/pg-out"
cat > "$T/pg-allow.sh" <<'EOF'
sed -i 's/a/b/' "$f" # portable: GNU CI image only
EOF
pg_run "$T/pg-allow.sh"
expect "portability-check: a # portable: line is counted as allowed" "1 allowed)" < "$T/pg-out"
cat > "$T/pg-heredoc.sh" <<'EOF'
#!/usr/bin/env bash
set -u
"$VULYK_PY" - "$f" <<'PY'
print(1) |& 2
PY
echo done
EOF
pg_run "$T/pg-heredoc.sh"
expect "portability-check: |& inside a Python heredoc body is not a hit" "exit=0;" < "$T/pg-out"
cat >> "$T/pg-heredoc.sh" <<'EOF'
make |& tee log
EOF
pg_run "$T/pg-heredoc.sh"
expect "portability-check: the line after the heredoc is read again" ": bash4: " < "$T/pg-out"
cat > "$T/pg-prose.md" <<'EOF'
A step that hangs is stopped by a timeout of 540 s; then python reports it.
EOF
pg_run "$T/pg-prose.md"
expect "portability-check: timeout in an .md sentence outside backticks is not a hit" "exit=0;" < "$T/pg-out"
cat > "$T/pg-cell.md" <<'EOF'
| Python | `python -m py_compile .claude/hooks/*.py` |
EOF
pg_run "$T/pg-cell.md"
expect "portability-check: the bare python cell of CLAUDE.md:76 is a hit" ": python: " < "$T/pg-out"
pg_run "$T/pg-no-such-file.sh"
expect "portability-check: a missing named file exits 2" "exit=2;" < "$T/pg-out"
mkdir -p "$T/pg-empty" && git -C "$T/pg-empty" init -q
( cd "$T/pg-empty" && pg_run )
expect "portability-check: nothing to scan exits 2" "exit=2;" < "$T/pg-out"

# --- the git guard (uncommitted-work-guard-01) ----------------------------------------------------
GUARD="$SRC/.claude/hooks/git-guard.sh"
GG="$T/gg"
mkdir -p "$GG/memory/stats" && git -C "$GG" init -q
echo '{}' > "$GG/memory/stats/skills.json"
git -C "$GG" add -A && git -C "$GG" -c user.email=t@t -c user.name=t commit -q -m init
cat > "$T/guard-in.py" <<'PY'
import json, sys
d = {"hook_event_name": "PreToolUse", "session_id": "s", "tool_name": sys.argv[1],
     "tool_input": {"command": sys.argv[2]}, "cwd": sys.argv[4]}
if sys.argv[3]:
    d["agent_id"] = sys.argv[3]; d["agent_type"] = "worker-code"
sys.stdout.write(json.dumps(d))
PY
guard() { # guard <tool> <command> [<agent_id>] - the hook's output for one call made in $GG
  ( cd "$GG" && "$PYBIN" "$T/guard-in.py" "$1" "$2" "${3:-}" "$(pwd -W 2>/dev/null || pwd)" | bash "$GUARD" 2>&1 )
}
silent() { # silent <label> - ok when stdin is empty: no decision, no noise
  local out; out="$(cat)"
  if [ -z "$out" ]; then ok "$1"; else bad "$1 - expected no output, got:"; printf '%s\n' "$out" | sed 's/^/        /'; fi
}

echo "--- git guard: a subagent"
for c in "git stash" "git stash -u" "git stash drop" "git stash clear" "git checkout -- f" "git checkout ." \
         "git checkout -f" "git checkout main -- f" "git restore f" "git reset --hard" "git clean -fd" \
         "git switch -f main" "git switch --discard-changes main" "git branch -D x" "git worktree remove --force ../w" \
         "cd sub && git stash" "VAR=1 git stash" "git -C sub reset --hard"; do
  guard Bash "$c" a1 | expect "git-guard: a subagent's $c is denied" '"deny"'
done
guard Bash 'git stash "unclosed' a1 | expect "git-guard: a subagent's unreadable git call is denied" '"deny"'
guard PowerShell "git stash" a1 | expect "git-guard: a subagent's PowerShell git stash is denied" '"deny"'
for c in "git stash list" "git stash show" "git checkout -b x" "git status" "git reset --soft HEAD~1" \
         "git reset HEAD f" "git clean -n" "git clean -fdn" "git restore --staged f" "git log --oneline" \
         "echo git stash" "bash scripts/cycle.sh advance x" "ls -la"; do
  guard Bash "$c" a1 | silent "git-guard: a subagent's $c passes"
done

echo "--- git guard: the main session"
echo '{"n":1}' > "$GG/memory/stats/skills.json"
out="$(guard Bash "git checkout -- memory/stats/skills.json")"
printf '%s' "$out" | expect "git-guard: the original case (checkout over a dirty skills.json) is denied" '"deny"'
printf '%s' "$out" | expect "git-guard: the refusal names the dirty file" "memory/stats/skills.json"
printf '%s' "$out" | expect "git-guard: the refusal gives the safe path" "your own terminal"
guard PowerShell "git stash" | expect "git-guard: main-session git stash over a dirty file is denied" '"deny"'
guard Bash "git reset --hard" | expect "git-guard: main-session reset --hard over a dirty file is denied" '"deny"'
guard Bash "git checkout -- other.txt" | silent "git-guard: a checkout of a clean path passes"
guard Bash "git branch -D x" | silent "git-guard: main-session branch -D passes (not the tree)"
guard Bash 'git stash "unclosed' | silent "git-guard: a main-session unreadable call fails open"
echo x > "$GG/new.txt"
out="$(guard Bash "git clean -fd")"
printf '%s' "$out" | expect "git-guard: clean -f over an untracked file is denied" '"deny"'
printf '%s' "$out" | expect "git-guard: the refusal names the untracked file" "new.txt"
git -C "$GG" add -A && git -C "$GG" -c user.email=t@t -c user.name=t commit -q -m clean
guard Bash "git checkout -- memory/stats/skills.json" | silent "git-guard: the neighbour (same checkout, clean tree) passes"
for c in "git stash" "git reset --hard" "git clean -fd" "git checkout ."; do
  guard Bash "$c" | silent "git-guard: main-session $c on a clean tree passes"
done
for i in 1 2 3 4 5 6 7 8 9 10 11 12; do echo x > "$GG/u$i.txt"; done
guard Bash "git clean -f" | expect "git-guard: the list stops at 10, then +N more" "+2 more"
rm -f "$GG"/u*.txt

echo "--- git guard: a cd before the git verb, heredoc bodies (round 1 repair)"
mkdir -p "$GG/sub" "$GG/docs" && echo a > "$GG/sub/f" && echo a > "$GG/docs/d.md"
git -C "$GG" add -A && git -C "$GG" -c user.email=t@t -c user.name=t commit -q -m sub
echo b > "$GG/sub/f"
out="$(guard Bash "cd sub && git checkout -- f")"
printf '%s' "$out" | expect "git-guard: a main-session cd then checkout over a dirty file is denied" '"deny"'
printf '%s' "$out" | expect "git-guard: the cd refusal names the file from the root" "sub/f"
guard PowerShell "Set-Location sub; git checkout -- f" | expect "git-guard: Set-Location then checkout is denied" '"deny"'
guard Bash "cd docs && git checkout ." | silent "git-guard: cd into a clean folder, then checkout . passes"
guard Bash "cd sub && cd .. && cd docs && git checkout ." | silent "git-guard: chained cds are followed"
guard Bash "$(printf "cat > r.md <<'EOF'\nthen cd x && git checkout -- f\nEOF")" a1 \
  | silent "git-guard: a heredoc body is text, not a command"
guard Bash "$(printf "cat > r.md <<EOF\ngit stash\nEOF\ngit stash")" a1 \
  | expect "git-guard: a git verb after the heredoc still counts" '"deny"'
guard Bash 'cat <<<"git stash" && git status' a1 | silent "git-guard: a here-string is not a heredoc start"

echo "--- git guard: a cd it cannot follow checks the whole tree (round 2 repair)"
for c in 'cd "$(git rev-parse --show-toplevel)" && git checkout .' 'cd $SOMEWHERE && git reset --hard' \
         'cd /no/such/folder && git reset --hard' 'cd - && git checkout .' 'pushd sub && popd && git checkout .' \
         'Set-Location $env:TEMP; git checkout .'; do
  guard Bash "$c" | expect "git-guard: an unresolvable cd target still checks the tree: $c" "sub/f"
done
mkdir -p "$T/norepo"; NR="$(cd "$T/norepo" && pwd -W 2>/dev/null || pwd)"
guard Bash "cd $NR && git reset --hard" \
  | expect "git-guard: a cd into a folder git status cannot read still checks the tree (Git Bash /tmp on Windows)" "sub/f"
guard Bash "$(printf 'echo "x <<b"\ngit reset --hard')" a1 | expect "git-guard: <<b inside quotes is no heredoc" '"deny"'
HOOKS="$(grep -o '\.claude/hooks/[A-Za-z0-9._-]*\.sh' "$SRC/.claude/settings.json" | sort -u)"
[ -n "$HOOKS" ] || bad "hook bits: settings.json names no .sh hook (a missing list is a failure)"
for h in $HOOKS; do
  case "$(git -C "$SRC" ls-files -s "$h")" in
    100755*) ok "hook bit: $h committed executable (settings.json runs it directly)" ;;
    *) bad "hook bit: $h committed without the executable bit" ;;
  esac
done
echo a > "$GG/sub/f"

echo "--- git guard: Law 5 - the main session never closes a Tier 3-4 story (0.48.1)"
mkdir -p "$GG/docs/specs/hv" "$GG/docs/specs/solo"
printf '# hv\n\n**Tier:** 3 · **Spec slug:** `hv`\n' > "$GG/docs/specs/hv/plan.md"
printf '# solo\n\n**Tier:** 2 · **Spec slug:** `solo`\n' > "$GG/docs/specs/solo/plan.md"
printf -- '---\nstory: hv-01\nstatus: todo\nreturned: DONE\n---\n' > "$GG/docs/specs/hv/hv-01.md"
printf -- '---\nstory: solo-01\nstatus: todo\nreturned: DONE\n---\n' > "$GG/docs/specs/solo/solo-01.md"
out="$(guard Bash "bash scripts/cycle.sh close-story docs/specs/hv/hv-01.md --commit --stamp s1")"
printf '%s' "$out" | expect "law5: the original case (the Queen closes a returned Tier 3 story) is denied" '"deny"'
printf '%s' "$out" | expect "law5: the refusal names the re-dispatch" "dispatch"
guard PowerShell "bash scripts/cycle.sh close-story ./docs/specs/hv/hv-01.md" \
  | expect "law5: the neighbour form (PowerShell, ./path, no flags) is denied" '"deny"'
guard Bash "git add -A && bash scripts/cycle.sh close-story docs/specs/hv/hv-01.md --commit" \
  | expect "law5: a close-story after another command is denied" '"deny"'
guard Bash "bash scripts/cycle.sh close-story docs/specs/hv/hv-01.md --commit --stamp s1" a1 \
  | silent "law5: a worker (subagent) closes its own Tier 3 story"
guard Bash "bash scripts/cycle.sh close-story docs/specs/solo/solo-01.md --commit" \
  | silent "law5: the Queen closes a Tier 2 story herself"
guard Bash "bash scripts/cycle.sh stamp-red docs/specs/hv/hv-01.md" \
  | silent "law5: stamp-red stays the Queen's escape (ADR-025), not a close"
guard Bash "grep -n close-story scripts/cycle.sh" | silent "law5: a grep for close-story passes"
rm -rf "$GG/docs/specs"

echo "--- git guard: launchers, UTF-8 stdin, the private audit's gaps (mass-audit-fixes-02)"
cat > "$T/guard-chk.py" <<'PY'
import json, sys
d = {"hook_event_name": "PreToolUse", "session_id": "s", "tool_name": sys.argv[1],
     "tool_input": {"command": sys.argv[2]}, "cwd": sys.argv[4]}
if sys.argv[3]:
    d["agent_id"] = sys.argv[3]; d["agent_type"] = "worker-code"
if sys.argv[5]:
    d["porcelain"] = json.loads(sys.argv[5])
with open(sys.argv[6], "w", encoding="utf-8") as f:
    f.write(json.dumps(d))
PY
chk() { # chk <tool> <command> [<agent_id>] [<porcelain JSON>] - `--check` stdout + exit=N for one call in $GG
  # (Git Bash would rewrite a /usr/bin/env command into a Windows path for the native Python: excluded)
  ( cd "$GG" && MSYS2_ARG_CONV_EXCL='/usr/bin/env' "$PYBIN" "$T/guard-chk.py" "$1" "$2" "${3:-}" "$(pwd -W 2>/dev/null || pwd)" "${4:-}" "$T/chk.json" \
    && bash "$GUARD" --check "$T/chk.json" 2>&1; echo "exit=$?" )
}
SUBPAY='{"tool_name":"Bash","agent_id":"a1","tool_input":{"command":"git reset --hard"}}'
mkdir -p "$T/onlypy" "$T/nopy"
printf '#!/bin/sh\nexec "%s" "$@"\n' "$PYBIN" > "$T/onlypy/py"; chmod +x "$T/onlypy/py"
printf '%s' "$SUBPAY" | PATH="$T/onlypy" "$BASH" "$GUARD" 2>&1 \
  | expect "git-guard: a PATH with only py still finds Python (subagent reset --hard denied)" '"deny"'
printf '%s' "$SUBPAY" | VULYK_PY="$PYBIN" PATH="$T/nopy" "$BASH" "$GUARD" 2>&1 \
  | expect "git-guard: VULYK_PY with no python on PATH is used (subagent reset --hard denied)" '"deny"'
printf '\357\273\277{"tool_name":"Bash","agent_id":"a1","tool_input":{"command":"echo \320\220\320\263\320\265\320\275\321\202 && git stash"}}' \
  | bash "$GUARD" 2>&1 | expect "git-guard: a UTF-8 BOM and Cyrillic payload is parsed (git stash denied)" '"deny"'
for c in "git checkout -f -b x" "git checkout -fb x" "git checkout --force -B x" "git checkout -f --orphan x"; do
  chk Bash "$c" a1 | expect "git-guard: forced checkout -b is denied: $c" "exit=1"
done
chk Bash "git checkout -b x" a1 | expect "git-guard: a plain checkout -b still passes" "exit=0"
for c in "$(printf 'git \\\nstash')" "/usr/bin/env git stash" 'git $(echo stash)' 'git `echo stash`' \
         'git "$VERB"' "git -c core.pager=cat stash push"; do
  chk Bash "$c" a1 | expect "git-guard: a subagent's hidden or continued verb is denied: $c" "exit=1"
done
chk PowerShell "$(printf 'git `\nstash')" a1 | expect "git-guard: the PowerShell backtick continuation is denied" "exit=1"
mkdir -p "$GG/docs/specs/x" "$GG/docs/specs/t1"
printf '# x\n\n**Tier:** 3 · **Spec slug:** `x`\n' > "$GG/docs/specs/x/plan.md"
printf '# t1\n\n**Tier:** 1 · **Spec slug:** `t1`\n' > "$GG/docs/specs/t1/plan.md"
chk Bash 'S=docs/specs/x/01.md; bash scripts/cycle.sh close-story "$S"' \
  | expect "law5: a story token holding \$ is unknown and denied" "exit=1"
chk Bash 'bash scripts/cycle.sh close-story `cat s`' | expect "law5: a story token holding a backtick is denied" "exit=1"
chk PowerShell 'bash scripts/cycle.sh close-story %S%' | expect "law5: a story token holding % is denied" "exit=1"
chk Bash "bash scripts/cycle.sh close-story docs/specs/nope/01.md --commit" \
  | expect "law5: a story whose plan.md cannot be read is denied" "exit=1"
chk Bash "bash scripts/cycle.sh close-story docs/specs/x/01.md" | expect "law5: the literal Tier 3 path stays denied" "exit=1"
chk Bash "bash scripts/cycle.sh close-story docs/specs/t1/01.md" | expect "law5: a Tier 1 path passes" "exit=0"
chk Bash 'bash scripts/cycle.sh close-story "$S"' a1 | expect "law5: a subagent's variable story token passes" "exit=0"
rm -rf "$GG/docs/specs"
out="$(chk Bash "git stash" "" '{"sleep": 3, "timeout": 0.5}')"
printf '%s' "$out" | expect "git-guard: a git status that times out denies" "exit=1"
printf '%s' "$out" | expect "git-guard: the timeout refusal says why" "git status timed out, cannot prove the tree is clean"
chk Bash "git stash" "" '""' | expect "git-guard: a git status that succeeds clean still passes" "exit=0"
chk Bash "git reset --hard" "" '" M memory/stats/skills.json\n"' \
  | expect "git-guard: a git status that succeeds dirty still denies, naming the file" "memory/stats/skills.json"

echo "--- git guard: every discarding form, through a shell, an alias, a heredoc (audit-fixes-1113-07)"
DIRTY='" M memory/stats/skills.json\n?? new.txt\n"'
chk Bash 'bash -c "git reset --hard"' a1 | expect "git-guard: a discarding verb fed to a shell is denied: bash -c" "exit=1"
for c in "git rm -f memory/stats/skills.json" "git rm -r -f ." "git rm --force memory/stats/skills.json" \
         "git checkout-index -f -a" "git checkout-index --force -- memory/stats/skills.json" \
         "git read-tree -u --reset HEAD" "git read-tree -u -m HEAD" \
         'sh -c "git reset --hard"' 'bash -lc "git clean -fd"' 'zsh -c "cd sub && git checkout ."' \
         'pwsh -Command "git reset --hard"' 'powershell.exe -Command git stash' \
         'git -c alias.wipe="reset --hard" wipe' 'git -c alias.x="!git reset --hard" x' \
         "$(printf "bash <<'X'\ngit reset --hard\nX")" "$(printf "sh -s <<X\ngit stash\nX")" \
         "$(printf "cat <<X | bash\ngit clean -fd\nX")" "git reset --merge" "git reset --merge HEAD~1" "git merge --abort" \
         'bash -c "git merge --abort"'; do
  chk Bash "$c" a1 | expect "git-guard: a subagent's $c is denied" "exit=1"
  chk Bash "$c" "" "$DIRTY" | expect "git-guard: main-session $c over a dirty tree is denied" "exit=1"
  chk Bash "$c" "" '""' | expect "git-guard: main-session $c on a clean tree passes" "exit=0"
done
chk PowerShell 'bash -c "git reset --hard"' a1 | expect "git-guard: a shell-fed verb from PowerShell is denied" "exit=1"
for c in "git branch -f main HEAD~3" "git branch --force main HEAD~3" "git branch -M x main" \
         "git checkout -B main HEAD~3" "git switch -C main HEAD~3" "git switch --force-create x" \
         "git update-ref -d refs/heads/main" "git update-ref refs/heads/main HEAD~3" 'bash -c "git branch -D x"'; do
  chk Bash "$c" a1 | expect "git-guard: a subagent's $c (loses commits) is denied" "exit=1"
  chk Bash "$c" "" "$DIRTY" | expect "git-guard: main-session $c follows the branch -D rule and passes" "exit=0"
done
for c in "git rm --cached memory/stats/skills.json" "git rm memory/stats/skills.json" "git rm -n -f x" \
         "git checkout-index -a" "git read-tree HEAD" "git read-tree -m HEAD" "git branch x" "git branch -d x" \
         "git checkout -b x" "git switch -c x" "git show-ref" 'bash -c "git status"' 'sh -c "echo hi"' \
         'pwsh -Command "git log"' 'git -c alias.st="status" st' "$(printf "cat <<'X'\ngit reset --hard\nX")" \
         "$(printf "cat > r.sh <<X\ngit stash\nX")" "bash scripts/x.sh" "git update-index --chmod=+x f"; do
  chk Bash "$c" a1 | expect "git-guard: a subagent's $c passes (read-only or unforced)" "exit=0"
done
( cd "$SRC" && bash "$GUARD" --check docs/defects/work-discarded-by-git-verb.shell.fixture > /dev/null 2>&1 )
[ $? -eq 1 ] && ok "git-guard: --check fails on the shell fixture (a heredoc fed to a shell)" \
  || bad "git-guard: --check passed the shell fixture"
# audit-fixes-1113-17: the shell-indirection forms the guard cannot enumerate are named in its left-open list
# guards-1115-01 (O2): the list is the header's last block, up to the first line of code, and the card's
# ## Check carries it word for word
GH="$(sed -n '/^# Left open/,/^[^#]/p' "$GUARD" | sed '1d;$d' | tr -d '\r' | sed 's/^# *//' | tr '\n' ' ' | tr -s ' ')"
CK="$(sed -n '/^Left open/,/^## /p' "$SRC/docs/defects/work-discarded-by-git-verb.md" | sed '1d;$d' | tr -d '\r' \
  | sed 's/^ *//' | tr '\n' ' ' | tr -s ' ')"
for n in 'command text piped into a shell' 'a here-string fed to a shell'; do
  case "$GH" in *"$n"*) ok "git-guard: the header's left-open list names $n" ;;
    *) bad "git-guard: the header's left-open list does not name $n" ;; esac
done
case "$GH" in *'reset --merge'*|*'merge --abort'*) bad "git-guard: the left-open list still names the reset --merge / merge --abort pair" ;;
  *) ok "git-guard: reset --merge and merge --abort are no longer left open" ;; esac
for n in 'Invoke-Expression' 'iex' 'tag -f' 'push --force' 'stage' 'cherry-pick' 'a redirection' 'a comment'; do
  case "$GH" in *"$n"*) bad "git-guard: the header's left-open list still names $n, closed by guards-1115-01" ;;
    *) ok "git-guard: the header's left-open list no longer names $n" ;; esac
done
for n in 'a shell option that takes a value before the script' 'xargs among them' \
         'a shell or a whole command held in a variable' 'a script word made by a pattern or a variable behind a wrapper'; do
  case "$GH" in *"$n"*) bad "git-guard: a cycle.sh verb outside the six is refused under every listed spelling, yet the header's left-open list still names $n" ;;
    *) ok "git-guard: the header's left-open list no longer names $n, closed by guards-1115-10" ;; esac
done
if [ -n "$GH" ] && [ "$GH" = "$CK" ]; then ok "git-guard: the card's ## Check list of open forms equals the header's"
else bad "git-guard: the card's open list differs from the header's - header: $GH / card: $CK"; fi

echo "--- git guard: a subagent under a DRIVER, cycle.sh verbs (audit-fixes-1113-07)"
mkdir -p "$GG/docs/specs/dv"; : > "$GG/docs/specs/dv/DRIVER"
for c in "git commit -m x" "git add ." "git -C sub commit -m x" 'bash -c "git commit -m x"' 'sh -c "git add -A"'; do
  chk Bash "$c" a1 | expect "git-guard: a subagent's $c is denied while a DRIVER exists" "exit=1"
  chk Bash "$c" | expect "git-guard: main-session $c under a DRIVER passes" "exit=0"
done
chk PowerShell "git commit -m x" a1 | expect "git-guard: a subagent's PowerShell git commit under a DRIVER is denied" "exit=1"
chk Bash "git update-index --chmod=+x f" a1 | expect "git-guard: update-index --chmod stays allowed under a DRIVER" "exit=0"
rm -f "$GG/docs/specs/dv/DRIVER"
for c in "git commit -m x" "git add ." "git -C sub commit -m x" 'bash -c "git commit -m x"'; do
  chk Bash "$c" a1 | expect "git-guard: a subagent's $c with no DRIVER passes" "exit=0"
done
for c in "bash scripts/cycle.sh revise docs/specs/dv/dv-01.md" "bash scripts/cycle.sh branch dv" \
         "bash scripts/cycle.sh reopen dv" "bash scripts/cycle.sh stamp-red docs/specs/dv/dv-01.md --baseline" \
         "./scripts/cycle.sh claim dv s1" 'bash -c "bash scripts/cycle.sh revise x"'; do
  chk Bash "$c" a1 | expect "git-guard: a subagent's $c is denied" "exit=1"
done
for c in "bash scripts/cycle.sh close-story docs/specs/dv/dv-01.md --commit --stamp s1" \
         "bash scripts/cycle.sh stamp-red docs/specs/dv/dv-01.md --stamp s1" "bash scripts/cycle.sh advance dv --stamp s1" \
         "bash scripts/cycle.sh status dv --json" "bash scripts/cycle.sh release dv s1" \
         "bash scripts/cycle.sh suite dv --commit --stamp s1" "grep -n revise scripts/cycle.sh scripts/lib.sh"; do
  chk Bash "$c" a1 | expect "git-guard: a subagent's $c passes" "exit=0"
done
chk Bash "bash scripts/cycle.sh revise docs/specs/dv/dv-01.md" | expect "git-guard: main-session cycle.sh revise passes" "exit=0"
rm -rf "$GG/docs/specs"

echo "--- git guard: no Python - the bash fallback, a crashed interpreter (audit-fixes-1113-07)"
BL="$(sed -n "s/^GUARD_VERBS='\(.*\)'.*/\1/p" "$GUARD" | tr ' ' '\n' | sed '/^$/d' | sort)"
PL="$(sed -n 's/^VERBS = (\(.*\))[[:space:]]*$/\1/p' "$GUARD" | tr -d "' " | tr ',' '\n' | sed '/^$/d' | sort)"
if [ -n "$BL" ] && [ "$BL" = "$PL" ]; then ok "git-guard: the fallback's verb list equals the Python part's"
else bad "git-guard: the verb lists differ - fallback: $(printf '%s' "$BL" | tr '\n' ' ') / python: $(printf '%s' "$PL" | tr '\n' ' ')"; fi
nopy() { # nopy <tool> <command> [<agent_id>] [<launcher dir>] - `--check` stdout + exit=N with only <launcher dir> on PATH
  ( cd "$GG" && "$PYBIN" "$T/guard-chk.py" "$1" "$2" "${3:-}" "$(pwd -W 2>/dev/null || pwd)" "" "$T/nopy.json" )
  ( cd "$GG" && VULYK_PY='' PATH="${4:-$T/nopy}" "$BASH" "$GUARD" --check "$T/nopy.json" 2>&1; echo "exit=$?" )
}
for v in $BL; do
  for tool in Bash PowerShell; do
    nopy "$tool" "git $v" | expect "git-guard: no Python, $tool git $v is denied" "exit=1"
  done
done
nopy Bash "git -C sub reset --hard" a1 | expect "git-guard: no Python, a subagent's git -C sub reset is denied" "exit=1"
nopy Bash 'bash -c "git reset --hard"' | expect "git-guard: no Python, a shell-fed git reset is denied" "exit=1"
nopy PowerShell "& git.exe stash" | expect "git-guard: no Python, PowerShell & git.exe stash is denied" "exit=1"
out="$(nopy Bash "git stash")"
printf '%s' "$out" | expect "git-guard: the no-Python refusal says Python is missing" "no Python"
for c in "git status" "git log --oneline" "ls -la" "Get-ChildItem"; do
  nopy Bash "$c" | expect "git-guard: no Python, $c passes" "exit=0"
  nopy PowerShell "$c" | expect "git-guard: no Python, PowerShell $c passes" "exit=0"
done
mkdir -p "$T/py3"; printf '#!/bin/sh\nexit 3\n' > "$T/py3/python3"; chmod +x "$T/py3/python3"
out="$(nopy Bash "git status" "" "$T/py3")"
printf '%s' "$out" | expect "git-guard: a launcher that exits 3 on a git command denies" "exit=1"
printf '%s' "$out" | expect "git-guard: the crash refusal says the guard failed" "the guard failed"
printf '%s' "$out" | expect "git-guard: the crash refusal says the owner can run it" "owner can run"
nopy Bash "ls digital" "" "$T/py3" | expect "git-guard: a launcher that exits 3 on a non-git command passes" "exit=0"

echo "--- git guard: shell keywords, eval, wrapper commands; an interpreter that exits 1 (audit-fixes-1113-15)"
for c in 'if true; then git stash; fi' 'for f in a; do git reset --hard; done' 'if false; then :; else git clean -fd; fi' \
         'if false; then :; elif true; then git stash; fi' 'while false; do git checkout .; done' '! git stash' \
         'eval git reset --hard' 'eval "git checkout ."' 'timeout 5 git stash' 'timeout -s KILL 5 git reset --hard' \
         'nohup git stash' 'nice -n 5 git clean -fd' 'nice git reset --hard' 'sudo -u x git reset --hard' \
         'echo f | xargs git checkout --' 'timeout 5 bash -c "git stash"'; do
  chk Bash "$c" a1 | expect "git-guard: a subagent's $c is denied" "exit=1"
  chk Bash "$c" "" "$DIRTY" | expect "git-guard: main-session $c over a dirty tree is denied" "exit=1"
done
chk Bash 'ls | xargs -I{} git rm -f {}' a1 | expect "git-guard: a subagent's xargs -I{} git rm -f is denied" "exit=1"
for c in 'if git diff --quiet; then echo clean; fi' 'timeout 5 git status' 'nice git log --oneline' 'eval echo git' \
         'nohup ls' 'for f in a; do git log; done'; do
  chk Bash "$c" a1 | expect "git-guard: a subagent's $c passes" "exit=0"
done
mkdir -p "$T/py1"; printf '#!/bin/sh\nexit 1\n' > "$T/py1/python3"; chmod +x "$T/py1/python3"
out="$(printf '%s' "$SUBPAY" | VULYK_PY="$T/py1/python3" bash "$GUARD" 2>&1)"
printf '%s' "$out" | expect "git-guard: an interpreter that exits 1 on a git command denies" '"deny"'
printf '%s' "$out" | expect "git-guard: the exit-1 refusal says the guard failed" "the guard failed"
out="$(printf '%s' '{"tool_name":"Bash","tool_input":{"command":"ls"}}' | VULYK_PY="$T/py1/python3" bash "$GUARD" 2>&1)"
[ -z "$out" ] && ok "git-guard: an interpreter that exits 1 on a non-git command passes" \
  || bad "git-guard: an interpreter that exits 1 on a non-git command - got: $out"
# an error inside the Python half (a broken shlex module on its path) is a crash, not a pass
mkdir -p "$T/badmod"; printf 'class shlex:\n    def __init__(self, *a, **k):\n        raise RuntimeError("broken")\n' > "$T/badmod/shlex.py"
out="$(printf '%s' "$SUBPAY" | PYTHONPATH="$(cd "$T/badmod" && (pwd -W 2>/dev/null || pwd))" VULYK_PY="$PYBIN" bash "$GUARD" 2>&1)"
printf '%s' "$out" | expect "git-guard: an error inside the Python half on a git command denies" "the guard failed"

echo "--- git guard: run state, script word, history verbs, forced forms, parser, fallback (guards-1115-01)"
cat > "$T/guard-batch.py" <<'PY'
import json, sys
tool, aid, cwd, porc, out = sys.argv[1:6]
for n, c in enumerate(sys.argv[6:], 1):
    d = {"hook_event_name": "PreToolUse", "session_id": "s", "tool_name": tool, "tool_input": {"command": c}, "cwd": cwd}
    if aid:
        d["agent_id"] = aid; d["agent_type"] = "worker-code"
    if porc:
        d["porcelain"] = json.loads(porc)
    with open("%s.%d.json" % (out, n), "w", encoding="utf-8") as f:
        f.write(json.dumps(d))
PY
GGW="$(cd "$GG" && (pwd -W 2>/dev/null || pwd))"; TW="$(cd "$T" && (pwd -W 2>/dev/null || pwd))"   # native paths: no MSYS conversion below
gbatch() { # gbatch <exit> <tool> <agent_id> <porcelain JSON> <label> <command>... - `--check` each command in $GG
  local want="$1" tool="$2" aid="$3" porc="$4" label="$5" n=0 c rc; shift 5
  MSYS2_ARG_CONV_EXCL='*' "$PYBIN" "$TW/guard-batch.py" "$tool" "$aid" "$GGW" "$porc" "$TW/gb" "$@"
  for c in "$@"; do
    n=$((n + 1))
    bash "$GUARD" --check "$T/gb.$n.json" > "$T/gb.out" 2>&1; rc=$?   # the input names the cwd: no cd, no fork
    if [ "$rc" = "$want" ]; then ok "$label: $c"; else bad "$label: $c - expected exit $want, got $rc: $(cat "$T/gb.out")"; fi
  done
}
nopyb() { # nopyb <exit> <agent_id> <label> <command>... - gbatch with no Python launcher on PATH
  local want="$1" aid="$2" label="$3" n=0 c rc; shift 3
  MSYS2_ARG_CONV_EXCL='*' "$PYBIN" "$TW/guard-batch.py" Bash "$aid" "$GGW" "" "$TW/nb" "$@"
  for c in "$@"; do
    n=$((n + 1))
    VULYK_PY='' PATH="$T/nopy" "$BASH" "$GUARD" --check "$T/nb.$n.json" > "$T/gb.out" 2>&1; rc=$?
    if [ "$rc" = "$want" ]; then ok "$label: $c"; else bad "$label: $c - expected exit $want, got $rc: $(cat "$T/gb.out")"; fi
  done
}
mkdir -p "$GG/.vulyk/state/dv" "$GG/docs/specs/dv" && echo 'wave.1=abc' > "$GG/.vulyk/state/dv/claim"
: > "$GG/docs/specs/dv/DRIVER"
SCR="$T/scr"; mkdir -p "$SCR" && git -C "$SCR" init -q; SCRW="$(cd "$SCR" && (pwd -W 2>/dev/null || pwd))"
# R1 (S1): a subagent's shell call on the run state; the original first, the reason names the Read tool
gbatch 1 Bash a1 "" "git-guard: a subagent shell call on the run state is denied" \
  'echo wave.1=abc >> .vulyk/state/dv/claim' 'cat .vulyk/state/dv/claim' 'cp x .vulyk/state/dv/approved' \
  'cd .vulyk/state && ls' 'cd .vulyk && cat state/dv/claim' 'cat .VULYK/State/dv/claim' \
  'cat docs/../.vulyk/state/dv/claim' 'rm -rf .vulyk/*/dv' 'sort < .vulyk/state/dv/claim' 'tee -a .vulyk/state/dv/x < f' \
  'python -c "open(\".vulyk/state/dv/claim\", \"w\")"' 'bash -c "echo x > .vulyk/state/dv/claim"' \
  "$(printf "python3 - <<'X'\nopen('.vulyk/state/dv/claim', 'w')\nX")" 'node -e "require(\"fs\").rmSync(\".vulyk/state\")"' \
  'x=.vulyk/state/dv/claim; cat $x' 'bash scripts/cycle.sh status dv && cat .vulyk/state/dv/claim'
gbatch 1 PowerShell a1 "" "git-guard: a subagent shell call on the run state is denied (PowerShell)" \
  'Set-Content .vulyk/state/dv/claim x' 'Get-Content .vulyk\state\dv\claim'
out="$(chk Bash 'cat .vulyk/state/dv/claim' a1)"
printf '%s' "$out" | expect "git-guard: the run-state refusal names the Read tool" "Read tool"
gbatch 0 Bash "" "" "git-guard: main-session run-state command passes as before" \
  'echo wave.1=abc >> .vulyk/state/dv/claim' 'cat .vulyk/state/dv/claim' 'bash -c "echo x > .vulyk/state/dv/claim"'
# N1 (S2): the cycle.sh rule however the script or the verb is written
gbatch 1 Bash a1 "" "git-guard: a subagent's cycle.sh call spelled another way is denied" \
  'c=scripts/cycle.sh; bash $c reopen dv' "bash scripts/cy''cle.sh reopen dv" 'bash scripts/cyc*.sh reopen dv' \
  'v=reopen; bash scripts/cycle.sh $v dv' 'for s in scripts/cycle.sh; do bash "$s" revise x; done' \
  'export C=scripts/cycle.sh; bash "$C" branch dv' 'bash "$UNSET" reopen dv' '"$UNSET" reopen dv' \
  'bash $(echo scripts/cycle.sh) reopen dv' 'ls scripts | xargs -n1 bash' \
  'bash scripts/cycle.sh stamp-red docs/specs/dv/dv-01.md "$F"' \
  'b=--baseline; bash scripts/cycle.sh stamp-red docs/specs/dv/dv-01.md $b' "bash 'scripts/cycle.sh' \"reopen\" dv"
gbatch 1 PowerShell a1 "" "git-guard: a subagent's cycle.sh call spelled another way is denied (PowerShell)" \
  '$c = "scripts/cycle.sh"; bash $c reopen dv' '$c = "scripts/cycle.sh"; & $c claim dv s1'
gbatch 0 Bash "" "" "git-guard: main-session cycle.sh call passes as before" \
  'c=scripts/cycle.sh; bash $c reopen dv' "bash scripts/cy''cle.sh reopen dv" 'bash scripts/cyc*.sh revise dv'
# L1: the flows a subagent keeps, a DRIVER held
gbatch 0 Bash a1 "" "git-guard: a subagent's own flow passes under a DRIVER" \
  "git ls-files '*.sh' | xargs -n1 bash -n" 'bash scripts/py.sh -m py_compile .claude/hooks/*.py' \
  "git ls-files '*.json' | xargs -n1 jq -e . > /dev/null" 'bash tests/cycle.test.sh --part red' \
  'bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh' 'bash tests/full-suite.test.sh' \
  'bash scripts/defects-check.sh docs/defects/x.md' 'bash scripts/wave-check.sh dv' 'bash scripts/trace-check.sh dv' \
  'bash scripts/scope-check.sh docs/specs/dv/dv-01.md' 'bash scripts/symbol-map.sh .claude/hooks/git-guard.sh --story dv-01' \
  'bash scripts/prompt-check.sh .claude/agents/worker-code.md' 'bash scripts/portability-check.sh .claude/hooks/git-guard.sh' \
  'bash scripts/cycle.sh close-story docs/specs/dv/dv-01.md --commit --stamp s1' \
  'bash scripts/cycle.sh stamp-red docs/specs/dv/dv-01.md --stamp s1' 'bash scripts/cycle.sh advance dv --stamp s1' \
  'bash scripts/cycle.sh status dv --json' 'bash scripts/cycle.sh release dv s1' 'bash scripts/cycle.sh suite dv --commit --stamp s1' \
  'for t in tests/*.test.sh; do bash "$t"; done' 'for f in a.sh b.sh; do bash -n "$f"; done' \
  'git status --porcelain' 'git log --oneline -5' 'git diff HEAD -- scripts' 'git show HEAD:scripts/lib.sh' \
  'git branch --show-current' 'git rev-parse HEAD' 'git update-index --chmod=+x f' \
  'cat docs/specs/dv/plan.md' 'grep -n Tier docs/specs/dv/plan.md' "grep -rn '.vulyk/state' scripts/" \
  "$(printf "cat > notes.md <<'EOF'\nThe run state .vulyk/state/dv/claim is cycle.sh's; plan.md, ACCEPTED, scripts/cycle.sh reopen\nEOF")" \
  'echo "see .vulyk/state/dv/claim" >> notes.md' 'printf "%s\n" .vulyk/state/dv > notes.md' 'echo git stash' 'ls -la' \
  'if [ -n "$X" ]; then echo y; fi 2>&1'
# G2 (S3, T14): history verbs, where the git command acts
gbatch 0 Bash a1 "" "git-guard: T14 original - a subagent's commit in an unrelated scratch repository passes under a DRIVER" \
  "cd $SCRW && git commit -m x" "git -C $SCRW add -A" "cd $SCRW && git rebase main"
gbatch 1 Bash a1 "" "git-guard: a subagent's history verb under a DRIVER is denied" \
  "git stage f" "git cherry-pick abc123" "git merge other" "git am x.patch" "git apply --cached x.patch" "git revert HEAD" \
  "git rebase main" "git pull" "git update-index --add f" 'git commit-tree HEAD^{tree} -m x' "git reset --soft HEAD~1" \
  "git reset HEAD f" "git checkout main" "git switch main" "git mv a b" "git rm --cached f" "git restore --staged f" \
  "git branch x" "git branch -m x y" "git symbolic-ref HEAD refs/heads/x" "git push origin x" "git notes add -m x" \
  "git fetch origin main:main" "git worktree add -b x ../w" "cd $SCRW && cd $GGW && git commit -m x" \
  "git -C $GGW commit -m x" "git --git-dir=$GGW/.git commit -m x" "GIT_DIR=$GGW/.git git commit -m x" \
  "cd $SCRW && git --work-tree=$GGW --git-dir=$GGW/.git add f" 'cd "$X" && git commit -m x' 'git -C "$X" commit -m x' \
  'git --git-dir="$X" commit -m x' "git -C $GGW/no-such commit -m x" "export GIT_DIR=$GGW/.git; cd $SCRW && git commit -m x"
gbatch 0 Bash "" "" "git-guard: main-session history verb under a DRIVER passes as before" \
  "git stage f" "git cherry-pick abc123" "git rebase main" "git reset --soft HEAD~1" "git -C $GGW commit -m x"
rm -f "$GG/docs/specs/dv/DRIVER"
gbatch 0 Bash a1 "" "git-guard: a subagent's history verb with no DRIVER passes" \
  "git stage f" "git cherry-pick abc123" "git rebase main" 'git commit-tree HEAD^{tree} -m x' "git reset --soft HEAD~1" \
  "git push origin main" "git tag v1"
# S6: the forms closed on the owner's answer, for a subagent at any time
gbatch 1 Bash a1 "" "git-guard: a subagent's forced tag or push is denied" \
  "git tag -f v1" "git tag --force v1 HEAD" "git tag -fa v1 -m x" "git push --force" "git push -f origin main" \
  "git push --force-with-lease origin main" "git push origin +main" 'bash -c "git push --force"'
gbatch 1 PowerShell a1 "" "git-guard: a subagent's PowerShell evaluate-a-string command is denied" \
  "Invoke-Expression 'git status'" "'git status' | iex" 'iex $cmd' 'invoke-expression -Command "ls"'
chk Bash 'pwsh -Command "iex ls"' a1 | expect "git-guard: iex handed to pwsh -Command is denied" "exit=1"
# guards-1115-09 (round 3, ask 6): the owner's "forms no agent needs" are closed for the main session too
gbatch 1 Bash "" "" "git-guard r3: a main-session forced tag or push is denied" "git tag -f v1" "git push --force" \
  "git push origin +main" 'bash -c "git tag --force v1"'
# guards-1115-11 (owner, 2026-11-16: «Push/tag нельзя, iex можно»): the main session may evaluate a string again;
# a discarding verb inside the string it hands over is still read
gbatch 0 PowerShell "" "" "git-guard r4: a main-session evaluate-a-string command passes" "Invoke-Expression 'git status'" \
  "'ls' | iex" 'iex $cmd'
gbatch 1 PowerShell "" "$DIRTY" "git-guard r4: a discarding verb inside a main-session evaluated string over a dirty tree is denied" \
  "Invoke-Expression 'git stash'" "iex 'git checkout .'"
gbatch 0 Bash "" "" "git-guard r3: a main-session unforced tag or push passes" "git tag v1" "git push origin main"
# S4: the verb behind a comment, a redirection or a keyword's option, for every caller
S4="$(printf 'echo hi # x\ngit reset --hard')"
set -- "$S4" "$(printf 'ls #c\ngit stash')" "$(printf 'echo hi # <<EOF\ngit reset --hard')" 'git 2>/dev/null reset --hard' \
  'git 2> /dev/null reset --hard' 'git >/dev/null 2>&1 stash' '2>/dev/null git checkout .' 'time -p git reset --hard' \
  'command -p git stash' 'exec -a foo git reset --hard' 'time -p command -p git clean -fd'
gbatch 1 Bash a1 "" "git-guard: a subagent's verb behind a comment, a redirection or a keyword option is denied" "$@"
gbatch 1 Bash "" "$DIRTY" "git-guard: a main-session verb behind a comment, a redirection or a keyword option over a dirty tree is denied" "$@"
gbatch 0 Bash "" '""' "git-guard: a main-session S4 form on a clean tree passes" "$S4" 'git 2>/dev/null reset --hard'
gbatch 1 Bash a1 "" "git-guard: a # or a 2>&1 inside a string stays text (holds as on HEAD)" \
  'echo "a #b"; git reset --hard' "$(printf 'echo "a\n#b"; git reset --hard')" 'echo "2>&1"; git stash'
# F1 (S5): no Python - the alias-function form for any caller, the subagent rules by text
nopyb 1 "" "git-guard: no Python, an alias that defines a shell function is denied" \
  "git -c 'alias.x=!r() { git reset --hard; }; r' x" "git -c 'alias.y=!f() { git stash; }; f' y"
nopyb 1 a1 "git-guard: no Python, a subagent's run-state or cycle.sh command is denied" \
  "git -c 'alias.x=!r() { git reset --hard; }; r' x" 'cat .vulyk/state/dv/claim' 'echo x >> .vulyk/state/dv/claim' \
  "bash scripts/cycle.sh reopen dv" "bash scripts/cy''cle.sh revise x" 'bash scripts/cyc*.sh branch dv' \
  "bash scripts/cycle.sh stamp-red docs/specs/dv/dv-01.md --baseline" 'c=scripts/cycle.sh; bash $c reopen dv'
nopyb 0 a1 "git-guard: no Python, a subagent's history verb with no DRIVER passes" "git commit -m x" "git cherry-pick abc"
: > "$GG/docs/specs/dv/DRIVER"
nopyb 1 a1 "git-guard: no Python, a subagent's history verb under a DRIVER is denied" \
  "git commit -m x" "git add ." "git cherry-pick abc" "git rebase main" 'bash -c "git commit -m x"' "git update-index --add f"
nopyb 0 a1 "git-guard: no Python, a subagent's read or own flow passes under a DRIVER" \
  "git status" "git log --oneline" "git update-index --chmod=+x f" "git ls-files '*.sh' | xargs -n1 bash -n" \
  "bash scripts/cycle.sh close-story docs/specs/dv/dv-01.md --commit --stamp s1" "bash tests/maintenance.test.sh"
nopyb 0 "" "git-guard: no Python, main-session commit under a DRIVER passes as before" "git commit -m x"
rm -rf "$GG/docs/specs" "$GG/.vulyk"

echo "--- git guard: classes left open by round 2, each with its neighbour (guards-1115-05)"
mkdir -p "$GG/docs/specs/dv" && : > "$GG/docs/specs/dv/DRIVER"
# a cd that does not take effect (a subshell, after ||, in a pipeline or in the background, a failing cd) leaves the
# build-lock lookup where the shell stands; a cd that does take effect moves it, inside its own subshell too
gbatch 1 Bash a1 "" "git-guard r2: a subagent's commit after a cd that does not take effect is denied under a DRIVER" \
  "(cd $SCRW); git commit -m x" "true || cd $SCRW; git commit -m x" "cd $SCRW 2>/dev/null extra; git commit -m x" \
  "cd $SCRW | true; git commit -m x" "cd $SCRW & git commit -m x" "(cd $SCRW); (git commit -m x)"
gbatch 0 Bash a1 "" "git-guard r2: a subagent's commit after a cd that takes effect passes" \
  "cd $SCRW && git commit -m x" "cd $SCRW; git commit -m x" "(cd $SCRW && git commit -m x)" \
  "(cd $GGW); cd $SCRW && git commit -m x"
# guards-1115-09 (round 3, finding 4): a cd inside a command string handed to a child shell moves only that child
gbatch 1 Bash a1 "" "git-guard r3: a subagent's commit after a cd inside a child shell's command string is denied under a DRIVER" \
  "bash -c 'cd $SCRW'; git commit -m x" "sh -c \"cd $SCRW\" && git commit -m x" "git -c 'alias.g=!cd $SCRW' g; git commit -m x"
gbatch 0 Bash a1 "" "git-guard r3: a subagent's commit inside the child shell that moved, or after an eval that moved, passes" \
  "bash -c 'cd $SCRW && git commit -m x'" "eval 'cd $SCRW'; git commit -m x"
# a command word holding an unresolved variable that names no guarded thing passes; one that may name cycle.sh, or
# whose name is the variable itself, is still refused
gbatch 0 Bash a1 "" "git-guard r2: a subagent's command word with an unresolved variable naming no guarded thing passes" \
  'bash "$CLAUDE_PROJECT_DIR/scripts/x.sh"' '$HOME/.local/bin/tool --version' '"${PYTHON:-python3}" -m pytest -q' \
  'echo x > "$OUT"' 'bash "$CLAUDE_PROJECT_DIR/scripts/cycle.sh" status dv'
gbatch 1 Bash a1 "" "git-guard r2: a subagent's unresolved command word that may name a guarded thing is denied" \
  'bash "$CLAUDE_PROJECT_DIR/scripts/cycle.sh" reopen dv' '"$D/cycle.sh" judge dv' \
  '"${X:-scripts/cycle.sh}" reopen dv' '$G reset --hard' 'bash "$UNSET" reopen dv'
rm -rf "$GG/docs/specs"
sed -n '1,/^GUARD_VERBS=/p' "$GUARD" | grep -qi 'cooperative agent, not an adversary' \
  && ok "git-guard r2: the header says the guard stops a cooperative agent, not an adversary" \
  || bad "git-guard r2: the header does not say the guard stops a cooperative agent, not an adversary"

echo "--- git guard: a command word whose default or resolved value names git (guards-1115-08)"
gbatch 1 Bash a1 "" "git-guard: a defaulted variable that names git is judged as git - a subagent's discarding verb is denied" \
  '${X:-git} reset --hard' '${X:-/usr/bin/git} reset --hard' '"${GIT:-git}" checkout -- .' \
  '${X-git.exe} clean -fd' '${X:-C:/Git/cmd/git.exe} reset --hard' 'G=git; $G reset --hard'
gbatch 0 Bash a1 "" "git-guard: a defaulted variable that names git is judged as git - a harmless verb or program passes" \
  '${X:-git} status' '${PAGER:-less} README.md' '"${PYTHON:-python3}" -m pytest -q' \
  'bash "$CLAUDE_PROJECT_DIR/scripts/x.sh"' '$HOME/.local/bin/tool --version'
# guards-1115-09 (round 3, finding 1): a default that names a shell, a wrapper or eval, and a value the command
# sets beside another default, are judged as the program they name
gbatch 1 Bash a1 "" "git-guard r3: a command word whose default or value names a program the hook reads through is judged as it" \
  '${S:-bash} -c "git reset --hard"' '"${SH:-sh}" -c "git stash"' '${E:-eval} git reset --hard' \
  '${W:-env} git clean -fd' '${W:-timeout} 5 git checkout -- .' 'G=git; ${G:-ls} reset --hard' \
  '${S:-bash} scripts/cycle.sh reopen dv' 'C=scripts/cycle.sh; ${C:-true} judge dv' \
  "\${S:-bash} -c 'd=.vulyk; echo x > \$d/state/dv/claim'"
gbatch 0 Bash a1 "" "git-guard r3: the same spellings running a harmless command pass" \
  '${S:-bash} -c "git status"' '${E:-eval} git log --oneline' '${W:-env} git status' 'G=git; ${G:-ls} status' \
  '${S:-bash} scripts/cycle.sh status dv' 'C=scripts/cycle.sh; ${C:-true} status dv'

echo "--- git guard: a cycle.sh verb outside the six under every listed spelling (guards-1115-10)"
# council round 3, finding 3: per class the original form, then its neighbour: a shell option that carries a value
# before the script; a verb, script or command string handed in by xargs; a shell or a whole command held in a
# variable; a globbed or variable script word behind a wrapper
gbatch 1 Bash a1 "" "git-guard: a cycle.sh verb outside the six is refused under every listed spelling" \
  'bash -eo pipefail scripts/cycle.sh revise dv' 'bash --rcfile r scripts/cycle.sh judge dv' \
  'sh -euo pipefail -c "bash scripts/cycle.sh revise dv"' 'bash -c -e "bash scripts/cycle.sh reopen dv"' \
  'echo revise dv | xargs bash scripts/cycle.sh' 'echo judge dv | xargs -n2 scripts/cycle.sh' \
  'echo scripts/cycle.sh | xargs -I{} bash {} revise dv' 'echo "bash scripts/cycle.sh revise dv" | xargs -0 sh -c' \
  'echo revise | xargs -I status bash scripts/cycle.sh status dv' \
  'echo --baseline | xargs bash scripts/cycle.sh stamp-red docs/specs/dv/dv-01.md' \
  'C="bash scripts/cycle.sh revise dv"; $C' 'C="scripts/cycle.sh judge"; bash $C dv' \
  'C="bash scripts/cycle.sh revise dv"; eval $C' 'S="timeout 60 bash"; $S scripts/cycle.sh reopen dv' \
  'b="docs/specs/dv/dv-01.md --baseline"; bash scripts/cycle.sh stamp-red $b' \
  'timeout 60 scripts/cyc*.sh revise dv' 'nice -n 5 scripts/cycle.s? judge dv' \
  'timeout 60 "$C" revise dv' 'c=scripts/cycle.sh; timeout -k 5 60 $c reopen dv'
gbatch 0 Bash a1 "" "git-guard: the six cycle.sh verbs pass under the same spellings" \
  'bash -eo pipefail scripts/cycle.sh status dv' 'bash --rcfile r scripts/cycle.sh advance dv' \
  'sh -euo pipefail -c "bash scripts/cycle.sh suite dv"' 'bash -c -e "bash scripts/cycle.sh release dv s1"' \
  'echo docs/specs/dv/dv-01.md | xargs bash scripts/cycle.sh close-story' 'echo dv | xargs -n1 scripts/cycle.sh status' \
  'echo dv | xargs -I{} bash scripts/cycle.sh advance {}' \
  'C="bash scripts/cycle.sh status dv"; $C' 'C="scripts/cycle.sh advance"; bash $C dv' \
  'C="bash scripts/cycle.sh stamp-red docs/specs/dv/dv-01.md --stamp s1"; eval $C' \
  'S="timeout 60 bash"; $S scripts/cycle.sh suite dv' 'b="docs/specs/dv/dv-01.md --stamp s1"; bash scripts/cycle.sh stamp-red $b' \
  'timeout 60 scripts/cyc*.sh status dv' 'nice -n 5 scripts/cycle.s? advance dv' \
  'c=scripts/cycle.sh; timeout -k 5 60 $c close-story docs/specs/dv/dv-01.md --commit' \
  "git ls-files '*.sh' | xargs -n1 bash -n" 'timeout 300 bash tests/cycle.test.sh --part red' \
  "find . -name '*.md' | xargs -I{} grep -l foo {}" 'bash -eo pipefail tests/maintenance.test.sh'

echo "--- git guard: a wrapper's option held in a variable, a defaulted script word, an unset program behind a wrapper (guards-1115-11)"
# council round 4, finding 3: an option or its value held in a variable behind a wrapper does not end the search
# for the git, shell or cycle.sh word after it - the original form (the command sets the variable), then its neighbours
mkdir -p "$GG/docs/specs/dv" && : > "$GG/docs/specs/dv/DRIVER"
gbatch 1 Bash a1 "" "git-guard r4: a subagent's guarded word behind a wrapper option held in a variable is denied" \
  'O=-i; env $O git reset --hard' 'env $O git stash' 'O=-n; timeout 5 $O git checkout -- .' 'nice $N git clean -fd' \
  'O=-i; env $O git commit -m x' 'O=-i; env $O bash -c "git reset --hard"' 'O=-i; env $O bash scripts/cycle.sh reopen dv' \
  'O=-i; env $O bash ${S:-scripts/cycle.sh} judge dv' 'U=me; sudo -u $U $O git stash'
gbatch 1 Bash "" "$DIRTY" "git-guard r4: a main-session discarding verb behind a wrapper option held in a variable over a dirty tree is denied" \
  'O=-i; env $O git checkout .' 'env $O git stash' 'O=-n; timeout 5 $O git reset --hard' 'nice $N git clean -fd' \
  'O=-i; env $O git stash -u'
gbatch 0 Bash "" '""' "git-guard r4: the same main-session forms on a clean tree pass" 'O=-i; env $O git checkout .' 'env $O git stash'
gbatch 0 Bash a1 "" "git-guard r4: a subagent's harmless command behind a wrapper option held in a variable passes" \
  'O=-i; env $O git status' 'O=-i; env $O bash scripts/cycle.sh status dv' 'env $O bash -c "git log --oneline"'
# council round 4, ask 2: a shell's script word written as a variable with a default is read as its default (and as
# each value the command gives it), under every operator and quoting, also behind a wrapper
gbatch 1 Bash a1 "" "git-guard r4: a subagent's defaulted script word naming cycle.sh with an owner-only verb is denied" \
  'bash ${S:-scripts/cycle.sh} judge dv' 'bash "${S-scripts/cycle.sh}" approve dv' 'bash ${S:=scripts/cycle.sh} revise dv' \
  'sh "${S=scripts/cycle.sh}" reopen dv' 'timeout 60 bash ${S:-scripts/cycle.sh} judge dv' \
  'S=scripts/cycle.sh; bash ${S:-x.sh} revise dv' 'bash ${S:-scripts/cyc*.sh} reopen dv'
gbatch 0 Bash a1 "" "git-guard r4: the same defaulted script word with a worker verb, or naming another script, passes" \
  'bash ${S:-scripts/cycle.sh} status dv' 'bash "${S-scripts/cycle.sh}" advance dv' 'timeout 60 bash ${S:=scripts/cycle.sh} suite dv' \
  'bash ${T:-tests/maintenance.test.sh}' 'bash "${S:-scripts/x.sh}" judge'
# council round 4, minor 4 (over-deny): behind a wrapper a program held in a variable the command does not set is an
# ordinary call; it is still refused when its words read as an owner-only cycle.sh verb or a discarding git verb
gbatch 0 Bash a1 "" "git-guard r4: a subagent's unset program variable behind a wrapper passes" \
  'timeout 60 $PY scripts/x.py' 'timeout 300 "$PYTHON" -m pytest -q' 'nice -n 5 ${RUNNER} tests/x.sh' 'env $NODE x.js'
gbatch 1 Bash a1 "" "git-guard r4: an unset program variable behind a wrapper whose words read as a guarded verb is denied" \
  'timeout 60 "$C" revise dv' 'timeout 60 $X judge dv' 'nice $G reset --hard' 'env $G stash'
# guards-1115-12 (round 5, finding 4): behind a wrapper a program word held in a variable the command sets is judged
# as that program also when a later word of the line names git, a shell, a wrapper or cycle.sh.
# guards-1115-13 (revert after round 6): the deny cases are dropped; 0.53 passes them too, and the hook header and
# the card name the class open
gbatch 0 Bash a1 "" "git-guard r5: the same held program with a worker verb or a read passes" \
  'C=scripts/cycle.sh; timeout 60 "$C" status dv git' 'G=git; timeout 60 $G status bash' 'timeout 60 $PY x.py git'
rm -rf "$GG/docs/specs"
# guards-1115-12 (round 5, ask 4): a subagent's program word held in a variable the command does not set (or sets from
# a substitution), with words naming no guarded thing, is an ordinary call, with or without a DRIVER; it is still
# denied when its words read as an owner-only cycle.sh verb or a discarding git verb.
# guards-1115-13 (revert after round 6): the reverted hook denies the R5OK forms again
R5OK=('"$PYBIN" tests/x.py --quick' '$VULYK_PY -m py_compile src/x.py' '$EDITOR src/a.txt' \
  'PY=$(command -v python3); "$PY" tests/x.py' 'PY="$(command -v python3)"; ${PY} -c 1')
R5NO=('"$C" revise dv' '$X judge dv' '$G reset --hard' '${G} stash' 'PY=$(command -v x); "$PY" reopen dv')
gbatch 1 Bash a1 "" "git-guard: known over-deny, 0.55.0: a subagent's unset program variable is denied (no DRIVER)" ${R5OK[@]+"${R5OK[@]}"}
gbatch 1 Bash a1 "" "git-guard r5: a subagent's unset program variable with a guarded verb is denied (no DRIVER)" ${R5NO[@]+"${R5NO[@]}"}
mkdir -p "$GG/docs/specs/dv" && : > "$GG/docs/specs/dv/DRIVER"
gbatch 1 Bash a1 "" "git-guard: known over-deny, 0.55.0: a subagent's unset program variable is denied (a DRIVER)" ${R5OK[@]+"${R5OK[@]}"}
gbatch 1 Bash a1 "" "git-guard r5: a subagent's unset program variable with a guarded verb is denied (a DRIVER)" ${R5NO[@]+"${R5NO[@]}"}
# guards-1115-13 (round 6, finding 2, by the revert): behind a wrapper a variable word that may expand to nothing or
# to an option, followed by a plain word, leaves a later git, shell or cycle.sh word the command word (original first)
gbatch 1 Bash a1 "" "git-guard r6: round-6 regression forms are denied again" \
  'env $X A=1 bash scripts/cycle.sh judge dv' 'env $X A=1 git reset --hard' 'nice $N 5 git reset --hard' \
  'nice $N -n 5 git stash -u' 'env $X A=1 git rebase -i HEAD~2'
rm -rf "$GG/docs/specs"

echo "--- git guard: worker prompts never commit (audit-fixes-1113-07)"
for w in worker-code worker-test; do
  grep -qF 'Never run `git commit` or `git add`' "$SRC/.claude/agents/$w.md" \
    && ok "git-guard: $w.md says never to run git commit or git add" \
    || bad "git-guard: $w.md does not say never to run git commit or git add"
done

echo "--- git guard: fails open, card fixtures"
out="$(printf 'not json' | bash "$GUARD" 2>&1; echo "exit=$?")"
[ "$out" = "exit=0" ] && ok "git-guard: broken JSON exits 0, silent" || bad "git-guard: broken JSON - got: $out"
mkdir -p "$T/nopy"
out="$(printf '{"tool_name":"Bash","agent_id":"a","tool_input":{"command":"git stash"}}' | PATH="$T/nopy" "$BASH" "$GUARD" 2>&1; echo "exit=$?")"
printf '%s' "$out" | expect "git-guard: no interpreter, the bash fallback denies a subagent's git stash" '"deny"'
for f in original neighbour; do
  ( cd "$SRC" && bash "$GUARD" --check "docs/defects/work-discarded-by-git-verb.$f.fixture" > /dev/null 2>&1 )
  [ $? -eq 1 ] && ok "git-guard: --check fails on the $f fixture" || bad "git-guard: --check passed the $f fixture"
done
( cd "$SRC" && bash "$GUARD" --check docs/defects/work-discarded-by-git-verb.md > /dev/null 2>&1 )
[ $? -eq 0 ] && ok "git-guard: --check passes a file that is no hook input" || bad "git-guard: --check failed on the card itself"

echo "--- git guard: a mod with tool.check"
MC="$T/conf-mod"; mkdir -p "$MC/plugins" "$T/fakemod/hooks" "$T/offmod/hooks"
printf '{\n  "enabledPlugins": {\n    "fakemod@local": true,\n    "offmod@local": false\n  }\n}\n' > "$MC/settings.json"
printf '{\n  "version": 2,\n  "plugins": {\n    "fakemod@local": [\n      { "scope": "user", "installPath": "%s" }\n    ],\n    "offmod@local": [\n      { "scope": "user", "installPath": "%s" }\n    ]\n  }\n}\n' \
  "$T/fakemod" "$T/offmod" > "$MC/plugins/installed_plugins.json"
printf "export default (r) => { r.on('tool.check', () => ({ allow: true })) }\n" > "$T/fakemod/hooks/register.ts"
cp "$T/fakemod/hooks/register.ts" "$T/offmod/hooks/register.ts"
H="$(hive modcheck)"
out="$(BRIEF_CONF="$MC" brief_of "$H")"
printf '%s' "$out" | expect "git-guard: an enabled mod with tool.check gets a brief line" "fakemod@local"
printf '%s' "$out" | expect_absent "git-guard: a disabled mod is not named" "offmod@local"
brief_of "$H" | expect_absent "git-guard: no such mod, no line" "tool.check"
rm -f "$T/fakemod/hooks/register.ts"
BRIEF_CONF="$MC" brief_of "$H" | expect_absent "git-guard: an enabled mod without tool.check, no line" "tool.check"

echo "--- plan step 3a: the existing-repo horizon gate"
sed -n '/^3a\. /,/^4\. /p' "$SRC/.claude/commands/vulyk-plan.md" | tr '\n' ' ' | tr -s ' ' \
  | expect "plan 3a: the existing-repo gate counts a module under ## Unmapped territory beside ## Codebase map" \
    '`## Codebase map` or `## Unmapped territory` lists'

echo "--- hives-behind: every local hive carries the local build (local-beta-rollout-01)"
HB="$SRC/scripts/hives-behind.sh"; HR="$T/hb"; mkdir -p "$HR/src"
printf '0.51.0-dev.2\r\n' > "$HR/src/VERSION"   # a CRLF checkout: whitespace is not a version
mkhive() { mkdir -p "$HR/$1/.claude"; [ -z "${2:-}" ] || printf '%s\n' "$2" > "$HR/$1/.claude/vulyk-version"; }
hb() { VULYK_SRC="$HR/src" VULYK_HIVES_FILE="$HR/reg" VULYK_TODAY=2026-11-12 bash "$HB" "$@" 2>&1; echo "[exit=$?]"; }
mkhive a 0.51.0-dev.2; mkhive b 0.51.0-dev.1; mkhive c
printf '# local hives\n\n%s\n' "$HR/a" > "$HR/reg"
hb | expect "hives-behind: a hive on the local build passes" "[exit=0]"
printf '%s\n%s\n' "$HR/a" "$HR/b" > "$HR/reg"
out="$(hb)"
printf '%s' "$out" | expect "hives-behind: a hive one dev build behind with no hold is red" "[exit=1]"
printf '%s' "$out" | expect "hives-behind: the lagging hive is named with both versions" "0.51.0-dev.1"
printf '%s\n' "$HR/c" > "$HR/reg"
hb | expect "hives-behind: a hive with no version file is red" "[exit=1]"
printf '%s\n' "$HR/nope" > "$HR/reg"
hb | expect "hives-behind: a registered hive that is not on disk is red" "[exit=1]"
printf '%s | hold 2026-11-15 feature branch checked out\n' "$HR/b" > "$HR/reg"
out="$(hb)"
printf '%s' "$out" | expect "hives-behind: a live hold passes" "[exit=0]"
printf '%s' "$out" | expect "hives-behind: a held hive is listed with its reason" "feature branch checked out"
printf '%s | hold 2026-11-10 suite over cap\n' "$HR/b" > "$HR/reg"
hb | expect "hives-behind: an expired hold is red" "[exit=1]"
printf '%s | hold 2026-11-20 suite over cap\n' "$HR/b" > "$HR/reg"
hb | expect "hives-behind: a hold more than 7 days ahead is red" "[exit=1]"
printf '%s | hold 2026-11-19 suite over cap\n' "$HR/b" > "$HR/reg"
hb | expect "hives-behind: a hold exactly 7 days ahead passes" "[exit=0]"
printf '%s | hold 2026-11-31 suite over cap\n' "$HR/b" > "$HR/reg"   # not yet past, so only the real-day rule makes it red
out="$(VULYK_SRC="$HR/src" VULYK_HIVES_FILE="$HR/reg" VULYK_TODAY=2026-11-28 bash "$HB" 2>&1; echo "[exit=$?]")"
printf '%s' "$out" | expect "hives-behind: a hold on a day that does not exist is red" "[exit=1]"
printf '%s' "$out" | expect "hives-behind: the impossible day is named, not taken as expired" "is not a real day"
printf '%s | hold 2026-12-29 suite over cap\n' "$HR/b" > "$HR/reg"
VULYK_SRC="$HR/src" VULYK_HIVES_FILE="$HR/reg" VULYK_TODAY=2026-12-30 bash "$HB" 2>&1 | grep -q 'hold expired' \
  && ok "hives-behind: an expired hold before a year end is named expired" || bad "hives-behind: an expired hold before a year end is named expired"
printf '%s | hold 2027-01-03 holiday\n' "$HR/b" > "$HR/reg"
VULYK_SRC="$HR/src" VULYK_HIVES_FILE="$HR/reg" VULYK_TODAY=2026-12-30 bash "$HB" >/dev/null 2>&1
[ $? -eq 0 ] && ok "hives-behind: a hold across a year end within 7 days passes" || bad "hives-behind: a hold across a year end within 7 days passes"
printf '%s | hold soon suite over cap\n' "$HR/b" > "$HR/reg"
hb | expect "hives-behind: a malformed hold is red" "[exit=1]"
printf '%s | canary\n%s\n' "$HR/a" "$HR/b" > "$HR/reg"
hb --canaries | expect "hives-behind: --canaries lists the canary hive" "$HR/a"
hb --canaries | expect_absent "hives-behind: --canaries leaves the other hives out" "$HR/b"
printf '%s | canary\n' "$HR/a" > "$HR/reg"
hb | expect "hives-behind: a canary mark is not a hold and not malformed" "[exit=0]"
printf '%s | canary | hold 2026-11-15 canary smoke red\n' "$HR/b" > "$HR/reg"
hb | expect "hives-behind: a held canary is listed with its reason" "canary smoke red"
printf '%s\n' "$HR/a" > "$HR/reg"
hb --canaries | expect "hives-behind: no canary marked is red" "[exit=1]"
printf '# nobody\n' > "$HR/reg"
hb | expect "hives-behind: an empty registry is red" "[exit=1]"
rm -f "$HR/reg"
hb | expect "hives-behind: no registry is a refusal, not a pass" "[exit=2]"
for fx in original neighbour; do
  VULYK_TODAY=2026-11-12 bash "$HB" --check "$SRC/docs/defects/public-release-per-change.$fx.fixture" >/dev/null 2>&1
  [ $? -eq 1 ] && ok "hives-behind: the card's $fx fixture is red" || bad "hives-behind: the card's $fx fixture is red"
done
echo "--- hives-behind --busy: a hive in use is never upgraded (post-052-tails-01)"
hbz() { VULYK_HIVES_FILE="$HR/none" VULYK_SESSION_ROOTS="$1" bash "$HB" --busy "$2" 2>&1; echo "[exit=$?]"; }
bash "$HB" --slug 'E:/Hives/Acme_co' | expect "hives-behind --slug: drive, colon and underscore become dashes" "E--Hives-Acme-co"
bash "$HB" --slug '/Users/a/.claude/my.proj' | expect "hives-behind --slug: a dot becomes a dash" "-Users-a--claude-my-proj"
BZ="$T/hbz";   # not "busy": a path in an unknown line must not satisfy a busy check
 Z1="$BZ/root1"; Z2="$BZ/root2"; ZH="$BZ/My_hive.x"
mkdir -p "$Z1/projects" "$Z2/projects" "$ZH/docs/specs/s1"
zslug="$(bash "$HB" --slug "$ZH")"
hbz "$Z1 $Z2" "$ZH" | expect "hives-behind --busy: no transcript dir under any root is unknown, never idle" "unknown"
hbz "$Z1 $Z2" "$ZH" | expect "hives-behind --busy: unknown exits 1" "[exit=1]"
mkdir -p "$Z2/projects/$zslug"; : > "$Z2/projects/$zslug/old.jsonl"; touch -t 202601010000 "$Z2/projects/$zslug/old.jsonl"
out="$(hbz "$Z1 $Z2" "$ZH")"
printf '%s' "$out" | expect "hives-behind --busy: a transcript dir in the second root with only old transcripts is idle" "idle"
printf '%s' "$out" | expect "hives-behind --busy: idle exits 0" "[exit=0]"
: > "$Z2/projects/$zslug/fresh.jsonl"
out="$(hbz "$Z1 $Z2" "$ZH")"
printf '%s' "$out" | expect "hives-behind --busy: a transcript written in the last 60 minutes is busy" "busy"
printf '%s' "$out" | expect "hives-behind --busy: busy exits 1" "[exit=1]"
rm -f "$Z2/projects/$zslug/fresh.jsonl"; mkdir -p "$Z2/projects/$zslug/s/subagents"; : > "$Z2/projects/$zslug/s/subagents/a.jsonl"
hbz "$Z1 $Z2" "$ZH" | expect "hives-behind --busy: a fresh subagent transcript is busy too" "busy"
mkdir -p "$Z2/projects/$zslug/sid/subagents/workflows/wf"; : > "$Z2/projects/$zslug/sid/subagents/workflows/wf/agent-a.jsonl"
rm -rf "$Z2/projects/$zslug/s"
hbz "$Z1 $Z2" "$ZH" | expect "hives-behind --busy: a fresh Workflow agent transcript (depth 5) is busy" "busy"
rm -rf "$Z2/projects/$zslug/sid"
rm -rf "$Z2/projects/$zslug/s"; printf 'stamp=x\n' > "$ZH/docs/specs/s1/DRIVER"
out="$(hbz "$Z1 $Z2" "$ZH")"
printf '%s' "$out" | expect "hives-behind --busy: a DRIVER file is busy" "busy"
printf '%s' "$out" | expect "hives-behind --busy: the DRIVER is named" "docs/specs/s1/DRIVER"
rm -f "$ZH/docs/specs/s1/DRIVER"
hbz "$Z1 $Z2" "$BZ/nope" | expect "hives-behind --busy: a hive not on disk is not idle" "[exit=1]"
VULYK_HIVES_FILE="$HR/none" bash "$HB" --busy >/dev/null 2>&1; [ $? -eq 2 ] && ok "hives-behind --busy: no hive argument is a refusal (exit 2)" || bad "hives-behind --busy: no hive argument is a refusal (exit 2)"

echo "--- hives-behind --busy: a session opened in a hive subfolder (post-052-tails-03)"
bash "$HB" --slug 'e:/x' | expect "hives-behind --slug: a lower-case drive letter is read upper-case" "E--x"
hbz "$Z1 $Z2" "$ZH" | expect "hives-behind --busy: the subfolder fixtures start idle" "idle"
mkdir -p "$Z1/projects/$zslug-sub"
printf '{"type":"user","cwd":"%s/sub","x":1}\n' "$ZH" > "$Z1/projects/$zslug-sub/s.jsonl"
out="$(hbz "$Z1 $Z2" "$ZH")"
printf '%s' "$out" | expect "hives-behind --busy: a fresh session in a hive subfolder is busy" "busy"
printf '%s' "$out" | expect "hives-behind --busy: the subfolder session exits 1" "[exit=1]"
zbs="$(printf '%s/sub' "$ZH" | sed 's#/#\\\\\\\\#g')"   # the same cwd as Windows writes it, JSON-escaped: \\tmp\\...
printf '{"cwd":"%s"}\n' "$zbs" > "$Z1/projects/$zslug-sub/s.jsonl"
hbz "$Z1 $Z2" "$ZH" | expect "hives-behind --busy: a backslash cwd below the hive is busy" "busy"
case "$(uname -s 2>/dev/null)" in MINGW*|MSYS*|CYGWIN*)
  printf '{"cwd":"%s/sub"}
' "$(printf '%s' "$ZH" | tr '[:lower:]' '[:upper:]')" > "$Z1/projects/$zslug-sub/s.jsonl"
  hbz "$Z1 $Z2" "$ZH" | expect "hives-behind --busy: on Windows a cwd in another case is the same folder" "busy" ;;
esac
rm -rf "$Z1/projects/$zslug-sub"; mkdir -p "$Z1/projects/$zslug-x"
printf '{"cwd":"%s_x"}\n' "$ZH" > "$Z1/projects/$zslug-x/s.jsonl"
hbz "$Z1 $Z2" "$ZH" | expect "hives-behind --busy: a sibling hive sharing the name prefix leaves this one idle" "idle"
printf '{"type":"mode"}\n' > "$Z1/projects/$zslug-x/s.jsonl"
hbz "$Z1 $Z2" "$ZH" | expect "hives-behind --busy: a fresh prefix-folder transcript with no cwd is busy" "busy"
rm -rf "$Z1/projects/$zslug-x"

echo "--- hives-behind --busy: a cwd-less Workflow journal takes the cwd of its session's top transcript (tails-1115-05, T5)"
Z3="$BZ/root3"; AH="$BZ/Acme"; mkdir -p "$AH" "$BZ/Acme_two"
aslug="$(bash "$HB" --slug "$AH")"; a2="$Z3/projects/$aslug-two"
mkdir -p "$Z3/projects/$aslug" "$a2/sid/subagents/workflows/wf"
: > "$Z3/projects/$aslug/old.jsonl"; touch -t 202601010000 "$Z3/projects/$aslug/old.jsonl"
printf '{"type":"workflow","x":1}\n' > "$a2/sid/subagents/workflows/wf/agent-a.jsonl"   # fresh, no cwd
top_cwd() { printf '{"type":"user","cwd":"%s"}\n' "$1" > "$a2/sid.jsonl"; touch -t 202601010000 "$a2/sid.jsonl"; }
top_cwd "$BZ/Acme_two"
out="$(hbz "$Z3" "$AH")"
printf '%s' "$out" | expect "hives-behind --busy: a neighbour hive's cwd-less journal, its top transcript in the neighbour, is idle" "idle"
printf '%s' "$out" | expect "hives-behind --busy: that idle exits 0" "[exit=0]"
top_cwd "$AH"
hbz "$Z3" "$AH" | expect "hives-behind --busy: a cwd-less journal whose top transcript names the hive is busy" "busy"
top_cwd "$AH/sub"
hbz "$Z3" "$AH" | expect "hives-behind --busy: a cwd-less journal whose top transcript names a folder below the hive is busy" "busy"
printf '{"type":"mode"}\n' > "$a2/sid.jsonl"; touch -t 202601010000 "$a2/sid.jsonl"
hbz "$Z3" "$AH" | expect "hives-behind --busy: a cwd-less journal whose top transcript has no cwd is busy" "busy"
rm -f "$a2/sid.jsonl"
hbz "$Z3" "$AH" | expect "hives-behind --busy: a cwd-less journal with no top transcript is busy" "busy"
rm -rf "$Z3" "$AH" "$BZ/Acme_two"

echo "--- hives-behind --busy: no transcript folder is idle once the registry proves the naming rule (busy-no-transcripts-01)"
NH="$BZ/Never_opened"; NH2="$BZ/Also_never"; mkdir -p "$NH" "$NH2"   # no session ever ran in either
hbr() { VULYK_HIVES_FILE="$1" VULYK_SESSION_ROOTS="$Z1 $Z2" bash "$HB" --busy "$2" 2>&1; echo "[exit=$?]"; }
printf '# local hives\n%s | canary\n%s | hold 2026-11-19 x\n' "$NH" "$ZH" > "$BZ/reg-ok"   # ZH resolves (root2)
out="$(hbr "$BZ/reg-ok" "$NH")"
printf '%s' "$out" | expect "hives-behind --busy: no folder, a registry hive resolves - idle" "idle no session transcript folder"
printf '%s' "$out" | expect "hives-behind --busy: that idle exits 0" "[exit=0]"
printf '%s' "$out" | expect "hives-behind --busy: the idle line says no session has run there" "no Claude Code session has run there"
printf '%s\n%s\n' "$NH" "$NH2" > "$BZ/reg-none"
out="$(hbr "$BZ/reg-none" "$NH")"
printf '%s' "$out" | expect "hives-behind --busy: no registry hive resolves - unknown, never idle" "unknown"
printf '%s' "$out" | expect "hives-behind --busy: that unknown exits 1" "[exit=1]"
for pathless in '   ' "$(printf '\t')" ' | hold 2026-11-19 x'; do   # an empty slug would match every root's projects/
  printf '%s\n%s\n' "$NH" "$pathless" > "$BZ/reg-pathless"
  hbr "$BZ/reg-pathless" "$NH" | expect "hives-behind --busy: a registry line with no path proves nothing ('$pathless')" "[exit=1]"
done
mkdir -p "$NH/docs/specs/s1"; printf 'stamp=x\n' > "$NH/docs/specs/s1/DRIVER"
hbr "$BZ/reg-ok" "$NH" | expect "hives-behind --busy: a DRIVER still makes a folderless hive busy" "busy a build driver"
rm -rf "$NH/docs"; nslug="$(bash "$HB" --slug "$NH")"; mkdir -p "$Z1/projects/$nslug-sub"
printf '{"cwd":"%s/sub"}\n' "$NH" > "$Z1/projects/$nslug-sub/s.jsonl"
hbr "$BZ/reg-ok" "$NH" | expect "hives-behind --busy: a fresh subfolder session still makes it busy" "busy a session in a subfolder"
rm -rf "$Z1/projects/$nslug-sub"

echo "--- map: every slice stays within the ~80-line cap and 130 chars (post-052-tails-02; tails-1115-10, T92)"
map_over() { # map_over <map dir> - one line per memory/map/*.md over 80 lines or with a line over 130 chars
  local f n w
  for f in "$1"/*.md; do
    [ -f "$f" ] || continue; n="$(tr -d '\r' < "$f" | wc -l | tr -d ' ')"
    [ "$n" -le 80 ] || echo "${f##*/} is $n lines, over the 80-line cap - split it, do not cut facts"
    w="$(tr -d '\r' < "$f" | awk '{ if (length($0) > m) m = length($0) } END { print m + 0 }')"   # joined bullets would dodge the line cap
    [ "$w" -le 130 ] || echo "${f##*/} has a $w-char line - wrap it, the 80-line cap counts wrapped lines"
  done
  return 0
}
MO="$T/map-over"; mkdir -p "$MO"; awk 'BEGIN { for (i = 0; i < 81; i++) print "- fact " i }' > "$MO/cycle.md"
awk 'BEGIN { s = sprintf("%131s", ""); gsub(/ /, "m", s); print s }' > "$MO/agents.md"
awk 'BEGIN { s = sprintf("%130s", ""); gsub(/ /, "m", s); for (i = 0; i < 80; i++) print s }' > "$MO/scripts-ok.md"
got="$(map_over "$MO")"
case "$got" in *"agents.md has a 131-char line"*) ok "map: a 131-char line fails the check in a slice not named scripts*" ;;
  *) bad "map: a 131-char line in agents.md passed: '$got'" ;; esac
case "$got" in *"cycle.md is 81 lines"*) ok "map: an 81-line slice not named scripts* fails the check" ;;
  *) bad "map: an 81-line cycle.md passed: '$got'" ;; esac
case "$got" in *scripts-ok.md*) bad "map: 80 lines of 130 chars was flagged: '$got'" ;;
  *) ok "map: 80 lines of 130 chars is within the cap" ;; esac
over="$(map_over "$SRC/memory/map")"
[ -z "$over" ] && ok "map: every memory/map/*.md is within 80 lines and 130 chars" || bad "map: $over"
n_sl="$(ls "$SRC"/memory/map/scripts*.md 2>/dev/null | wc -l | tr -d ' ')"
[ "$n_sl" -ge 4 ] && ok "map: the scripts map is split into $n_sl slices" || bad "map: the scripts map is one slice ($n_sl) - split it by sub-area"

echo "--- commands: ship description, status line, busy guard (post-052-tails-01)"
sed -n '2p' "$SRC/.claude/commands/vulyk-ship.md" | expect_absent "ship: the description no longer says it never tags" "never tags"
sed -n '2p' "$SRC/.claude/commands/vulyk-ship.md" | expect "ship: the description names the local dev-build tag" "local dev-build tag"
expect "status: the lagging-hives line runs hives-behind.sh" "bash scripts/hives-behind.sh" < "$SRC/.claude/commands/vulyk-status.md"
sed -n '/^2a\. /,/^3\. /p' "$SRC/.claude/commands/vulyk-ship.md" | tr '\n' ' ' | tr -s ' ' > "$T/ship2a"
expect "ship 2a: every hive is asked --busy before its upgrade" "bash scripts/hives-behind.sh --busy <hive>" < "$T/ship2a"
expect "ship 2a: every ship re-checks each live hold" "every ship re-checks each live hold" < "$T/ship2a"
expect "ship 2a: the busy check runs again right before the hive commit" "right before the hive commit" < "$T/ship2a"
expect "ship 2a: a busy or unknown hive is held" "busy or unknown" < "$T/ship2a"
expect "ship 2a: the others follow only when at least one canary took the build" "At least one canary took the build" < "$T/ship2a"
expect "ship 2a: no canary taking the build holds every other hive" "No canary took the build" < "$T/ship2a"
expect "ship 2a: the local-beta step ends on hives-behind.sh" "bash scripts/hives-behind.sh" < "$T/ship2a"
expect "ship 2a: the step skips by name without a registry" "local beta: no hive registry" < "$T/ship2a"
expect "ship 2a: the dev build is never pushed" "never pushed" < "$T/ship2a"
expect "ship 2a: the plugin.json version moves with VERSION" "plugin.json" < "$T/ship2a"
expect "ship 2a: the dev build gets a local tag for the next upgrade" "git tag v<version>" < "$T/ship2a"
expect "ship 2a: a reverted canary is held too" "the reverted canary" < "$T/ship2a"
sed -n '/^2\. History/,/^2a\. /p' "$SRC/.claude/commands/vulyk-ship.md" | tr '\n' ' ' | tr -s ' ' \
  | expect "ship 2: in the VULYK source the build number comes from 2a" "step 2a numbers the build"
expect "ship 2a: the canaries go first" "bash scripts/hives-behind.sh --canaries" < "$T/ship2a"
expect "ship 2a: a red canary stops the rollout" "a red canary stops the rollout" < "$T/ship2a"

echo "--- beta-fixes-1113-03: a paperwork-only suite.log head, --go from the owner"
tr '\n' ' ' < "$SRC/.claude/agents/lead-review.md" | tr -d '\r' | tr -s ' ' \
  | expect "lead-review: a suite.log head that differs only by paperwork commits is not reported" "only by paperwork commits"
tr '\n' ' ' < "$SRC/.claude/commands/vulyk-plan.md" | tr -d '\r' | tr -s ' ' \
  | expect "plan: --go comes only from the owner's own words" "only from the owner's own words"
fi # guards

CHECKS="$(grep -c . "$LEDGER" || true)"
FAILED="$(grep -c . "$FAILS" || true)"
[ "$FAILED" -eq 0 ] || fail=1
echo "maintenance.test.sh: $CHECKS checks, $FAILED failed"
exit $fail
