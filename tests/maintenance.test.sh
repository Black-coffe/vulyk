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
PYBIN="$(command -v python3 || command -v python)" || { echo "maintenance.test.sh: needs python3 or python"; exit 1; }
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
DESCRIPTIONS_MAX_BYTES=4623     # agents 2 907 + commands 1 716, measured 2026-09-29

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
if shipped_render "$SRC/CLAUDE.md" "$T/shipped.md" 2>"$T/render.err"; then
  if why="$(within_budget "$T/shipped.md" "$CONSTITUTION_MAX_BYTES" "$CONSTITUTION_MAX_LINES")"; then
    ok "shipped constitution within budget ($(size_of "$T/shipped.md") B, $(lines_of "$T/shipped.md") lines)"
  else bad "shipped constitution over budget: $why"; fi
else bad "could not render the shipped constitution: $(cat "$T/render.err")"; fi
for m in VULYK:PROFILE:START VULYK:PROFILE:END VULYK:COMMANDS:START VULYK:COMMANDS:END; do
  [ "$(grep -c "<!-- $m -->" "$SRC/CLAUDE.md")" -eq 1 ] && ok "marker $m once" || bad "marker $m missing or repeated"
done
desc="$(cat "$SRC"/.claude/agents/*.md "$SRC"/.claude/commands/*.md | tr -d '\r' | grep '^description:' | wc -c | tr -d ' ')"
if [ "$desc" -le "$DESCRIPTIONS_MAX_BYTES" ]; then ok "agent + command descriptions within $DESCRIPTIONS_MAX_BYTES B ($desc B)"
else bad "agent + command descriptions $desc B > $DESCRIPTIONS_MAX_BYTES B"; fi

# --- due maintenance: the SessionStart brief (auto-maintenance-02) ---------------------------------
BRIEF_HOOK="$SRC/.claude/hooks/session-start-brief.sh"
iso_ago() { date -u -d "-$1 days" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-"$1"d +%Y-%m-%dT%H:%M:%SZ; }
hive() { # hive <name> - a fresh fixture hive: git repo on main with one commit, empty memory
  local h="$T/$1"
  mkdir -p "$h/memory/learnings" "$h/memory/stats" "$h/memory/map"
  echo "# learnings" > "$h/memory/learnings/README.md"
  git -C "$h" init -q -b main 2>/dev/null || { git -C "$h" init -q; git -C "$h" checkout -q -b main; }
  git -C "$h" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  echo "$h"
}
brief_of() { echo '{}' | CLAUDE_PROJECT_DIR="$1" bash "${2:-$BRIEF_HOOK}" 2>&1; }
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

CHECKS="$(grep -c . "$LEDGER" || true)"
FAILED="$(grep -c . "$FAILS" || true)"
[ "$FAILED" -eq 0 ] || fail=1
echo "maintenance.test.sh: $CHECKS checks, $FAILED failed"
exit $fail
