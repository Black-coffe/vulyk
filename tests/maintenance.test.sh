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

CHECKS="$(grep -c . "$LEDGER" || true)"
FAILED="$(grep -c . "$FAILS" || true)"
[ "$FAILED" -eq 0 ] || fail=1
echo "maintenance.test.sh: $CHECKS checks, $FAILED failed"
exit $fail
