#!/usr/bin/env bash
# Reads PART lines (tests/full-suite.sh output, a round's suite.log) and names every part to cut.
#
#   Usage: bash scripts/suite-parts-check.sh <file>
#
# A PART line: `PART <name> <ok|FAIL|SKIP|CAP> <N>s cap <C>s[ - <reason>]`. For each CAP line, each cap
# over 300 and each N*10 > C*7 (a part past 70% of its cap) it prints
#   suite-parts-check: cut part <name>: <N>s of cap <C>s (<cap|over-cap|grew>)
# Exit 1 on any such line; 0 when none, including a readable file with no PART line (defects-check.sh
# runs every block check on any argument); 2 with no argument or a path that is not a readable regular
# file: missing input is a refusal, never a pass (as portability-check.sh refuses a named missing file).
[ $# -ge 1 ] && [ -n "$1" ] || { echo "usage: bash scripts/suite-parts-check.sh <file>" >&2; exit 2; }
[ -f "$1" ] && [ -r "$1" ] || { echo "suite-parts-check: no such file: $1" >&2; exit 2; }
awk '
  $1 == "PART" && NF >= 6 && $5 == "cap" && $4 ~ /^[0-9]+s$/ && $6 ~ /^[0-9]+s/ {
    n = $4; sub(/s$/, "", n); c = $6; sub(/s.*$/, "", c)
    why = ""
    if ($3 == "CAP") why = "cap"
    else if (c + 0 > 300) why = "over-cap"
    else if (n * 10 > c * 7) why = "grew"
    if (why != "") { printf "suite-parts-check: cut part %s: %ss of cap %ss (%s)\n", $2, n, c, why; bad = 1 }
  }
  END { exit bad ? 1 : 0 }
' "$1"
