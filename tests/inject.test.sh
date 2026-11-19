#!/usr/bin/env bash
# The defects-inject hook contract (docs/specs/self-learning/contract.md §1 effective status, §3),
# driven through a fixture library - no model calls, no network. Covers .claude/hooks/defects-inject.sh:
# which cards are injected (every card but a revoked one, block cards included), how a target
# matches (path glob on file_path / notebook_path, a path token or a `cmd:` regex on a Bash line, a `tool:`
# regex on tool_name), the session + agent dedup, `reset` on SessionStart, the 12-line budget and its fold
# line, narrowest-first order, How-to / Allowed rendering, foldered cards, and the latency budget.
#
#   Usage: bash tests/inject.test.sh                  # from the VULYK repo root, every part
#          bash tests/inject.test.sh --part <name>    # functional (every assert but the medians) or latency
#          bash tests/inject.test.sh --list-parts     # the part names, one per line
# tests/full-suite.sh runs the functional part among its parallel jobs and the latency part alone, last.
#
# Latency runs against $VULYK_LATENCY_LIBRARY (a hive's docs/defects, e.g. the pilot's 19 real cards) copied to a
# temp dir when that variable names a folder, else against the fixture library. Asserted <= 400 ms median; the
# contract target is <= 200 ms and the measured median is printed either way.
set -u
PARTS="functional latency" PART=''
while [ $# -gt 0 ]; do
  case "$1" in
    --list-parts) printf '%s
' $PARTS; exit 0 ;;
    --part)
      PART="${2:-}"; shift
      case " $PARTS " in
        *" $PART "*) ;;
        *) echo "unknown part '$PART' - parts:" >&2; printf '%s
' $PARTS >&2; exit 1 ;;
      esac ;;
    *) echo "usage: bash tests/inject.test.sh [--part <name>] [--list-parts]" >&2; exit 2 ;;
  esac
  shift
done
part() { [ -z "$PART" ] || [ "$PART" = "$1" ]; } # `if part <name>; then ... fi` wraps each part
SRC="$(cd "$(dirname "$0")/.." && pwd)"
. "$SRC/scripts/lib.sh"   # vulyk_python, run_capped, sed_inplace
HOOK="$SRC/.claude/hooks/defects-inject.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fail=0
vulyk_python || { echo "inject.test.sh: needs python3 or python"; exit 1; }
PYBIN="$VULYK_PY"
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

expect_eq() { # expect_eq <label> <want> <got>
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 - expected '$2', got '$3'"; fi
}

expect_silent() { # expect_silent <label>   (reads run's output: the hook's stdout, then rc=N)
  local label="$1" out; out="$(cat)"
  if [ "$out" = "rc=0" ]; then ok "$label"
  else bad "$label - expected no output and exit 0, got:"; printf '%s\n' "$out" | sed 's/^/        /'; fi
}

ctx() { # the additionalContext of run's output, decoded (✗ and — as themselves)
  head -1 | "$PYBIN" -c 'import json,sys; sys.stdout.buffer.write(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"].encode("utf-8"))' 2>/dev/null
}

run() { # run <root> <json> [arg]   -> the hook's stdout, then a line rc=<exit code>
  local out rc root="$1" json="$2"; shift 2
  out="$(printf '%s' "$json" | CLAUDE_PROJECT_DIR="$root" bash "$HOOK" "$@")"; rc=$?
  [ -z "$out" ] || printf '%s\n' "$out"
  printf 'rc=%s' "$rc"
}

now_us() {
  if [ -n "${EPOCHREALTIME:-}" ]; then local t="${EPOCHREALTIME//[.,]/}"; echo "$t"
  else "$PYBIN" -c 'import time; print(int(time.time() * 1e6))'; fi
}

median_ms() { # median_ms <root> <json>   -> median of 30 hook calls, in ms
  local i s e; : > "$T/lat"
  for i in $(seq 30); do
    s="$(now_us)"; printf '%s' "$2" | CLAUDE_PROJECT_DIR="$1" bash "$HOOK" >/dev/null 2>&1; e="$(now_us)"
    echo $(( (e - s) / 1000 )) >> "$T/lat"
  done
  sort -n "$T/lat" | sed -n '15p;16p' | awk '{ s += $1 } END { printf "%d", s / 2 }'
}

# --- case 0: syntax ---------------------------------------------------------------------------
echo "--- syntax"
if bash -n "$HOOK" 2>/dev/null; then ok "bash -n .claude/hooks/defects-inject.sh"
else bad "bash -n .claude/hooks/defects-inject.sh failed"; bash -n "$HOOK"; exit 1; fi

# --- the fixture library ----------------------------------------------------------------------
HIVE="$T/hive"; D="$HIVE/docs/defects"
mkdir -p "$D/fixtures" "$HIVE/pipeline"
W="$(cd "$HIVE" && { pwd -W 2>/dev/null || pwd; })"      # the root as Claude Code writes file_path
echo '{}' > "$D/fixtures/a.json"; echo '{}' > "$D/fixtures/b.json"
cat > "$D/README.md" <<'EOF'
# Defect library - the index, never a card
EOF
cat > "$D/voice-text.md" <<'EOF'
---
id: voice-text
title: Voice text rule
status: text
paths: ["pipeline/voiceover.py", "EDIT_*.json"]
---

# Voice text rule

## Never
- Never A1 cut on the word-end mark.
- Never A2 raise the music
  before lead_s.

## Allowed
- ALLOWEDLINE is not injected.
EOF
cat > "$D/speech-block.md" <<'EOF'
---
id: speech-block
title: Blocking class
status: block
check: python pipeline/verify.py <arg>
fixtures: [docs/defects/fixtures/a.json, docs/defects/fixtures/b.json]
paths: ["pipeline/voiceover.py"]
---

## Never
- BLOCKNEVER is injected like a text card.
EOF
cat > "$D/old-revoked.md" <<'EOF'
---
id: old-revoked
title: Lifted rule
status: revoked
paths: ["pipeline/**", "*.json", "cmd:edit_build"]
---

## Never
- REVOKEDNEVER must not be injected.
EOF
cat > "$D/block-onefix.md" <<'EOF'
---
id: block-onefix
title: Block with one fixture
status: block
check: python pipeline/verify.py <arg>
fixtures: [docs/defects/fixtures/a.json, docs/defects/fixtures/missing.json]
paths: ["cmd:edit_build\\.py|draft_cut\\.py"]
---

## Never
- CMDNEVER build without the check.
EOF
cat > "$D/cmd-text.md" <<'EOF'
---
id: cmd-text
title: Build commands
status: text
paths: ["cmd:edit_build\\.py|draft_cut\\.py"]
---

## Never
- CMDTEXTNEVER build by hand.
EOF
cat > "$D/block-nocheck.md" <<'EOF'
---
id: block-nocheck
title: Block with no check
status: block
paths: ["cmd:edit_build"]
---

## Never
- NOCHECKNEVER is injected: nothing else speaks for it.
EOF
# CRLF and the Russian heading must be tolerated.
printf -- '---\r\nid: json-card\r\ntitle: JSON sheets\r\nstatus: text\r\npaths: ["*.json"]\r\n---\r\n\r\n## Нельзя\r\n\r\n- JSONNEVER hand-edit a sheet.\r\n' \
  > "$D/json-card.md"
LONG="long line"
for i in 01 02 03 04 05 06 07 08; do
  printf -- '---\nid: big-%s\ntitle: Big %s\nstatus: text\npaths: ["big/**"]\n---\n\n## Never\n- BIG%s %s\n' \
    "$i" "$i" "$i" "$LONG" > "$D/big-$i.md"
done
NOLIB="$T/nolib"; mkdir -p "$NOLIB/docs"

edit() { # edit <session> <path> [agent]   -> an Edit PreToolUse payload
  local a=""; [ -n "${3:-}" ] && a=",\"agent_id\":\"$3\""
  printf '{"session_id":"%s","tool_name":"Edit","tool_input":{"file_path":"%s","old_string":"a","new_string":"b"},"cwd":"%s"%s}' \
    "$1" "$2" "$W" "$a"
}
bashcall() { # bashcall <session> <command>
  printf '{"session_id":"%s","tool_name":"Bash","tool_input":{"command":"%s"},"cwd":"%s"}' "$1" "$2" "$W"
}
pscall() { # pscall <session> <command>   -> a PowerShell PreToolUse payload
  printf '{"session_id":"%s","tool_name":"PowerShell","tool_input":{"command":"%s"},"cwd":"%s"}' "$1" "$2" "$W"
}

if part functional; then # --- part functional: every case but the latency medians
# --- what is injected -------------------------------------------------------------------------
echo "--- inject"
o="$(run "$HIVE" "$(edit s1 "$W/pipeline/voiceover.py")")"
printf '%s' "$o" | expect "the output is the PreToolUse JSON form" '"hookEventName": "PreToolUse"'
printf '%s' "$o" | expect "exit 0" "rc=0"
c="$(printf '%s' "$o" | ctx)"
printf '%s' "$c" | expect "Edit on a matching glob names the text card" "voice-text — Voice text rule"
printf '%s' "$c" | expect "its Never lines come prefixed with ✗" "✗ Never A1 cut on the word-end mark."
printf '%s' "$c" | expect "a wrapped Never line is joined" "✗ Never A2 raise the music before lead_s."
printf '%s' "$c" | expect "an Allowed line on a card with Never lines prints as ✓" "✓ ALLOWEDLINE is not injected."
printf '%s' "$c" | expect "a block card (check + 2 fixtures) is injected like a text card (defects-check --files gates it)" "✗ BLOCKNEVER is injected like a text card."
printf '%s' "$c" | expect_absent "a revoked card is not injected" "REVOKEDNEVER"
if [ -d "$HIVE/.claude/state/defects" ]; then ok "state lives under .claude/state/defects/"
else bad "no .claude/state/defects/ after an injection"; fi

run "$HIVE" "$(edit s1 "$W/pipeline/voiceover.py")" | expect_silent "same session + agent twice: the second call is silent"
o="$(run "$HIVE" "$(edit s1 "$W/pipeline/voiceover.py" agent-7)")"
printf '%s' "$o" | ctx | expect "a different agent_id in the same session injects" "voice-text — Voice text rule"
run "$HIVE" "$(edit s1 "$W/pipeline/voiceover.py" agent-7)" | expect_silent "that agent's second call is silent"

o="$(run "$HIVE" '{"session_id":"s5","tool_name":"NotebookEdit","tool_input":{"notebook_path":"edits/EDIT_3.json"}}')"
c="$(printf '%s' "$o" | ctx)"
printf '%s' "$c" | expect "notebook_path matches; a glob without / matches the basename" "voice-text"
printf '%s' "$c" | expect "a CRLF card with ## Нельзя is read" "✗ JSONNEVER hand-edit a sheet."

o="$(run "$HIVE" "$(bashcall s2 'cd pipeline && py -3 edit_build.py x.json')")"
c="$(printf '%s' "$o" | ctx)"
printf '%s' "$c" | expect "Bash injects via a cmd: regex" "✗ CMDTEXTNEVER build by hand."
printf '%s' "$c" | expect "a declared block with a check but <2 fixtures is injected too" "✗ CMDNEVER build without the check."
printf '%s' "$c" | expect "a block card with no check is injected" "✗ NOCHECKNEVER is injected"
printf '%s' "$c" | expect "Bash injects via a path token" "✗ JSONNEVER hand-edit a sheet."
printf '%s' "$c" | expect_absent "Bash: a card whose globs miss every token stays out" "voice-text"
printf '%s' "$c" | expect_absent "Bash: a revoked cmd: card stays out" "REVOKEDNEVER"
o="$(run "$HIVE" "$(bashcall s6 "python \\\"$W/pipeline/voiceover.py\\\" --check")")"
printf '%s' "$o" | ctx | expect "Bash: a quoted absolute path token is made repo-relative" "voice-text"
# P10-15: a quoted path with a space was split into pieces no glob matched.
printf -- '---\nid: notes-space\ntitle: Notes with a space\nstatus: text\npaths: ["My Notes/*.md"]\n---\n\n## Never\n- SPACENEVER edit notes blind.\n' > "$D/notes-space.md"
run "$HIVE" "$(bashcall s6q 'python \"My Notes/a.md\" | wc -l')" | ctx | expect "P10-15: a double-quoted path with a space matches its glob" "✗ SPACENEVER"
run "$HIVE" "$(bashcall s6r "sed -i.bak 1d 'My Notes/b.md'")" | ctx | expect "P10-15: a single-quoted path with a space matches too" "✗ SPACENEVER"
run "$HIVE" "$(bashcall s6s "python \\\"$W/My Notes/c.md\\\"")" | ctx | expect "P10-15: a quoted absolute path with a space is made repo-relative" "✗ SPACENEVER"
run "$HIVE" "$(bashcall s6t 'touch \"a\" \"My Notes/d.md\"')" | ctx | expect "P10-15: quotes pair left to right across tokens" "✗ SPACENEVER"
run "$HIVE" "$(bashcall s6u 'touch My Notes/a.md')" | expect_silent "P10-15 neighbour: the unquoted words are two arguments, no match"
rm -f "$D/notes-space.md"
run "$HIVE" "$(bashcall s3 'ls -la docs && git status')" | expect_silent "an unrelated Bash command is silent"
# audit-fixes-1113-04: a PowerShell command line is read as a Bash one, for cmd: entries and for paths.
cb="$(run "$HIVE" "$(bashcall ps1b 'cd pipeline; py -3 edit_build.py x.json')" | ctx)"
cps="$(run "$HIVE" "$(pscall ps1p 'cd pipeline; py -3 edit_build.py x.json')" | ctx)"
printf '%s' "$cps" | expect "a PowerShell command gets the card its cmd: entry names" "✗ CMDTEXTNEVER build by hand."
if [ -n "$cb" ] && [ "$cps" = "$cb" ]; then ok "a PowerShell command gets the card text the same command gets under Bash"
else bad "a PowerShell command gets the card text the same command gets under Bash - Bash:"
  printf '%s\n' "$cb" | sed 's/^/        /'; echo "      PowerShell:"; printf '%s\n' "$cps" | sed 's/^/        /'; fi
run "$HIVE" "$(pscall ps2 'Get-Content -Path .\\pipeline\\voiceover.py | Set-Content x.txt')" | ctx \
  | expect "a PowerShell command naming a file inside a card's glob gets that card" "voice-text — Voice text rule"
run "$HIVE" "$(pscall ps3 'Get-ChildItem docs; git status')" | expect_silent "an unrelated PowerShell command is silent"
# J1 (tails-1115-07, T78): a command that only reads (search, print, list, count, compare; no redirect to a file, no
# in-place flag) gets no card; one that writes, any git command (lead-review's cards come from one `git diff`) and
# one the hook cannot read get them as before.
printf -- '---\nid: lib-card\ntitle: Lib rule\nstatus: text\npaths: ["scripts/**"]\n---\n\n## Never\n- LIBNEVER edit lib blind.\n' > "$D/lib-card.md"
run "$HIVE" "$(bashcall j1a 'grep -n x scripts/lib.sh')" | expect_silent "J1: a read-only command gets no card (grep -n x scripts/lib.sh)"
run "$HIVE" "$(pscall j1b 'Get-Content scripts/lib.sh | Select-String -Pattern x')" \
  | expect_silent "J1: a read-only command gets no card (a PowerShell read: Get-Content | Select-String)"
run "$HIVE" "$(bashcall j1c 'cat scripts/lib.sh | wc -l 2>/dev/null; ls scripts && diff scripts/lib.sh scripts/a.sh')" \
  | expect_silent "J1: a read-only command gets no card (a pipe, a list, a /dev/null redirect, a compare)"
run "$HIVE" "$(bashcall j1d 'grep -n x scripts/lib.sh | tee out.txt')" | ctx | expect "J1 neighbour: a read piped into a writer gets the card" "✗ LIBNEVER"
run "$HIVE" "$(bashcall j1e 'grep -n x scripts/lib.sh > out.txt')" | ctx | expect "J1 neighbour: a read redirected to a file gets the card" "✗ LIBNEVER"
run "$HIVE" "$(bashcall j1f 'sed -i.bak s/x/y/ scripts/lib.sh')" | ctx | expect "J1 neighbour: sed -i.bak gets the card" "✗ LIBNEVER"
run "$HIVE" "$(bashcall j1g 'git diff HEAD~1..HEAD -- scripts/lib.sh')" | ctx | expect "J1 neighbour: git diff <range> -- <path> gets the card" "✗ LIBNEVER"
run "$HIVE" "$(bashcall j1h 'cat $(echo scripts/lib.sh)')" | ctx | expect "J1 neighbour: a command the hook cannot read gets the card" "✗ LIBNEVER"
run "$HIVE" "$(pscall j1i 'Get-Content scripts/lib.sh > out.txt')" | ctx | expect "J1 neighbour: a PowerShell read redirected to a file gets the card" "✗ LIBNEVER"
rm -f "$D/lib-card.md"

# --- reset on SessionStart --------------------------------------------------------------------
echo "--- reset"
run "$HIVE" '{"session_id":"s1","source":"startup"}' reset | expect_silent "reset prints nothing"
run "$HIVE" "$(edit s1 "$W/pipeline/voiceover.py")" | expect_silent "source=startup does not clear the session"
run "$HIVE" '{"session_id":"s1","source":"resume"}' reset >/dev/null
run "$HIVE" "$(edit s1 "$W/pipeline/voiceover.py")" | expect_silent "source=resume does not clear the session"
run "$HIVE" '{"session_id":"s2","source":"compact"}' reset >/dev/null
run "$HIVE" "$(edit s1 "$W/pipeline/voiceover.py")" | expect_silent "compact of another session leaves this one alone"
run "$HIVE" '{"session_id":"s1","source":"compact"}' reset >/dev/null
run "$HIVE" "$(edit s1 "$W/pipeline/voiceover.py")" | ctx | expect "source=compact clears the session: it injects again" "voice-text"
run "$HIVE" '{"session_id":"s1","source":"clear"}' reset >/dev/null
run "$HIVE" "$(edit s1 "$W/pipeline/voiceover.py" agent-7)" | ctx | expect "source=clear clears the session too" "voice-text"

# --- budget -----------------------------------------------------------------------------------
echo "--- budget"
c="$(run "$HIVE" "$(edit s4 "$W/big/x.txt")" | ctx)"
n="$(printf '%s\n' "$c" | sed '1d;/^+[0-9]* cards: /d' | grep -c .)"
if [ "$n" -le 12 ]; then ok "the shown cards stay within 12 lines after the header ($n)"
else bad "the shown cards are $n lines"; fi
printf '%s' "$c" | expect "cards past the budget fold into one +N cards line" "+2 cards: big-07, big-08"
printf '%s' "$c" | expect_absent "a folded card's lines are not shown" "BIG08"
printf '%s' "$c" | expect "the first card is shown in full" "✗ BIG01 long line"
run "$HIVE" "$(edit s4 "$W/big/x.txt")" | expect_silent "folded cards are recorded as shown"
c="$(printf '%s' "$(edit s4b "$W/big/x.txt")" | DEFECTS_INJECT_LINES=3 CLAUDE_PROJECT_DIR="$HIVE" bash "$HOOK" | ctx)"
n="$(printf '%s\n' "$c" | sed '1d;/^+[0-9]* cards: /d' | grep -c .)"
if [ "$n" -le 3 ]; then ok "DEFECTS_INJECT_LINES=3 shrinks the budget ($n lines)"
else bad "DEFECTS_INJECT_LINES=3 printed $n lines"; fi
printf '%s' "$c" | expect "DEFECTS_INJECT_LINES=3 folds the rest" "+7 cards: big-02,"

# --- tool scope, order, branches, folders (rules-tree delivery) -------------------------------
echo "--- delivery"
H2="$T/hive2"; D2="$H2/docs/defects"; mkdir -p "$D2/pay"
W2="$(cd "$H2" && { pwd -W 2>/dev/null || pwd; })"
card() { # card <file under D2> <paths> <body...>
  local f="$1" p="$2" id; shift 2; id="$(basename "$f" .md)"
  { printf -- '---\nid: %s\ntitle: T %s\nstatus: text\npaths: %s\n---\n\n' "$id" "$id" "$p"; printf '%s\n' "$@"; } > "$D2/$f"
}
card web.md '["tool:WebFetch"]' '## Never' '- WEBNEVER fetch blind.'
card chrome.md '["tool:mcp__chrome-devtools__.*"]' '## Never' '- CHROMENEVER click blind.'
card src-all.md '["src/**"]' '## Never' '- SRCNEVER broad rule.'
card stripe.md '["src/pay/stripe.py"]' '## Never' '- STRIPENEVER narrow rule.'
card edit-tool.md '["tool:Edit|Bash"]' '## Never' '- EDITTOOLNEVER on every edit.'
card a-old.md '["fresh/**"]' '## Never' '- OLDNEVER.' '## Owner quotes' '- 2025-01-01 · «old»'
card b-new.md '["fresh/**"]' '## Never' '- NEWNEVER.' '## Owner quotes' '- 2026-05-01 · «new»'
card c-short.md '["cmd:dep"]' '## Never' '- SHORTNEVER.'
card d-long.md '["cmd:deploy\\s+now"]' '## Never' '- LONGNEVER.'
card ht.md '["how/**"]' '## How-to' '- HOWLINE do it this way.'
card perm.md '["how/**"]' '## Allowed' '- 2026-10-01 · «PERMLINE»'
printf 'exception: ht\n' > "$T/exc"; sed_inplace '2r '"$T/exc" "$D2/perm.md"
card perm2.md '["how/x.txt"]' '## Allowed' '- 2026-10-02 · «PERM2LINE»'
card nv.md '["nv/**"]' '## Never' '- NVLINE never here.'
card perm3.md '["nv/a.txt"]' '## Allowed' '- 2026-10-03 · «PERM3LINE»'
card none.md '["none/**"]' 'No branch sections here.'
card pay/fold.md '["fold/**"]' '## Never' '- FOLDNEVER in a folder.'
card pay/bare.md '["fold/**"]' 'Nothing.'
edit2() { # edit2 <session> <path>   -> an Edit payload in hive2
  printf '{"session_id":"%s","tool_name":"Edit","tool_input":{"file_path":"%s"},"cwd":"%s"}' "$1" "$2" "$W2"
}
tool() { # tool <session> <tool_name>
  printf '{"session_id":"%s","tool_name":"%s","tool_input":{"url":"https://x"},"cwd":"%s"}' "$1" "$2" "$W2"
}
c="$(run "$H2" "$(tool d1 WebFetch)" | ctx)"
printf '%s' "$c" | expect "tool_name WebFetch matches tool:WebFetch" "✗ WEBNEVER fetch blind."
printf '%s' "$c" | expect_absent "a glob-only card does not match a non-file tool" "SRCNEVER"
printf '%s' "$c" | expect_absent "tool:Edit|Bash does not match WebFetch" "EDITTOOLNEVER"
run "$H2" "$(tool d2 mcp__chrome-devtools__click)" | ctx | expect "an mcp tool matches a tool: regex" "✗ CHROMENEVER click blind."
run "$H2" "$(tool d2b mcp__other__click)" | expect_silent "a tool no card names is silent"
c="$(run "$H2" "$(edit2 d3 "$W2/src/pay/stripe.py")" | ctx)"
printf '%s' "$c" | expect "a tool: entry matches on an Edit call" "EDITTOOLNEVER"
o1="$(printf '%s' "$c" | grep -n STRIPENEVER | cut -d: -f1)"; o2="$(printf '%s' "$c" | grep -n SRCNEVER | cut -d: -f1)"
if [ -n "$o1" ] && [ -n "$o2" ] && [ "$o1" -lt "$o2" ]; then ok "the card on src/pay/stripe.py prints before the one on src/**"
else bad "order narrow-first broken:"; printf '%s\n' "$c" | sed 's/^/        /'; fi
c="$(printf '{"session_id":"d4","tool_name":"Bash","tool_input":{"command":"deploy now"},"cwd":"%s"}' "$W2" | CLAUDE_PROJECT_DIR="$H2" bash "$HOOK" | ctx)"
printf '%s' "$c" | expect "a tool: entry matches on a Bash call" "EDITTOOLNEVER"
o1="$(printf '%s' "$c" | grep -n LONGNEVER | cut -d: -f1)"; o2="$(printf '%s' "$c" | grep -n SHORTNEVER | cut -d: -f1)"
if [ -n "$o1" ] && [ -n "$o2" ] && [ "$o1" -lt "$o2" ]; then ok "a cmd: entry ranks by its literal characters"
else bad "cmd: order broken:"; printf '%s\n' "$c" | sed 's/^/        /'; fi
c="$(run "$H2" "$(edit2 d5 "$W2/fresh/a.txt")" | ctx)"
o1="$(printf '%s' "$c" | grep -n NEWNEVER | cut -d: -f1)"; o2="$(printf '%s' "$c" | grep -n OLDNEVER | cut -d: -f1)"
if [ -n "$o1" ] && [ -n "$o2" ] && [ "$o1" -lt "$o2" ]; then ok "equal scope: the card with the newer dated line first"
else bad "freshness order broken:"; printf '%s\n' "$c" | sed 's/^/        /'; fi
c="$(run "$H2" "$(edit2 d6 "$W2/how/x.txt")" | ctx)"
printf '%s' "$c" | expect "a How-to line prints as →" "→ HOWLINE do it this way."
printf '%s' "$c" | expect "a linked Allowed line prints as ✓ with its exception:" "✓ 2026-10-01 · «PERMLINE» (exception: ht)"
printf '%s' "$c" | expect "a How-to card prohibits nothing: an unlinked Allowed card beside it prints its ✓ line, the How-to first" "✓ 2026-10-02 · «PERM2LINE» (the How-to of ht comes first)"
printf '%s' "$c" | expect_absent "no withheld line under a How-to card" "withheld"
c="$(run "$H2" "$(edit2 d6b "$W2/nv/a.txt")" | ctx)"
printf '%s' "$c" | expect "an unlinked Allowed card under a Never card is withheld in one line" "✓ withheld: perm3 conflicts with nv (no exception:)"
printf '%s' "$c" | expect_absent "the withheld card's ✓ line is not printed" "PERM3LINE"
run "$H2" "$(edit2 d7 "$W2/none/a.txt")" | ctx | expect "a card with no branch lines prints read <path>" "read docs/defects/none.md"
c="$(run "$H2" "$(edit2 d8 "$W2/fold/a.txt")" | ctx)"
printf '%s' "$c" | expect "a foldered card prints with ref <area>/<id>" "pay/fold — T fold"
printf '%s' "$c" | expect "its Never line prints" "✗ FOLDNEVER in a folder."
printf '%s' "$c" | expect "a foldered card with no branch lines points at its real path" "read docs/defects/pay/bare.md"

# --- what stays silent ------------------------------------------------------------------------
echo "--- silent"
run "$NOLIB" "$(edit s1 "$W/pipeline/voiceover.py")" | expect_silent "no docs/defects/ is silent"
run "$HIVE" '{"session_id":"s1","tool_name":"Edit","tool_input":{"file_path":' | expect_silent "malformed JSON is silent, exit 0"
run "$HIVE" '' | expect_silent "empty stdin is silent, exit 0"
run "$HIVE" "$(edit s7 "$W/README.md")" | expect_silent "an Edit no card names is silent"
mkdir -p "$T/nopy"
o="$(edit s8 "$W/pipeline/voiceover.py" | CLAUDE_PROJECT_DIR="$HIVE" PATH="$T/nopy" "$BASH" "$HOOK"; echo "rc=$?")"
printf '%s' "$o" | expect_silent "no python on PATH is silent, exit 0"
o="$(edit s9 "$W/pipeline/voiceover.py" | env -u CLAUDE_PROJECT_DIR bash "$HOOK")"
printf '%s' "$o" | ctx | expect "without CLAUDE_PROJECT_DIR the input cwd is the root" "voice-text"

# --- a python3 that runs nothing (review 0.19, major 1) ---------------------------------------
echo "--- python3 stub"
mkdir -p "$T/stubbin"; printf '#!/bin/sh
exit 9009
' > "$T/stubbin/python3"; chmod +x "$T/stubbin/python3"
if ( VULYK_PY=""; PATH="$T/stubbin:$PATH"; vulyk_python ); then
  o="$(printf '%s' "$(edit stub "$W/pipeline/voiceover.py")" | PATH="$T/stubbin:$PATH" CLAUDE_PROJECT_DIR="$HIVE" bash "$HOOK")"
  if printf '%s' "$o" | grep -q additionalContext; then ok "a python3 stub exiting 9009 falls through to python"
  else bad "a python3 stub silenced the hook"; fi
else echo "  skip  no python on PATH besides python3"; fi

# P10-10: exit 1 was taken as "python ran" (a Python 2 named python3, a broken install), and neither a
# preset $VULYK_PY nor Windows' `py` launcher was tried.
echo "--- P10-10: which python runs the hook"
REALPY="$(command -v "$PYBIN")"
mkdir -p "$T/py1bin" "$T/pyonly"
printf '#!/bin/sh\necho "half a line"\nexit 1\n' > "$T/py1bin/python3"; chmod +x "$T/py1bin/python3"
o="$(edit p10a "$W/pipeline/voiceover.py" | env -u VULYK_PY PATH="$T/py1bin:$PATH" CLAUDE_PROJECT_DIR="$HIVE" bash "$HOOK")"
printf '%s' "$o" | ctx | expect "P10-10: a python3 exiting 1 falls through to the next python" "voice-text"
printf '%s' "$o" | expect_absent "P10-10: and the failed one's output is not printed" "half a line"
printf '#!/bin/sh\n: > "%s/vpy-used"\nexec "%s" "$@"\n' "$T" "$REALPY" > "$T/vpy"; chmod +x "$T/vpy"
o="$(edit p10b "$W/pipeline/voiceover.py" | VULYK_PY="$T/vpy" PATH="$T/py1bin:$PATH" CLAUDE_PROJECT_DIR="$HIVE" bash "$HOOK")"
expect_eq "P10-10: a preset VULYK_PY is tried first" yes "$([ -e "$T/vpy-used" ] && echo yes || echo no)"
printf '%s' "$o" | ctx | expect "P10-10: ... and injects" "voice-text"
printf '#!/bin/sh\nexec "%s" "$@"\n' "$(command -v cat)" > "$T/pyonly/cat"
printf '#!/bin/sh\nexec "%s" "$@"\n' "$REALPY" > "$T/pyonly/py"; chmod +x "$T/pyonly/cat" "$T/pyonly/py"
o="$(edit p10c "$W/pipeline/voiceover.py" | env -u VULYK_PY PATH="$T/pyonly" CLAUDE_PROJECT_DIR="$HIVE" "$BASH" "$HOOK")"
printf '%s' "$o" | ctx | expect "P10-10: with only py on PATH the hook still runs" "voice-text"

# P10-11: an Agent / WebFetch / mcp__ call started python (0.5-2 s on Windows) in a library no `tool:` card
# could match. A python3 stub that leaves a mark shows whether python was started at all.
echo "--- P10-11: no tool: card, no python start"
mkdir -p "$T/markbin"; printf '#!/bin/sh\n: > "%s/py-started"\nexit 9009\n' "$T" > "$T/markbin/python3"; chmod +x "$T/markbin/python3"
started() { # started <root> <json>   -> yes when the hook tried a python, else no
  rm -f "$T/py-started"
  printf '%s' "$2" | env -u VULYK_PY PATH="$T/markbin:$PATH" CLAUDE_PROJECT_DIR="$1" bash "$HOOK" >/dev/null 2>&1
  [ -e "$T/py-started" ] && echo yes || echo no
}
# bash 3.2 brace-expands a JSON literal with \" inside "$(...)": each payload is built in a variable first.
for t in Agent WebFetch mcp__chrome-devtools__click BashOutput; do
  p="{\"session_id\":\"p11\",\"tool_name\":\"$t\",\"tool_input\":{\"url\":\"https://x\"}}"
  expect_eq "P10-11: $t in a library with no tool: card starts no python" no "$(started "$HIVE" "$p")"
done
expect_eq "P10-11 neighbour: an Agent call in a library with a tool: card still starts python" yes \
  "$(started "$H2" '{"session_id":"p11","tool_name":"Agent","tool_input":{"prompt":"x"}}')"
expect_eq "P10-11 neighbour: an Edit call in a library with no tool: card still starts python" yes \
  "$(started "$HIVE" "$(edit p11 "$W/pipeline/voiceover.py")")"
expect_eq "P10-11 neighbour: a payload with no tool_name (SessionStart) still starts python" yes \
  "$(started "$HIVE" '{"session_id":"p11","source":"compact"}' )"
run "$H2" "$(tool p11b WebFetch)" | ctx | expect "P10-11 neighbour: the tool: card itself is still injected" "✗ WEBNEVER fetch blind."
# O3: a tool: line in README.md is not a card's; only card files count.
cp "$D/README.md" "$T/readme.keep"; printf 'A card may scope `tool:WebFetch`.\n' >> "$D/README.md"
expect_eq "O3: a tool: line in README.md alone does not start python for an Agent call" no \
  "$(started "$HIVE" '{"session_id":"o3","tool_name":"Agent","tool_input":{"prompt":"x"}}')"
cp "$T/readme.keep" "$D/README.md"
# O3: a hive whose docs/defects/ holds no card file exits before python for every tool.
EMPTY="$T/emptyhive"; ED="$EMPTY/docs/defects"; mkdir -p "$ED/fixtures" "$ED/pay"
EW="$(cd "$EMPTY" && { pwd -W 2>/dev/null || pwd; })"
printf '# Defects\n`tool:WebFetch`\n' > "$ED/README.md"; printf '# Index\ntool:\n' > "$ED/INDEX.md"
printf -- '---\nid: fx\nstatus: text\npaths: ["**", "tool:.*"]\n---\n## Never\n- x\n' > "$ED/fixtures/fx.md"
cp "$ED/fixtures/fx.md" "$ED/pay/ReadMe.MD"; cp "$ED/fixtures/fx.md" "$ED/pay/index.md"
printf 'not a card\n' > "$ED/notes.txt"
EDIT_O3="{\"session_id\":\"o3\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$EW/src/a.py\"}}"
expect_eq "O3: no card file -> an Edit starts no python" no "$(started "$EMPTY" "$EDIT_O3")"
expect_eq "O3: no card file -> a Bash call starts no python" no \
  "$(started "$EMPTY" '{"session_id":"o3","tool_name":"Bash","tool_input":{"command":"ls src"}}')"
expect_eq "O3: no card file -> a PowerShell command that can match nothing starts no python" no \
  "$(started "$EMPTY" '{"session_id":"o3","tool_name":"PowerShell","tool_input":{"command":"Get-ChildItem src"}}')"
expect_eq "O3: no card file -> an Agent call starts no python" no \
  "$(started "$EMPTY" '{"session_id":"o3","tool_name":"Agent","tool_input":{"prompt":"x"}}')"
printf -- '---\nid: one\nstatus: block\ncheck: false <arg>\npaths: ["src/**"]\n---\n## Never\n- x\n' > "$ED/pay/one.md"
expect_eq "O3 neighbour: one foldered card file -> the Edit starts python" yes "$(started "$EMPTY" "$EDIT_O3")"
expect_eq "O3 neighbour: ... and an Agent call still does not (no tool: in a card file)" no \
  "$(started "$EMPTY" '{"session_id":"o3","tool_name":"Agent","tool_input":{"prompt":"x"}}')"

# --- cards on reading a story (0.41): a Read of a story file delivers the cards for its ## Files ------
echo "--- story read"
mkdir -p "$HIVE/docs/specs/demo" "$HIVE/docs/notes"
cat > "$HIVE/docs/specs/demo/demo-01-voice.md" <<'EOF'
---
story: demo-01-voice
spec: demo
status: todo
---

# Voice fix

## Files
<!--
- not/a/path.py
-->
- pipeline/voiceover.py
- `tests/test_voice.py`

## Verification
`pytest`
EOF
printf -- '# Demo (brief)\n\n## Files\n- pipeline/voiceover.py\n' > "$HIVE/docs/specs/demo/brief.md"
printf -- '---\nstory: x\n---\n\n## Files\n- pipeline/voiceover.py\n' > "$HIVE/docs/notes/not-a-story.md"
readcall() { # readcall <session> <path> [agent]   -> a Read PreToolUse payload
  local a=""; [ -n "${3:-}" ] && a=",\"agent_id\":\"$3\""
  printf '{"session_id":"%s","tool_name":"Read","tool_input":{"file_path":"%s"},"cwd":"%s"%s}' "$1" "$2" "$W" "$a"
}
o="$(run "$HIVE" "$(readcall r1 "$W/docs/specs/demo/demo-01-voice.md" w1)")"
printf '%s' "$o" | ctx | expect "a story Read shows the card for its ## Files" "voice-text — Voice text rule"
printf '%s' "$o" | ctx | expect_absent "a ## Files line inside a comment is not a path" "not/a/path.py"
run "$HIVE" "$(readcall r1 "$W/docs/specs/demo/demo-01-voice.md" w1)" | expect_silent "the same agent reading the story again: silent"
run "$HIVE" "$(edit r1 "$W/pipeline/voiceover.py" w1)" | expect_silent "its first Edit of that path: the card is not repeated"
o="$(run "$HIVE" "$(readcall r1 "docs/specs/demo/demo-01-voice.md" w2)")"
printf '%s' "$o" | ctx | expect "a relative story path works for another agent" "voice-text — Voice text rule"
run "$HIVE" "$(readcall r2 "$W/docs/specs/demo/brief.md")" | expect_silent "a brief.md Read is silent"
run "$HIVE" "$(readcall r2 "$W/docs/notes/not-a-story.md")" | expect_silent "a story-shaped file outside docs/specs/ is silent"
run "$HIVE" "$(readcall r2 "$W/pipeline/voiceover.py")" | expect_silent "a source file Read is silent"
# Round 1: a card folded into `+N cards` on the story Read is only named there; its lines still come at the Edit.
printf -- '---\nstory: demo-02-big\n---\n\n## Files\n- big/x.py\n' > "$HIVE/docs/specs/demo/demo-02-big.md"
o="$(run "$HIVE" "$(readcall r3 "$W/docs/specs/demo/demo-02-big.md" f1)")"
printf '%s' "$o" | ctx | expect "eight big cards on a story Read fold the rest" "+2 cards: big-07, big-08"
o="$(run "$HIVE" "$(edit r3 "$W/big/x.py" f1)")"
printf '%s' "$o" | ctx | expect "a card folded on a story Read arrives in full at the first Edit" "✗ BIG08 long line"
printf '%s' "$o" | ctx | expect_absent "a card shown in full on the story Read is not repeated at the Edit" "BIG01"
# Ask 12 (tails-1115-07): `## Files` is read outside fenced code blocks only, with the fence rule of FENCE_AWK in
# scripts/cycle.sh (3+ ` or ~ opens; only the same character, as long or longer, with nothing after it, closes).
mkdir -p "$HIVE/docs/specs/fence"
fstory() { # fstory <file> <fence open> <fence close>   -> a story whose ## Red receipt fence holds a ## Files
  printf -- '---\nstory: %s\n---\n\n## Red receipt\n%s\n## Files\n- big/fenced.py\n%s\n\n## Files\n- pipeline/voiceover.py\n' \
    "$(basename "$1" .md)" "$2" "$3" > "$HIVE/docs/specs/fence/$1"
}
fstory f-01.md '```' '```'
o="$(run "$HIVE" "$(readcall fr1 "$W/docs/specs/fence/f-01.md")" | ctx)"
printf '%s' "$o" | expect_absent "a fenced section adds no path: a ## Files inside a fence above the real one" "big-0"
printf '%s' "$o" | expect "a fenced section adds no path: ... and the real ## Files still delivers" "voice-text — Voice text rule"
fstory f-02.md '````' "$(printf '```\n- big/inner.py\n````')"
o="$(run "$HIVE" "$(readcall fr2 "$W/docs/specs/fence/f-02.md")" | ctx)"
printf '%s' "$o" | expect_absent "a fenced section adds no path: a 4-backtick fence holding a 3-backtick one" "big-0"
printf '%s' "$o" | expect "a fenced section adds no path: ... the 4-backtick story still reads the real ## Files" "voice-text"
fstory f-03.md '~~~' '~~~'
o="$(run "$HIVE" "$(readcall fr3 "$W/docs/specs/fence/f-03.md")" | ctx)"
printf '%s' "$o" | expect_absent "a fenced section adds no path: a ~~~ fence" "big-0"
printf '%s' "$o" | expect "a fenced section adds no path: ... the ~~~ story still reads the real ## Files" "voice-text"
printf -- '---\nstory: f-04\n---\n\n## Files\n- big/x.py\n- pipeline/voiceover.py\n' > "$HIVE/docs/specs/fence/f-04.md"
o="$(run "$HIVE" "$(readcall fr4 "$W/docs/specs/fence/f-04.md")" | ctx)"
printf '%s' "$o" | expect "a fenced section adds no path, neighbour: a story with no fence reads as today" "big-01"
printf '%s' "$o" | expect "a fenced section adds no path, neighbour: ... both of its paths" "voice-text"
# --- court guard (audit-fixes-1113-08, contract C1): a blind council seat stays inside its court ---------
echo "--- court guard"
CG="$SRC/.claude/hooks/court-guard.sh"
CP="$T/courtproj"; CR="$CP/.vulyk/court/acme/round-1"
mkdir -p "$CR/docs/specs/acme" "$CR/src" "$CP/docs/specs/acme" "$CP/src"
printf '# brief\n' > "$CR/docs/specs/acme/brief.md"; printf '# plan\n' > "$CP/docs/specs/acme/plan.md"
CPW="$(cd "$CP" && { pwd -W 2>/dev/null || pwd; })"; CRW="$CPW/.vulyk/court/acme/round-1"
cg() { # cg <agent_type, - for the main session> <cwd> <tool> <tool_input JSON> -> deny | allow
  local a='' out
  [ "$1" != - ] && a=",\"agent_id\":\"c1\",\"agent_type\":\"$1\""
  out="$(printf '{"session_id":"c","tool_name":"%s","tool_input":%s,"cwd":"%s"%s}' "$3" "$4" "$2" "$a" |
    CLAUDE_PROJECT_DIR="$CPW" bash "$CG")"
  case "$out" in *'"permissionDecision": "deny"'*) echo deny ;; '') echo allow ;; *) echo other ;; esac
}
# bash 3.2 brace-expands a JSON literal with \" inside "$(...)": each payload is built in a variable first.
p="{\"file_path\":\"$CRW/docs/specs/acme/brief.md\"}"
expect_eq "court guard: a seat's Read inside the court passes" allow "$(cg council-opus "$CRW" Read "$p")"
p="{\"file_path\":\"$CPW/docs/specs/acme/plan.md\"}"
expect_eq "court guard: a seat's Read of the main tree's spec file is denied" deny "$(cg council-opus "$CRW" Read "$p")"
expect_eq "court guard: the same Read by a worker passes" allow "$(cg worker-code "$CPW" Read "$p")"
expect_eq "court guard: the same Read by the main session passes" allow "$(cg - "$CPW" Read "$p")"
p="{\"pattern\":\"x\",\"path\":\"$CPW/src\"}"
expect_eq "court guard: a seat's Grep outside the court is denied" deny "$(cg council-haiku "$CRW" Grep "$p")"
p="{\"pattern\":\"x\",\"path\":\"$CRW/src\"}"
expect_eq "court guard: a seat's Grep inside the court passes" allow "$(cg council-haiku "$CRW" Grep "$p")"
expect_eq "court guard: a seat's Glob with no path from the main tree is denied" deny \
  "$(cg council-opus "$CPW" Glob '{"pattern":"**/*.md"}')"
expect_eq "court guard: a seat's Glob with no path from inside the court passes" allow \
  "$(cg council-opus "$CRW" Glob '{"pattern":"**/*.md"}')"
expect_eq "court guard: a Bash path inside the court passes" allow \
  "$(cg council-opus "$CRW" Bash '{"command":"cat docs/specs/acme/brief.md"}')"
expect_eq "court guard: a Bash path argument that climbs out of the court is denied" deny \
  "$(cg council-opus "$CRW" Bash '{"command":"cat ../../../../docs/specs/acme/plan.md"}')"
p="{\"command\":\"cd $CPW && ls src\"}"
expect_eq "court guard: a cd out of the court is denied" deny "$(cg council-opus "$CRW" Bash "$p")"
p="{\"command\":\"mkdir -p $CPW/.vulyk/reports/acme/round-1\"}"
expect_eq "court guard: the seat's report folder passes" allow "$(cg council-opus "$CRW" Bash "$p")"
expect_eq "court guard: git log with no pathspec is denied" deny "$(cg council-opus "$CRW" Bash '{"command":"git log --oneline"}')"
expect_eq "court guard: git show <rev>:docs/specs/... is denied" deny \
  "$(cg council-opus "$CRW" Bash '{"command":"git show HEAD~2:docs/specs/acme/plan.md"}')"
expect_eq "court guard: git diff with a pathspec under docs/specs/ is denied" deny \
  "$(cg council-opus "$CRW" Bash '{"command":"git diff HEAD~1 -- docs/specs/acme"}')"
expect_eq "court guard: git status passes" allow "$(cg council-haiku "$CRW" Bash '{"command":"git status --short"}')"
expect_eq "court guard: another agent's git log passes" allow "$(cg worker-code "$CPW" Bash '{"command":"git log --oneline"}')"
# Round 1 (audit-fixes-1113-15): a command's non-path words were read as paths and starved the blind seat.
printf '# Acme\n## Profile\nx\n## Next\n' > "$CR/CLAUDE.md"
for c in "sed -n '/^## Profile/,/^## [A-Z]/p' CLAUDE.md" "awk '/^## Profile/{on=1} on' CLAUDE.md" \
         "tr '\\\\n' ' ' < CLAUDE.md" "grep -n '/api/v1' src" "grep -e '/^##/' CLAUDE.md" \
         "awk '{print \$1/2}' CLAUDE.md" "echo '/acme/round-1 done'" "printf '%s\\\\n' '/x/y'" \
         "sed -e 's/~/home/' -e '/^\$/d' CLAUDE.md" "cat CLAUDE.md | tr -d '\\\\r' | sed -n '/## Profile/,\$p'" \
         "jq '.a' docs/specs/acme/brief.md"; do
  p="{\"command\":\"$c\"}"
  expect_eq "court guard: a non-path word passes: $c" allow "$(cg council-opus "$CRW" Bash "$p")"
done
for c in "cat $CPW/docs/specs/acme/plan.md" "ls ../../../../docs/specs" "sed -n 1p $CPW/docs/specs/acme/plan.md" \
         "grep -n plan $CPW/docs/specs" "awk 1 < $CPW/docs/specs/acme/plan.md" "cat ~/x.md" "cat \$HOME/x.md" \
         "grep -f $CPW/docs/specs/acme/plan.md x" "echo $CPW/docs/specs/acme/plan.md"; do
  p="{\"command\":\"$c\"}"
  expect_eq "court guard: a real read outside the court is still denied: $c" deny "$(cg council-opus "$CRW" Bash "$p")"
done
# guards-1115-04 (contract C2): git by an allowlist, resolved paths, glued options, the seat's own court, the temp folder.
for c in "git log --oneline -- src" "git -c alias.v=show v HEAD:src/a.md" "git unpack-file 0123abcd" \
         "git cat-file -p HEAD:src/a.md" "git lg -- src" "git rev-parse HEAD:docs/specs/acme/plan.md" \
         "git ls-files HEAD~1:docs/specs/acme" "git -c core.pager=cat status" "GIT_DIR=$CPW/.git git status" \
         "env GIT_WORK_TREE=$CPW git status"; do
  p="{\"command\":\"$c\"}"
  expect_eq "court guard: a seat git read outside the allowlist is denied: $c" deny "$(cg council-opus "$CRW" Bash "$p")"
done
for c in "git status" "git status --short -- src" "git --no-pager status -sb" "git -C src status --short" \
         "git rev-parse --show-toplevel" "git rev-parse --abbrev-ref HEAD" "git ls-files src" \
         "git ls-files --others --exclude-standard" "git --version" "git version"; do
  p="{\"command\":\"$c\"}"
  expect_eq "court guard: an allowlisted git form passes in the court: $c" allow "$(cg council-opus "$CRW" Bash "$p")"
done
# S7: a path is judged by its resolved form; /proc and a link in the court point back into the project.
rm -rf "$CR/peek"; ln -s "$CP/docs/specs" "$CR/peek" 2>/dev/null
if [ ! -L "$CR/peek" ] && command -v cygpath >/dev/null 2>&1; then   # Git Bash without symlinks: a junction
  rm -rf "$CR/peek"; cmd //c mklink //J "$(cygpath -w "$CR/peek")" "$(cygpath -w "$CP/docs/specs")" >/dev/null 2>&1
fi
[ -e "$CR/peek/acme/plan.md" ] && ok "court guard: the link fixture points into the project" ||
  bad "court guard: could not make a link in the court for the resolved-path case"
for c in "cat /proc/1234/cwd/docs/specs/acme/plan.md" "cat /proc/self/root$CP/docs/specs/acme/plan.md" \
         "cat $CP/docs/specs/acme/plan.md" "cat peek/acme/plan.md" \
         "sed --expression=p ../../../../docs/specs/*/plan.md" "sed -ep ../../../../docs/specs/*/plan.md" \
         "grep --regexp=plan ../../../../docs/specs/a*/plan.md" "awk -f$CPW/docs/specs/acme/plan.md CLAUDE.md" \
         "grep -f pats.txt ../../../../docs/specs/*/plan.md" \
         "cat /tmp/claude/x/plan-copy.md" "cat /tmp/claude-1000/x/plan-copy.md"; do
  p="{\"command\":\"$c\"}"
  expect_eq "court guard: a resolved, glued or temp-folder read outside the court is denied: $c" deny \
    "$(cg council-opus "$CRW" Bash "$p")"
done
p="{\"file_path\":\"$CRW/peek/acme/plan.md\"}"
expect_eq "court guard: a seat's Read through a link out of the court is denied" deny "$(cg council-opus "$CRW" Read "$p")"
for c in "cat docs/specs/acme/brief.md" "sed --expression=p CLAUDE.md" "sed -ep CLAUDE.md" \
         "grep --regexp=Profile CLAUDE.md" "awk -fprog.awk CLAUDE.md" "cat /dev/null" "ls /usr/bin" \
         "cat /tmp/other/x.md" "ls /tmp" "python3 -c 'print(1)'"; do
  p="{\"command\":\"$c\"}"
  expect_eq "court guard: its plain twin passes: $c" allow "$(cg council-opus "$CRW" Bash "$p")"
done
p='{"command":"cat /tmp/claude/x/plan-copy.md"}'
expect_eq "court guard: the main session's read of its temp folder passes" allow "$(cg - "$CPW" Bash "$p")"
expect_eq "court guard: a worker's read of the temp folder passes" allow "$(cg worker-code "$CPW" Bash "$p")"
# S10: one court on disk - a court path passes from any directory; a second court - only the one the call stands in.
p="{\"file_path\":\"$CRW/docs/specs/acme/brief.md\"}"
expect_eq "court guard: one court, a Read by absolute path from the project root passes" allow "$(cg council-opus "$CPW" Read "$p")"
TW="$(cd "$T" && { pwd -W 2>/dev/null || pwd; })"
expect_eq "court guard: one court, a Read by absolute path from another directory passes" allow "$(cg council-opus "$TW" Read "$p")"
CO="$CP/.vulyk/court/other/round-1"; COW="$CPW/.vulyk/court/other/round-1"
mkdir -p "$CO/docs/specs/other"; printf '# other brief\n' > "$CO/docs/specs/other/brief.md"
expect_eq "court guard: two courts, a Read of the seat's own court from inside it passes" allow "$(cg council-opus "$CRW" Read "$p")"
expect_eq "court guard: two courts, a Read into a court from no court is denied" deny "$(cg council-opus "$CPW" Read "$p")"
out="$(printf '{"session_id":"c","tool_name":"Read","tool_input":%s,"cwd":"%s","agent_id":"c1","agent_type":"council-opus"}' \
  "$p" "$CPW" | CLAUDE_PROJECT_DIR="$CPW" bash "$CG")"
printf '%s' "$out" | expect "court guard: two courts, the refusal says to work from inside the court" "work from inside your court"
p="{\"command\":\"cat $CRW/CLAUDE.md\"}"
expect_eq "court guard: two courts, a Bash read into a court from no court is denied" deny "$(cg council-opus "$CPW" Bash "$p")"
p="{\"command\":\"cd $CRW && cat CLAUDE.md && ls $CPW/.vulyk/reports\"}"
expect_eq "court guard: two courts, a cd into the court then a read there passes" allow "$(cg council-opus "$CPW" Bash "$p")"
p="{\"file_path\":\"$COW/docs/specs/other/brief.md\"}"
expect_eq "court guard: a Read of another round's court is denied" deny "$(cg council-opus "$CRW" Read "$p")"
for c in "cat ../../other/round-1/docs/specs/other/brief.md" "cd ../../other/round-1 && cat CLAUDE.md" "ls .." \
         "cd $CRW && cat $COW/docs/specs/other/brief.md"; do
  p="{\"command\":\"$c\"}"
  expect_eq "court guard: another round's court is denied: $c" deny "$(cg council-opus "$CRW" Bash "$p")"
done
# guards-1115-07 (repair of round 2, by class): git found in every command position, a path judged in every form
# the shell reads it in, a cd judged by what the shell really does; each class with its original form and a
# neighbour, and the seat's own flows that must still pass.
cgb() { # cgb <want> <cwd> <command text>: a council-opus Bash call, the text JSON-encoded
  local p; p="$("$PYBIN" -c 'import json,sys; print(json.dumps({"command": sys.argv[1]}))' "$3")"
  expect_eq "court guard r2: $1 from $(basename "$2"): $3" "$1" "$(cg council-opus "$2" Bash "$p")"
}
mkdir -p "$CR/docs/specs/acme/deep"
PL='../../../../docs/specs/acme/plan.md'
while IFS= read -r c; do cgb deny "$CRW" "$c"; done <<EOF
! git show HEAD~1:docs/specs/acme/plan.md
if true; then git log -p; fi
for i in 1; do git log -p; done
true; while false; do :; done; until true; do git log -p; done
2>/dev/null git log -p
time -p git log -p
command -p git log -p
exec -a x git log -p
env -i git log -p
env -u X git log -p
timeout 5 git log -p
nice -n 5 git log -p
nohup git log -p
echo HEAD | xargs git show
echo show | xargs git
eval git log -p
eval 'git show HEAD~1:docs/specs/acme/plan.md'
bash -c 'git log -p'
sh -ec 'git log -p'
echo "\$(git log -p)"
echo "\`git log -p\`"
g=git; \$g log -p
"\$G" log -p
{git,} log -p
p=$PL; cat "\$p"
p=$CPW/docs/specs/acme/plan.md && cat \${p}
echo "\$(cat $PL)"
x="\$(<$PL)"; echo ok
curl -s file:///$CPW/docs/specs/acme/plan.md
curl -s FILE://localhost/$CPW/docs/specs/acme/plan.md
cat ./$PL
cat ./../../../../docs/specs/acme/plan.m?
cat src/../../../../../docs/specs/acm?/plan.md
cat .?/../../../../docs/specs/acme/plan.md
cat<$PL
grep -n x<$PL
while read -r l; do echo "\$l"; done<$PL
exec 3<$PL; cat <&3
cd docs/specs/acme/nope; cat $PL
(cd docs/specs/acme/deep); cat $PL
true || cd docs/specs/acme/deep; cat $PL
cd docs/specs/acme/deep extra; cat $PL
CDPATH=../.. cd other/round-1 && cat CLAUDE.md
tar -tf$PL
sort -o$PL CLAUDE.md
diff --from-file=$PL CLAUDE.md
cat '.\\..\\..\\..\\..\\docs\\specs\\acme\\plan.md'
EOF
cgb deny "$CRW" "$(printf 'cat <<EOF.\nnote\nEOF.\ncat %s' "$PL")"
cgb deny "$CRW" "$(printf 'cat <<"E-1"\nnote\nE-1\ncat %s' "$PL")"
cgb deny "$CRW" "$(printf 'echo $((1<<X))\ncat %s\nX' "$PL")"
cgb deny "$CRW" "$(printf '(( 1<<X ))\ncat %s\nX' "$PL")"
while IFS= read -r c; do cgb allow "$CRW" "$c"; done <<'EOF'
python3 -c "print(6 * 7)"
python3 -c "print(2 ** 10)"
sed -i '$d' CLAUDE.md
echo x > "$OUT"
git ls-files '*.md' | xargs sed -n 1p
sed 's/</\&lt;/g' CLAUDE.md
grep -n '<b>' CLAUDE.md
awk -F/ '{print $1}' CLAUDE.md
echo $((1<<2))
git status 2>&1 | head -5
cat CLAUDE.md>/dev/null
cat 2>/dev/null CLAUDE.md
cd src && cat ../CLAUDE.md
cd docs/specs/acme/deep && cat ../brief.md
for f in docs/specs/acme/*.md; do cat "$f"; done
timeout 5 git status
env -i git status
nice git rev-parse --show-toplevel
bash -c 'cat CLAUDE.md'
eval 'cat CLAUDE.md'
grep -n git CLAUDE.md
echo "$(git status --short)"
p=docs/specs/acme/brief.md; cat "$p"
echo see file:docs/specs/acme/brief.md
curl -s https://example.com/../x
EOF
cgb allow "$CRW" "$(printf 'cat > ../../../reports/acme/round-1/opus.md <<EOF\n* a $name **b `x` ../../../../docs\nEOF')"
cgb allow "$CRW" "$(printf 'python3 - <<PY\nprint(6 * 7)\nPY')"
# guards-1115-09 (round 3, ask 7): a substitution runs where its command stands, so one after `cd COURT &&` reads
# the court; one before the cd, or after a cd that ends with its subshell, is still judged where the call stood.
# guards-1115-13 (revert after round 6): the reverted parser denies the first group again
cgo() { # cgo <cwd> <command text>: a council-opus Bash call the reverted parser over-denies (0.55.0 re-opens it)
  local p; p="$("$PYBIN" -c 'import json,sys; print(json.dumps({"command": sys.argv[1]}))' "$2")"
  expect_eq "court guard: known over-deny, 0.55.0: denied from $(basename "$1"): $2" deny "$(cg council-opus "$1" Bash "$p")"
}
printf 'x\n' > "$CR/src/main.py"; printf 'x\n' > "$CP/src/main.py"
while IFS= read -r c; do cgo "$CPW" "$c"; done <<'EOF'
cd .vulyk/court/acme/round-1 && echo "$(cat src/main.py)"
cd .vulyk/court/acme/round-1 && wc -l $(ls src/main.py)
cd .vulyk/court/acme/round-1 && x="$(< src/main.py)"; echo "$x"
cd .vulyk/court/acme/round-1 && test "$(wc -l < src/main.py)" -gt 0 && echo `cat src/main.py`
EOF
while IFS= read -r c; do cgb deny "$CPW" "$c"; done <<'EOF'
echo "$(cat src/main.py)"; cd .vulyk/court/acme/round-1
cd .vulyk/court/acme/round-1 && echo "$(cat ../../../../src/main.py)"
(cd .vulyk/court/acme/round-1); echo "$(cat src/main.py)"
EOF
# guards-1115-09 (round 3, finding 2): an unquoted arithmetic expansion holding a substitution, and a case arm whose
# pattern is a wildcard, are ordinary shell; a command inside either is still judged.
# guards-1115-13 (revert after round 6): the reverted parser denies these ordinary forms again
while IFS= read -r c; do cgo "$CRW" "$c"; done <<'EOF'
s=$(date +%s); echo took $(( $(date +%s) - s ))s
echo $(( $(date +%s) - 5 ))
case x in a) echo a;; *) echo b;; esac
case "$1" in -h|--help) echo h;; *) cat src/main.py;; esac
EOF
cgo "$CRW" "$(printf 'case x in\n  a) echo a ;;\n  *) echo b ;;\nesac')"
while IFS= read -r c; do cgb deny "$CRW" "$c"; done <<EOF
case x in *) cat $PL;; esac
echo \$(( \$(wc -l < $PL) + 1 ))
case x in a) echo a;; *) git log -p;; esac
EOF
# guards-1115-11 (round 4, finding 1): `$((` is arithmetic only when its first unmatched `)` is followed by another;
# a body that opens and closes with a parenthesised group is a command substitution, and its commands are judged
while IFS= read -r c; do cgb deny "$CRW" "$c"; done <<EOF
echo \$((cat $PL) && (true))
echo \$((git log -p) | (head -1))
x=\$((cat $PL); (echo)); echo ok
wc -l \$((cat $PL) || (git show HEAD:docs/specs/acme/plan.md))
EOF
cgb allow "$CRW" 'echo $((cat src/main.py) && (true))'
# guards-1115-13 (revert after round 6): arithmetic holding a parenthesised group is denied again
while IFS= read -r c; do cgo "$CRW" "$c"; done <<'EOF'
echo $(( (1 + 2) * 3 ))
echo $(( $(wc -l < src/main.py) + (2) ))
EOF
# guards-1115-11 (round 4, finding 2): the redirects on `esac` are judged; pattern mode starts only at an unquoted
# `case` word and ends at its `esac` in the same simple command too (a case with no arm)
while IFS= read -r c; do cgb deny "$CRW" "$c"; done <<EOF
case x in *) echo a;; esac > $PL
case x in *) cat;; esac < $PL
case x in *) cat;; esac <$PL
case x in a) echo a;; esac 2>> $PL
case x in esac > $PL
case x in esac; cat $PL; (true)
case x in esac; cd ../../../..; (true)
case x in esac; git log -p; (true)
'case' x; cat $PL; (true)
\\case x; git log -p; (true)
"case" y; cd ../../../..; (true)
ca\\se x; cat $PL; (true)
EOF
while IFS= read -r c; do cgb allow "$CRW" "$c"; done <<'EOF'
case x in *) echo a;; esac > out.txt
case x in *) cat;; esac < src/main.py
case x in esac; cat src/main.py; (true)
'case' x; cat src/main.py; (true)
echo case esac; cat src/main.py
EOF
# guards-1115-12 (round 5, finding 1): the scan that tells `$((` arithmetic passes over an escaped or quoted `)`,
# as bash does, so a substitution whose body holds one is still read as commands
while IFS= read -r c; do cgb deny "$CRW" "$c"; done <<EOF
echo \$((cat $PL; echo \\)) )
echo \$((cat $PL; echo ')') )
echo \$((cat $PL; echo ")") )
echo \$((git log -p; echo \\)) )
x=\$((cd ../../../..; echo \\)) ); echo ok
EOF
while IFS= read -r c; do cgb allow "$CRW" "$c"; done <<'EOF'
echo $((cat src/main.py; echo \)) )
echo $(( 2 * 3 ))
EOF
# guards-1115-12 (round 5, finding 2): `case` opens pattern mode only where bash reads it as the keyword: not behind
# a redirect or a quoted or escaped keyword word, and never in PowerShell
while IFS= read -r c; do cgb deny "$CRW" "$c"; done <<EOF
>/dev/null case x; cat $PL; (true)
2>&1 case x; git log -p; (true)
<src/main.py case x; cd ../../../..; (true)
>out.txt case y in; cat $PL; (true)
'if' case x; cat $PL; (true)
"then" case x; git log -p; (true)
\\do case x; cd ../../../..; (true)
'!' case x; cat $PL; (true)
"while" case x; cat $PL; (true)
'until' case x; cat $PL; (true)
\\else case x; cat $PL; (true)
'elif' case x; cat $PL; (true)
"coproc" case x; cat $PL; (true)
echo \$(>/dev/null case x; cat $PL; (true))
bash -c "'if' case x; cat $PL; (true)"
EOF
while IFS= read -r c; do cgb allow "$CRW" "$c"; done <<'EOF'
>/dev/null case x; cat src/main.py; (true)
'if' case x; cat src/main.py; (true)
if case x in a) false;; esac; then cat src/main.py; fi
! case x in a) true;; esac
EOF
cgp() { # cgp <want> <command text>: a council-opus PowerShell call from the court, the text JSON-encoded
  local p; p="$("$PYBIN" -c 'import json,sys; print(json.dumps({"command": sys.argv[1]}))' "$2")"
  expect_eq "court guard r5: $1 PowerShell: $2" "$1" "$(cg council-opus "$CRW" PowerShell "$p")"
}
for c in "case x; cat $PL; (1)" "case x; cd ../../../..; (1)" "case x; git log -p; (1)" "case x in *) cat $PL; (1)" \
         "case x; Get-Content $PL; (1)"; do cgp deny "$c"; done
cgp allow 'case x; Get-Content src/main.py; (1)'
# guards-1115-12 (round 5, finding 3): a line continuation inside or right after `esac` is joined before the word
# is read, so the case closes there and what follows (its redirects too) is judged
for c in "case x in *) echo a;; es\\\\\nac; cat %s; (true)" "case x in *) echo a;; esa\\\\\nc; git log -p; (true)" \
         "case x in *) echo a;; e\\\\\nsac; cd ../../../..; (true)" "case x in *) echo a;; esac\\\\\n; cat %s; (true)" \
         "case x in *) cat;; es\\\\\nac < %s" "case x in *) echo a;; esac\\\\\n> %s" "case x in es\\\\\nac; cat %s; (true)" \
         "case x in esac\\\\\n> %s"; do
  cgb deny "$CRW" "$(printf "$c" "$PL")"
done
cgb allow "$CRW" "$(printf 'case x in *) echo a;; es\\\nac; cat src/main.py; (true)')"
cgb allow "$CRW" "$(printf 'case x in *) echo a;; esac\\\n> out.txt')"
# guards-1115-13 (round 6, findings 1 and 5, by the revert): a word the tokenizer turns into a separator or a
# parenthesis before `case`, and a quoted or escaped arm separator inside an arm, open no pattern mode: the
# commands after them are judged (original forms first, then neighbours)
cg6() { # cg6 <command text>: a council-opus Bash call from the court that must be denied
  local p; p="$("$PYBIN" -c 'import json,sys; print(json.dumps({"command": sys.argv[1]}))' "$1")"
  expect_eq "court guard r6: round-6 regression forms are denied again: $1" deny "$(cg council-opus "$CRW" Bash "$p")"
}
while IFS= read -r c; do cg6 "$c"; done <<EOF
echo ';' case x; cat $PL; (true)
echo { case x; cd ../../../..; (true)
echo \\; case x; git log -p; (true)
a=(1) case x; cat $PL; (true)
echo \${x:-(} case x; git log -p; (true)
echo \$(echo ';' case x; cat $PL; (true))
case x in *) echo ';;'; cat $PL; (true);; esac
case x in *) echo \\;\\; ; git log -p; (true);; esac
EOF
# The seat's own flows when the hook input carries the court in the Git Bash spelling, and a court path in
# another letter case (Windows folds case; elsewhere another case is another file).
cgb allow "$CR" 'echo x > ../../../reports/acme/round-1/opus.md'
cgb allow "$CR" 'cat docs/specs/acme/brief.md'
cgb deny "$CR" "cat $PL"
p='{"file_path":"docs/specs/acme/brief.md"}'
expect_eq "court guard r2: a relative Read in the court from a Git Bash cwd passes" allow "$(cg council-opus "$CR" Read "$p")"
p="{\"file_path\":\"$PL\"}"
expect_eq "court guard r2: a relative Read out of the court from a Git Bash cwd is denied" deny "$(cg council-opus "$CR" Read "$p")"
p="{\"pattern\":\"src/../../../../../docs/specs/**/plan.md\"}"
expect_eq "court guard r2: a Glob whose pattern climbs out behind a folder is denied" deny "$(cg council-opus "$CRW" Glob "$p")"
if command -v cygpath >/dev/null 2>&1; then
  UP="$(printf '%s' "$CR" | tr '[:lower:]' '[:upper:]')"
  p="{\"file_path\":\"$UP/DOCS/SPECS/ACME/BRIEF.MD\"}"
  expect_eq "court guard r2: a Read of the seat's own court in another letter case passes" allow "$(cg council-opus "$CRW" Read "$p")"
  UPW="$(printf '%s' "$CRW" | tr '[:lower:]' '[:upper:]')"
  p="{\"file_path\":\"$UPW/DOCS/SPECS/ACME/BRIEF.MD\"}"
  expect_eq "court guard r2: a Read of the seat's own court in another letter case passes (drive form)" allow "$(cg council-opus "$CR" Read "$p")"
  p="{\"file_path\":\"$(printf '%s' "$CP" | tr '[:lower:]' '[:upper:]')/DOCS/SPECS/ACME/PLAN.MD\"}"
  expect_eq "court guard r2: a Read of the main tree in another letter case is denied" deny "$(cg council-opus "$CRW" Read "$p")"
fi
fi # part functional

if part latency; then # --- part latency: the two 200 ms medians, on the fixture library above
echo "--- latency"
LAT="$HIVE"; LW="$W"; SRCNAME="fixture library"
if [ -n "${VULYK_LATENCY_LIBRARY:-}" ] && [ -d "$VULYK_LATENCY_LIBRARY" ]; then
  mkdir -p "$T/yt/docs"; cp -r "$VULYK_LATENCY_LIBRARY" "$T/yt/docs/defects"; LAT="$T/yt"
  LW="$(cd "$LAT" && { pwd -W 2>/dev/null || pwd; })"; SRCNAME="real library copy"
fi
m="$(median_ms "$LAT" "{\"session_id\":\"lat\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"cd pipeline && python edit_build.py EDIT_3.json --check\"},\"cwd\":\"$LW\"}")"
echo "  median defects-inject.sh (Bash): ${m} ms over 30 calls ($SRCNAME; target <= 200 ms)"
if [ "$m" -le 200 ]; then ok "median latency, Bash, <= 200 ms"
else bad "median latency, Bash, ${m} ms > 200 ms"; fi
m="$(median_ms "$LAT" "{\"session_id\":\"lat\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$LW/pipeline/voiceover.py\"},\"cwd\":\"$LW\"}")"
echo "  median defects-inject.sh (Edit): ${m} ms over 30 calls ($SRCNAME; target <= 200 ms)"
if [ "$m" -le 200 ]; then ok "median latency, Edit, <= 200 ms"
else bad "median latency, Edit, ${m} ms > 200 ms"; fi
# Read joined the matcher (0.41): a Read of anything but a story must stay in bash, far under the Edit cost.
m="$(median_ms "$LAT" "{\"session_id\":\"lat\",\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$LW/pipeline/voiceover.py\"},\"cwd\":\"$LW\"}")"
echo "  median defects-inject.sh (Read, not a story): ${m} ms over 30 calls ($SRCNAME; target <= 100 ms)"
if [ "$m" -le 100 ]; then ok "median latency, non-story Read, <= 100 ms"
else bad "median latency, non-story Read, ${m} ms > 100 ms"; fi
fi # part latency

CHECKS="$(grep -c . "$LEDGER" || true)"
FAILED="$(grep -c . "$FAILS" || true)"
[ "$FAILED" -eq 0 ] || fail=1
echo "inject.test.sh: $CHECKS checks, $FAILED failed"
exit $fail
