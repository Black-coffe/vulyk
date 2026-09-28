#!/usr/bin/env bash
# The anomaly telemetry contract, driven through hand-written fixtures - no model calls, no
# network, nothing sent. Covers scripts/telemetry.sh (`enum`, `agents`, `record`, `bundle`,
# `check`, `consent`, `publish`, `inbox`) and scripts/lib.sh's `is_paperwork_path` entry for the new
# stats file. Schemas: docs/specs/anomaly-telemetry/plan.md ## Contracts.
#
#   Usage: bash tests/telemetry.test.sh            # from the VULYK repo root
#
# Mirrors tests/council.test.sh: a throwaway git repo under mktemp -d, `expect()` on stdout
# substrings, a non-zero exit on the first wrong answer, one summary line at the end.
set -u
SRC="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fail=0
# Verdicts are tallied on disk, not in a variable: `cmd | expect ...` runs expect in a subshell
# (the right-hand side of a pipe), so a `fail=1` set there would be lost and a red assertion
# would still exit 0. Every helper below is safe to call from either side of a pipe.
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

expect_order() { # expect_order <label> <needle>...   (reads the output to judge from stdin)
  local label="$1"; shift
  local out n line prev=0; out="$(cat)"
  for n in "$@"; do
    line="$(printf '%s\n' "$out" | grep -nF -- "$n" | head -1 | cut -d: -f1)"
    if [ -z "$line" ] || [ "$line" -le "$prev" ]; then
      bad "$label - '$n' is missing or out of order in:"
      printf '%s\n' "$out" | sed 's/^/        /'; return
    fi
    prev="$line"
  done
  ok "$label"
}

expect_eq() { # expect_eq <label> <expected> <actual>
  local label="$1" want="$2" got="$3"
  if [ "$want" = "$got" ]; then ok "$label"
  else bad "$label - expected [$want], got [$got]"; fi
}

# --- case 0: syntax ---------------------------------------------------------------------------
# First, always: every case below runs the script, so a syntax error must be named as one.
echo "--- syntax"
for s in scripts/telemetry.sh scripts/lib.sh; do
  if bash -n "$SRC/$s" 2>/dev/null; then ok "bash -n $s"
  else bad "bash -n $s failed"; bash -n "$SRC/$s"; exit 1; fi
done

# --- the fixture hive -------------------------------------------------------------------------
HIVE="$T/hive"
mkdir -p "$HIVE/scripts" "$HIVE/memory/stats" "$HIVE/.claude/agents"
cp "$SRC/scripts/telemetry.sh" "$SRC/scripts/lib.sh" "$HIVE/scripts/"
cp "$SRC"/.claude/agents/*.md "$HIVE/.claude/agents/"
cat > "$HIVE/CLAUDE.md" <<'EOF'
# Fixture hive

## Profile

| Field | Value |
|---|---|
| Stack | shell |
EOF
git -C "$HIVE" init -q -b main . && git -C "$HIVE" config user.email t@t &&
  git -C "$HIVE" config user.name "Test Owner" && git -C "$HIVE" config core.autocrlf false
git -C "$HIVE" add -A && git -C "$HIVE" commit -qm init >/dev/null

LOG="$HIVE/memory/stats/anomalies.jsonl"
WEEK="$(date -u +%G-W%V)"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
tel() { (cd "$HIVE" && VULYK_HIVE="$HIVE" bash scripts/telemetry.sh "$@"); }

set_consent() { # set_consent <cell text>   ('' removes the row)
  grep -v '^| Telemetry |' "$HIVE/CLAUDE.md" > "$HIVE/CLAUDE.md.new"
  mv "$HIVE/CLAUDE.md.new" "$HIVE/CLAUDE.md"
  [ -n "${1:-}" ] && printf '| Telemetry | %s |\n' "$1" >> "$HIVE/CLAUDE.md"
  return 0
}

# --- case 1: enum and the agent token set -----------------------------------------------------
echo "--- enum, agents"
tel enum | expect "enum prints context_high" "context_high"
tel enum | expect "enum prints scope_breach"  "scope_breach"
tel enum | expect "enum prints sessionend_llm (0.19)" "sessionend_llm"
tel enum | expect "enum prints model_below_floor (0.20)" "model_below_floor"
expect_eq "enum is exactly 10 codes" "10" "$(tel enum | grep -c .)"
tel enum | expect_absent "enum prints codes only, no prose" " "
tel agents | expect "agents prints a framework agent" "cycle-clerk"
tel agents | expect "agents prints the catch-all token" "other"
expect_eq "agents = .claude/agents/*.md basenames + council-sonnet (retired, still legal) + other" \
  "$(( $(ls "$HIVE"/.claude/agents/*.md | wc -l) + 2 ))" "$(tel agents | grep -c .)"
tel agents | expect "a retired framework agent stays a legal token" "council-sonnet"
tel agents | expect_absent "agents does not print the .md extension" ".md"

# --- case 2: record ---------------------------------------------------------------------------
echo "--- record"
tel record context_high 150000 140000 --ref session:x
expect_eq "record appends one row" "1" "$(grep -c . "$LOG")"
expect_eq "the local row carries the 12 contract keys, in order" \
  '["v","ts","code","value","threshold","vulyk","tier","model","agent","spec","story","ref"]' \
  "$(jq -c 'keys_unsorted' < "$LOG" | head -1)"
expect_eq "agent is empty when --agent is not given" "" "$(jq -r '.agent' < "$LOG" | head -1 | tr -d '\r')"
tel record context_high 150000 140000 --ref session:x
expect_eq "a second identical (code, ref) appends nothing" "1" "$(grep -c . "$LOG")"

tel record agent_prefix_high 60000 50000 --ref agent:a --agent cycle-clerk
expect_eq "a framework agent token lands as given" "cycle-clerk" \
  "$(grep -F '"ref":"agent:a"' "$LOG" | jq -r '.agent')"
tel record agent_prefix_high 60000 50000 --ref agent:b --agent worker-01-core
expect_eq "a dispatch name outside the set lands as other" "other" \
  "$(grep -F '"ref":"agent:b"' "$LOG" | jq -r '.agent')"

BEFORE="$(grep -c . "$LOG")"
ERR="$(tel record not_a_code 1 0 --ref session:z 2>&1 >/dev/null)"; RC=$?
expect_eq "an unknown code exits 1" "1" "$RC"
printf '%s' "$ERR" | expect "an unknown code names itself on stderr" "not_a_code"
expect_eq "an unknown code is one line on stderr" "1" "$(printf '%s\n' "$ERR" | grep -c .)"
expect_eq "an unknown code writes nothing" "$BEFORE" "$(grep -c . "$LOG")"

# --- case 3: bundle - the anonymization guard -------------------------------------------------
echo "--- bundle"
SPEC="secret-spec-slug"
STORY="secret-spec-slug-07-private"
REF="session:/e/Projects/hive/owner@example.com.jsonl"
: > "$LOG"
printf '{"v":1,"ts":"%s","code":"context_high","value":150000,"threshold":140000,"vulyk":"0.13.3","tier":3,"model":"opus","agent":"","spec":"%s","story":"%s","ref":"%s"}\n' \
  "$NOW" "$SPEC" "$STORY" "$REF" >> "$LOG"
printf '{"v":1,"ts":"%s","code":"agent_prefix_high","value":60000,"threshold":50000,"vulyk":"0.13.3","tier":3,"model":"sonnet","agent":"cycle-clerk","spec":"%s","story":"%s","ref":"agent:x"}\n' \
  "$NOW" "$SPEC" "$STORY" >> "$LOG"
# A row from a different week must stay behind; a row with an unknown code must not travel.
printf '{"v":1,"ts":"1999-01-04T00:00:00Z","code":"stage_long","value":40,"threshold":24,"vulyk":"0.13.3","tier":3,"model":"","agent":"","spec":"%s","story":"","ref":"stage:1"}\n' "$SPEC" >> "$LOG"

BUNDLE="$T/bundle.jsonl"
tel bundle > "$BUNDLE"
expect_eq "bundle emits this week's rows only" "2" "$(grep -c . "$BUNDLE")"
expect_eq "the bundle row carries the 10 contract keys, in order" \
  '["v","code","value","threshold","vulyk","tier","model","agent","week","hive"]' \
  "$(jq -c 'keys_unsorted' < "$BUNDLE" | head -1)"
cat "$BUNDLE" | expect_absent "the spec slug does not travel"  "$SPEC"
cat "$BUNDLE" | expect_absent "the story id does not travel"   "$STORY"
cat "$BUNDLE" | expect_absent "the ref does not travel"        "session:"
cat "$BUNDLE" | expect_absent "no path separator travels"      "/"
cat "$BUNDLE" | expect_absent "no backslash travels"           "\\"
cat "$BUNDLE" | expect_absent "no address travels"             "@"
cat "$BUNDLE" | expect_absent "no timestamp travels"           "$NOW"
cat "$BUNDLE" | expect "the agent token does travel"           '"agent":"cycle-clerk"'
cat "$BUNDLE" | expect "the ISO week travels"                  "\"week\":\"$WEEK\""
expect_eq "hive is 12 hex" "1" "$(jq -r '.hive' < "$BUNDLE" | head -1 | grep -c '^[0-9a-f]\{12\}$')"

# --- case 4: check ----------------------------------------------------------------------------
echo "--- check"
if tel check "$BUNDLE" >/dev/null 2>&1; then ok "check accepts bundle's own output"
else bad "check rejected bundle's own output:"; tel check "$BUNDLE" 2>&1 | sed 's/^/        /'; fi

reject() { # reject <label> <jq mutation of a valid bundle row> <reason substring>
  local label="$1" mutation="$2" needle="$3" f="$T/bad.jsonl" err rc
  head -1 "$BUNDLE" | jq -c "$mutation" > "$f"
  err="$(tel check "$f" 2>&1 >/dev/null)"; rc=$?
  if [ "$rc" -ne 1 ]; then bad "$label - expected exit 1, got $rc"; return; fi
  if printf '%s' "$err" | grep -qF -- "$f:1: " && printf '%s' "$err" | grep -qF -- "$needle"; then
    ok "check rejects $label"
  else bad "check rejects $label - expected '<file>:1: ...$needle' in:"
    printf '%s\n' "$err" | sed 's/^/        /'; fi
}
reject "an extra key"                '. + {"note":"x"}'      "key set"
reject "an unknown code"             '.code = "not_a_code"'  "code is not in the enum"
reject "an agent outside the set"    '.agent = "mystery"'    "agent token set"
reject "a string carrying a path"    '.vulyk = "1.2.3/home"' "path, an address or whitespace"
reject "a hive that is not 12 hex"   '.hive = "nothex"'      "hive is not 12 hex"
reject "a semver with a suffix"      '.vulyk = "1.2.3-x"'    "vulyk is not a semver"

# --- case 5: consent --------------------------------------------------------------------------
echo "--- consent"
set_consent ""
expect_eq "no Telemetry row = off"            "off" "$(tel consent)"
set_consent "on - anonymized weekly bundle"
expect_eq "the row's first token wins (on)"   "on"  "$(tel consent)"
set_consent "off - the default"
expect_eq "the row's first token wins (off)"  "off" "$(tel consent)"
set_consent '`on` - backticked'
expect_eq "backticks are tolerated"           "on"  "$(tel consent)"

# --- case 6: publish - prints, never sends ----------------------------------------------------
echo "--- publish"
# A PATH shim in front of git and gh: every invocation is recorded, git still works (telemetry.sh
# needs rev-parse), gh is a no-op. The assertion below is the whole point of the case.
SHIM="$T/shim"; CALLS="$T/calls.txt"; : > "$CALLS"
REALGIT="$(command -v git)"
mkdir -p "$SHIM"
cat > "$SHIM/git" <<EOF
#!/usr/bin/env bash
printf 'git %s\n' "\$*" >> "$CALLS"
exec "$REALGIT" "\$@"
EOF
cat > "$SHIM/gh" <<EOF
#!/usr/bin/env bash
printf 'gh %s\n' "\$*" >> "$CALLS"
exit 0
EOF
chmod +x "$SHIM/git" "$SHIM/gh"
shimmed() { (cd "$HIVE" && PATH="$SHIM:$PATH" VULYK_HIVE="$HIVE" bash scripts/telemetry.sh "$@"); }

set_consent "off - the default"
shimmed publish | expect "consent off prints one 'nothing to send' line" "nothing to send"
expect_eq "consent off creates no bundle file" "0" \
  "$(ls "$HIVE/.vulyk/telemetry" 2>/dev/null | grep -c . || true)"

LOCAL="$T/vulyk-local"
mkdir -p "$LOCAL/telemetry/inbox"
git -C "$LOCAL" init -q -b main . && git -C "$LOCAL" config user.email t@t &&
  git -C "$LOCAL" config user.name "Test Owner"
git -C "$LOCAL" add -A 2>/dev/null; git -C "$LOCAL" commit -qm init --allow-empty >/dev/null

set_consent "on - anonymized weekly bundle"
OUT="$( (cd "$HIVE" && PATH="$SHIM:$PATH" VULYK_HIVE="$HIVE" VULYK_LOCAL="$LOCAL" \
        bash scripts/telemetry.sh publish) 2>&1 )"
HIVEID="$(jq -r '.hive' < "$BUNDLE" | head -1)"
printf '%s' "$OUT" | expect "a local checkout gets a printed commit command" "git add 'telemetry/inbox/$WEEK/$HIVEID.jsonl'"
expect_eq "the bundle is copied into telemetry/inbox/<week>/<hive>.jsonl" "yes" \
  "$([ -s "$LOCAL/telemetry/inbox/$WEEK/$HIVEID.jsonl" ] && echo yes || echo no)"
if tel check "$LOCAL/telemetry/inbox/$WEEK/$HIVEID.jsonl" >/dev/null 2>&1
then ok "the copied bundle passes check"; else bad "the copied bundle fails check"; fi

rm -rf "$LOCAL/telemetry/inbox/$WEEK"
OUT="$( (cd "$HIVE" && PATH="$SHIM:$PATH" VULYK_HIVE="$HIVE" VULYK_LOCAL="$LOCAL" \
        bash scripts/telemetry.sh publish --dry-run) 2>&1 )"
printf '%s' "$OUT" | expect "--dry-run still prints the commit command" "git add 'telemetry/inbox/$WEEK/$HIVEID.jsonl'"
expect_eq "--dry-run copies nothing" "no" \
  "$([ -e "$LOCAL/telemetry/inbox/$WEEK/$HIVEID.jsonl" ] && echo yes || echo no)"

rm -rf "$LOCAL/telemetry"   # no inbox -> no local checkout -> the PR recipe
OUT="$( (cd "$HIVE" && PATH="$SHIM:$PATH" VULYK_HIVE="$HIVE" VULYK_LOCAL="$LOCAL" \
        bash scripts/telemetry.sh publish) 2>&1 )"
printf '%s' "$OUT" | expect "no local checkout gets the PR recipe" "gh pr create"
printf '%s' "$OUT" | expect_absent "the PR recipe does not claim anything was sent" "telemetry: wrote"

# (a) The cross-machine recipe is the whole fork -> PR sequence, in order: pasted as-is it
# ends in an open pull request (council round 1, ask 2). The ordered-needle assertion
# itself lives in (d) below, where a hive with rows in two weeks exercises both blocks.
printf '%s' "$OUT" | expect "the PR is opened against the configured origin slug" \
  "gh pr create --repo 'Black-coffe/vulyk' --head 'telemetry/$WEEK-$HIVEID'"
printf '%s' "$OUT" | expect "the PR body is one sentence with no path" \
  "--body 'An anonymized weekly anomaly bundle - codes and numbers only.'"

# (b) A hive (and a checkout) whose path holds a space and a `#`: every printed path is
# single-quoted, and check's own <file>:<line>: prefix survives the `#` (review finding 14).
HIVE2="$T/sp ace#hive"
LOCAL2="$T/vu lyk#local"
mkdir -p "$HIVE2/scripts" "$HIVE2/memory/stats" "$HIVE2/.claude/agents"
cp "$SRC/scripts/telemetry.sh" "$SRC/scripts/lib.sh" "$HIVE2/scripts/"
cp "$SRC"/.claude/agents/*.md "$HIVE2/.claude/agents/"
printf '| Telemetry | on - anonymized weekly bundle |\n' > "$HIVE2/CLAUDE.md"
git -C "$HIVE2" init -q -b main . && git -C "$HIVE2" config user.email t@t &&
  git -C "$HIVE2" config user.name "Test Owner" && git -C "$HIVE2" config core.autocrlf false
git -C "$HIVE2" add -A >/dev/null 2>&1; git -C "$HIVE2" commit -qm init >/dev/null
mkdir -p "$LOCAL2/telemetry/inbox"
git -C "$LOCAL2" init -q -b main . && git -C "$LOCAL2" config user.email t@t &&
  git -C "$LOCAL2" config user.name "Test Owner"
git -C "$LOCAL2" commit -qm init --allow-empty >/dev/null

LOG2="$HIVE2/memory/stats/anomalies.jsonl"
PREVWEEK="$(date -u -d '7 days ago' +%G-W%V 2>/dev/null || date -u -v-7d +%G-W%V)"
PREVTS="$(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-7d +%Y-%m-%dT%H:%M:%SZ)"
printf '{"v":1,"ts":"%s","code":"context_high","value":150000,"threshold":140000,"vulyk":"0.13.3","tier":3,"model":"opus","agent":"","spec":"s","story":"t","ref":"session:a"}\n' \
  "$NOW" >> "$LOG2"
printf '{"v":1,"ts":"%s","code":"stage_long","value":40,"threshold":24,"vulyk":"0.13.3","tier":2,"model":"","agent":"","spec":"s","story":"t","ref":"stage:b"}\n' \
  "$PREVTS" >> "$LOG2"
tel2()      { (cd "$HIVE2" && PATH="$SHIM:$PATH" VULYK_HIVE="$HIVE2" bash scripts/telemetry.sh "$@"); }
tel2local() { (cd "$HIVE2" && PATH="$SHIM:$PATH" VULYK_HIVE="$HIVE2" VULYK_LOCAL="$LOCAL2" \
               bash scripts/telemetry.sh "$@"); }
HIVEID2="$(tel2 bundle --week "$WEEK" | jq -r '.hive' | head -1 | tr -d '\r')"

OUT="$(tel2local publish --week "$WEEK" 2>&1)"
# git prints the checkout's own toplevel form (on Windows a C:/... path), which is what the
# recipe quotes - the space and the `#` are in it either way.
LOCAL2TOP="$(git -C "$LOCAL2" rev-parse --show-toplevel)"
printf '%s' "$OUT" | expect "a checkout path with a space and a # is single-quoted" "cd '$LOCAL2TOP'"
printf '%s' "$OUT" | expect "the local git add line is quoted" \
  "git add 'telemetry/inbox/$WEEK/$HIVEID2.jsonl'"
OUT="$(tel2 publish --week "$WEEK" 2>&1)"
printf '%s' "$OUT" | expect "the cp line quotes a bundle path with a space and a #" \
  "cp '$HIVE2/.vulyk/telemetry/$WEEK-$HIVEID2.jsonl'"

BADF="$T/ba d#bundle.jsonl"
tel2 bundle --week "$WEEK" | head -1 | jq -c '.code = "not_a_code"' > "$BADF"
ERR="$(tel2 check "$BADF" 2>&1 >/dev/null)"
printf '%s' "$ERR" | expect "check's <file>:<line>: prefix survives a # in the path" "$BADF:1: "

# (c) A15: with no --week, publish covers the previous ISO week and the current one.
OUT="$(tel2local publish --dry-run 2>&1)"
printf '%s' "$OUT" | expect "a bare publish names the current week"  "telemetry/inbox/$WEEK/$HIVEID2.jsonl"
printf '%s' "$OUT" | expect "a bare publish names the previous week" "telemetry/inbox/$PREVWEEK/$HIVEID2.jsonl"
expect_eq "each week gets its own bundle file" "yes" \
  "$([ -s "$HIVE2/.vulyk/telemetry/$PREVWEEK-$HIVEID2.jsonl" ] && echo yes || echo no)"
OUT="$(tel2local publish --week "$WEEK" --dry-run 2>&1)"
printf '%s' "$OUT" | expect_absent "--week selects exactly one week" "$PREVWEEK"
tel2 publish --week 1999-W01 2>&1 | expect "a week with no rows is skipped" "nothing to send"

# (d) Two weeks, no local checkout (review finding 8): ONE fork and ONE cd, and every week's
# block starts back at the clone's default branch, so each PR carries exactly one week.
OUT="$(tel2 publish 2>&1)"
printf '%s' "$OUT" | expect_order "the PR recipe runs fork, branch, copy, add, commit, push, PR - twice, in order" \
  "gh repo fork" "cd 'vulyk-telemetry'" 'base="$(git rev-parse --abbrev-ref HEAD)"' \
  "git switch -c 'telemetry/$PREVWEEK-$HIVEID2'" "mkdir -p 'telemetry/inbox/$PREVWEEK'" \
  "git add 'telemetry/inbox/$PREVWEEK/$HIVEID2.jsonl'" \
  "git commit -m 'telemetry($PREVWEEK): $HIVEID2'" \
  "git push -u origin 'telemetry/$PREVWEEK-$HIVEID2'" "gh pr create --repo" \
  "git switch -c 'telemetry/$WEEK-$HIVEID2'" "mkdir -p 'telemetry/inbox/$WEEK'" \
  "git add 'telemetry/inbox/$WEEK/$HIVEID2.jsonl'" \
  "git commit -m 'telemetry($WEEK): $HIVEID2'" \
  "git push -u origin 'telemetry/$WEEK-$HIVEID2'"
expect_eq "the fork and clone step is printed once for both weeks" "1" \
  "$(printf '%s\n' "$OUT" | grep -c 'gh repo fork')"
expect_eq "each week's block starts from the clone's default branch" "2" \
  "$(printf '%s\n' "$OUT" | grep -B1 "git switch -c 'telemetry/" | grep -cF 'git switch "$base"')"
expect_eq "each week gets its own PR" "2" \
  "$(printf '%s\n' "$OUT" | grep -c 'gh pr create --repo')"

# The rule the whole spec rests on (.claude/commands/vulyk-ship.md:11): nothing is sent.
cat "$CALLS" | expect_absent "publish never invokes git push"   " push"
cat "$CALLS" | expect_absent "publish never invokes git commit" " commit"
cat "$CALLS" | expect_absent "publish never invokes gh"         "gh "
cat "$CALLS" | expect_absent "publish never invokes a pr"       "pr create"
cat "$CALLS" | expect_absent "publish never invokes git clone"  " clone"
cat "$CALLS" | expect_absent "publish never invokes a fork"     "fork"

# --- case 7: the log is paperwork -------------------------------------------------------------
echo "--- is_paperwork_path"
paper() { ( . "$SRC/scripts/lib.sh"; is_paperwork_path "$1" && echo true || echo false ); }
expect_eq "memory/stats/anomalies.jsonl is paperwork"  "true"  "$(paper memory/stats/anomalies.jsonl)"
expect_eq "memory/stats/other.jsonl is not"            "false" "$(paper memory/stats/other.jsonl)"
expect_eq "the entry stays anchored (no bare basename)" "false" "$(paper anomalies.jsonl)"

# --- case 8: the paperwork the contract names -------------------------------------------------
echo "--- paperwork"
cat "$SRC/CLAUDE.md" | expect "CLAUDE.md ## Commands names this suite" \
  '| Anomaly telemetry contract tests | `bash tests/telemetry.test.sh` |'

# --- detectors (anomaly-telemetry-02) ---------------------------------------------------------
# Story 02 adds the `scan` verb's five detectors, .claude/hooks/anomaly-scan.sh and
# `handoff.py measure`. Its cases belong here, below this marker.
PY="$(command -v python3 || command -v python || true)"
mkdir -p "$HIVE/.claude/hooks"
cp "$SRC/.claude/hooks/handoff.py" "$SRC/.claude/hooks/handoff.sh" "$SRC/.claude/hooks/anomaly-scan.sh" \
  "$HIVE/.claude/hooks/"

# --- case 9: handoff.py measure ----------------------------------------------------------------
echo "--- handoff.py measure"
MEASURE="$T/measure"
mkdir -p "$MEASURE/subagents"

cat > "$MEASURE/main.jsonl" <<'EOF'
{"type":"assistant","isSidechain":false,"message":{"model":"claude-fable-5-1","usage":{"input_tokens":1000,"cache_read_input_tokens":500,"cache_creation_input_tokens":2000,"output_tokens":300}}}
EOF
MAIN_OUT="$("$PY" "$SRC/.claude/hooks/handoff.py" measure "$MEASURE/main.jsonl" < /dev/null)"
expect_eq "measure tokens equals context_tokens()'s answer" "3800" \
  "$(printf '%s' "$MAIN_OUT" | jq -r '.tokens')"

cat > "$MEASURE/subagents/agent-a1.jsonl" <<'EOF'
{"type":"assistant","isSidechain":true,"message":{"model":"claude-sonnet-4-5","usage":{"input_tokens":40000,"cache_creation_input_tokens":15000,"cache_read_input_tokens":0,"output_tokens":50},"content":[{"type":"tool_use","name":"Bash"}]}}
{"type":"assistant","isSidechain":true,"message":{"model":"claude-sonnet-4-5","usage":{"input_tokens":100,"cache_creation_input_tokens":0,"cache_read_input_tokens":2000,"output_tokens":40},"content":[{"type":"text","text":"done"}]}}
EOF
printf '{"agentType":"cycle-clerk"}\n' > "$MEASURE/subagents/agent-a1.meta.json"
SIDE_OUT="$("$PY" "$SRC/.claude/hooks/handoff.py" measure "$MEASURE/subagents/agent-a1.jsonl" --sidechain < /dev/null)"
expect_eq "measure --sidechain first_prefix is the first turn's input+cache_creation" "55000" \
  "$(printf '%s' "$SIDE_OUT" | jq -r '.first_prefix')"
expect_eq "measure --sidechain assistant_turns counts sidechain entries" "2" \
  "$(printf '%s' "$SIDE_OUT" | jq -r '.assistant_turns')"
expect_eq "measure --sidechain last_has_text reads the last entry's content" "true" \
  "$(printf '%s' "$SIDE_OUT" | jq -r '.last_has_text')"
expect_eq "measure --sidechain agent_type reads the sibling .meta.json" "cycle-clerk" \
  "$(printf '%s' "$SIDE_OUT" | jq -r '.agent_type')"
expect_eq "measure --sidechain model is the subagent's own (0.20: the floor check reads it)" "claude-sonnet-4-5" \
  "$(printf '%s' "$SIDE_OUT" | jq -r '.model')"

MISSING_OUT="$("$PY" "$SRC/.claude/hooks/handoff.py" measure "$MEASURE/does-not-exist.jsonl" < /dev/null)"; MISSING_RC=$?
expect_eq "measure on a missing file prints {}" "{}" "$MISSING_OUT"
expect_eq "measure on a missing file exits 0" "0" "$MISSING_RC"

# Review finding 16: `measure` is a direct call, so it must return with a terminal (or any
# never-written pipe) on stdin - the hook-payload read used to block it forever.
TTY_RC=0; TTY_OUT=""
if { : < /dev/tty; } 2>/dev/null; then
  TTY_OUT="$(timeout 5 "$PY" "$SRC/.claude/hooks/handoff.py" measure "$MEASURE/main.jsonl" < /dev/tty 2>/dev/null)" || TTY_RC=$?
else
  FIFO="$T/measure.fifo"; rm -f "$FIFO"; mkfifo "$FIFO"
  sleep 10 > "$FIFO" &            # a writer that never writes: a blind read would never return
  FIFO_PID=$!
  TTY_OUT="$(timeout 5 "$PY" "$SRC/.claude/hooks/handoff.py" measure "$MEASURE/main.jsonl" < "$FIFO" 2>/dev/null)" || TTY_RC=$?
  kill "$FIFO_PID" 2>/dev/null; wait "$FIFO_PID" 2>/dev/null || true
fi
expect_eq "measure with a terminal on stdin returns instead of blocking" "0" "$TTY_RC"
expect_eq "measure with a terminal on stdin still prints its measurement" "3800" \
  "$(printf '%s' "$TTY_OUT" | jq -r '.tokens')"

STATUS_RC=0
bash "$SRC/.claude/hooks/handoff.sh" status < /dev/null >/dev/null 2>&1 || STATUS_RC=$?
expect_eq "handoff.sh status still exits 0 with measure added" "0" "$STATUS_RC"

# --- case 9b: handoff.py sessionstart - which sessions get the handoff (ADR-013 D7) ------------
# Only a session that continues earlier work - /clear or compaction - is handed the last
# handoff, and never more than 4 000 characters of it. A resumed session still carries its own
# context, so it gets nothing, like startup and fork.
echo "--- handoff.py sessionstart"
RS="$T/restore"; mkdir -p "$RS/.claude/handoff"
RSW="$(cd "$RS" && { pwd -W 2>/dev/null || pwd; })"   # native python on Windows needs C:/...
head -c 9000 /dev/zero | tr '\0' 'x' > "$RS/.claude/handoff/h.md"
restore_index() {
  printf '{"path":"%s/.claude/handoff/h.md","ts":%s,"reason":"exit"}\n' "$RSW" "$(date +%s)" \
    > "$RS/.claude/handoff/index.json"
}
restored() { # restored <source> - the length of the handoff body injected, 0 when none
  printf '{"source":"%s","cwd":"%s"}' "$1" "$RSW" \
    | CLAUDE_PROJECT_DIR="$RSW" "$PY" "$SRC/.claude/hooks/handoff.py" sessionstart 2>/dev/null \
    | { jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null || true; } \
    | grep -o 'xxxxxxxxxx*' | awk '{ if (length > m) m = length } END { print m + 0 }'
}
restore_index
expect_eq "startup gets no handoff"             "0"    "$(restored startup)"
expect_eq "fork gets no handoff"                "0"    "$(restored fork)"
expect_eq "a payload with no source gets none"  "0"    "$(restored '')"
expect_eq "clear gets it, cut to 4000 chars"    "4000" "$(restored clear)"
expect_eq "compact gets it again (deliberate)"  "4000" "$(restored compact)"
restore_index
expect_eq "resume gets no handoff"              "0"    "$(restored resume)"

# --- case 10: scan - agent_prefix_high / agent_empty --------------------------------------------
echo "--- scan: agent_prefix_high, agent_empty"
# The layout Claude Code actually writes (recon/hooks-and-stats.md §6, review Critical 1):
# `<dir>/<session-id>.jsonl` beside `<dir>/<session-id>/subagents/`, plain dispatches directly
# there and workflow ones under `workflows/<wf>/`. `<dir>/subagents/` - where the detector used
# to look - is the control: a file there is above threshold and must yield no row at all.
PROJ="$T/proj"
SESSION="$PROJ/sid1"
mkdir -p "$SESSION/subagents/workflows/wf1" "$PROJ/subagents"
agent_file() { # agent_file <path> <prefix tokens> <text|tool_use> <agentType>
  local block
  if [ "$3" = "text" ]; then block='{"type":"text","text":"done"}'; else block='{"type":"tool_use","name":"Bash"}'; fi
  printf '{"type":"assistant","isSidechain":true,"message":{"model":"claude-sonnet-5-5","usage":{"input_tokens":%s,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":10},"content":[%s]}}\n' \
    "$2" "$block" > "$1"
  printf '{"agentType":"%s"}\n' "$4" > "${1%.jsonl}.meta.json"
}
agent_file "$SESSION/subagents/agent-a1.jsonl"              60000 text     cycle-clerk
agent_file "$SESSION/subagents/workflows/wf1/agent-a2.jsonl" 70000 tool_use my-custom-agent
agent_file "$PROJ/subagents/agent-a3.jsonl"                  80000 text     cycle-clerk
cat > "$PROJ/sid1.jsonl" <<'EOF'
{"type":"assistant","isSidechain":false,"message":{"model":"claude-sonnet-5-5","usage":{"input_tokens":100,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":50}}}
EOF

# Every python start is counted: the bound of a Stop-hook scan is "no python for a file whose
# ref is already in the log" (plan A17, review Major 5), which is only visible from outside as
# a process that is never spawned.
PYSHIM="$T/pyshim"; PYCALLS="$T/pycalls.txt"; mkdir -p "$PYSHIM"; : > "$PYCALLS"
cat > "$PYSHIM/python3" <<EOF
#!/usr/bin/env bash
printf 'py\n' >> "$PYCALLS"
exec "$PY" "\$@"
EOF
chmod +x "$PYSHIM/python3"
telpy() { (cd "$HIVE" && PATH="$PYSHIM:$PATH" VULYK_HIVE="$HIVE" bash scripts/telemetry.sh "$@"); }
pycount() { grep -c . "$PYCALLS" 2>/dev/null | head -1; }

: > "$LOG"; : > "$PYCALLS"
telpy scan --transcript "$PROJ/sid1.jsonl" >/dev/null 2>&1
expect_eq "scan finds the subagent beside the session dir, not beside the transcript" "1" \
  "$(grep -c '"ref":"agent:agent-a1.jsonl"' "$LOG")"
expect_eq "scan finds the workflow subagent one directory deeper" "1" \
  "$(grep -c '"ref":"agent:agent-a2.jsonl"' "$LOG")"
expect_eq "nothing is read from <dirname>/subagents/ beside the transcript" "0" \
  "$(grep -c '"ref":"agent:agent-a3.jsonl"' "$LOG")"
expect_eq "scan records exactly two agent_prefix_high rows" "2" \
  "$(grep -c '"code":"agent_prefix_high"' "$LOG")"
expect_eq "agent_prefix_high carries the cycle-clerk agent token" "cycle-clerk" \
  "$(grep -F '"ref":"agent:agent-a1.jsonl"' "$LOG" | jq -r '.agent')"
expect_eq "agent_prefix_high maps a non-framework agentType to other" "other" \
  "$(grep -F '"ref":"agent:agent-a2.jsonl"' "$LOG" | jq -r '.agent')"
# Major 6: at Stop time a subagent whose last entry is a tool_use is mid-turn, not empty.
expect_eq "a plain scan records no agent_empty row" "0" \
  "$(grep -c '"code":"agent_empty"' "$LOG")"
expect_eq "the first scan starts python for the transcript and both subagents" "3" "$(pycount)"

AGENT_ROWS="$(grep -c . "$LOG")"
: > "$PYCALLS"
telpy scan --transcript "$PROJ/sid1.jsonl" >/dev/null 2>&1
expect_eq "a second scan over the same session appends nothing" "$AGENT_ROWS" "$(grep -c . "$LOG")"
expect_eq "a second scan starts no python for an already-recorded subagent" "1" "$(pycount)"

# --final (SessionEnd) is where agent_empty is judged, once.
telpy scan --transcript "$PROJ/sid1.jsonl" --final >/dev/null 2>&1
expect_eq "scan --final records exactly one agent_empty row" "1" \
  "$(grep -c '"code":"agent_empty"' "$LOG")"
expect_eq "agent_empty ref is agent:<basename>" "agent:agent-a2.jsonl" \
  "$(grep '"code":"agent_empty"' "$LOG" | jq -r '.ref')"
expect_eq "agent_empty maps a non-framework agentType to other" "other" \
  "$(grep '"code":"agent_empty"' "$LOG" | jq -r '.agent')"
FINAL_ROWS="$(grep -c . "$LOG")"
telpy scan --transcript "$PROJ/sid1.jsonl" --final >/dev/null 2>&1
expect_eq "a second --final scan appends nothing" "$FINAL_ROWS" "$(grep -c . "$LOG")"

# Major 5, the other half of the bound: with no --transcript there is no session to scope to,
# so no subagent file is read even though one is above threshold.
: > "$LOG"; : > "$PYCALLS"
telpy scan >/dev/null 2>&1
expect_eq "a scan with no --transcript records no agent row" "0" \
  "$(grep -c '"code":"agent_' "$LOG" || true)"
expect_eq "a scan with no --transcript starts no python at all" "0" "$(pycount)"

# --- case 10b: scan - the per-session seen-list (plan A18, round-3 review Critical 1) -----------
echo "--- scan: seen-list bounds the Stop-hook scan"
# The case story 08 could not have passed: 40 subagents UNDER the threshold, so none of them
# ever produces a log row and the log-ref bound never fires. Without the seen-list every Stop
# scan re-measures all forty (the reviewer measured 74 python starts / ~26 s on a real session).
SEENPROJ="$T/seenproj"
SEENSESSION="$SEENPROJ/sid2"
mkdir -p "$SEENSESSION/subagents"
N_SUB=40
i=1
while [ "$i" -le "$N_SUB" ]; do
  agent_file "$SEENSESSION/subagents/agent-s$i.jsonl" 100 text cycle-clerk
  i=$(( i + 1 ))
done
# One subagent that IS an anomaly, and whose last entry is a tool_use: it proves the cached JSON
# drives the detectors, not just the skip - `agent_empty` at SessionEnd must come out of the
# cache with no python started for the file.
agent_file "$SEENSESSION/subagents/agent-big.jsonl" 60000 tool_use cycle-clerk
cat > "$SEENPROJ/sid2.jsonl" <<'EOF'
{"type":"assistant","isSidechain":false,"message":{"model":"claude-sonnet-5-5","usage":{"input_tokens":100,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":50}}}
EOF

# A shim that logs its argv, not just a tick: "no python for this subagent" is only provable
# from outside as a file name that never reaches an interpreter.
ARGSHIM="$T/argshim"; PYARGS="$T/pyargs.txt"; mkdir -p "$ARGSHIM"; : > "$PYARGS"
cat > "$ARGSHIM/python3" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$PYARGS"
exec "$PY" "\$@"
EOF
chmod +x "$ARGSHIM/python3"
telargs() { (cd "$HIVE" && PATH="$ARGSHIM:$PATH" VULYK_HIVE="$HIVE" bash scripts/telemetry.sh "$@"); }
argcount() { grep -c . "$PYARGS" 2>/dev/null | head -1; }
SEEN_FILE="$HIVE/.vulyk/telemetry/seen/sid2"

: > "$LOG"; : > "$PYARGS"; rm -rf "$HIVE/.vulyk"
telargs scan --transcript "$SEENPROJ/sid2.jsonl" >/dev/null 2>&1
expect_eq "the first scan measures every subagent plus the main transcript" "$(( N_SUB + 2 ))" \
  "$(argcount)"
expect_eq "only the over-threshold subagent records a row" "1" \
  "$(grep -c '"code":"agent_prefix_high"' "$LOG" || true)"
expect_eq "a plain scan records no agent_empty row" "0" \
  "$(grep -c '"code":"agent_empty"' "$LOG" || true)"
expect_eq "the seen-list holds one line per subagent" "$(( N_SUB + 1 ))" "$(grep -c . "$SEEN_FILE")"
expect_eq "a seen-list line is <basename><TAB><bytes><TAB><measure json>" \
  "agent-s1.jsonl $(wc -c < "$SEENSESSION/subagents/agent-s1.jsonl" | tr -d ' ') {" \
  "$(grep '^agent-s1\.jsonl' "$SEEN_FILE" | awk -F'\t' '{print $1, $2, substr($3,1,1)}')"

: > "$PYARGS"
telargs scan --transcript "$SEENPROJ/sid2.jsonl" >/dev/null 2>&1
expect_eq "the second scan starts python at most once (the main transcript's own measure)" "1" \
  "$(argcount)"
expect_eq "no subagent file reaches an interpreter on the second scan" "0" \
  "$(grep -c 'agent-s' "$PYARGS" || true)"
expect_eq "the second scan still holds one line per subagent" "$(( N_SUB + 1 ))" \
  "$(grep -c . "$SEEN_FILE")"

# SessionEnd: agent_empty is judged off the cached JSON of a file nothing has touched since.
: > "$PYARGS"
telargs scan --transcript "$SEENPROJ/sid2.jsonl" --final >/dev/null 2>&1
expect_eq "a --final scan over seen subagents starts python at most once" "1" "$(argcount)"
expect_eq "no subagent file reaches an interpreter on the --final scan" "0" \
  "$(grep -c 'agent-' "$PYARGS" || true)"
expect_eq "agent_empty is recorded from the cached measurement" "1" \
  "$(grep -c '"code":"agent_empty"' "$LOG")"
expect_eq "the cached agent_empty row carries the cached agentType" "cycle-clerk" \
  "$(grep '"code":"agent_empty"' "$LOG" | jq -r '.agent')"

# A subagent that grew is measured again - and only it: the key is the byte size, not an age.
printf '{"type":"assistant","isSidechain":true,"message":{"model":"claude-sonnet-5-5","usage":{"input_tokens":100,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":10},"content":[{"type":"text","text":"more"}]}}\n' \
  >> "$SEENSESSION/subagents/agent-s7.jsonl"
GREW_BYTES="$(wc -c < "$SEENSESSION/subagents/agent-s7.jsonl" | tr -d ' ')"
: > "$PYARGS"
telargs scan --transcript "$SEENPROJ/sid2.jsonl" >/dev/null 2>&1
expect_eq "the grown subagent is measured again" "1" "$(grep -c 'agent-s7\.jsonl' "$PYARGS")"
expect_eq "and it is the only subagent measured" "2" "$(argcount)"
expect_eq "its seen-list line is rewritten with the new byte size" "$GREW_BYTES" \
  "$(grep '^agent-s7\.jsonl' "$SEEN_FILE" | awk -F'\t' '{print $2}')"
expect_eq "the seen-list still holds one line per subagent" "$(( N_SUB + 1 ))" \
  "$(grep -c . "$SEEN_FILE")"

# A scan with no --transcript has no session, so it has no seen-list either.
rm -rf "$HIVE/.vulyk"
telargs scan >/dev/null 2>&1
expect_eq "a scan with no --transcript writes no seen-list" "0" \
  "$([ -d "$HIVE/.vulyk" ] && echo 1 || echo 0)"

# --- case 11: scan - context_high ----------------------------------------------------------------
echo "--- scan: context_high"
: > "$LOG"
CTX="$T/ctx-main.jsonl"
cat > "$CTX" <<'EOF'
{"type":"assistant","isSidechain":false,"message":{"model":"claude-fable-5-1","usage":{"input_tokens":100000,"cache_read_input_tokens":40000,"cache_creation_input_tokens":10000,"output_tokens":5000}}}
EOF
tel scan --transcript "$CTX" >/dev/null 2>&1
expect_eq "scan records one context_high row above the absolute threshold" "1" \
  "$(grep -c '"code":"context_high"' "$LOG")"
expect_eq "context_high maps claude-fable-5-1 to fable" "fable" \
  "$(grep '"code":"context_high"' "$LOG" | jq -r '.model')"
expect_eq "context_high carries an empty agent" "" \
  "$(grep '"code":"context_high"' "$LOG" | jq -r '.agent')"

# --- case 11b: the model floor (0.20.0, ADR-015) ---------------------------------------------------
echo "--- model floor: lib.sh, top-model.sh --floor, scan"
floorof() { (. "$SRC/scripts/lib.sh"; model_below_floor "$1") 2>/dev/null || echo ok; }
expect_eq "claude-sonnet-5 is below the sonnet floor"          "sonnet 5.0 5.5" "$(floorof claude-sonnet-5)"
expect_eq "claude-opus-5 is below the opus floor"              "opus 5.0 5.5"   "$(floorof claude-opus-5)"
expect_eq "a dated Haiku 4.5 ID is below the haiku floor"      "haiku 4.5 5.5"  "$(floorof claude-haiku-4-5-20251001)"
expect_eq "a family-last legacy ID is read too"                "sonnet 3.5 5.5" "$(floorof claude-3-5-sonnet-20241022)"
expect_eq "a provider-prefixed ID is read too"                 "opus 4.6 5.5"   "$(floorof anthropic.claude-opus-4-6)"
expect_eq "claude-sonnet-5-5 sits on the floor"                "ok" "$(floorof claude-sonnet-5-5)"
expect_eq "a newer generation is above the floor"              "ok" "$(floorof claude-opus-6)"
expect_eq "an alias is never below: only a resolved ID is"     "ok" "$(floorof sonnet)"
expect_eq "VULYK_MODEL_FLOOR lowers the floor for a hive"      "ok" \
  "$(VULYK_MODEL_FLOOR='sonnet 4.5; opus 4.6' floorof claude-sonnet-4-5)"
expect_eq "a partial override keeps the other families' floors" "opus 4.1 5.5" \
  "$(VULYK_MODEL_FLOOR='sonnet 4.5' floorof claude-opus-4-1)"
expect_eq "the alias of an unreleased floor is below it"       "haiku alias 5.5" "$(floorof haiku)"
expect_eq "the override can mark haiku released"               "ok" "$(VULYK_MODEL_FLOOR='haiku 4.5' floorof haiku)"

FLOORHIVE="$T/floorhive"; mkdir -p "$FLOORHIVE/scripts" "$FLOORHIVE/.claude/agents" "$FLOORHIVE/home/.claude" "$FLOORHIVE/templates"
cp "$SRC/scripts/top-model.sh" "$SRC/scripts/lib.sh" "$FLOORHIVE/scripts/"
cp "$SRC"/.claude/agents/*.md "$FLOORHIVE/.claude/agents/"
cp "$SRC/templates/story.md" "$FLOORHIVE/templates/"
floorcheck() { # floorcheck [VAR=value]... - top-model.sh --floor in a hive with a clean env and an empty home
  (cd "$FLOORHIVE" && env -u ANTHROPIC_MODEL -u ANTHROPIC_DEFAULT_FABLE_MODEL -u ANTHROPIC_DEFAULT_OPUS_MODEL \
    -u ANTHROPIC_DEFAULT_SONNET_MODEL -u ANTHROPIC_DEFAULT_HAIKU_MODEL -u CLAUDE_CODE_SUBAGENT_MODEL \
    -u ANTHROPIC_SMALL_FAST_MODEL -u CLAUDE_CODE_USE_BEDROCK -u CLAUDE_CODE_USE_VERTEX -u CLAUDE_CODE_USE_FOUNDRY \
    -u VULYK_MODEL_FLOOR HOME="$FLOORHIVE/home" CLAUDE_CONFIG_DIR="$FLOORHIVE/home/.claude" \
    CLAUDE_PROJECT_DIR="$FLOORHIVE" "$@" bash scripts/top-model.sh --floor)
}
floorcheck >/dev/null 2>&1
expect_eq "--floor exits 0 on the shipped agents, the story template and a clean env" "0" "$?"
OUT="$(floorcheck ANTHROPIC_DEFAULT_SONNET_MODEL=claude-sonnet-5 2>&1)"; RC=$?
expect_eq "--floor exits 1 on an env pin below the floor" "1" "$RC"
printf '%s\n' "$OUT" | expect "--floor names the env pin" "env ANTHROPIC_DEFAULT_SONNET_MODEL = claude-sonnet-5 is sonnet 5.0, floor 5.5"
printf '{\n  "env": { "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-5" }\n}\n' > "$FLOORHIVE/home/.claude/settings.json"
floorcheck 2>&1 | expect "--floor reads a user settings.json env block" "ANTHROPIC_DEFAULT_OPUS_MODEL = claude-opus-5 is opus 5.0, floor 5.5"
rm -f "$FLOORHIVE/home/.claude/settings.json"
floorcheck CLAUDE_CODE_USE_BEDROCK=1 2>&1 | expect "--floor warns on a provider with no family pin" \
  "CLAUDE_CODE_USE_BEDROCK is set and ANTHROPIC_DEFAULT_SONNET_MODEL is not"
floorcheck CLAUDE_CODE_USE_BEDROCK=1 ANTHROPIC_DEFAULT_OPUS_MODEL=anthropic.claude-opus-5-5 \
  ANTHROPIC_DEFAULT_SONNET_MODEL=anthropic.claude-sonnet-5-5 >/dev/null 2>&1
expect_eq "--floor is clean on a provider with both families pinned at the floor" "0" "$?"
floorcheck CLAUDE_CODE_SUBAGENT_MODEL=haiku 2>&1 | expect "--floor names a route to the unreleased haiku floor" \
  "env CLAUDE_CODE_SUBAGENT_MODEL = haiku - no haiku at its floor 5.5 has shipped"
mkdir -p "$FLOORHIVE/docs/specs/demo"
printf -- '---\nstory: demo-01\nmodel: claude-opus-4-6   # pinned\n---\n' > "$FLOORHIVE/docs/specs/demo/demo-01-x.md"
floorcheck 2>&1 | expect "--floor names a story pinned below the floor" "docs/specs/demo/demo-01-x.md model = claude-opus-4-6 is opus 4.6"
rm -rf "$FLOORHIVE/docs"
sed -i 's/^model: sonnet$/model: claude-sonnet-4-5/' "$FLOORHIVE/.claude/agents/worker-code.md"
floorcheck 2>&1 | expect "--floor names an agent pinned below the floor" "worker-code.md model = claude-sonnet-4-5 is sonnet 4.5"

: > "$LOG"
FLPROJ="$T/floorproj"; mkdir -p "$FLPROJ/fs1/subagents"
floor_line() { # floor_line <model> <true|false sidechain>
  printf '{"type":"assistant","isSidechain":%s,"message":{"model":"%s","usage":{"input_tokens":100,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":5},"content":[{"type":"text","text":"done"}]}}\n' "$2" "$1"
}
floor_line claude-opus-5 false       > "$FLPROJ/fs1.jsonl"
floor_line claude-sonnet-5 true      > "$FLPROJ/fs1/subagents/agent-b1.jsonl"
printf '{"agentType":"worker-code"}\n' > "$FLPROJ/fs1/subagents/agent-b1.meta.json"
floor_line claude-sonnet-5-5 true    > "$FLPROJ/fs1/subagents/agent-b2.jsonl"
printf '{"agentType":"drone-scout"}\n' > "$FLPROJ/fs1/subagents/agent-b2.meta.json"
tel scan --transcript "$FLPROJ/fs1.jsonl" >/dev/null 2>&1
expect_eq "scan records the main session that ran below the floor" "opus 5.0 5.5" \
  "$(grep '"code":"model_below_floor"' "$LOG" | grep '"ref":"session:' | jq -r '"\(.model) \(.value) \(.threshold)"')"
expect_eq "scan records the subagent that ran below the floor, with its agent" "sonnet worker-code" \
  "$(grep '"code":"model_below_floor"' "$LOG" | grep '"ref":"agent:' | jq -r '"\(.model) \(.agent)"')"
expect_eq "a subagent on the floor yields no row" "0" "$(grep -c 'agent-b2' "$LOG")"
tel scan --transcript "$FLPROJ/fs1.jsonl" >/dev/null 2>&1
expect_eq "a second scan adds no model_below_floor row" "2" "$(grep -c '"code":"model_below_floor"' "$LOG")"
# Review finding: with no .meta.json the agent column is empty, and `read` collapses two tabs in a
# row - the model must still reach the detector, and the agent stay empty.
floor_line claude-sonnet-5 true > "$FLPROJ/fs1/subagents/agent-b3.jsonl"
tel scan --transcript "$FLPROJ/fs1.jsonl" >/dev/null 2>&1
expect_eq "a subagent with no agentType still records its below-floor model" "sonnet||5.0" \
  "$(grep '"code":"model_below_floor"' "$LOG" | grep 'agent-b3' | jq -r '"\(.model)|\(.agent)|\(.value)"')"

# --- case 12: scan - council_rounds_high ---------------------------------------------------------
echo "--- scan: council_rounds_high"
mkdir -p "$HIVE/docs/specs/fixture-spec" "$HIVE/docs/specs/low-round-spec"
printf '**Tier:** 2 · **Spec slug:** `fixture-spec`\n' > "$HIVE/docs/specs/fixture-spec/plan.md"
printf '**Tier:** 1 · **Spec slug:** `low-round-spec`\n' > "$HIVE/docs/specs/low-round-spec/plan.md"
COUNCIL_LOG="$HIVE/memory/stats/council.jsonl"
: > "$COUNCIL_LOG"
printf '{"ts":"%s","spec":"fixture-spec","round":3,"verdict":"GREEN"}\n' "$NOW" >> "$COUNCIL_LOG"
printf '{"ts":"%s","spec":"low-round-spec","round":2,"verdict":"GREEN"}\n' "$NOW" >> "$COUNCIL_LOG"

: > "$LOG"
tel scan >/dev/null 2>&1
expect_eq "council_rounds_high fires for the spec at round 3" "1" \
  "$(grep -c '"code":"council_rounds_high".*"spec":"fixture-spec"' "$LOG")"
expect_eq "council_rounds_high carries the spec's tier from plan.md" "2" \
  "$(grep '"code":"council_rounds_high"' "$LOG" | jq -r '.tier')"
expect_eq "no council_rounds_high row for the spec at round 2" "0" \
  "$(grep -c '"spec":"low-round-spec"' "$LOG")"

# Review finding 15: a spec read out of council.jsonl is data - it never becomes a path and
# never reaches the row unless it is a plain slug.
printf '{"ts":"%s","spec":"../x","round":4,"verdict":"RED"}\n' "$NOW" >> "$COUNCIL_LOG"
: > "$LOG"
tel scan >/dev/null 2>&1
expect_eq "a spec outside the slug shape still records the anomaly" "1" \
  "$(grep -c '"code":"council_rounds_high","value":4' "$LOG")"
expect_eq "the unsafe spec never reaches the row" "" \
  "$(grep -F '"value":4' "$LOG" | jq -r '.spec')"
expect_eq "the unsafe spec yields tier 0 - no path was built" "0" \
  "$(grep -F '"value":4' "$LOG" | jq -r '.tier')"

# --- case 13: scan - stage_long -------------------------------------------------------------------
echo "--- scan: stage_long"
mkdir -p "$HIVE/docs/specs/stage-long-spec" "$HIVE/docs/specs/stage-short-spec"
cat > "$HIVE/docs/specs/stage-long-spec/journal.md" <<'EOF'
- 2026-01-01T00:00:00Z · 01-spec · start · next: plan
- 2026-01-02T06:00:00Z · 02-plan · planned · next: build
EOF
cat > "$HIVE/docs/specs/stage-short-spec/journal.md" <<'EOF'
- 2026-01-01T00:00:00Z · 01-spec · start · next: plan
- 2026-01-01T02:00:00Z · 02-plan · planned · next: build
EOF

: > "$LOG"
tel scan >/dev/null 2>&1
expect_eq "stage_long fires for a 30h gap" "1" \
  "$(grep -c '"code":"stage_long".*"spec":"stage-long-spec"' "$LOG")"
expect_eq "stage_long value is the gap in hours" "30" \
  "$(grep '"code":"stage_long".*"spec":"stage-long-spec"' "$LOG" | jq -r '.value')"
expect_eq "stage_long threshold is the configured hours" "24" \
  "$(grep '"code":"stage_long".*"spec":"stage-long-spec"' "$LOG" | jq -r '.threshold')"
expect_eq "no stage_long row for a 2h gap" "0" \
  "$(grep -c '"spec":"stage-short-spec"' "$LOG")"

# --- case 14: scan - scope_breach ------------------------------------------------------------------
echo "--- scan: scope_breach"
SCOPE_LOG="$HIVE/memory/stats/scope.jsonl"
: > "$SCOPE_LOG"
printf '{"ts":"%s","story":"breach-story","declared":1,"changed":3,"out_of_scope":["a/b.sh","c/d.sh"]}\n' "$NOW" >> "$SCOPE_LOG"
printf '{"ts":"%s","story":"clean-story","declared":1,"changed":1,"out_of_scope":[]}\n' "$NOW" >> "$SCOPE_LOG"

: > "$LOG"
tel scan >/dev/null 2>&1
expect_eq "scope_breach fires for a non-empty out_of_scope" "1" \
  "$(grep -c '"code":"scope_breach"' "$LOG")"
expect_eq "scope_breach value is the out-of-scope path count" "2" \
  "$(grep '"code":"scope_breach"' "$LOG" | jq -r '.value')"
expect_eq "scope_breach carries the story id" "breach-story" \
  "$(grep '"code":"scope_breach"' "$LOG" | jq -r '.story')"
expect_eq "no scope_breach row for an empty out_of_scope" "0" \
  "$(grep -c '"story":"clean-story"' "$LOG")"
expect_eq "scope_breach ref is scope:<story>" "scope:breach-story" \
  "$(grep '"code":"scope_breach"' "$LOG" | jq -r '.ref')"

# Review finding 11: scope.jsonl holds one row per scope-check RUN, so a story checked twice
# became two anomalies. One row per story, first breach wins (plan A17).
printf '{"ts":"2026-01-01T00:00:00Z","story":"breach-story","declared":1,"changed":5,"out_of_scope":["a/b.sh"]}\n' \
  >> "$SCOPE_LOG"
tel scan >/dev/null 2>&1
expect_eq "a second scope.jsonl row for the same story adds no second anomaly" "1" \
  "$(grep -c '"code":"scope_breach"' "$LOG")"
expect_eq "the first breach wins" "2" \
  "$(grep '"code":"scope_breach"' "$LOG" | jq -r '.value')"

# --- case 15: scan - kill switch and the no-transcript, no-session-dir path -------------------------
echo "--- scan: kill switch, minimal invocation"
: > "$LOG"
(cd "$HIVE" && VULYK_HIVE="$HIVE" VULYK_TELEMETRY_SCAN=0 bash scripts/telemetry.sh scan --transcript "$CTX") >/dev/null 2>&1
expect_eq "VULYK_TELEMETRY_SCAN=0 writes nothing" "0" "$(grep -c . "$LOG" 2>/dev/null || true)"

: > "$LOG"
SCAN_RC=0
tel scan >/dev/null 2>&1 || SCAN_RC=$?
expect_eq "scan with no transcript and no session dir exits 0" "0" "$SCAN_RC"
expect_eq "scan with no transcript still runs the stats-file detectors" "1" \
  "$(grep -c '"code":"scope_breach"' "$LOG")"

# --- case 16: anomaly-scan.sh - wiring and fail-open ------------------------------------------------
echo "--- anomaly-scan.sh"
# ADR-013 D7: the scan runs once per session, on SessionEnd; the learnings hook and the
# effortLevel key are gone from VULYK's own settings.json.
expect_eq "anomaly-scan.sh is not wired on Stop" "0" \
  "$(jq -r '.hooks.Stop[].hooks[].command' "$SRC/.claude/settings.json" | grep -c 'anomaly-scan.sh')"
expect_eq "anomaly-scan.sh is wired on SessionEnd" "1" \
  "$(jq -r '.hooks.SessionEnd[].hooks[].command' "$SRC/.claude/settings.json" | grep -c 'anomaly-scan.sh')"
expect_eq "the Stop hook handoff.sh stop is still wired" "1" \
  "$(jq -r '.hooks.Stop[].hooks[].command' "$SRC/.claude/settings.json" | grep -c 'handoff.sh stop')"
expect_eq "no learnings hook is wired anywhere" "0" \
  "$(jq -r '.hooks[][].hooks[].command' "$SRC/.claude/settings.json" | grep -c 'session-end-learnings')"
expect_eq "the learnings hook no longer ships" "0" \
  "$([ -e "$SRC/.claude/hooks/session-end-learnings.sh" ] && echo 1 || echo 0)"
expect_eq "settings.json carries no effortLevel" "false" "$(jq -r 'has("effortLevel")' "$SRC/.claude/settings.json" | tr -d '\r')"

: > "$LOG"
HOOK_RC=0
echo '{"transcript_path":""}' | CLAUDE_PROJECT_DIR="$HIVE" VULYK_HIVE="$HIVE" bash "$HIVE/.claude/hooks/anomaly-scan.sh" \
  > "$T/hook-out" 2> "$T/hook-err" || HOOK_RC=$?
expect_eq "anomaly-scan.sh exits 0 on the success path" "0" "$HOOK_RC"
expect_eq "anomaly-scan.sh prints nothing on the success path" "" "$(cat "$T/hook-out")"

# Plan A17 / review Major 6: the hook reads hook_event_name, and only a SessionEnd scan may
# judge a subagent empty. The session fixture is case 10's.
: > "$LOG"
printf '{"transcript_path":"%s","hook_event_name":"Stop"}\n' "$PROJ/sid1.jsonl" |
  CLAUDE_PROJECT_DIR="$HIVE" VULYK_HIVE="$HIVE" bash "$HIVE/.claude/hooks/anomaly-scan.sh" >/dev/null 2>&1
expect_eq "a Stop hook records the prefix anomalies" "2" \
  "$(grep -c '"code":"agent_prefix_high"' "$LOG")"
expect_eq "a Stop hook records no agent_empty row" "0" \
  "$(grep -c '"code":"agent_empty"' "$LOG")"
printf '{"transcript_path":"%s","hook_event_name":"SessionEnd"}\n' "$PROJ/sid1.jsonl" |
  CLAUDE_PROJECT_DIR="$HIVE" VULYK_HIVE="$HIVE" bash "$HIVE/.claude/hooks/anomaly-scan.sh" >/dev/null 2>&1
expect_eq "a SessionEnd hook passes --final, so agent_empty is judged" "1" \
  "$(grep -c '"code":"agent_empty"' "$LOG")"

BASHBIN="$(command -v bash)"
EMPTYPATH="$T/emptybin"; mkdir -p "$EMPTYPATH"
NOJQ_RC=0
echo '{}' | PATH="$EMPTYPATH" CLAUDE_PROJECT_DIR="$HIVE" VULYK_HIVE="$HIVE" "$BASHBIN" "$HIVE/.claude/hooks/anomaly-scan.sh" \
  >/dev/null 2>&1 || NOJQ_RC=$?
expect_eq "anomaly-scan.sh exits 0 when jq is missing" "0" "$NOJQ_RC"

JQONLY="$T/jq-only"; mkdir -p "$JQONLY"
cp "$(command -v jq)" "$JQONLY/jq"
NOPY_RC=0
echo '{}' | PATH="$JQONLY" CLAUDE_PROJECT_DIR="$HIVE" VULYK_HIVE="$HIVE" "$BASHBIN" "$HIVE/.claude/hooks/anomaly-scan.sh" \
  >/dev/null 2>&1 || NOPY_RC=$?
expect_eq "anomaly-scan.sh exits 0 when python is missing" "0" "$NOPY_RC"

mkdir -p "$T/no-telemetry"
NOSCRIPT_RC=0
echo '{}' | CLAUDE_PROJECT_DIR="$T/no-telemetry" VULYK_HIVE="$T/no-telemetry" bash "$HIVE/.claude/hooks/anomaly-scan.sh" \
  >/dev/null 2>&1 || NOSCRIPT_RC=$?
expect_eq "anomaly-scan.sh exits 0 when scripts/telemetry.sh is missing" "0" "$NOSCRIPT_RC"

# sessionend_llm (0.19): a SessionEnd hook that runs `claude -p` - in its settings.json command
# or in the script that command runs - is killed at 60 s. The hook names it; nothing else fires.
echo "--- anomaly-scan.sh: sessionend_llm"
LLMSET="$HIVE/.claude/settings.json"
printf '#!/usr/bin/env bash\ntail -c 2000 "$1" | claude -p --model sonnet "distill" > out.md\n' > "$HIVE/.claude/hooks/learn.sh"
printf '#!/usr/bin/env bash\n# the old way was: claude -p "distill"\necho quiet\n' > "$HIVE/.claude/hooks/quiet.sh"
llm_hook() { # llm_hook <settings json> - run the hook as a SessionEnd would, print sessionend_llm refs
  printf '%s\n' "$1" > "$LLMSET"
  : > "$LOG"
  echo '{"hook_event_name":"SessionEnd"}' | CLAUDE_PROJECT_DIR="$HIVE" VULYK_HIVE="$HIVE" \
    bash "$HIVE/.claude/hooks/anomaly-scan.sh" >/dev/null 2>&1
  grep '"code":"sessionend_llm"' "$LOG" | sed -n 's/.*"ref":"\([^"]*\)".*/\1/p' | paste -sd' '
}
expect_eq "fires on a SessionEnd script that calls claude -p, naming it" "sessionend:learn.sh" \
  "$(llm_hook '{"hooks":{"SessionEnd":[{"hooks":[{"type":"command","command":"$CLAUDE_PROJECT_DIR/.claude/hooks/anomaly-scan.sh"},{"type":"command","command":"bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/learn.sh\""}]}]}}')"
expect_eq "... and the row is the 12-key local row with value 1" "1" \
  "$(grep '"code":"sessionend_llm"' "$LOG" | jq -r '[(keys | length == 12), (.value == 1)] | all' | tr -d '\r' | grep -c true)"
echo '{"hook_event_name":"SessionEnd"}' | CLAUDE_PROJECT_DIR="$HIVE" VULYK_HIVE="$HIVE" \
  bash "$HIVE/.claude/hooks/anomaly-scan.sh" >/dev/null 2>&1
expect_eq "a second SessionEnd adds no second row" "1" "$(grep -c '"code":"sessionend_llm"' "$LOG")"
expect_eq "fires on an inline claude -p command" "sessionend:inline" \
  "$(llm_hook '{"hooks":{"SessionEnd":[{"hooks":[{"type":"command","command":"claude -p \"summarize\" > notes.md"}]}]}}')"
expect_eq "silent when the same script is wired on Stop, not SessionEnd" "" \
  "$(llm_hook '{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"$CLAUDE_PROJECT_DIR/.claude/hooks/learn.sh"}]}]}}')"
expect_eq "silent when claude -p is only in a comment" "" \
  "$(llm_hook '{"hooks":{"SessionEnd":[{"hooks":[{"type":"command","command":"$CLAUDE_PROJECT_DIR/.claude/hooks/quiet.sh"}]}]}}')"
expect_eq "silent on VULYK's own settings.json and hooks" "" \
  "$(llm_hook "$(cat "$SRC/.claude/settings.json")")"
LLM_OFF="$(printf '%s\n' '{"hooks":{"SessionEnd":[{"hooks":[{"type":"command","command":"$CLAUDE_PROJECT_DIR/.claude/hooks/learn.sh"}]}]}}' > "$LLMSET"
  : > "$LOG"; echo '{}' | VULYK_TELEMETRY_SCAN=0 CLAUDE_PROJECT_DIR="$HIVE" VULYK_HIVE="$HIVE" \
  bash "$HIVE/.claude/hooks/anomaly-scan.sh" >/dev/null 2>&1; grep -c . "$LOG")"
expect_eq "VULYK_TELEMETRY_SCAN=0 silences it too" "0" "$LLM_OFF"
rm -f "$LLMSET" "$HIVE/.claude/hooks/learn.sh" "$HIVE/.claude/hooks/quiet.sh"; : > "$LOG"

# --- session-start-brief.sh: the litopys offer (0.19, plan 1.7) --------------------------------
# One line, until litopys is in enabledPlugins (either settings file) or the Profile declines it.
echo "--- session-start-brief.sh: litopys"
if bash -n "$SRC/.claude/hooks/session-start-brief.sh" 2>/dev/null; then ok "bash -n session-start-brief.sh"
else bad "bash -n session-start-brief.sh failed"; fi
BRIEF="$T/hive-brief"; mkdir -p "$BRIEF/memory" "$BRIEF/.claude"
printf '# Hive\n\n| Field | Value |\n|---|---|\n| Stack | shell |\n' > "$BRIEF/CLAUDE.md"
brief() { echo '{}' | CLAUDE_PROJECT_DIR="$BRIEF" bash "$SRC/.claude/hooks/session-start-brief.sh" 2>&1; }
brief | expect "absent: the hive brief line is still first" "[VULYK] no map yet"
brief | expect "absent: the offer names the install commands" \
  "claude plugin marketplace add Black-coffe/litopys --scope project\` then \`claude plugin install litopys@litopys --scope project"
brief | expect "absent: the offer names the decline row" "| Chronicle | none (declined <date>) |"
expect_eq "absent: exactly one litopys line" "1" "$(brief | grep -c 'litopys (session chronicle plugin) is not installed here')"
printf '{"enabledPlugins":{"litopys@litopys":true}}\n' > "$BRIEF/.claude/settings.json"
brief | expect_absent "installed (settings.json): no offer" "litopys (session chronicle plugin)"
rm -f "$BRIEF/.claude/settings.json"
printf '{\n  "enabledPlugins": {\n    "litopys@my-fork": true\n  }\n}\n' > "$BRIEF/.claude/settings.local.json"
brief | expect_absent "installed (settings.local.json, any marketplace): no offer" "litopys (session chronicle plugin)"
rm -f "$BRIEF/.claude/settings.local.json"
printf '{"enabledPlugins":{"other@litopys":true}}\n' > "$BRIEF/.claude/settings.json"
brief | expect "a different plugin from the litopys marketplace is not litopys" "litopys (session chronicle plugin)"
rm -f "$BRIEF/.claude/settings.json"
printf '| Chronicle | none (declined 2026-09-27) |\n' >> "$BRIEF/CLAUDE.md"
brief | expect_absent "declined in the Profile: no offer" "litopys (session chronicle plugin)"
brief | expect "declined: the hive brief line stays" "[VULYK] no map yet"

# --- install and consent wiring (anomaly-telemetry-05) ----------------------------------------
# Story 05 adds the Telemetry Profile row, install.sh's /dev/tty question and `wire_hook`.
# Its local cases belong here, below this marker.
echo "--- install.sh: the Telemetry row, the question, wire_hook"

if bash -n "$SRC/install.sh" 2>/dev/null; then ok "bash -n install.sh"
else bad "bash -n install.sh failed"; bash -n "$SRC/install.sh"; fi

rowval() { # rowval <constitution> - the first token of the Telemetry row's value cell
  grep -m1 '^|[[:space:]]*Telemetry[[:space:]]*|' "$1" 2>/dev/null \
    | awk -F'|' '{print $3}' | tr -d '`' | awk '{print $1}'
}
profile_rows() { awk '/VULYK:PROFILE:START/{f=1;next}/VULYK:PROFILE:END/{f=0}f' "$1" | grep '^| '; }

expect_eq "the repo's own constitution consents to nothing" "off" "$(cd "$SRC" && bash scripts/telemetry.sh consent)"

# Every install below names its consent explicitly unless the case is ABOUT the question, so
# no case can block on a prompt when the suite is run from a real terminal.
TGT="$T/hive-install"; mkdir -p "$TGT"
bash "$SRC/install.sh" "$TGT" --telemetry off > "$T/install.out" 2>&1
expect_eq "fresh install writes the Telemetry row as off" "off" "$(rowval "$TGT/CLAUDE.md")"
expect_eq "the row is the last row inside the Profile block" "1" \
  "$(profile_rows "$TGT/CLAUDE.md" | tail -1 | grep -c '^| Telemetry |')"
expect_eq "the installed hive's own consent verb reads it" "off" \
  "$(VULYK_HIVE="$TGT" bash "$TGT/scripts/telemetry.sh" consent)"
expect_eq "the anomaly log is never shipped into a hive" "0" \
  "$([ -e "$TGT/memory/stats/anomalies.jsonl" ] && echo 1 || echo 0)"
expect_eq "the council ledger is never shipped into a hive" "0" \
  "$([ -e "$TGT/memory/stats/council.jsonl" ] && echo 1 || echo 0)"
# ADR-013 D7: a fresh hive gets no learnings hook and no Stop scan
expect_eq "fresh install: no learnings hook file" "0" \
  "$([ -e "$TGT/.claude/hooks/session-end-learnings.sh" ] && echo 1 || echo 0)"
expect_eq "fresh install: no learnings hook wired" "0" "$(grep -c 'session-end-learnings' "$TGT/.claude/settings.json")"
expect_eq "fresh install: the scan is wired on SessionEnd only" "0 1" \
  "$(jq -r '[.hooks.Stop[]?.hooks[].command | select(test("anomaly-scan"))] | length' "$TGT/.claude/settings.json" | tr -d '\r') $(jq -r '[.hooks.SessionEnd[]?.hooks[].command | select(test("anomaly-scan"))] | length' "$TGT/.claude/settings.json" | tr -d '\r')"
# ...and a project that already had its own settings.json gets the same through wire_hook
OWNSET="$T/hive-own-settings"; mkdir -p "$OWNSET/.claude"
printf '{"permissions":{"allow":["Bash(ls:*)"]}}\n' > "$OWNSET/.claude/settings.json"
bash "$SRC/install.sh" "$OWNSET" --telemetry off > "$T/ownset.out" 2>&1
cat "$T/ownset.out" | expect "an owner's settings.json gets the scan on SessionEnd" "wire           .claude/settings.json -> SessionEnd: anomaly-scan.sh"
cat "$T/ownset.out" | expect_absent "and no Stop wiring" "-> Stop:"
expect_eq "and no learnings hook" "0" "$(grep -c 'session-end-learnings' "$OWNSET/.claude/settings.json")"

# --telemetry on changes that one row's value and nothing else in the constitution
PROF_BEFORE="$(grep -v '^| Telemetry |' "$TGT/CLAUDE.md")"
bash "$SRC/install.sh" "$TGT" --upgrade --telemetry on > "$T/up-on.out" 2>&1
expect_eq "--telemetry on flips the row" "on" "$(rowval "$TGT/CLAUDE.md")"
expect_eq "nothing else in the constitution moved" "1" \
  "$([ "$PROF_BEFORE" = "$(grep -v '^| Telemetry |' "$TGT/CLAUDE.md")" ] && echo 1 || echo 0)"
expect_eq "the row is still there exactly once" "1" "$(grep -c '^| Telemetry |' "$TGT/CLAUDE.md")"

# an answered row survives a plain upgrade byte for byte, and is not asked about again
CONST_BEFORE="$(cat "$TGT/CLAUDE.md")"
bash "$SRC/install.sh" "$TGT" --upgrade > "$T/up-plain.out" 2>&1
expect_eq "an answered row is byte-identical after --upgrade" "1" \
  "$([ "$CONST_BEFORE" = "$(cat "$TGT/CLAUDE.md")" ] && echo 1 || echo 0)"
cat "$T/up-plain.out" | expect_absent "no question for a hive that already answered" "Enable telemetry?"

# --check reports the pending insertion and writes nothing
sed -i '/^| Telemetry |/d' "$TGT/CLAUDE.md"
CONST_BEFORE="$(cat "$TGT/CLAUDE.md")"
bash "$SRC/install.sh" "$TGT" --upgrade --check > "$T/up-check.out" 2>&1
expect_eq "--check never writes the row" "1" \
  "$([ "$CONST_BEFORE" = "$(cat "$TGT/CLAUDE.md")" ] && echo 1 || echo 0)"
cat "$T/up-check.out" | expect "--check reports the pending row" "would set      CLAUDE.md Profile row: Telemetry"

# a Profile block with no markers: warn, and never write the row (ADR-005: only exception is
# the Telemetry row itself, and only inside existing markers)
NOMARK="$T/hive-nomarkers"; mkdir -p "$NOMARK"
# An upgrade run through the hive's own scripts/vulyk-update.sh replaces that very script. An
# in-place copy made the old process read the new file from its old offset and execute the
# tail (upgrading a 0.17 hive to 0.18); install.sh now copies beside and renames over.
SELF="$T/hive-self"; mkdir -p "$SELF"
bash "$SRC/install.sh" "$SELF" --telemetry off > "$T/self-install.out" 2>&1
{
  printf '#!/usr/bin/env bash\n'
  printf '# padding line %s - the offset the old process resumes from must land inside the new file\n' $(seq 1 40)
  printf 'bash "%s/install.sh" "%s" --upgrade --telemetry off > /dev/null 2>&1\n' "$SRC" "$SELF"
  printf 'echo "updater: after the upgrade"\n'
  printf 'echo "updater: done"\n'
} > "$SELF/scripts/vulyk-update.sh"
expect_eq "an upgrade run from the hive's own updater lets that updater finish cleanly" \
  "updater: after the upgrade|updater: done" "$(bash "$SELF/scripts/vulyk-update.sh" 2>&1 | paste -sd'|')"
expect_eq "... and leaves the release's updater in place" "0" \
  "$(cmp -s "$SRC/scripts/vulyk-update.sh" "$SELF/scripts/vulyk-update.sh"; echo $?)"

bash "$SRC/install.sh" "$NOMARK" --telemetry off > "$T/nomark-install.out" 2>&1
sed -i '/VULYK:PROFILE:START/d; /VULYK:PROFILE:END/d' "$NOMARK/CLAUDE.md"
NOMARK_BEFORE="$(cat "$NOMARK/CLAUDE.md")"
VULYK_TELEMETRY=on bash "$SRC/install.sh" "$NOMARK" --upgrade > "$T/nomark-upgrade.out" 2>&1
cat "$T/nomark-upgrade.out" | expect "marker-less Profile: warns and names the row and value" \
  "warning: Profile block has no markers - not writing | Telemetry | on |; add the row by hand"
expect_eq "marker-less Profile: the file is unchanged" "1" \
  "$([ "$NOMARK_BEFORE" = "$(cat "$NOMARK/CLAUDE.md")" ] && echo 1 || echo 0)"

# A run with no controlling terminal: setsid is what makes /dev/tty unopenable even when the
# suite itself is driven from a real one. Without setsid the case is only honest when this
# shell already has no terminal - otherwise it is skipped, loudly.
tty_reachable() { ( exec 3< /dev/tty ) 2>/dev/null; }
NOTTY=""
if command -v setsid >/dev/null 2>&1 && setsid --wait true 2>/dev/null; then NOTTY="setsid --wait"
elif ! tty_reachable; then NOTTY="env"
fi

if [ -n "$NOTTY" ]; then
  # upgrade, row missing, nobody to ask -> appended as off, silently
  $NOTTY bash "$SRC/install.sh" "$TGT" --upgrade > "$T/up-notty.out" 2>&1
  expect_eq "no terminal: the missing row is appended as off" "off" "$(rowval "$TGT/CLAUDE.md")"
  expect_eq "appended exactly once" "1" "$(grep -c '^| Telemetry |' "$TGT/CLAUDE.md")"
  cat "$T/up-notty.out" | expect_absent "no terminal: no question is printed" "Enable telemetry?"
  cat "$T/up-notty.out" | expect_absent "no terminal: no explanation is printed" "Telemetry (optional"

  # a piped `y` on stdin is NOT an answer: stdin is never the answer channel
  PIPED="$T/hive-piped"; mkdir -p "$PIPED"
  echo y | $NOTTY bash "$SRC/install.sh" "$PIPED" > "$T/piped.out" 2>&1
  expect_eq "piped stdin never answers the question" "off" "$(rowval "$PIPED/CLAUDE.md")"
else
  echo "  skip  no-terminal cases: no setsid and this shell has a reachable /dev/tty"
fi

# The real thing, through a pseudo-terminal, when util-linux `script` is on PATH.
if command -v script >/dev/null 2>&1 && script --version 2>&1 | grep -qi 'util-linux'; then
  PTY="$T/hive-pty"; mkdir -p "$PTY"
  printf 'y\n' | script -qec "bash '$SRC/install.sh' '$PTY'" /dev/null > "$T/pty.out" 2>&1 || true
  cat "$T/pty.out" | expect "a terminal gets the explanation, naming off as the default" "Default: off."
  cat "$T/pty.out" | expect "a terminal gets exactly one question" "Enable telemetry? [y/N]"
  expect_eq "answering y lands the row as on" "on" "$(rowval "$PTY/CLAUDE.md")"
else
  echo "  skip  terminal case: no util-linux \`script\` on PATH to drive a pseudo-terminal"
fi

# wire_hook / unwire_hook (ADR-013 D7): a 0.17-shaped settings.json - the scan on Stop, the
# learnings hook on SessionEnd, no scan there yet - loses the two entries this release no longer
# wants, gains the SessionEnd scan once, keeps everything else, and a second upgrade is
# byte-identical. The backup is the file as the owner left it, however many edits followed.
SET="$TGT/.claude/settings.json"
jq '.hooks.Stop = [{"hooks":[{"type":"command","command":"$CLAUDE_PROJECT_DIR/.claude/hooks/handoff.sh stop"},{"type":"command","command":"$CLAUDE_PROJECT_DIR/.claude/hooks/anomaly-scan.sh"}]}]
    | .hooks.SessionEnd = [{"hooks":[{"type":"command","command":"$CLAUDE_PROJECT_DIR/.claude/hooks/session-end-learnings.sh"},{"type":"command","command":"$CLAUDE_PROJECT_DIR/.claude/hooks/handoff.sh sessionend"}]}]' \
  "$SET" > "$T/set.json" && mv "$T/set.json" "$SET"
cp "$SET" "$T/set.before"
bash "$SRC/install.sh" "$TGT" --upgrade --check > "$T/wire0.out" 2>&1
cat "$T/wire0.out" | expect "--check reports the Stop unwiring" "would unwire   .claude/settings.json -> Stop: anomaly-scan.sh"
cat "$T/wire0.out" | expect "--check reports the learnings unwiring" "would unwire   .claude/settings.json -> SessionEnd: session-end-learnings.sh"
cat "$T/wire0.out" | expect "--check reports the SessionEnd wiring" "would wire     .claude/settings.json -> SessionEnd: anomaly-scan.sh"
expect_eq "--check leaves settings.json untouched" "1" "$(cmp -s "$T/set.before" "$SET" && echo 1 || echo 0)"
bash "$SRC/install.sh" "$TGT" --upgrade --telemetry off > "$T/wire.out" 2>&1
cat "$T/wire.out" | expect "unwire_hook reports Stop" "unwire         .claude/settings.json -> Stop: anomaly-scan.sh"
cat "$T/wire.out" | expect "unwire_hook reports the learnings hook" "unwire         .claude/settings.json -> SessionEnd: session-end-learnings.sh"
cat "$T/wire.out" | expect "wire_hook reports SessionEnd" "wire           .claude/settings.json -> SessionEnd: anomaly-scan.sh"
cat "$T/wire.out" | expect_absent "nothing is wired on Stop" "wire           .claude/settings.json -> Stop"
expect_eq "anomaly-scan.sh is gone from Stop" "0" \
  "$(jq -r '.hooks.Stop[].hooks[].command' "$SET" | grep -c 'anomaly-scan.sh')"
expect_eq "the existing Stop entry is preserved" "1" \
  "$(jq -r '.hooks.Stop[].hooks[].command' "$SET" | grep -c 'handoff.sh stop')"
expect_eq "anomaly-scan.sh is wired once on SessionEnd" "1" \
  "$(jq -r '.hooks.SessionEnd[].hooks[].command' "$SET" | grep -c 'anomaly-scan.sh')"
expect_eq "the learnings hook is gone from settings.json" "0" "$(grep -c 'session-end-learnings' "$SET")"
expect_eq "the existing SessionEnd entry is preserved" "1" \
  "$(jq -r '.hooks.SessionEnd[].hooks[].command' "$SET" | grep -c 'handoff.sh sessionend')"
expect_eq "SessionStart wiring is untouched" "1" \
  "$(jq -r '.hooks.SessionStart[].hooks[].command' "$SET" | grep -c 'vulyk-update-check.sh')"
expect_eq "the backup is settings.json as it was before the run" "1" \
  "$(cmp -s "$T/set.before" "$SET.vulyk-bak" && echo 1 || echo 0)"
SET_BEFORE="$(cat "$SET")"
bash "$SRC/install.sh" "$TGT" --upgrade --telemetry off > "$T/wire2.out" 2>&1
expect_eq "a second upgrade leaves settings.json byte-identical" "1" \
  "$([ "$SET_BEFORE" = "$(cat "$SET")" ] && echo 1 || echo 0)"
cat "$T/wire2.out" | expect_absent "and reports no second wiring" "-> SessionEnd: anomaly-scan.sh"
cat "$T/wire2.out" | expect_absent "and no second unwiring" "unwire"
bash "$SRC/install.sh" "$TGT" --upgrade --check > "$T/wire3.out" 2>&1
cat "$T/wire3.out" | expect_absent "--check reports no wiring for an already-wired hook" "would wire     .claude/settings.json -> SessionEnd"
cat "$T/wire3.out" | expect_absent "--check reports no unwiring once it is done" "would unwire"

# council.jsonl (convergent-judge-03): excluded as runtime; --upgrade strips the seeded
# autonomous-cycle rows an older release shipped, and nothing else.
echo "--- install.sh: council.jsonl exclusion and seeded-row cleanup"
bash "$SRC/install.sh" "$TGT" --check > "$T/council-check.out" 2>&1
cat "$T/council-check.out" | expect "--check lists council.jsonl as a runtime skip" \
  "would skip (runtime) memory/stats/council.jsonl"
LEDG="$TGT/memory/stats/council.jsonl"
KEEP1='{"ts":"2026-09-20T10:00:00Z","spec":"my-feature","round":1,"verdict":"GREEN"}'
KEEP2='{"ts":"2026-09-21T10:00:00Z","spec":"other","round":2,"verdict":"RED","note":"x"}'
seed_ledger() {
  { echo '{"ts":"2026-09-13T11:09:36Z","spec":"autonomous-cycle","round":1,"verdict":"RED"}'
    echo "$KEEP1"
    echo '{"ts":"2026-09-13T14:03:59Z","spec":"autonomous-cycle","round":2,"verdict":"RED"}'
    echo "$KEEP2"
    echo '{"ts":"2026-09-13T16:00:00Z","spec":"autonomous-cycle","round":3,"verdict":"GREEN"}'
  } > "$LEDG"
}
seed_ledger; cp "$LEDG" "$T/ledger.before"
bash "$SRC/install.sh" "$TGT" --upgrade --check > "$T/council-upcheck.out" 2>&1
cat "$T/council-upcheck.out" | expect "--upgrade --check reports the pending cleanup" \
  "council.jsonl: would remove 3 seeded autonomous-cycle row(s)"
expect_eq "--upgrade --check leaves the ledger untouched" "1" \
  "$(cmp -s "$T/ledger.before" "$LEDG" && echo 1 || echo 0)"
bash "$SRC/install.sh" "$TGT" --upgrade --telemetry off > "$T/council-up.out" 2>&1
cat "$T/council-up.out" | expect "--upgrade reports the removed rows" \
  "council.jsonl: removed 3 seeded autonomous-cycle row(s)"
expect_eq "--upgrade keeps every other row byte for byte" "1" \
  "$(printf '%s\n%s\n' "$KEEP1" "$KEEP2" | cmp -s - "$LEDG" && echo 1 || echo 0)"
bash "$SRC/install.sh" "$TGT" --upgrade --telemetry off > "$T/council-up2.out" 2>&1
cat "$T/council-up2.out" | expect_absent "a ledger with no seeded rows: nothing said" "council.jsonl:"
expect_eq "a ledger with no seeded rows: untouched" "1" \
  "$(printf '%s\n%s\n' "$KEEP1" "$KEEP2" | cmp -s - "$LEDG" && echo 1 || echo 0)"
seed_ledger; cp "$LEDG" "$T/ledger.before"; mkdir -p "$TGT/docs/specs/autonomous-cycle"
bash "$SRC/install.sh" "$TGT" --upgrade --telemetry off > "$T/council-own.out" 2>&1
cat "$T/council-own.out" | expect_absent "a hive with its own autonomous-cycle spec: nothing said" "council.jsonl:"
expect_eq "a hive with its own autonomous-cycle spec: ledger untouched" "1" \
  "$(cmp -s "$T/ledger.before" "$LEDG" && echo 1 || echo 0)"
rmdir "$TGT/docs/specs/autonomous-cycle"

# --- install.sh: --constitution replace (ADR-013 D7) ------------------------------------------
# The release's constitution goes in whole; the hive's Profile and Commands bodies are carried
# over verbatim between the markers; the old file is kept as <name>.pre-<major.minor>.md. A
# plain --upgrade never writes it and prints the size and the command. Comparisons drop CR:
# a Windows checkout of the release is CRLF, and the carried lines take its line ending.
echo "--- install.sh: --constitution replace"
BAKNAME="pre-$(tr -d '[:space:]' < "$SRC/VERSION" | cut -d. -f1-2)"
outside() { # the file minus both block bodies (markers kept)
  awk '/VULYK:PROFILE:END|VULYK:COMMANDS:END/ { f = 0 } !f { print } /VULYK:PROFILE:START|VULYK:COMMANDS:START/ { f = 1 }' "$1" | tr -d '\r'
}
block() { awk -v m="$2" 'index($0, m ":END") { f = 0 } f { print } index($0, m ":START") { f = 1 }' "$1" | tr -d '\r'; }
treesum() { (cd "$1" && find . -type f -exec md5sum {} + | LC_ALL=C sort | md5sum); }
same() { cmp -s "$1" "$2" && echo 1 || echo 0; }

CR="$T/hive-replace"; mkdir -p "$CR"
bash "$SRC/install.sh" "$CR" --telemetry on > /dev/null 2>&1
sed -i 's/| Stack | `<fill in>` |/| Stack | `filled-stack` |/; s/| Lint | `<fill in>` |/| Lint | `npm run lint -- --quiet` |/' "$CR/CLAUDE.md"
printf 'An owner line outside the blocks\n' >> "$CR/CLAUDE.md"
cp "$CR/CLAUDE.md" "$T/cr.before"
block "$CR/CLAUDE.md" VULYK:PROFILE > "$T/cr.profile"
block "$CR/CLAUDE.md" VULYK:COMMANDS > "$T/cr.commands"

bash "$SRC/install.sh" "$CR" --upgrade > "$T/cr-plain.out" 2>&1
expect_eq "plain --upgrade never writes the constitution" "1" "$(same "$T/cr.before" "$CR/CLAUDE.md")"
cat "$T/cr-plain.out" | expect "plain --upgrade prints the sizes" "constitution differs from yours: CLAUDE.md is "
cat "$T/cr-plain.out" | expect "plain --upgrade prints the migrate command" "install.sh\" \"$CR\" --upgrade --constitution replace"
cat "$T/cr-plain.out" | expect "plain --upgrade names the backup" "the old file as CLAUDE.$BAKNAME.md"

S0="$(treesum "$CR")"
bash "$SRC/install.sh" "$CR" --upgrade --check --constitution replace > "$T/cr-check.out" 2>&1
cat "$T/cr-check.out" | expect "--check names the backup" "would back up  CLAUDE.md -> CLAUDE.$BAKNAME.md"
cat "$T/cr-check.out" | expect "--check names the replace" "would replace  CLAUDE.md with the"
expect_eq "--check --constitution replace writes nothing" "$S0" "$(treesum "$CR")"

RC=0; bash "$SRC/install.sh" "$CR" --upgrade --constitution replace > "$T/cr-real.out" 2>&1 || RC=$?
expect_eq "--constitution replace exits 0" "0" "$RC"
cat "$T/cr-real.out" | expect "it reports the backup" "back up        CLAUDE.md -> CLAUDE.$BAKNAME.md"
expect_eq "the backup is the old file byte for byte" "1" "$(same "$T/cr.before" "$CR/CLAUDE.$BAKNAME.md")"
expect_eq "the Profile body is carried over verbatim" "$(cat "$T/cr.profile")" "$(block "$CR/CLAUDE.md" VULYK:PROFILE)"
expect_eq "the Commands body is carried over verbatim" "$(cat "$T/cr.commands")" "$(block "$CR/CLAUDE.md" VULYK:COMMANDS)"
expect_eq "everything outside the blocks is the release's text" "$(outside "$SRC/CLAUDE.md")" "$(outside "$CR/CLAUDE.md")"
expect_eq "the Telemetry row keeps its answer" "on" "$(rowval "$CR/CLAUDE.md")"
expect_eq "an owner line outside the blocks survives in the backup only" "0 1" \
  "$(grep -c 'An owner line outside' "$CR/CLAUDE.md") $(grep -c 'An owner line outside' "$CR/CLAUDE.$BAKNAME.md")"
expect_eq "VULYK's own Commands rows never land in a hive" "0" "$(grep -c 'Anomaly telemetry contract tests' "$CR/CLAUDE.md")"
cat "$T/cr-real.out" | expect_absent "a Profile with every release row gets no missing-rows note" "rows yours lacks"

bash "$SRC/install.sh" "$CR" --upgrade --constitution replace > "$T/cr-again.out" 2>&1
cat "$T/cr-again.out" | expect "a second replace has nothing to do" "is already the"
expect_eq "and writes no second backup" "1" "$(ls "$CR"/CLAUDE.pre-*.md | grep -c .)"
bash "$SRC/install.sh" "$CR" --upgrade > "$T/cr-after.out" 2>&1
cat "$T/cr-after.out" | expect_absent "a migrated hive gets no migrate hint" "--constitution replace"

# the sidecar: CLAUDE.vulyk.md is replaced, the foreign CLAUDE.md that imports it is not opened
SC="$T/hive-sidecar-replace"; mkdir -p "$SC"
printf '# My project rules\n\n@CLAUDE.vulyk.md\n' > "$SC/CLAUDE.md"
bash "$SRC/install.sh" "$SC" --telemetry off > /dev/null 2>&1
sed -i 's/| Stack | `<fill in>` |/| Stack | `sidecar-stack` |/; /^| Browser MCP |/d' "$SC/CLAUDE.vulyk.md"
printf 'An owner line in the sidecar\n' >> "$SC/CLAUDE.vulyk.md"
cp "$SC/CLAUDE.md" "$T/sc.foreign"; cp "$SC/CLAUDE.vulyk.md" "$T/sc.before"
bash "$SRC/install.sh" "$SC" --upgrade --constitution replace > "$T/sc.out" 2>&1
cat "$T/sc.out" | expect "the sidecar is backed up under its own name" "back up        CLAUDE.vulyk.md -> CLAUDE.vulyk.$BAKNAME.md"
expect_eq "the foreign CLAUDE.md is byte-identical" "1" "$(same "$T/sc.foreign" "$SC/CLAUDE.md")"
expect_eq "the sidecar backup is the old sidecar" "1" "$(same "$T/sc.before" "$SC/CLAUDE.vulyk.$BAKNAME.md")"
expect_eq "the sidecar's Profile is carried over" "1" "$(grep -c 'sidecar-stack' "$SC/CLAUDE.vulyk.md")"
expect_eq "the sidecar's outside text is the release's" "$(outside "$SRC/CLAUDE.md")" "$(outside "$SC/CLAUDE.vulyk.md")"
expect_eq "the sidecar's Telemetry row keeps its answer" "off" "$(rowval "$SC/CLAUDE.vulyk.md")"
cat "$T/sc.out" | expect "a release Profile row the hive lacks is named, not dropped silently" "this release's Profile has rows yours lacks: Browser MCP."

# refused, before anything is written, when the markers are gone
NMR="$T/hive-replace-nomarkers"; mkdir -p "$NMR"
bash "$SRC/install.sh" "$NMR" --telemetry off > /dev/null 2>&1
sed -i '/VULYK:COMMANDS:START/d; /VULYK:COMMANDS:END/d' "$NMR/CLAUDE.md"
S1="$(treesum "$NMR")"
RC=0; bash "$SRC/install.sh" "$NMR" --upgrade --constitution replace > "$T/nmr.out" 2>&1 || RC=$?
expect_eq "a constitution without markers: replace exits 1" "1" "$RC"
cat "$T/nmr.out" | expect "and says why, naming the manual merge" "--constitution replace refused: CLAUDE.md lacks the VULYK:PROFILE and VULYK:COMMANDS"
expect_eq "and writes nothing at all" "$S1" "$(treesum "$NMR")"
cat "$T/nmr.out" | expect_absent "not even a framework file" "update         "
RC=0; bash "$SRC/install.sh" "$NMR" --constitution replace > "$T/nmr2.out" 2>&1 || RC=$?
expect_eq "--constitution replace without --upgrade is an error" "1" "$RC"
EMPTYH="$T/hive-replace-empty"; mkdir -p "$EMPTYH"
RC=0; bash "$SRC/install.sh" "$EMPTYH" --upgrade --constitution replace > "$T/empty.out" 2>&1 || RC=$?
expect_eq "no constitution to replace is an error" "1" "$RC"
expect_eq "and leaves the directory empty" "" "$(ls -A "$EMPTYH")"

# --- install.sh: retired framework files and the hooks wired to them (ADR-013 D7) -------------
# A release clone with history: v9.8.0 ships council-sonnet.md and session-end-learnings.sh, the
# working tree (9.9.0) does not. An unedited retired file is removed and its hook unwired; one
# the owner edited is kept, and its hook stays wired; a retired file no tag can vouch for is
# removed as ADR-005 D2 always did.
echo "--- install.sh: retired framework files"
REL="$T/release"; mkdir -p "$REL"
tar -C "$SRC" --exclude=./.git --exclude=./.claude/worktrees -cf - . | tar -C "$REL" -xf -
git -C "$REL" init -q -b main . && git -C "$REL" config user.email t@t &&
  git -C "$REL" config user.name "Test Owner" && git -C "$REL" config core.autocrlf false
printf '9.8.0\n' > "$REL/VERSION"
printf -- '---\nname: council-sonnet\n---\nold seat\n' > "$REL/.claude/agents/council-sonnet.md"
printf '#!/usr/bin/env bash\nexit 0\n' > "$REL/.claude/hooks/session-end-learnings.sh"
git -C "$REL" add -A >/dev/null 2>&1 && git -C "$REL" commit -qm v9.8.0 >/dev/null 2>&1 && git -C "$REL" tag v9.8.0
RH="$T/hive-retire"; mkdir -p "$RH"
bash "$REL/install.sh" "$RH" --telemetry off > /dev/null 2>&1
expect_eq "the old release shipped both files" "2" \
  "$(grep -cxE '\.claude/agents/council-sonnet\.md|\.claude/hooks/session-end-learnings\.sh' "$RH/.claude/vulyk-manifest")"
jq '.hooks.SessionEnd[0].hooks += [{"type":"command","command":"$CLAUDE_PROJECT_DIR/.claude/hooks/session-end-learnings.sh"}]' \
  "$RH/.claude/settings.json" > "$T/rh.json" && mv "$T/rh.json" "$RH/.claude/settings.json"
printf 'my own tweak\n' >> "$RH/.claude/agents/council-sonnet.md"
echo dummy > "$RH/.claude/agents/retired-smoke.md"
echo ".claude/agents/retired-smoke.md" >> "$RH/.claude/vulyk-manifest"
LC_ALL=C sort -u -o "$RH/.claude/vulyk-manifest" "$RH/.claude/vulyk-manifest"
rm -f "$REL/.claude/agents/council-sonnet.md" "$REL/.claude/hooks/session-end-learnings.sh"
printf '9.9.0\n' > "$REL/VERSION"

S2="$(treesum "$RH")"
bash "$REL/install.sh" "$RH" --upgrade --check > "$T/rh-check.out" 2>&1
cat "$T/rh-check.out" | expect "--check: the unedited retired hook would go" "would remove   .claude/hooks/session-end-learnings.sh"
cat "$T/rh-check.out" | expect "--check: its wiring would go with it" "would unwire   .claude/settings.json -> SessionEnd: session-end-learnings.sh"
cat "$T/rh-check.out" | expect "--check: the edited retired agent is kept" "keep (edited)  .claude/agents/council-sonnet.md"
expect_eq "--check writes nothing" "$S2" "$(treesum "$RH")"

bash "$REL/install.sh" "$RH" --upgrade > "$T/rh.out" 2>&1
cat "$T/rh.out" | expect "an unedited retired file is removed" "remove         .claude/hooks/session-end-learnings.sh"
expect_eq "and is gone" "0" "$([ -e "$RH/.claude/hooks/session-end-learnings.sh" ] && echo 1 || echo 0)"
expect_eq "and unwired" "0" "$(grep -c 'session-end-learnings' "$RH/.claude/settings.json")"
cat "$T/rh.out" | expect "an edited retired file is kept, with a note" "keep (edited)  .claude/agents/council-sonnet.md - retired in 9.9.0, but edited since v9.8.0"
expect_eq "and is still there" "1" "$([ -e "$RH/.claude/agents/council-sonnet.md" ] && echo 1 || echo 0)"
cat "$T/rh.out" | expect "a retired file no tag vouches for is removed (ADR-005 D2)" "remove         .claude/agents/retired-smoke.md"
expect_eq "the new manifest lists none of the three" "0" \
  "$(grep -cE 'council-sonnet|session-end-learnings|retired-smoke' "$RH/.claude/vulyk-manifest")"

# an edited learnings hook stays, and so does its wiring
RH2="$T/hive-retire-edited"; mkdir -p "$RH2"
printf '9.8.0\n' > "$REL/VERSION"
git -C "$REL" checkout -q v9.8.0 -- .claude/agents/council-sonnet.md .claude/hooks/session-end-learnings.sh
bash "$REL/install.sh" "$RH2" --telemetry off > /dev/null 2>&1
jq '.hooks.SessionEnd[0].hooks += [{"type":"command","command":"$CLAUDE_PROJECT_DIR/.claude/hooks/session-end-learnings.sh"}]' \
  "$RH2/.claude/settings.json" > "$T/rh2.json" && mv "$T/rh2.json" "$RH2/.claude/settings.json"
printf '# my distiller\n' >> "$RH2/.claude/hooks/session-end-learnings.sh"
rm -f "$REL/.claude/agents/council-sonnet.md" "$REL/.claude/hooks/session-end-learnings.sh"
printf '9.9.0\n' > "$REL/VERSION"
bash "$REL/install.sh" "$RH2" --upgrade > "$T/rh2.out" 2>&1
cat "$T/rh2.out" | expect "an edited learnings hook is kept" "keep (edited)  .claude/hooks/session-end-learnings.sh"
expect_eq "and stays wired" "1" "$(grep -c 'session-end-learnings' "$RH2/.claude/settings.json")"
cat "$T/rh2.out" | expect "the unedited retired agent beside it goes" "remove         .claude/agents/council-sonnet.md"

# --- install.sh: the defect library - wiring and shipping (0.19, contract §5) ------------------
# wire_hook takes a matcher and an argument; "already wired" is event + script + argument. The
# hooks' own scripts are package B's - none of this depends on what they contain.
echo "--- install.sh: defect library wiring and shipping"
PRE_M='Edit|Write|MultiEdit|NotebookEdit|Bash'
defect_wiring() { # defect_wiring <settings.json> - "<intake> <inject under the matcher> <reset on SessionStart>"
  printf '%s %s %s' \
    "$(jq -r '[.hooks.UserPromptSubmit[]?.hooks[].command | select(test("defect-intake\\.sh\"?$"))] | length' "$1" | tr -d '\r')" \
    "$(jq -r --arg m "$PRE_M" '[.hooks.PreToolUse[]? | select(.matcher == $m) | .hooks[].command | select(test("defects-inject\\.sh\"?$"))] | length' "$1" | tr -d '\r')" \
    "$(jq -r '[.hooks.SessionStart[]?.hooks[].command | select(test("defects-inject\\.sh\"? reset$"))] | length' "$1" | tr -d '\r')"
}
expect_eq "VULYK's own settings.json carries the three wirings once each" "1 1 1" "$(defect_wiring "$SRC/.claude/settings.json")"
expect_eq "a fresh hive gets them with the settings.json it is given" "1 1 1" "$(defect_wiring "$TGT/.claude/settings.json")"
cat "$T/ownset.out" | expect "an owner's settings.json: intake wired" \
  "wire           .claude/settings.json -> UserPromptSubmit: defect-intake.sh"
cat "$T/ownset.out" | expect "an owner's settings.json: inject wired under its matcher" \
  "wire           .claude/settings.json -> PreToolUse [$PRE_M]: defects-inject.sh"
cat "$T/ownset.out" | expect "an owner's settings.json: reset wired on SessionStart" \
  "wire           .claude/settings.json -> SessionStart: defects-inject.sh reset"
expect_eq "... and all three land in the owner's file" "1 1 1" "$(defect_wiring "$OWNSET/.claude/settings.json")"

# A hive whose owner arranged things: a quoted launcher with a redirect on a startup-only group,
# the inject script already on SessionStart WITHOUT the argument, intake already wired, and an
# own Bash guard on PreToolUse.
DW="$T/hive-defect-wire"; mkdir -p "$DW"
bash "$SRC/install.sh" "$DW" --telemetry off > /dev/null 2>&1
cat > "$DW/.claude/settings.json" <<'EOF'
{"hooks":{
 "SessionStart":[{"matcher":"startup","hooks":[{"type":"command","command":"\"$CLAUDE_PROJECT_DIR/.claude/hooks/vulyk-update-check.sh\" 2>/dev/null || true"}]},
                 {"hooks":[{"type":"command","command":"\"$CLAUDE_PROJECT_DIR/.claude/hooks/defects-inject.sh\""}]}],
 "PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"my-guard.sh"}]}],
 "UserPromptSubmit":[{"hooks":[{"type":"command","command":"\"$CLAUDE_PROJECT_DIR/.claude/hooks/defect-intake.sh\""}]}]
}}
EOF
cp "$DW/.claude/settings.json" "$T/dw.before"
bash "$SRC/install.sh" "$DW" --upgrade --check > "$T/dw-check.out" 2>&1
cat "$T/dw-check.out" | expect "--check: the reset would be wired" "would wire     .claude/settings.json -> SessionStart: defects-inject.sh reset"
cat "$T/dw-check.out" | expect "--check: the inject would be wired" "would wire     .claude/settings.json -> PreToolUse [$PRE_M]: defects-inject.sh"
cat "$T/dw-check.out" | expect_absent "--check: intake is already wired" "-> UserPromptSubmit: defect-intake.sh"
expect_eq "--check leaves the file alone" "1" "$(same "$T/dw.before" "$DW/.claude/settings.json")"
bash "$SRC/install.sh" "$DW" --upgrade --telemetry off > "$T/dw.out" 2>&1
DWS="$DW/.claude/settings.json"
expect_eq "the three wirings, each once" "1 1 1" "$(defect_wiring "$DWS")"
expect_eq "the argument-less inject entry the owner had stays, once" "1" \
  "$(jq -r '[.hooks.SessionStart[].hooks[].command | select(test("defects-inject\\.sh\"?$"))] | length' "$DWS" | tr -d '\r')"
expect_eq "a redirect after the script is not an argument: no second update check" "1" \
  "$(jq -r '[.hooks.SessionStart[].hooks[].command | select(test("vulyk-update-check"))] | length' "$DWS" | tr -d '\r')"
expect_eq "the reset copies the siblings' quoting" "1" \
  "$(jq -r '.hooks.SessionStart[].hooks[].command' "$DWS" | tr -d '\r' | grep -cxF '"$CLAUDE_PROJECT_DIR/.claude/hooks/defects-inject.sh" reset')"
expect_eq "nothing joins the owner's startup-only group" "1" \
  "$(jq -r '.hooks.SessionStart[] | select(.matcher == "startup") | .hooks | length' "$DWS" | tr -d '\r')"
expect_eq "the owner's Bash guard group is untouched" '["my-guard.sh"]' \
  "$(jq -c '[.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[].command]' "$DWS" | tr -d '\r')"
DW_BEFORE="$(cat "$DWS")"
bash "$SRC/install.sh" "$DW" --upgrade --telemetry off > "$T/dw2.out" 2>&1
expect_eq "a second upgrade leaves it byte-identical" "1" "$([ "$DW_BEFORE" = "$(cat "$DWS")" ] && echo 1 || echo 0)"
cat "$T/dw2.out" | expect_absent "and wires nothing" "wire           .claude/settings.json"

# --- install.sh: the host's hook wrapper, reproduced exactly (0.19.1) ------------------------
# 0.19.0 copied a Varto-style `bash -c '"...x.sh"'` prefix and dropped the closing quote: every
# new hook died with "unexpected EOF" and exit 2, which on PreToolUse blocks every tool. Each
# form below is how a real host wires VULYK; the new entries must take the same form AND run.
echo "--- install.sh: hook wrapper forms (plain, bash -c, node launcher, mixed)"
WRAPBIN="$T/Git Bin"; mkdir -p "$WRAPBIN"                     # a launcher path with a space in it
printf '#!/usr/bin/env bash\nexec bash "$@"\n' > "$WRAPBIN/bash-wrap"; chmod +x "$WRAPBIN/bash-wrap"
STUBBIN="$T/stub-bin"; mkdir -p "$STUBBIN"                    # fibi's node launcher, as bash
printf '#!/usr/bin/env bash\nshift; h="$1"; shift\nexec bash "$CLAUDE_PROJECT_DIR/.claude/hooks/$h" "$@"\n' > "$STUBBIN/node"
chmod +x "$STUBBIN/node"
STUB="$T/stub-project"; mkdir -p "$STUB/.claude/hooks"         # stub hooks: log how they were called
for h in defect-intake.sh defects-inject.sh; do
  printf '#!/usr/bin/env bash\nprintf "%%s %%s\\n" "${0##*/}" "$*" >> "$STUBLOG"\nexit 0\n' > "$STUB/.claude/hooks/$h"
  chmod +x "$STUB/.claude/hooks/$h"
done
STUBLOG="$T/stub.log"
W='"'"$WRAPBIN/bash-wrap"'"'
P='$CLAUDE_PROJECT_DIR/.claude/hooks/'
wrapper_case() { # wrapper_case <name> <cmd-of vulyk-update-check.sh> <cmd-of anomaly-scan.sh> <intake> <inject> <reset>
  local name="$1" upd="$2" scan="$3" want_in="$4" want_inj="$5" want_rs="$6" d="$T/hive-wrap-$1" s got c
  mkdir -p "$d"
  bash "$SRC/install.sh" "$d" --telemetry off > /dev/null 2>&1
  s="$d/.claude/settings.json"
  jq -n --arg upd "$upd" --arg scan "$scan" --arg tmb "${upd/vulyk-update-check.sh/top-model-brief.sh}" \
    '{hooks:{SessionStart:[{hooks:[{type:"command",command:$upd},{type:"command",command:$tmb}]}],
             SessionEnd:[{hooks:[{type:"command",command:$scan}]}]}}' > "$s"
  bash "$SRC/install.sh" "$d" --upgrade --telemetry off > "$T/wrap-$name.out" 2>&1
  got="$(jq -r '[.hooks.UserPromptSubmit[]?.hooks[].command | select(test("defect-intake"))] | join("|")' "$s" | tr -d '\r')"
  expect_eq "$name: intake wired in the host's form" "$want_in" "$got"
  got="$(jq -r --arg m "$PRE_M" '[.hooks.PreToolUse[]? | select(.matcher == $m) | .hooks[].command | select(test("defects-inject"))] | join("|")' "$s" | tr -d '\r')"
  expect_eq "$name: inject wired in the host's form" "$want_inj" "$got"
  got="$(jq -r '[.hooks.SessionStart[]?.hooks[].command | select(test("defects-inject"))] | join("|")' "$s" | tr -d '\r')"
  expect_eq "$name: reset wired in the host's form, argument where the host puts it" "$want_rs" "$got"
  : > "$STUBLOG"
  for c in "$want_in" "$want_inj" "$want_rs"; do
    if (export CLAUDE_PROJECT_DIR="$STUB" STUBLOG PATH="$STUBBIN:$PATH"; bash -c "$c" < /dev/null) > "$T/wrap-run.out" 2>&1; then
      ok "$name: runs through bash -c: $c"
    else bad "$name: exit $? from bash -c: $c"; sed 's/^/        /' "$T/wrap-run.out"; fi
  done
  expect_eq "$name: each stub saw the right script and argument" \
    "defect-intake.sh |defects-inject.sh |defects-inject.sh reset" "$(tr -d '\r' < "$STUBLOG" | paste -sd'|' -)"
  got="$(cat "$s")"
  bash "$SRC/install.sh" "$d" --upgrade --telemetry off > "$T/wrap-$name-2.out" 2>&1
  expect_eq "$name: a second upgrade leaves settings.json byte-identical" "1" "$([ "$got" = "$(cat "$s")" ] && echo 1 || echo 0)"
  cat "$T/wrap-$name-2.out" | expect_absent "$name: and wires nothing" "wire           .claude/settings.json"
}
wrapper_case plain "${P}vulyk-update-check.sh" "${P}anomaly-scan.sh" \
  "${P}defect-intake.sh" "${P}defects-inject.sh" "${P}defects-inject.sh reset"
wrapper_case bash-c "$W -c '\"${P}vulyk-update-check.sh\"'" "$W -c '\"${P}anomaly-scan.sh\"'" \
  "$W -c '\"${P}defect-intake.sh\"'" "$W -c '\"${P}defects-inject.sh\"'" "$W -c '\"${P}defects-inject.sh\" reset'"
N='node "${CLAUDE_PROJECT_DIR}/scripts/vulyk-hook.mjs"'
wrapper_case node-launcher "$N vulyk-update-check.sh" "$N anomaly-scan.sh" \
  "$N defect-intake.sh" "$N defects-inject.sh" "$N defects-inject.sh reset"
# our-home: the owner's `bash "${CLAUDE_PROJECT_DIR}/..."` beside plain entries an older installer
# added - the owner's wrapper wins.
B='bash "${CLAUDE_PROJECT_DIR}/.claude/hooks/'
wrapper_case mixed "${B}vulyk-update-check.sh\"" "${P}anomaly-scan.sh" \
  "${B}defect-intake.sh\"" "${B}defects-inject.sh\"" "${B}defects-inject.sh\" reset"
# A host 0.19.0 already broke: the three entries lack their closing quote. They count as wired,
# so re-running the update must repair them in place, not skip them or add a second copy.
BC="$T/hive-wrap-bash-c"; BCS="$BC/.claude/settings.json"
cp "$BCS" "$T/bc.good"
sed -i "/defect/s/'\"\(\r\{0,1\}\)\$/\"\1/" "$BCS"   # Windows python writes CRLF
expect_eq "fixture: three defect entries lost their closing quote" "3" \
  "$(jq -r '.hooks[][].hooks[].command | select(test("defect"))' "$BCS" | tr -d '\r' | grep -vc "'\$")"
bash "$SRC/install.sh" "$BC" --upgrade --check > "$T/bc-check.out" 2>&1
expect_eq "--check: three would be repaired" "3" "$(grep -c 'would repair   .claude/settings.json' "$T/bc-check.out")"
bash "$SRC/install.sh" "$BC" --upgrade --telemetry off > "$T/bc.out" 2>&1
cat "$T/bc.out" | expect "the broken reset is repaired" "repair         .claude/settings.json -> SessionStart: defects-inject.sh reset"
expect_eq "settings.json is back to the correct form, byte for byte" "1" "$(same "$T/bc.good" "$BCS")"
bash "$SRC/install.sh" "$BC" --upgrade --telemetry off > "$T/bc2.out" 2>&1
cat "$T/bc2.out" | expect_absent "a run after the repair wires and repairs nothing" "settings.json ->"

# --- install.sh: CRLF host files (core.autocrlf=true) -----------------------------------------
# The manifest read with its CRs never matched a shipped path, so every framework file came out
# "remove" and real retirements were skipped; a CRLF .gitignore grew its block again every run.
echo "--- install.sh: CRLF manifest and .gitignore"
CR="$T/hive-crlf"; mkdir -p "$CR"
bash "$SRC/install.sh" "$CR" --telemetry off > /dev/null 2>&1
printf '#!/usr/bin/env bash\n' > "$CR/.claude/hooks/retired-old.sh"
printf '.claude/hooks/retired-old.sh\n' >> "$CR/.claude/vulyk-manifest"
sed -i 's/$/\r/' "$CR/.claude/vulyk-manifest" "$CR/.gitignore"
expect_eq "fixture: the manifest is CRLF" "1" "$(grep -qc $'\r' "$CR/.claude/vulyk-manifest" && echo 1 || echo 0)"
bash "$SRC/install.sh" "$CR" --upgrade --check > "$T/crlf-check.out" 2>&1
cat "$T/crlf-check.out" | expect "--check: the retired file would go" "would remove   .claude/hooks/retired-old.sh"
expect_eq "--check: nothing still shipped is marked for removal" "1" \
  "$(grep -F 'would remove' "$T/crlf-check.out" | grep -c .)"
bash "$SRC/install.sh" "$CR" --upgrade --telemetry off > "$T/crlf.out" 2>&1
expect_eq "only the retired file is removed" "1" "$(grep -F 'remove         ' "$T/crlf.out" | grep -c .)"
expect_eq "and it is gone, the framework files stay" "0 1" \
  "$([ -e "$CR/.claude/hooks/retired-old.sh" ] && echo 1 || echo 0) $([ -f "$CR/.claude/hooks/defects-inject.sh" ] && echo 1 || echo 0)"
expect_eq "a CRLF .gitignore does not get the runtime block twice" "1" \
  "$(grep -c 'VULYK runtime artifacts' "$CR/.gitignore")"
expect_eq "a fresh hive's .gitattributes pins LF for hooks, drivers and the manifest" "4" \
  "$(tr -d '\r' < "$CR/.gitattributes" | grep -cxE '(\*\.sh|\.claude/hooks/\*\.py|\.claude/workflows/\*\.js|\.claude/vulyk-manifest) text eol=lf')"
cat "$T/crlf.out" | expect_absent "and a second run adds no rule" "gitattributes  added"

# Shipping: only the index skeleton, install semantics; VULYK's own cards and hook state never.
DREL="$T/release-defects"; mkdir -p "$DREL"
tar -C "$SRC" --exclude=./.git --exclude=./.claude/worktrees -cf - . | tar -C "$DREL" -xf -
rm -rf "$DREL/docs/defects" "$DREL/.claude/state"
mkdir -p "$DREL/docs/defects" "$DREL/.claude/state/defects"
printf '# Defect library\n' > "$DREL/docs/defects/README.md"
printf -- '---\nid: clipped-speech\n---\n' > "$DREL/docs/defects/clipped-speech.md"
printf 'k\n' > "$DREL/.claude/state/defects/keys"
DH="$T/hive-defects"; mkdir -p "$DH"
bash "$DREL/install.sh" "$DH" --telemetry off > "$T/dh.out" 2>&1
expect_eq "the defect index skeleton ships" "1" "$(same "$DREL/docs/defects/README.md" "$DH/docs/defects/README.md")"
expect_eq "VULYK's own defect cards never ship" "0" "$([ -e "$DH/docs/defects/clipped-speech.md" ] && echo 1 || echo 0)"
expect_eq "hook state never ships" "0" "$([ -e "$DH/.claude/state" ] && echo 1 || echo 0)"
expect_eq "the manifest lists the index" "1" "$(grep -cxF docs/defects/README.md "$DH/.claude/vulyk-manifest")"
expect_eq "a hive's .gitignore gets .claude/state/" "1" "$(grep -cxF '.claude/state/' "$DH/.gitignore")"
expect_eq "VULYK's own .gitignore has .claude/state/" "1" "$(tr -d '\r' < "$SRC/.gitignore" | grep -cxF '.claude/state/')"
printf '# My index\n- my-card\n' > "$DH/docs/defects/README.md"
printf '# Defect library v2\n' > "$DREL/docs/defects/README.md"
bash "$DREL/install.sh" "$DH" --upgrade --telemetry off > "$T/dh-up.out" 2>&1
expect_eq "--upgrade never overwrites a hive's own index" "# My index" "$(head -1 "$DH/docs/defects/README.md" | tr -d '\r')"
cat "$T/dh-up.out" | expect "and says it kept it" "skip (exists)  docs/defects/README.md"
bash "$DREL/install.sh" "$DH" --check > "$T/dh-check.out" 2>&1
cat "$T/dh-check.out" | expect "--check lists hook state as a runtime skip" "would skip (runtime) .claude/state/defects/keys"

# --- case 17: inbox - distil, then stage the clear (anomaly-telemetry-07) ----------------------
echo "--- inbox"
# The repo side of the weekly promise: a scratch VULYK-repo-shaped checkout with committed
# bundles, distilled into per-(week, code) counts and cleared as a STAGED deletion - never a
# commit. Run through the same PATH shim as publish, so the never-executed list covers it too.
INBOX="$T/vulyk repo"
mkdir -p "$INBOX/scripts" "$INBOX/.claude/agents" \
         "$INBOX/telemetry/inbox/2026-W37" "$INBOX/telemetry/inbox/2026-W38"
cp "$SRC/scripts/telemetry.sh" "$SRC/scripts/lib.sh" "$INBOX/scripts/"
cp "$SRC"/.claude/agents/*.md "$INBOX/.claude/agents/"
printf '# Telemetry inbox\n' > "$INBOX/telemetry/inbox/README.md"
inbox_row() { # inbox_row <code> <week> <hive>
  printf '{"v":1,"code":"%s","value":1,"threshold":0,"vulyk":"0.13.3","tier":3,"model":"opus","agent":"","week":"%s","hive":"%s"}\n' \
    "$1" "$2" "$3"
}
HIVE_A="aaaaaaaaaaaa"; HIVE_B="bbbbbbbbbbbb"
{ inbox_row context_high 2026-W37 "$HIVE_A"; inbox_row stage_long 2026-W37 "$HIVE_A"; } \
  > "$INBOX/telemetry/inbox/2026-W37/$HIVE_A.jsonl"
inbox_row context_high 2026-W37 "$HIVE_B" > "$INBOX/telemetry/inbox/2026-W37/$HIVE_B.jsonl"
inbox_row context_high 2026-W38 "$HIVE_A" > "$INBOX/telemetry/inbox/2026-W38/$HIVE_A.jsonl"
git -C "$INBOX" init -q -b main . && git -C "$INBOX" config user.email t@t &&
  git -C "$INBOX" config user.name "Test Owner" && git -C "$INBOX" config core.autocrlf false
git -C "$INBOX" add -A >/dev/null 2>&1; git -C "$INBOX" commit -qm init >/dev/null
telin() { (cd "$INBOX" && PATH="$SHIM:$PATH" VULYK_HIVE="$INBOX" bash scripts/telemetry.sh "$@"); }
TAB="$(printf '\t')"

# (a) the table: one line per (week, code), rows and distinct hives, sorted by week then code
OUT="$(telin inbox 2>&1)"
printf '%s' "$OUT" | expect "a (week, code) two hives share counts both rows and both hives" \
  "2026-W37${TAB}context_high${TAB}2${TAB}2"
printf '%s' "$OUT" | expect "a single-hive (week, code) counts one hive" \
  "2026-W37${TAB}stage_long${TAB}1${TAB}1"
printf '%s' "$OUT" | expect "the second week gets its own row" \
  "2026-W38${TAB}context_high${TAB}1${TAB}1"
printf '%s' "$OUT" | expect_order "the table is sorted by week then code" \
  "2026-W37${TAB}context_high" "2026-W37${TAB}stage_long" "2026-W38${TAB}context_high"
expect_eq "the table is exactly three lines" "3" "$(printf '%s\n' "$OUT" | grep -c .)"
expect_eq "a plain inbox deletes nothing" "" "$(git -C "$INBOX" status --porcelain)"

# (b) --clear stages the deletions and stops there: no commit, README untouched
HEAD_BEFORE="$(git -C "$INBOX" rev-parse HEAD)"
telin inbox --clear | expect "--clear still prints the table first" "2026-W38${TAB}context_high"
expect_eq "--clear stages exactly the three bundles as deletions" \
  "D  telemetry/inbox/2026-W37/$HIVE_A.jsonl
D  telemetry/inbox/2026-W37/$HIVE_B.jsonl
D  telemetry/inbox/2026-W38/$HIVE_A.jsonl" \
  "$(git -C "$INBOX" status --porcelain | LC_ALL=C sort)"
expect_eq "the inbox README survives the clear" "yes" \
  "$([ -f "$INBOX/telemetry/inbox/README.md" ] && echo yes || echo no)"
expect_eq "--clear never commits - HEAD is unchanged" "$HEAD_BEFORE" \
  "$(git -C "$INBOX" rev-parse HEAD)"

# (c) a root with no telemetry/inbox/ (every hive): a notice, exit 0
NOINBOX="$T/hive-no-inbox"; mkdir -p "$NOINBOX/scripts" "$NOINBOX/.claude/agents"
cp "$SRC/scripts/telemetry.sh" "$SRC/scripts/lib.sh" "$NOINBOX/scripts/"
OUT="$( (cd "$NOINBOX" && VULYK_HIVE="$NOINBOX" bash scripts/telemetry.sh inbox 2>&1); echo "rc=$?" )"
printf '%s' "$OUT" | expect "no inbox names the root and calls it nothing to distil" \
  "telemetry: no inbox at $NOINBOX - nothing to distil"
printf '%s' "$OUT" | expect "no inbox is not an error" "rc=0"

# (d) an invalid row: check's lines, exit 1, and nothing deleted
git -C "$INBOX" reset -q --hard HEAD
printf 'not json at all\n' > "$INBOX/telemetry/inbox/2026-W37/$HIVE_B.jsonl"
ERR="$(telin inbox --clear 2>&1 >/dev/null)"; RC=$?
printf '%s' "$ERR" | expect "a bad bundle is named <file>:<line>: <reason>" \
  "$INBOX/telemetry/inbox/2026-W37/$HIVE_B.jsonl:1: not valid JSON"
expect_eq "a bad bundle stops inbox --clear" "1" "$RC"
expect_eq "a failed check deletes nothing" "yes" \
  "$([ -f "$INBOX/telemetry/inbox/2026-W38/$HIVE_A.jsonl" ] && echo yes || echo no)"
expect_eq "a failed check stages nothing" "" \
  "$(git -C "$INBOX" status --porcelain | grep '^D' || true)"
git -C "$INBOX" checkout -q -- telemetry/inbox

# (e) the rule the whole spec rests on, now with inbox's own git calls in the ledger too
cat "$CALLS" | expect "the shim recorded inbox's own git rm" " rm -r -q -- telemetry/inbox/"
cat "$CALLS" | expect_absent "nothing in the script invokes git push"   " push"
cat "$CALLS" | expect_absent "nothing in the script invokes git commit" " commit"
cat "$CALLS" | expect_absent "nothing in the script invokes gh"         "gh "
cat "$CALLS" | expect_absent "nothing in the script invokes a pr"       "pr create"
cat "$CALLS" | expect_absent "nothing in the script invokes git clone"  " clone"
cat "$CALLS" | expect_absent "nothing in the script invokes a fork"     "fork"

# --- case 18: bundle - an empty string field keeps every other field in its own key ------------
# Round-4 opus seat, ask 3: the local row used to be read with a tab IFS, and tab is IFS
# whitespace - an empty `model` collapsed with its neighbour and pushed `agent` off the end.
# Those are exactly the rows `detect_agents` writes: it never passes --model.
echo "--- bundle: empty fields keep their slots"
set_consent "on - anonymized weekly bundle"
: > "$LOG"
localrow() { # localrow <model> <agent> <ref>
  printf '{"v":1,"ts":"%s","code":"agent_empty","value":3,"threshold":0,"vulyk":"0.13.3","tier":2,"model":"%s","agent":"%s","spec":"s","story":"","ref":"%s"}\n' \
    "$NOW" "$1" "$2" "$3" >> "$LOG"
}
localrow ""       "worker-code" "agent:no-model"
localrow "sonnet" ""            "agent:no-agent"
localrow ""       ""            "agent:neither"
localrow "sonnet" "cycle-clerk" "agent:both"

EMPTYB="$T/empty-fields.jsonl"
tel bundle --week "$WEEK" --out "$EMPTYB"
expect_eq "four local rows bundle as four rows" "4" "$(grep -c . "$EMPTYB")"
pair() { jq -r '"\(.model)/\(.agent)"' < "$EMPTYB" | tr -d '\r' | sed -n "$1p"; }
expect_eq "an empty model keeps the agent token" "/worker-code"       "$(pair 1)"
expect_eq "an empty agent keeps the model alias" "sonnet/"            "$(pair 2)"
expect_eq "both empty stay empty"                "/"                  "$(pair 3)"
expect_eq "both set are unchanged"               "sonnet/cycle-clerk" "$(pair 4)"
if tel check "$EMPTYB" >/dev/null 2>&1; then ok "check accepts all four rows"
else bad "check rejected the four rows:"; tel check "$EMPTYB" 2>&1 | sed 's/^/        /'; fi

# One emitter, no second parser: publish's own bundle is byte-identical to `bundle --out`.
HIVEID3="$(jq -r '.hive' < "$EMPTYB" | head -1 | tr -d '\r')"
tel publish --week "$WEEK" --dry-run >/dev/null 2>&1
expect_eq "publish --dry-run emits the same rows as bundle --out" "same" \
  "$(cmp -s "$EMPTYB" "$HIVE/.vulyk/telemetry/$WEEK-$HIVEID3.jsonl" && echo same || echo different)"

# --- case 19: the agent token set is fixed in the script, not read from the hive ---------------
# Round-5 opus seat, ask 3: the set used to be the hive's own .claude/agents/ basenames, so an
# owner-added agent (ADR-005 invites exactly that) became a legal token - free text in the
# bundle - that the VULYK repo's `check` then rejected, aborting every hive's inbox that week.
echo "--- agents: a fixed set, an owner's own agent becomes other"
BAKED_AGENTS="$( (cd "$SRC" && bash scripts/telemetry.sh agents) | tr -d '' )"
FHIVE="$T/hive-frontend"
mkdir -p "$FHIVE/scripts" "$FHIVE/memory/stats" "$FHIVE/.claude/agents"
cp "$SRC/scripts/telemetry.sh" "$SRC/scripts/lib.sh" "$FHIVE/scripts/"
cp "$SRC"/.claude/agents/*.md "$FHIVE/.claude/agents/"
printf 'name: worker-frontend
' > "$FHIVE/.claude/agents/worker-frontend.md"
printf '# Fixture hive

## Profile

| Field | Value |
|---|---|
| Telemetry | on - anonymized weekly bundle |
'   > "$FHIVE/CLAUDE.md"
git -C "$FHIVE" init -q -b main . && git -C "$FHIVE" config user.email t@t &&
  git -C "$FHIVE" config user.name "Test Owner" && git -C "$FHIVE" config core.autocrlf false
git -C "$FHIVE" add -A >/dev/null 2>&1; git -C "$FHIVE" commit -qm init >/dev/null
telf() { (cd "$FHIVE" && VULYK_HIVE="$FHIVE" bash scripts/telemetry.sh "$@"); }
FLOG="$FHIVE/memory/stats/anomalies.jsonl"

NOAG="$T/hive-no-agents-dir"; mkdir -p "$NOAG/scripts" "$NOAG/memory/stats"
cp "$SRC/scripts/telemetry.sh" "$SRC/scripts/lib.sh" "$NOAG/scripts/"

expect_eq "a hive with an extra agent file prints the same list" "$BAKED_AGENTS"   "$(telf agents | tr -d '')"
expect_eq "a hive with no .claude/agents/ at all prints the same list" "$BAKED_AGENTS"   "$( (cd "$NOAG" && VULYK_HIVE="$NOAG" bash scripts/telemetry.sh agents) | tr -d '' )"
telf agents | expect_absent "an owner-added agent is not a token" "worker-frontend"

# record: the owner's own name never reaches the local row; a framework name is kept
telf record agent_prefix_high 60000 50000 --agent worker-frontend --ref agent:f
expect_eq "--agent with an owner-added name records as other" "other"   "$(grep -F '"ref":"agent:f"' "$FLOG" | jq -r '.agent' | tr -d '')"
telf record agent_prefix_high 60000 50000 --agent worker-code --ref agent:w
expect_eq "--agent with a framework name records unchanged" "worker-code"   "$(grep -F '"ref":"agent:w"' "$FLOG" | jq -r '.agent' | tr -d '')"
# a row already in the log under the old behaviour still bundles clean
printf '{"v":1,"ts":"%s","code":"agent_empty","value":3,"threshold":0,"vulyk":"0.13.3","tier":3,"model":"sonnet","agent":"worker-frontend","spec":"","story":"","ref":"agent:hand"}
'   "$NOW" >> "$FLOG"

FB="$T/frontend-bundle.jsonl"
telf bundle --week "$WEEK" --out "$FB"
expect_eq "three local rows bundle as three rows" "3" "$(grep -c . "$FB")"
fagent() { jq -r '.agent' < "$FB" | tr -d '' | sed -n "$1p"; }
expect_eq "an owner-added name recorded as other bundles as other" "other"       "$(fagent 1)"
expect_eq "a framework name bundles unchanged"                     "worker-code" "$(fagent 2)"
expect_eq "a hand-written row with an owner-added name bundles as other" "other" "$(fagent 3)"
if telf check "$FB" >/dev/null 2>&1; then ok "check accepts the bundle from the hive"
else bad "check rejected the bundle from the hive:"; telf check "$FB" 2>&1 | sed 's/^/        /'; fi
if (cd "$SRC" && bash scripts/telemetry.sh check "$FB") >/dev/null 2>&1; then
  ok "check accepts the same bundle from the VULYK repo"
else bad "check rejected the bundle from the VULYK repo:"
  (cd "$SRC" && bash scripts/telemetry.sh check "$FB") 2>&1 | sed 's/^/        /'; fi

BADAGENT="$T/frontend-bad.jsonl"
printf '{"v":1,"code":"agent_prefix_high","value":60000,"threshold":50000,"vulyk":"0.13.3","tier":3,"model":"sonnet","agent":"worker-frontend","week":"%s","hive":"aaaaaaaaaaaa"}
'   "$WEEK" > "$BADAGENT"
ERR="$(telf check "$BADAGENT" 2>&1 >/dev/null)"; RC=$?
printf '%s' "$ERR" | expect "the hive rejects an out-of-set agent by name"   "agent is not in the agent token set"
expect_eq "an out-of-set agent fails check in the hive" "1" "$RC"
ERR="$( (cd "$SRC" && bash scripts/telemetry.sh check "$BADAGENT") 2>&1 >/dev/null )"; RC=$?
printf '%s' "$ERR" | expect "the VULYK repo rejects the same row for the same reason"   "agent is not in the agent token set"
expect_eq "an out-of-set agent fails check in the VULYK repo" "1" "$RC"

# --- case 20: the drift guard - the baked list IS this repo's agent roster ---------------------
# The only place the suite looks at .claude/agents/, and only to prove the list has not drifted.
echo "--- agents: drift guard"
REPO_BASENAMES="$(for f in "$SRC"/.claude/agents/*.md; do basename "$f" .md; done | LC_ALL=C sort)"
# Retired agents stay in the set (a hive on an older release still bundles them) and are the only
# names allowed beyond the roster: council-sonnet since 0.18.0 (ADR-013 D1).
RETIRED="council-sonnet"
expect_eq "the baked agent list minus other and the retired names = this repo's .claude/agents/*.md basenames (added or renamed a framework agent? edit AGENTS in scripts/telemetry.sh)"   "$REPO_BASENAMES" "$(printf '%s
' "$BAKED_AGENTS" | grep -vxF other | grep -vxF "$RETIRED" | LC_ALL=C sort)"
expect_eq "a retired agent has no file in .claude/agents/" "0" "$([ -e "$SRC/.claude/agents/$RETIRED.md" ] && echo 1 || echo 0)"
RETB="$T/retired-agent.jsonl"
printf '{"v":1,"code":"agent_empty","value":3,"threshold":0,"vulyk":"0.17.0","tier":1,"model":"sonnet","agent":"council-sonnet","week":"%s","hive":"aaaaaaaaaaaa"}\n' "$WEEK" > "$RETB"
if (cd "$SRC" && bash scripts/telemetry.sh check "$RETB") >/dev/null 2>&1; then
  ok "check still accepts a 0.17 bundle row naming council-sonnet"
else bad "check rejected a bundle row naming the retired council-sonnet:"
  (cd "$SRC" && bash scripts/telemetry.sh check "$RETB") 2>&1 | sed 's/^/        /'; fi
grep -v '^[[:space:]]*#' "$SRC/scripts/telemetry.sh"   | expect_absent "no code line in telemetry.sh reads .claude/agents" ".claude/agents"

CHECKS="$(grep -c . "$LEDGER" || true)"
FAILED="$(grep -c . "$FAILS" || true)"
[ "$FAILED" -eq 0 ] || fail=1
echo "telemetry.test.sh: $CHECKS checks, $FAILED failed"
exit $fail
