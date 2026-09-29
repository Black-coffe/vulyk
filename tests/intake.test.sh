#!/usr/bin/env bash
# The defect-intake hook contract (docs/specs/self-learning/contract.md §3), driven through a
# fixture library - no model calls, no network. Covers .claude/hooks/defect-intake.sh: what fires
# (timecode, lexicon, card keys), what stays silent (plain requests, timecodes only inside harness
# or pasted blocks, revoked cards, no library, bad JSON, no python), and the latency budget.
#
#   Usage: bash tests/intake.test.sh            # from the VULYK repo root
#
# Latency runs against D:/YouTube_AI/docs/defects copied to a temp dir when that library exists
# (the pilot's 19 real cards), else against the fixture library. Asserted <= 400 ms median; the
# contract target is <= 200 ms and the measured median is printed either way.
set -u
SRC="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$SRC/.claude/hooks/defect-intake.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fail=0
PYBIN="$(command -v python3 || command -v python)" || { echo "intake.test.sh: needs python3 or python"; exit 1; }
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

expect_silent() { # expect_silent <label>   (reads the hook's stdout; "rc=N" is appended by run)
  local label="$1" out; out="$(cat)"
  if [ "$out" = "rc=0" ]; then ok "$label"
  else bad "$label - expected no output and exit 0, got:"; printf '%s\n' "$out" | sed 's/^/        /'; fi
}

run() { # run <root> <json>   -> the hook's stdout, then a line rc=<exit code>
  local out rc
  out="$(printf '%s' "$2" | CLAUDE_PROJECT_DIR="$1" bash "$HOOK")"; rc=$?
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
if bash -n "$HOOK" 2>/dev/null; then ok "bash -n .claude/hooks/defect-intake.sh"
else bad "bash -n .claude/hooks/defect-intake.sh failed"; bash -n "$HOOK"; exit 1; fi

# --- the fixture library ----------------------------------------------------------------------
HIVE="$T/hive"; mkdir -p "$HIVE/docs/defects"
cat > "$HIVE/docs/defects/README.md" <<'EOF'
# Defect library - the index, never a card. keys: [readme-word]
EOF
cat > "$HIVE/docs/defects/speech-cut.md" <<'EOF'
---
id: speech-cut
title: Clipped speech
status: text
keys: [clipped, "cut off", полуслов]
paths: ["pipeline/voiceover.py"]
---

# Clipped speech

## Never
- Cut on the word-end mark.
EOF
cat > "$HIVE/docs/defects/old-rule.md" <<'EOF'
---
id: old-rule
title: A lifted rule
status: revoked
keys: [legacy-word]
---

# A lifted rule
EOF
# CRLF must be tolerated.
printf -- '---\r\nid: hiss\r\ntitle: Hiss on the track\r\nstatus: text\r\nkeys: [hiss, шипит]\r\n---\r\n\r\n# Hiss\r\n' \
  > "$HIVE/docs/defects/hiss.md"
NOLIB="$T/nolib"; mkdir -p "$NOLIB/docs"

# --- what fires -------------------------------------------------------------------------------
echo "--- fires"
o="$(run "$HIVE" '{"prompt":"at 10:04 the voice drops","session_id":"s"}')"
printf '%s' "$o" | expect "a timecode fires" "Looks like an owner correction"
printf '%s' "$o" | expect "the trigger names the timecode" "timecode 10:04"
printf '%s' "$o" | expect "the output is the UserPromptSubmit JSON form" '"hookEventName": "UserPromptSubmit"'
printf '%s' "$o" | expect "no class matched says none" "Matched classes: none"
printf '%s' "$o" | expect "exit 0" "rc=0"

o="$(run "$HIVE" '{"prompt":"опять обрезал голос","session_id":"s"}')"
printf '%s' "$o" | expect "\"опять обрезал голос\" fires with no timecode and no card key" "Looks like an owner correction"
o="$(run "$HIVE" '{"prompt":"ты обрезал голос в конце","session_id":"s"}')"
printf '%s' "$o" | expect "\"обрезал\" alone fires" "Looks like an owner correction"
o="$(run "$HIVE" '{"prompt":"This is not what I asked for","session_id":"s"}')"
printf '%s' "$o" | expect "an English lexicon phrase fires" "Looks like an owner correction"

o="$(run "$HIVE" '{"prompt":"the ending sounds Clipped to me","session_id":"s"}')"
printf '%s' "$o" | expect "a card key fires, case-insensitive" "Looks like an owner correction"
printf '%s' "$o" | expect "a card key names the card id" "Matched classes: speech-cut"
o="$(run "$HIVE" '{"prompt":"there is hiss under the voice","session_id":"s"}')"
printf '%s' "$o" | expect "a CRLF card's keys are read" "Matched classes: hiss"

o="$(run "$HIVE" '{"prompt":"<pasted_content id=\"1\">log at 10:04</pasted_content id=\"1\"> опять","session_id":"s"}')"
printf '%s' "$o" | expect "human text still fires next to a pasted block" "Looks like an owner correction"
printf '%s' "$o" | expect_absent "the pasted block's timecode is not the trigger" "timecode"

o="$(run "$HIVE" '{"prompt":"at 10:04 again","session_id":"s"}')"
n="$(printf '%s' "$o" | head -1 | "$PYBIN" -c 'import json,sys; print(len(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"]))')"
if [ "${n:-9999}" -le 600 ]; then ok "additionalContext with no ids stays within 600 chars ($n)"
else bad "additionalContext is ${n:-unparsable} chars"; fi

# --- what stays silent ------------------------------------------------------------------------
echo "--- silent"
run "$HIVE" '{"prompt":"нет, давай завтра","session_id":"s"}' | expect_silent "\"нет, давай завтра\" is silent"
run "$HIVE" '{"prompt":"Сделай 3 варианта обложки","session_id":"s"}' | expect_silent "\"Сделай 3 варианта обложки\" is silent"
run "$HIVE" '{"prompt":"<task-notification>agent done at 10:04</task-notification> ok, next","session_id":"s"}' \
  | expect_silent "a timecode only inside <task-notification> is silent"
run "$HIVE" '{"prompt":"<system-reminder>\nnow 12:30, again\n</system-reminder>\nсделай отчёт","session_id":"s"}' \
  | expect_silent "a timecode only inside <system-reminder> is silent"
run "$HIVE" '{"prompt":"<cross-session-message from=\"x\">render at 03:25 done</cross-session-message> продолжай","session_id":"s"}' \
  | expect_silent "a timecode only inside <cross-session-message from=\"x\"> is silent"
run "$HIVE" '{"prompt":"<pasted_content id=\"1\">00:01 start\n00:02 end</pasted_content id=\"1\"> разбери лог","session_id":"s"}' \
  | expect_silent "a timecode only inside <pasted_content id=\"1\"> is silent"
run "$HIVE" '{"prompt":"посмотри вывод\n```\n[04:30] ffmpeg done\n```\nи продолжай","session_id":"s"}' \
  | expect_silent "a timecode only inside a \`\`\` fence is silent"
run "$HIVE" '{"prompt":"the legacy-word thing, please","session_id":"s"}' | expect_silent "a revoked card's keys do not fire"
run "$HIVE" '{"prompt":"mention readme-word here","session_id":"s"}' | expect_silent "README.md is not a card"
run "$NOLIB" '{"prompt":"at 10:04 опять","session_id":"s"}' | expect_silent "no docs/defects/ is silent"
run "$HIVE" '{"prompt": "at 10:04' | expect_silent "malformed JSON is silent, exit 0"
run "$HIVE" '' | expect_silent "empty stdin is silent, exit 0"
mkdir -p "$T/nopy"
o="$(printf '%s' '{"prompt":"at 10:04 опять"}' | CLAUDE_PROJECT_DIR="$HIVE" PATH="$T/nopy" "$BASH" "$HOOK"; echo "rc=$?")"
printf '%s' "$o" | expect_silent "no python on PATH is silent, exit 0"
o="$(cd "$HIVE" && printf '%s' "{\"prompt\":\"at 10:04\",\"cwd\":\"$(pwd -W 2>/dev/null || pwd)\"}" | env -u CLAUDE_PROJECT_DIR bash "$HOOK")"
printf '%s' "$o" | expect "without CLAUDE_PROJECT_DIR the input cwd is the root" "Looks like an owner correction"

# --- a python3 that runs nothing (review 0.19, major 1) ---------------------------------------
echo "--- python3 stub"
mkdir -p "$T/stubbin"; printf '#!/bin/sh
exit 9009
' > "$T/stubbin/python3"; chmod +x "$T/stubbin/python3"
if command -v python >/dev/null 2>&1; then
  o="$(printf '%s' '{"prompt":"опять обрезал голос","session_id":"stub"}' | PATH="$T/stubbin:$PATH" CLAUDE_PROJECT_DIR="$HIVE" bash "$HOOK")"
  if printf '%s' "$o" | grep -q additionalContext; then ok "a python3 stub exiting 9009 falls through to python"
  else bad "a python3 stub silenced the hook"; fi
else echo "  skip  no python on PATH besides python3"; fi

# --- latency ----------------------------------------------------------------------------------
echo "--- latency"
LAT="$HIVE"; SRCNAME="fixture library"
if [ -d "D:/YouTube_AI/docs/defects" ]; then
  mkdir -p "$T/yt/docs"; cp -r "D:/YouTube_AI/docs/defects" "$T/yt/docs/"; LAT="$T/yt"; SRCNAME="YouTube_AI library copy"
fi
m="$(median_ms "$LAT" '{"prompt":"На 01:03 обрів слова после \"глубоко\", опять","session_id":"lat"}')"
echo "  median defect-intake.sh: ${m} ms over 30 calls ($SRCNAME; target <= 200 ms)"
if [ "$m" -le 200 ]; then ok "median latency <= 200 ms"
else bad "median latency ${m} ms > 200 ms"; fi

# --- --lexicon: the same word list as portable ERE, for litopys corrections (evolve-corrections-count)
echo "--- --lexicon exports the lexicon as ERE lines"
timeout 10 bash "$HOOK" --lexicon > "$T/lex.txt" < <(sleep 30)   # an open stdin that never ends: reading it would time out
[ $? -eq 0 ] && ok "--lexicon exits 0 without reading stdin" || bad "--lexicon read stdin or failed"
LX=""; for l in C.UTF-8 C.utf8 en_US.UTF-8 en_US.utf8; do locale -a 2>/dev/null | grep -qx "$l" && { LX="$l"; break; }; done
lex() { printf '%s\n' "$1" | LC_ALL="${LX:-C.UTF-8}" grep -Eiq -f "$T/lex.txt"; }
lex "переделайте это" && ok "a stem matches at a word start (переделайте)" || bad "stem at word start missed"
lex "непеределай" && bad "a stem inside a word matched (непеределай)" || ok "neighbour: a stem inside a word does not match"
lex "again!" && ok "a phrase with a punctuation edge matches (again!)" || bad "phrase at an edge missed"
lex "against it" && bad "a phrase inside a longer word matched (against)" || ok "neighbour: a phrase needs both edges (against)"
lex "Опять не то" && ok "a capitalised Cyrillic stem matches under a UTF-8 locale" || bad "Cyrillic case not folded"
[ "$(grep -c . "$T/lex.txt")" -eq "$("$PYBIN" -c "
import ast,re,sys
s=open(sys.argv[1],encoding='utf-8').read()
print(sum(len(ast.literal_eval(re.search(r'^%s = (\[.*\])' % k, s, re.M).group(1))) for k in ('STEMS', 'WORDS')))" "$HOOK")" ] \
  && ok "one ERE line per stem and phrase of the hook's own lists" || bad "the export and the hook's lists differ in length"

CHECKS="$(grep -c . "$LEDGER" || true)"
FAILED="$(grep -c . "$FAILS" || true)"
[ "$FAILED" -eq 0 ] || fail=1
echo "intake.test.sh: $CHECKS checks, $FAILED failed"
exit $fail
