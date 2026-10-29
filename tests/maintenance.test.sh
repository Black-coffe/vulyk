#!/usr/bin/env bash
# Self-maintenance contract (docs/specs/auto-maintenance): the always-loaded text stays inside its byte
# budget. No model calls, no network.
#
#   Usage: bash tests/maintenance.test.sh            # from the VULYK repo root
#
# Budget (ADR-013 D7, report rrsi-self-improvement §5.3). The caps are numbers here on purpose:
# raising one is a visible diff the owner reviews, paid only by an owner quote or an accepted ADR.
# Sizes are measured CR-stripped, which equals the git blob on every platform.
set -u
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
desc="$(cat "$SRC"/.claude/agents/*.md "$SRC"/.claude/commands/*.md | tr -d '\r' | grep '^description:' | wc -c | tr -d ' ')"
if [ "$desc" -le "$DESCRIPTIONS_MAX_BYTES" ]; then ok "agent + command descriptions within $DESCRIPTIONS_MAX_BYTES B ($desc B)"
else bad "agent + command descriptions $desc B > $DESCRIPTIONS_MAX_BYTES B"; fi

# rules_always_over <dir> - prints each path-less rules file over RULES_ALWAYS_MAX_LINES (one with paths: is exempt)
rules_always_over() {
  local f
  for f in "$1"/*.md; do
    [ -f "$f" ] || continue
    tr -d '\r' < "$f" | sed -n '1{/^---$/!q;d};/^---$/q;/^paths:/{p;q}' | grep -q . && continue
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

# --- due maintenance: the SessionStart brief (auto-maintenance-02) ---------------------------------
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

echo "--- due maintenance: gc"
H="$(hive gc-stub)"; stub "$H/memory/learnings/2026-09-14_090058.md"
brief_of "$H" | expect "a stub learning makes gc due" "gc (1 stub, 0 raw learnings)"
H="$(hive gc-nine)"; for i in 1 2 3 4 5 6 7 8 9; do echo "- real $i" > "$H/memory/learnings/l$i.md"; done
brief_of "$H" | expect_absent "9 real learnings: gc not due" "maintenance due"
echo "- real 10" > "$H/memory/learnings/l10.md"
brief_of "$H" | expect "10 real learnings: gc due" "gc (0 stub, 10 raw learnings)"
echo "- merged" > "$H/memory/learnings/CONSOLIDATED.md"
brief_of "$H" | expect "CONSOLIDATED.md is not counted as raw" "gc (0 stub, 10 raw learnings)"

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

# --- /vulyk-gc refuses a gutted CONSOLIDATED.md (hindsight-harvest-03) --------------------------------
echo "--- /vulyk-gc commit line refuses to commit a CONSOLIDATED.md that lost more than half"
GC_LINE="$(tr -d '\r' < "$SRC/.claude/commands/vulyk-gc.md" | sed -n 's/^`\(f=memory\/learnings\/CONSOLIDATED\.md;.*\)`$/\1/p')"
[ -n "$GC_LINE" ] && ok "vulyk-gc.md carries the guarded commit line" || bad "no guarded commit line in vulyk-gc.md"
entries() { local i; printf '# Consolidated learnings\n\n## Topic\n'; for i in $(seq 1 "$1"); do printf '%s. lesson number %s, with a reason\n' "$i" "$i"; done; }
gc_case() { # gc_case <dir> <entries at HEAD, or new> <entries now> [index name] - runs the line, prints its output
  local g="$T/$1" idx="memory/${4:-memory.md}"; mkdir -p "$g/memory/learnings" && cd "$g" || return 1
  git init -q -b main . && git config user.name t && git config user.email t@t && git config core.autocrlf false
  printf '# index\n' > "$idx"
  if [ "$2" != new ]; then entries "$2" > memory/learnings/CONSOLIDATED.md; fi
  git add -A && git commit -q -m base
  entries "$3" > memory/learnings/CONSOLIDATED.md
  printf -- '- a pointer gc added\n' >> "$idx"
  bash -c "$GC_LINE" 2>&1; echo "commits=$(git rev-list --count HEAD)"
  echo "committed: $(git diff --name-only HEAD~1 HEAD 2>/dev/null | paste -sd' ' -)"
  cd "$SRC" || return 1
}
gc_case cut 10 4 > "$T/gc-cut"
expect "10 entries -> 4: refused" "gc: refused - CONSOLIDATED.md lost more than half" < "$T/gc-cut"
expect "a refusal commits nothing" "commits=1" < "$T/gc-cut"
expect "the counts are printed" "CONSOLIDATED.md: entries 10→4" < "$T/gc-cut"
gc_case trim 10 7 > "$T/gc-trim"
expect_absent "10 entries -> 7: not refused" "refused" < "$T/gc-trim"
expect "10 entries -> 7: committed" "commits=2" < "$T/gc-trim"
gc_case fresh new 3 > "$T/gc-fresh"
expect "a file new at HEAD: committed" "commits=2" < "$T/gc-fresh"
expect "a file new at HEAD prints 0 as the old count" "CONSOLIDATED.md: entries 0→3" < "$T/gc-fresh"
expect "the index is committed with the learnings" "committed: memory/learnings/CONSOLIDATED.md memory/memory.md" < "$T/gc-trim"
gc_case upper 10 7 MEMORY.md > "$T/gc-upper"   # a hive whose index is memory/MEMORY.md failed every gc run
expect "an index named MEMORY.md: committed" "commits=2" < "$T/gc-upper"
expect "an index named MEMORY.md: committed with the learnings" "committed: memory/MEMORY.md memory/learnings/CONSOLIDATED.md" < "$T/gc-upper"

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
dump_from_deep() { ( cd "$H/sub/deep" && env -u CLAUDE_PROJECT_DIR HOME="$(W "$TH")" USERPROFILE="$(W "$TH")" \
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
pc_case hivedel; rm "$PCD/.claude/agents/worker-test.md"; echo 0.42.0 > "$PCD/.claude/vulyk-version"; pc_run
expect "prompt-check: a framework agent a hive deleted exits 0 (upgrade keeps host deletions)" "exit=0;" < "$T/pc-out"
expect "prompt-check: the hive deletion is a warn line" "prompt-check: warn scripts/telemetry.sh:1: telemetry: AGENTS names worker-test" < "$T/pc-out"
pc_case agentspan; printf '\nDispatch it with `Agent drone-ghost` here.\n' >> "$PCD/$CMDF"; pc_run
pc_bites "an agent name inside a longer span (post-043-tails)" agent
pc_case noverbs; sed_inplace 's/^case "\$VERB" in/case "$CMD" in/' "$PCD/scripts/cycle.sh"; pc_run
expect "prompt-check: a cycle.sh without a verb dispatcher exits 0" "exit=0;" < "$T/pc-out"
grep -c '^prompt-check: warn scripts/cycle.sh:1: verb: ' "$T/pc-out" > "$T/pc-nv" 2>&1
expect "prompt-check: a cycle.sh without a verb dispatcher is one warn line, not a silent skip" "1" < "$T/pc-nv"

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
CASES
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

CHECKS="$(grep -c . "$LEDGER" || true)"
FAILED="$(grep -c . "$FAILS" || true)"
[ "$FAILED" -eq 0 ] || fail=1
echo "maintenance.test.sh: $CHECKS checks, $FAILED failed"
exit $fail
