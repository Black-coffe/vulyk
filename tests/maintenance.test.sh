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

echo "--- git guard: fails open, card fixtures"
out="$(printf 'not json' | bash "$GUARD" 2>&1; echo "exit=$?")"
[ "$out" = "exit=0" ] && ok "git-guard: broken JSON exits 0, silent" || bad "git-guard: broken JSON - got: $out"
mkdir -p "$T/nopy"
out="$(printf '{"tool_name":"Bash","agent_id":"a","tool_input":{"command":"git stash"}}' | PATH="$T/nopy" "$BASH" "$GUARD" 2>&1; echo "exit=$?")"
[ "$out" = "exit=0" ] && ok "git-guard: no interpreter exits 0, silent" || bad "git-guard: no interpreter - got: $out"
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
BZ="$T/busy"; Z1="$BZ/root1"; Z2="$BZ/root2"; ZH="$BZ/My_hive.x"
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
rm -rf "$Z1/projects/$zslug-sub"; mkdir -p "$Z1/projects/$zslug-x"
printf '{"cwd":"%s_x"}\n' "$ZH" > "$Z1/projects/$zslug-x/s.jsonl"
hbz "$Z1 $Z2" "$ZH" | expect "hives-behind --busy: a sibling hive sharing the name prefix leaves this one idle" "idle"
printf '{"type":"mode"}\n' > "$Z1/projects/$zslug-x/s.jsonl"
hbz "$Z1 $Z2" "$ZH" | expect "hives-behind --busy: a fresh prefix-folder transcript with no cwd is busy" "busy"
rm -rf "$Z1/projects/$zslug-x"

echo "--- map: the scripts slices stay within the ~80-line cap (post-052-tails-02)"
n_sl=0
for f in "$SRC"/memory/map/scripts*.md; do
  [ -f "$f" ] || continue; n_sl=$((n_sl + 1)); n="$(wc -l < "$f" | tr -d ' ')"
  [ "$n" -le 80 ] && ok "map: ${f##*/} is $n lines, within 80" || bad "map: ${f##*/} is $n lines, over the 80-line cap - split it, do not cut facts"
  w="$(awk '{ if (length($0) > m) m = length($0) } END { print m + 0 }' "$f")"   # joined bullets would dodge the line cap
  [ "$w" -le 130 ] && ok "map: ${f##*/} lines are within 130 chars" || bad "map: ${f##*/} has a $w-char line - wrap it, the 80-line cap counts wrapped lines"
done
[ "$n_sl" -ge 2 ] && ok "map: the scripts map is split into $n_sl slices" || bad "map: the scripts map is one slice ($n_sl) - split it by sub-area"

echo "--- commands: ship description, status line, busy guard (post-052-tails-01)"
sed -n '2p' "$SRC/.claude/commands/vulyk-ship.md" | expect_absent "ship: the description no longer says it never tags" "never tags"
sed -n '2p' "$SRC/.claude/commands/vulyk-ship.md" | expect "ship: the description names the local dev-build tag" "local dev-build tag"
expect "status: the lagging-hives line runs hives-behind.sh" "bash scripts/hives-behind.sh" < "$SRC/.claude/commands/vulyk-status.md"
sed -n '/^2a\. /,/^3\. /p' "$SRC/.claude/commands/vulyk-ship.md" | tr '\n' ' ' | tr -s ' ' > "$T/ship2a"
expect "ship 2a: every hive is asked --busy before its upgrade" "bash scripts/hives-behind.sh --busy <hive>" < "$T/ship2a"
expect "ship 2a: every ship re-checks each live hold" "every ship re-checks each live hold" < "$T/ship2a"
expect "ship 2a: the busy check runs again right before the hive commit" "right before the hive commit" < "$T/ship2a"
expect "ship 2a: a busy or unknown hive is held" "busy or unknown" < "$T/ship2a"
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

CHECKS="$(grep -c . "$LEDGER" || true)"
FAILED="$(grep -c . "$FAILS" || true)"
[ "$FAILED" -eq 0 ] || fail=1
echo "maintenance.test.sh: $CHECKS checks, $FAILED failed"
exit $fail
