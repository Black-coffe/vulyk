#!/usr/bin/env bash
# The defect-intake hook contract (docs/specs/self-learning/contract.md §3), driven through a
# fixture library - no model calls, no network. Covers .claude/hooks/defect-intake.sh: what fires
# (timecode, lexicon, card keys), what stays silent (plain requests, timecodes only inside harness
# or pasted blocks, revoked cards, no library, bad JSON, no python), and the latency budget.
# rules-tree-05: the explicit phrase, paste and dictation-tag handling, side-agent notes, the
# `answer` mode (AskUserQuestion), and the install.sh --upgrade wiring of both on a scratch hive.
#
#   Usage: bash tests/intake.test.sh                  # from the VULYK repo root, every part
#          bash tests/intake.test.sh --part <name>    # functional (every assert but the medians) or latency
#          bash tests/intake.test.sh --list-parts     # the part names, one per line
# tests/full-suite.sh runs the functional part among its parallel jobs and the latency part alone, last.
#
# Latency runs against D:/YouTube_AI/docs/defects copied to a temp dir when that library exists
# (the pilot's 19 real cards), else against the fixture library. Asserted <= 400 ms median; the
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
    *) echo "usage: bash tests/intake.test.sh [--part <name>] [--list-parts]" >&2; exit 2 ;;
  esac
  shift
done
part() { [ -z "$PART" ] || [ "$PART" = "$1" ]; } # `if part <name>; then ... fi` wraps each part
SRC="$(cd "$(dirname "$0")/.." && pwd)"
. "$SRC/scripts/lib.sh"   # vulyk_python, run_capped
HOOK="$SRC/.claude/hooks/defect-intake.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fail=0
vulyk_python || { echo "intake.test.sh: needs python3 or python"; exit 1; }
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

ctx() { # ctx <root> <json> [hook arg]   -> the decoded additionalContext, or "(silent)"
  printf '%s' "$2" | CLAUDE_PROJECT_DIR="$1" bash "$HOOK" ${3:+"$3"} | "$PYBIN" -c '
import json, sys
raw = sys.stdin.read()
out = json.loads(raw)["hookSpecificOutput"]["additionalContext"] if raw.strip() else "(silent)"
sys.stdout.buffer.write(out.encode("utf-8"))'
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

if part functional; then # --- part functional: every case but the latency median
# --- what fires -------------------------------------------------------------------------------
echo "--- fires"
o="$(run "$HIVE" '{"prompt":"at 10:04 the voice drops","session_id":"s"}')"
printf '%s' "$o" | expect "a timecode fires" "looks like a correction ("
printf '%s' "$o" | expect "the trigger names the timecode" "timecode 10:04"
printf '%s' "$o" | expect "the output is the UserPromptSubmit JSON form" '"hookEventName": "UserPromptSubmit"'
printf '%s' "$o" | expect "no class matched says none" "file the quote now in a new card"
printf '%s' "$o" | expect "exit 0" "rc=0"

o="$(run "$HIVE" '{"prompt":"опять обрезал голос","session_id":"s"}')"
printf '%s' "$o" | expect "\"опять обрезал голос\" fires with no timecode and no card key" "looks like a correction ("
o="$(run "$HIVE" '{"prompt":"ты обрезал голос в конце","session_id":"s"}')"
printf '%s' "$o" | expect "\"обрезал\" alone fires" "looks like a correction ("
o="$(run "$HIVE" '{"prompt":"This is not what I asked for","session_id":"s"}')"
printf '%s' "$o" | expect "an English lexicon phrase fires" "looks like a correction ("

o="$(run "$HIVE" '{"prompt":"the ending sounds Clipped to me","session_id":"s"}')"
printf '%s' "$o" | expect "a card key fires, case-insensitive" "looks like a correction ("
printf '%s' "$o" | expect "a card key names the card id" "file the quote now in speech-cut "
o="$(run "$HIVE" '{"prompt":"there is hiss under the voice","session_id":"s"}')"
printf '%s' "$o" | expect "a CRLF card's keys are read" "file the quote now in hiss "

o="$(run "$HIVE" '{"prompt":"<pasted_content id=\"1\">log at 10:04</pasted_content id=\"1\"> опять","session_id":"s"}')"
printf '%s' "$o" | expect "human text still fires next to a pasted block" "looks like a correction ("
printf '%s' "$o" | expect_absent "the pasted block's timecode is not the trigger" "timecode"
printf '%s' "$o" | expect_absent "typed words win over the paste: no are-these-your-words line" "a pasted text"

o="$(run "$HIVE" '{"prompt":"at 10:04 again","session_id":"s"}')"
n="$(printf '%s' "$o" | head -1 | "$PYBIN" -c 'import json,sys; print(len(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"]))')"
if [ "${n:-9999}" -le 600 ]; then ok "additionalContext with no ids stays within 600 chars ($n)"
else bad "additionalContext is ${n:-unparsable} chars"; fi

# --- capture (rules-tree-05): the explicit phrase, pastes, side-agent notes ----------------------
echo "--- the explicit phrase"
ctx "$HIVE" '{"prompt":"внеси в запрет: обрезка на полуслове"}' \
  | expect "RU typed \"внеси в запрет\" asks for a never card" "owner asks to file a never card: write it now, verbatim"
ctx "$HIVE" '{"prompt":"<pasted_content id=\"1\">запиши в правило: режь только по паузе</pasted_content id=\"1\"> вот"}' \
  | expect "RU \"запиши в правило\" inside a paste asks for a how-to card" "owner asks to file a how-to card"
ctx "$HIVE" '{"prompt":"додай до дозволу: можна різати на паузі"}' \
  | expect "UK \"додай до дозволу\" asks for an allowed card" "owner asks to file a allowed card"
ctx "$HIVE" '{"prompt":"вот это внеси это в запрет, обрезка"}'   | expect "RU spoken \"внеси это в запрет\" asks for a never card" "owner asks to file a never card"
ctx "$HIVE" '{"prompt":"додай оце до заборон"}'   | expect "UK \"додай оце до заборон\" asks for a never card" "owner asks to file a never card"
ctx "$HIVE" '{"prompt":"add this to never: cutting a word in half"}' \
  | expect "EN \"add this to never\" asks for a never card" "owner asks to file a never card"
o="$(ctx "$HIVE" '{"prompt":"опять запрет нарушен, правило не то"}')"
printf '%s' "$o" | expect_absent "the lexicon without the phrase does not ask for a card" "owner asks to file"
printf '%s' "$o" | expect "and still files the typed correction" "looks like a correction"

echo "--- typed and pasted corrections"
o="$(ctx "$HIVE" '{"prompt":"опять обрезал голос"}')"
printf '%s' "$o" | expect "a typed correction is filed at once" "file the quote now in a new card and report one line with «отмени»"
printf '%s' "$o" | expect_absent "the old reminder text is gone" "Looks like an owner correction"
o="$(ctx "$HIVE" '{"prompt":"<pasted_content id=\"1\">опять обрезал голос</pasted_content id=\"1\"> посмотри"}')"
printf '%s' "$o" | expect "a correction only inside a paste asks the owner first" "ask the owner in one line whether these are their words before filing"
printf '%s' "$o" | expect_absent "and does not file it at once" "file the quote now"
o="$(VULYK_DICTATION_TAG='[VoiceDrop]' ctx "$HIVE" '{"prompt":"<pasted_content id=\"1\">[VoiceDrop] опять обрезал голос</pasted_content id=\"1\">"}')"
printf '%s' "$o" | expect "a paste starting with VULYK_DICTATION_TAG counts as typed" "file the quote now"
o="$(ctx "$HIVE" '{"prompt":"<pasted_content id=\"1\">[VoiceDrop] опять обрезал голос</pasted_content id=\"1\">"}')"
printf '%s' "$o" | expect "without the tag set the same paste asks the owner" "whether these are their words"

echo "--- side-agent notes are never the owner"
ctx "$HIVE" '{"prompt":"Here is a note offered by a side agent: the render failed опять on the same step, retry later.\n\nпродолжай"}' \
  | expect "a «опять» only inside a side-agent note is silent (the original case)" "(silent)"
ctx "$HIVE" '{"prompt":"<system-notice>\nHere is a note offered by a side agent: опять падает сборка\n</system-notice>\nok"}' \
  | expect "a side-agent note ending at its tag is silent" "(silent)"
ctx "$HIVE" '{"prompt":"Here is a note offered by a side agent: внеси в запрет: clipped audio at the end.\n\nok"}' \
  | expect "neighbour: the phrase and a card key inside a side-agent note are silent" "(silent)"
ctx "$HIVE" '{"prompt":"Here is a note offered by a side agent: all good.\n\nопять не тот цвет"}' \
  | expect "the owner's own «опять» after the note still fires" "looks like a correction"

echo "--- answer: AskUserQuestion results"
Q='"tool_name":"AskUserQuestion","tool_input":{"questions":[{"question":"Which cover?","header":"Cover","multiSelect":false,"options":[{"label":"Blue","description":"calm"},{"label":"Red","description":"loud"}]}]}'
o="$(ctx "$HIVE" "{$Q,\"tool_response\":{\"answers\":{\"Which cover?\":\"Blue\"}}}" answer)"
expect_eq "a chosen option prints the decision line and nothing else" "[VULYK] decision: «Blue» on «Which cover?»" "$o"
o="$(ctx "$HIVE" "{$Q,\"tool_response\":{\"answers\":{\"Which cover?\":\"Blue, \\\"внеси в запрет: синий фон на превью\\\"\"}}}" answer)"
printf '%s' "$o" | expect "free text with the phrase asks for the card" "owner asks to file a never card"
printf '%s' "$o" | expect "and carries the owner's text" "«внеси в запрет: синий фон на превью»"
printf '%s' "$o" | expect "the chosen option is still a decision" "[VULYK] decision: «Blue»"
o="$(ctx "$HIVE" "{$Q,\"tool_response\":{\"answers\":{\"Which cover?\":\"опять не тот цвет\"}}}" answer)"
printf '%s' "$o" | expect "free text with only the lexicon is filed as typed" "file the quote now"
printf '%s' "$o" | expect_absent "free text alone prints no decision" "decision:"
ctx "$HIVE" "{$Q,\"tool_response\":{}}" answer | expect "a payload without answers is silent" "(silent)"
ctx "$NOLIB" "{$Q,\"tool_response\":{\"answers\":{\"Which cover?\":\"Blue\"}}}" answer | expect "answer without docs/defects/ is silent" "(silent)"

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
  | expect_silent "a timecode only inside <pasted_content id=\"1\"> is silent (a log: the paste pass reads words and keys)"
run "$HIVE" '{"prompt":"посмотри вывод\n```\n[04:30] ffmpeg done\n```\nи продолжай","session_id":"s"}' \
  | expect_silent "a timecode only inside a \`\`\` fence is silent"
# evolve 2026-10-19: a relayed side-agent note ("...теперь снова пишет Opus...") was flagged as an owner
# correction; the owner's own words typed after a note still fire.
run "$HIVE" '{"prompt":"Here is a note offered by a side agent:\n\n> Heads up · повтор теперь снова пишет Opus\n>\n> - at 10:04 опять","session_id":"s"}' \
  | expect_silent "a relayed side-agent note is not an owner correction"
run "$HIVE" '{"prompt":"Here is a note offered by a side agent:\n\n> Heads up · всё ок\n\nопять не так","session_id":"s"}' \
  | expect "the owner's words after a side-agent note still fire" "looks like a correction"
run "$HIVE" '{"prompt":"the legacy-word thing, please","session_id":"s"}' | expect_silent "a revoked card's keys do not fire"
run "$HIVE" '{"prompt":"mention readme-word here","session_id":"s"}' | expect_silent "README.md is not a card"
run "$NOLIB" '{"prompt":"at 10:04 опять","session_id":"s"}' | expect_silent "no docs/defects/ is silent"
run "$HIVE" '{"prompt": "at 10:04' | expect_silent "malformed JSON is silent, exit 0"
run "$HIVE" '' | expect_silent "empty stdin is silent, exit 0"
mkdir -p "$T/nopy"
o="$(printf '%s' '{"prompt":"at 10:04 опять"}' | CLAUDE_PROJECT_DIR="$HIVE" PATH="$T/nopy" "$BASH" "$HOOK"; echo "rc=$?")"
printf '%s' "$o" | expect_silent "no python on PATH is silent, exit 0"
o="$(cd "$HIVE" && printf '%s' "{\"prompt\":\"at 10:04\",\"cwd\":\"$(pwd -W 2>/dev/null || pwd)\"}" | env -u CLAUDE_PROJECT_DIR bash "$HOOK")"
printf '%s' "$o" | expect "without CLAUDE_PROJECT_DIR the input cwd is the root" "looks like a correction ("

# --- a python3 that runs nothing (review 0.19, major 1) ---------------------------------------
echo "--- python3 stub"
mkdir -p "$T/stubbin"; printf '#!/bin/sh
exit 9009
' > "$T/stubbin/python3"; chmod +x "$T/stubbin/python3"
if ( VULYK_PY=""; PATH="$T/stubbin:$PATH"; vulyk_python ); then
  o="$(printf '%s' '{"prompt":"опять обрезал голос","session_id":"stub"}' | PATH="$T/stubbin:$PATH" CLAUDE_PROJECT_DIR="$HIVE" bash "$HOOK")"
  if printf '%s' "$o" | grep -q additionalContext; then ok "a python3 stub exiting 9009 falls through to python"
  else bad "a python3 stub silenced the hook"; fi
else echo "  skip  no python on PATH besides python3"; fi

# --- install.sh --upgrade rewires the inject matcher and adds the answer hook (rules-tree-05) ---
echo "--- install.sh --upgrade wiring"
UP="$T/up"; mkdir -p "$UP"; export VULYK_CLAUDE="$T/no-claude"   # no run reaches the real claude binary
# The plain fresh install is the one tests/telemetry.test.sh caches (same dir, lock and layout; its install
# part asserts the cache equals a real install): built once per run under VULYK_INSTALL_CACHE, else here.
ICACHE="${VULYK_INSTALL_CACHE:-$T/install-cache}" w=0
while [ ! -d "$ICACHE/tree" ] && [ "$w" -lt 300 ]; do
  mkdir -p "$(dirname "$ICACHE")"
  if mkdir "$ICACHE.lock" 2>/dev/null; then
    echo "$$" > "$ICACHE.lock/pid"
    if [ ! -d "$ICACHE/tree" ]; then
      tmp="$ICACHE.build.$$"; rm -rf "$tmp"; mkdir -p "$tmp/tree"
      bash "$SRC/install.sh" "$tmp/tree" --telemetry off > "$tmp/install.out" 2>&1
      mv "$tmp" "$ICACHE"
    fi
    rm -rf "$ICACHE.lock"; break
  fi
  holder="$(cat "$ICACHE.lock/pid" 2>/dev/null)"
  if { [ -n "$holder" ] && ! kill -0 "$holder" 2>/dev/null; } || { [ -z "$holder" ] && [ "$w" -ge 10 ]; }; then
    mv "$ICACHE.lock" "$ICACHE.lock.stale.$$" 2>/dev/null && rm -rf "$ICACHE.lock.stale.$$"; continue
  fi
  sleep 1; w=$((w + 1))
done
[ -d "$ICACHE/tree" ] && cp -a "$ICACHE/tree/." "$UP/" && cp "$ICACHE/install.out" "$T/up-install.out"
if [ -f "$UP/.claude/settings.json" ]; then
  F="$UP/.claude/settings.json"
  jq '.hooks.PreToolUse[0].matcher = "Edit|Write|MultiEdit|NotebookEdit|Bash"
      | .hooks.PostToolUse |= map(select(.matcher != "AskUserQuestion"))' "$F" > "$T/old.json" && mv "$T/old.json" "$F"
  bash "$SRC/install.sh" "$UP" --upgrade --telemetry off > "$T/up.out" 2>&1
  expect_eq "an upgraded hive's inject matcher is the widened one" \
    "Edit|Write|MultiEdit|NotebookEdit|Read|Bash|WebFetch|WebSearch|Agent|mcp__.*" \
    "$(jq -r '.hooks.PreToolUse[] | select(any(.hooks[]; .command | test("defects-inject")) ) | .matcher' "$F")"
  expect_eq "defects-inject.sh is wired once on PreToolUse" "1" \
    "$(jq -r '.hooks.PreToolUse[].hooks[].command' "$F" | grep -c 'defects-inject.sh')"
  expect_eq "the PostToolUse AskUserQuestion block runs defect-intake.sh answer" "1" \
    "$(jq -r '.hooks.PostToolUse[] | select(.matcher == "AskUserQuestion") | .hooks[].command' "$F" | grep -c 'defect-intake.sh answer$')"
  cp "$F" "$T/up.before"
  bash "$SRC/install.sh" "$UP" --upgrade --telemetry off > "$T/up2.out" 2>&1
  expect_eq "a second upgrade leaves settings.json byte-identical" "1" "$(cmp -s "$T/up.before" "$F" && echo 1 || echo 0)"
  # 0.41: Read joins the matcher (cards on reading a story); a hive on the 0.32 matcher is rewired too.
  inject_matcher() { jq -r '.hooks.PreToolUse[] | select(any(.hooks[]; .command | test("defects-inject")) ) | .matcher' "$F" | tr -d '\r'; }
  jq '(.hooks.PreToolUse[] | select(any(.hooks[]; .command | test("defects-inject")))).matcher = "Edit|Write|MultiEdit|NotebookEdit|Bash|WebFetch|WebSearch|Agent|mcp__.*"' \
    "$F" > "$T/old.json" && mv "$T/old.json" "$F"
  bash "$SRC/install.sh" "$UP" --upgrade --telemetry off > "$T/up3.out" 2>&1
  expect_eq "a hive on the 0.32 matcher gets the one with Read" \
    "Edit|Write|MultiEdit|NotebookEdit|Read|Bash|WebFetch|WebSearch|Agent|mcp__.*" "$(inject_matcher)"
  expect_eq "... with defects-inject.sh wired once" "1" \
    "$(jq -r '.hooks.PreToolUse[].hooks[].command' "$F" | grep -c 'defects-inject.sh')"
  jq '(.hooks.PreToolUse[] | select(any(.hooks[]; .command | test("defects-inject")))).matcher = "Edit|Bash"' \
    "$F" > "$T/old.json" && mv "$T/old.json" "$F"
  bash "$SRC/install.sh" "$UP" --upgrade --telemetry off > "$T/up4.out" 2>&1
  expect_eq "a matcher the owner set by hand is kept" "Edit|Bash" "$(inject_matcher)"
else bad "install.sh into a scratch hive failed"; sed 's/^/        /' "$T/up-install.out" | tail -5; fi
fi # part functional

if part latency; then # --- part latency: the 200 ms median, on the fixture library above
echo "--- latency"
LAT="$HIVE"; SRCNAME="fixture library"
if [ -d "D:/YouTube_AI/docs/defects" ]; then
  mkdir -p "$T/yt/docs"; cp -r "D:/YouTube_AI/docs/defects" "$T/yt/docs/"; LAT="$T/yt"; SRCNAME="YouTube_AI library copy"
fi
m="$(median_ms "$LAT" '{"prompt":"На 01:03 обрів слова после \"глубоко\", опять","session_id":"lat"}')"
echo "  median defect-intake.sh: ${m} ms over 30 calls ($SRCNAME; target <= 200 ms)"
if [ "$m" -le 200 ]; then ok "median latency <= 200 ms"
else bad "median latency ${m} ms > 200 ms"; fi
fi # part latency

if part functional; then
# --- --lexicon: the same word list as portable ERE, for litopys corrections (evolve-corrections-count)
echo "--- --lexicon exports the lexicon as ERE lines"
run_capped 10 bash "$HOOK" --lexicon > "$T/lex.txt" < <(sleep 30)   # an open stdin that never ends: reading it would time out
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
fi # part functional

CHECKS="$(grep -c . "$LEDGER" || true)"
FAILED="$(grep -c . "$FAILS" || true)"
[ "$FAILED" -eq 0 ] || fail=1
echo "intake.test.sh: $CHECKS checks, $FAILED failed"
exit $fail
