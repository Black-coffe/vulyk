#!/usr/bin/env bash
# The defects-inject hook contract (docs/specs/self-learning/contract.md §1 effective status, §3),
# driven through a fixture library - no model calls, no network. Covers .claude/hooks/defects-inject.sh:
# which cards are injected (text only; block with check + 2 fixtures and revoked never), how a target
# matches (path glob on file_path / notebook_path, a path token or a `cmd:` regex on a Bash line),
# the session + agent dedup, `reset` on SessionStart, the 4000-char budget, and the latency budget.
#
#   Usage: bash tests/inject.test.sh            # from the VULYK repo root
#
# Latency runs against D:/YouTube_AI/docs/defects copied to a temp dir when that library exists
# (the pilot's 19 real cards), else against the fixture library. Asserted <= 400 ms median; the
# contract target is <= 200 ms and the measured median is printed either way.
set -u
SRC="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$SRC/.claude/hooks/defects-inject.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fail=0
PYBIN="$(command -v python3 || command -v python)" || { echo "inject.test.sh: needs python3 or python"; exit 1; }
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
- BLOCKNEVER must not be injected.
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
# CRLF and the Russian heading must be tolerated.
printf -- '---\r\nid: json-card\r\ntitle: JSON sheets\r\nstatus: text\r\npaths: ["*.json"]\r\n---\r\n\r\n## Нельзя\r\n\r\n- JSONNEVER hand-edit a sheet.\r\n' \
  > "$D/json-card.md"
LONG="$(printf 'x%.0s' $(seq 680))"
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

# --- what is injected -------------------------------------------------------------------------
echo "--- inject"
o="$(run "$HIVE" "$(edit s1 "$W/pipeline/voiceover.py")")"
printf '%s' "$o" | expect "the output is the PreToolUse JSON form" '"hookEventName": "PreToolUse"'
printf '%s' "$o" | expect "exit 0" "rc=0"
c="$(printf '%s' "$o" | ctx)"
printf '%s' "$c" | expect "Edit on a matching glob names the text card" "voice-text — Voice text rule"
printf '%s' "$c" | expect "its Never lines come prefixed with ✗" "✗ Never A1 cut on the word-end mark."
printf '%s' "$c" | expect "a wrapped Never line is joined" "✗ Never A2 raise the music before lead_s."
printf '%s' "$c" | expect_absent "Allowed lines are not injected" "ALLOWEDLINE"
printf '%s' "$c" | expect_absent "a block card (check + 2 fixtures) is not injected" "BLOCKNEVER"
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
printf '%s' "$c" | expect "Bash injects via a cmd: regex (block with <2 fixtures is text)" "✗ CMDNEVER build without the check."
printf '%s' "$c" | expect "Bash injects via a path token" "✗ JSONNEVER hand-edit a sheet."
printf '%s' "$c" | expect_absent "Bash: a card whose globs miss every token stays out" "voice-text"
printf '%s' "$c" | expect_absent "Bash: a revoked cmd: card stays out" "REVOKEDNEVER"
o="$(run "$HIVE" "$(bashcall s6 "python \\\"$W/pipeline/voiceover.py\\\" --check")")"
printf '%s' "$o" | ctx | expect "Bash: a quoted absolute path token is made repo-relative" "voice-text"
run "$HIVE" "$(bashcall s3 'ls -la docs && git status')" | expect_silent "an unrelated Bash command is silent"

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
n="$(printf '%s' "$c" | sed '/^Also matched/d' | wc -m | tr -d ' ')"
if [ "$n" -le 4000 ]; then ok "the shown cards stay within 4000 chars ($n)"
else bad "the shown cards are $n chars"; fi
printf '%s' "$c" | expect "cards past the budget are listed" "Also matched, not shown (budget)"
printf '%s' "$c" | expect "the list names the last card by path" "docs/defects/big-08.md"
printf '%s' "$c" | expect_absent "a listed card's lines are not shown" "BIG08"
printf '%s' "$c" | expect "the first card is shown in full" "BIG01 x"

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
if command -v python >/dev/null 2>&1; then
  o="$(printf '%s' "$(edit stub "$W/pipeline/voiceover.py")" | PATH="$T/stubbin:$PATH" CLAUDE_PROJECT_DIR="$HIVE" bash "$HOOK")"
  if printf '%s' "$o" | grep -q additionalContext; then ok "a python3 stub exiting 9009 falls through to python"
  else bad "a python3 stub silenced the hook"; fi
else echo "  skip  no python on PATH besides python3"; fi

# --- latency ----------------------------------------------------------------------------------
echo "--- latency"
LAT="$HIVE"; LW="$W"; SRCNAME="fixture library"
if [ -d "D:/YouTube_AI/docs/defects" ]; then
  mkdir -p "$T/yt/docs"; cp -r "D:/YouTube_AI/docs/defects" "$T/yt/docs/"; LAT="$T/yt"
  LW="$(cd "$LAT" && { pwd -W 2>/dev/null || pwd; })"; SRCNAME="YouTube_AI library copy"
fi
m="$(median_ms "$LAT" "{\"session_id\":\"lat\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"cd pipeline && python edit_build.py EDIT_3.json --check\"},\"cwd\":\"$LW\"}")"
echo "  median defects-inject.sh (Bash): ${m} ms over 30 calls ($SRCNAME; target <= 200 ms)"
if [ "$m" -le 200 ]; then ok "median latency, Bash, <= 200 ms"
else bad "median latency, Bash, ${m} ms > 200 ms"; fi
m="$(median_ms "$LAT" "{\"session_id\":\"lat\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$LW/pipeline/voiceover.py\"},\"cwd\":\"$LW\"}")"
echo "  median defects-inject.sh (Edit): ${m} ms over 30 calls ($SRCNAME; target <= 200 ms)"
if [ "$m" -le 200 ]; then ok "median latency, Edit, <= 200 ms"
else bad "median latency, Edit, ${m} ms > 200 ms"; fi

CHECKS="$(grep -c . "$LEDGER" || true)"
FAILED="$(grep -c . "$FAILS" || true)"
[ "$FAILED" -eq 0 ] || fail=1
echo "inject.test.sh: $CHECKS checks, $FAILED failed"
exit $fail
