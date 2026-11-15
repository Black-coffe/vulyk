#!/usr/bin/env bash
# VULYK secret redaction - deterministic stdin->stdout filter, no model, no tokens.
#
#   Usage: some-writer | scripts/redact.sh > file
#
# Masks well-known credential shapes before free text a human once typed or pasted
# is written to disk: /vulyk-plan's brief.md (committed to git), handoff.py
# (.claude/handoff/ - gitignored, but re-injected into future sessions and routinely
# shared), and the free-text notes cycle.sh, human-check.sh, ship-check.sh and
# acceptance-log.sh write to the ledgers. The patterns are intentionally loud rather than clever:
# a false positive costs one unreadable line, a false negative costs a rotation.
#
# handoff.py mirrors a minimal subset of these patterns as a built-in fallback for
# environments where bash is missing - if you extend this list, extend that one too.
#
# This is the only VULYK script that transforms instead of reports. When it cannot do
# its work (sed or awk missing, the sed dialect rejects the expressions, a filter in the
# pipe fails) it withholds the text: stdout is the one line [VULYK:REDACT-FAILED], stderr
# says `redact: degraded: <why>`, `telemetry.sh record redact_degraded` runs, exit 1.
# Unmasked text never passes through. Otherwise exit 0.

set -u

MASK='[VULYK:REDACTED]'
FAILED='[VULYK:REDACT-FAILED]'
HERE="$(dirname "$0")"

# Case variants spelled out instead of sed's GNU-only `I` flag - BSD sed must not choke.
KEYWORDS='password|PASSWORD|Password|passwd|PASSWD|secret|SECRET|Secret|[Aa]pi[_-]?[Kk]ey|API[_-]?KEY|apikey|APIKEY|[Aa]ccess[_-]?[Kk]ey|ACCESS[_-]?KEY|[Aa]ccess[_-]?[Tt]oken|ACCESS[_-]?TOKEN|[Rr]efresh[_-]?[Tt]oken|REFRESH[_-]?TOKEN|[Aa]uth[_-]?[Tt]oken|AUTH[_-]?TOKEN|[Cc]lient[_-]?[Ss]ecret|CLIENT[_-]?SECRET|[Pp]rivate[_-]?[Kk]ey|PRIVATE[_-]?KEY|[Cc]redentials?|CREDENTIALS?|[Pp]assphrase|PASSPHRASE|[Cc]ookie|COOKIE'
# A bare token key (TOKEN=, GH_TOKEN:, "token":) must END in token - max_tokens, token_budget and
# tokenizer are counters and settings, and this framework writes them everywhere - and its value must
# look like one: 16+ chars, no spaces. Prose says "token: see below" and "token = `agent`".
TOKEN_KEY='[A-Za-z0-9_-]*(token|TOKEN|Token)'
TOKEN_VALUE="[\"']?[A-Za-z0-9._~+/=-]{16,}[\"']?"
# A short secret name must END the key and stand alone or after '_'/'-': SMTP_PASS, PASS, DB_PWD, db-pwd -
# but not password_reset_count, bypass, compass, a bare PWD (the shell's current folder) or dsn_timeout.
# The char before the key is captured (sed has no lookbehind) and written back.
END_KEY="(^|[^A-Za-z0-9_-])([\"']?(([A-Za-z0-9_-]*[_-])?(PASS|pass|Pass)|[A-Za-z0-9_-]*[_-](PWD|pwd|Pwd))[\"']?[[:space:]]*[=:][[:space:]]*)"
# A one-time code key ENDS the key, alone or after '_'/'-' (OTP, SMS_OTP, TOTP, otp_code) - not footprint or otpauth_url.
OTP_KEY="(^|[^A-Za-z0-9_-])([\"']?([A-Za-z0-9_-]*[_-])?(T?OTP|t?otp|T?Otp|Totp)([_-]?(CODE|code|Code))?[\"']?[[:space:]]*[=:][[:space:]]*)"
# A *_KEY name (ENCRYPTION_KEY, signing-key, appKey, ENCRYPTIONKEY, encryption.key) or a *_AUTH name (TWILIO_AUTH)
# holds a key when its value looks like one: 16+ chars, no spaces, a `base64:` prefix allowed (APP_KEY=base64:...).
# A bare key (key: value) is prose; primary_key=True and sort_key=re.compile(...) are too short to match; glued
# names are upper case only (monkey, turkey stay words).
KEY_KEY="[A-Za-z0-9_.-]*[._-](KEY|key|Key)|[A-Za-z0-9_-]*[a-z0-9]Key|[A-Za-z0-9_-]*[A-Z0-9]KEY|[A-Za-z0-9_.-]*[._-](AUTH|auth|Auth)"
KEY_VALUE="[\"']?(base64:)?[A-Za-z0-9._~+/=-]{16,}[\"']?"
# A DSN key holds a URL; it is masked whole when the URL carries a credential (scheme://key@host).
DSN_KEY="(^|[^A-Za-z0-9_-])([\"']?([A-Za-z0-9_-]*[_-])?(DSN|dsn|Dsn)[\"']?[[:space:]]*[=:][[:space:]]*)"
DSN_VALUE="[\"']?[A-Za-z][A-Za-z0-9+.-]*://[^[:space:]\"'@]+@[^[:space:]\"']*[\"']?"
# The value: a whole quoted string (spaces and all, to its closing quote however short), else one unquoted
# word of 6+ chars that does not open with ':' (so `token::Kind` or `secret::Name` in Rust / C++ stays readable).
VALUE="(\"[^\"]+\"|'[^']+'|[\"']?[^\"'[:space:]:][^\"'[:space:]]{5,}[\"']?)"
# A Russian / Ukrainian keyword (spelled out per case, as above): its unquoted value is ASCII, 6+ chars, so a
# Cyrillic word after it stays prose. A password said in prose (`the password is x`) holds a digit or a symbol.
CYR_KEYWORDS='Секретный ключ|секретный ключ|СЕКРЕТНЫЙ КЛЮЧ|Секретний ключ|секретний ключ|СЕКРЕТНИЙ КЛЮЧ|Пароль|пароль|ПАРОЛЬ|Гасло|гасло|ГАСЛО|Токен|токен|ТОКЕН|Секрет|секрет|СЕКРЕТ'
CYR_VALUE="(\"[^\"]+\"|'[^']+'|[A-Za-z0-9._~+/=!@\$%^&*-]{6,})"
PROSE_KEY='(password|Password|PASSWORD|passphrase|Passphrase|secret|Secret|token|Token)[[:space:]]+(is|was)[[:space:]]+'
# Its unquoted value is 6+ chars (one alternative per place of the digit or symbol), so a length or a count
# stays prose: `the password is 8 chars`.
PS="[^\"'[:space:]]"; PD='[0-9!@$%^&*]'
PROSE_VALUE="(\"[^\"]+\"|'[^']+'|$PS{5,}$PD$PS*|$PS{4}$PD$PS+|$PS{3}$PD$PS{2,}|$PS{2}$PD$PS{3,}|$PS$PD$PS{4,}|$PD$PS{5,})"
# A command-line credential: an argument value that is not another flag.
ARG_VALUE="(\"[^\"]+\"|'[^']+'|[^\"'[:space:]-][^\"'[:space:]]*)"
# The arguments between a command and its -p: words and flags, none of them a -p - so the command's own -p
# is the one masked, never a later command's on the same line (ssh -p 22, docker run -p 8080:80).
ARG_TOK='[^[:space:];&|]'
NOT_P="([[:space:]]+([^-[:space:];&|]$ARG_TOK*|-[^p[:space:];&|]$ARG_TOK*))*"
# sshpass takes only its own flags before -p (-f, -d and -P carry one argument); a word there is the command.
SSHPASS_OPTS="([[:space:]]+(-[fdP][[:space:]]+$ARG_TOK+|-[^p[:space:];&|]$ARG_TOK*))*"

SED_ARGS=( -E
  -e "s|AKIA[0-9A-Z]{16}|$MASK|g"
  -e "s|ASIA[0-9A-Z]{16}|$MASK|g"
  -e "s|gh[pousr]_[A-Za-z0-9]{20,}|$MASK|g"
  -e "s|github_pat_[A-Za-z0-9_]{22,}|$MASK|g"
  -e "s|xox[baprs]-[A-Za-z0-9-]{10,}|$MASK|g"
  -e "s|sk-[A-Za-z0-9_-]{20,}|$MASK|g"
  -e "s|AIza[0-9A-Za-z_-]{35}|$MASK|g"
  -e "s|[0-9]{8,10}:AA[A-Za-z0-9_-]{33}|$MASK|g"
  -e "s|glpat-[A-Za-z0-9_-]{20,}|$MASK|g"
  -e "s|npm_[A-Za-z0-9]{36}|$MASK|g"
  -e "s|pypi-[A-Za-z0-9_-]{50,}|$MASK|g"
  -e "s|hf_[A-Za-z0-9]{30,}|$MASK|g"
  -e "s|gsk_[A-Za-z0-9]{40,}|$MASK|g"
  -e "s|SG\.[A-Za-z0-9_-]{16,}\.[A-Za-z0-9_-]{16,}|$MASK|g"
  -e "s#[rs]k_(live|test)_[A-Za-z0-9]{20,}#$MASK#g"
  -e "s|hooks\.slack\.com/services/[A-Za-z0-9/_-]{20,}|hooks.slack.com/services/$MASK|g"
  -e "s|xapp-[A-Za-z0-9-]{10,}|$MASK|g"
  -e "s|whsec_[A-Za-z0-9]{20,}|$MASK|g"
  -e "s|GOCSPX-[A-Za-z0-9_-]{20,}|$MASK|g"
  -e "s#(^|[^A-Za-z0-9/:.])1//0[A-Za-z0-9_-]{20,}#\1$MASK#g"
  -e "s|ya29\.[A-Za-z0-9._-]{20,}|$MASK|g"
  -e "s#shp(at|ca|pa|ss)_[A-Za-z0-9]{20,}#$MASK#g"
  -e "s|AGE-SECRET-KEY-1[0-9A-Z]{20,}|$MASK|g"
  -e "s|do[por]_v1_[A-Za-z0-9]{20,}|$MASK|g"
  -e "s#(discord(app)?\.com/api/webhooks/)[0-9]{5,}/[A-Za-z0-9_-]{20,}#\1$MASK#g"
  -e "s|([?&]code=)[^&#[:space:]\"']{10,}|\1$MASK|g"
  -e "s#(ssh-(rsa|ed25519|dss)|ecdsa-sha2-nistp[0-9]+)[[:space:]]+AAAA[A-Za-z0-9+/]{16,}=*#\1 $MASK#g"
  -e "s|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{5,}|$MASK|g"
  -e "s|[Bb]earer[[:space:]]+[A-Za-z0-9._~+/-]{16,}=*|Bearer $MASK|g"
  -e "s#([Aa]uthorization|AUTHORIZATION)([\"']?[[:space:]]*[:=][[:space:]]*[\"']?)([Bb]asic|BASIC|[Tt]oken|TOKEN)[[:space:]]+[A-Za-z0-9._~+/-]{8,}=*#\1\2\3 $MASK#g"
  # A URL password may hold a raw '/'; a port before a path (host:443/@scope) is all digits, so it is not one.
  # The user may be empty (redis://:pw@host); a password with no '/' may hold ':' and '@' (to the last '@').
  -e "s#(://)[^/[:space:]:@]*:([^/[:space:]]+|[^/[:space:]@]*[^0-9/[:space:]@][^[:space:]@]*|[^/[:space:]@]+)@#\1$MASK@#g"
  # A Cookie / Set-Cookie header that carries a name=value pair loses its whole value, to the end of the line.
  -e "s#(^|[^A-Za-z0-9_-])(([Ss]et-)?[Cc]ookie|SET-COOKIE|COOKIE)([[:space:]]*:[[:space:]]*)[^[:space:]=;:]+(=[^[:space:]]|;[^=]*=[^[:space:]]).*#\1\2\4$MASK#g"
  -e "s#([\"']?[A-Za-z0-9_-]*($KEYWORDS)[A-Za-z0-9_-]*[\"']?[[:space:]]*[=:][[:space:]]*)$VALUE#\1$MASK#g"
  -e "s#$END_KEY$VALUE#\1\2$MASK#g"
  -e "s#$DSN_KEY$DSN_VALUE#\1\2$MASK#g"
  -e "s#$OTP_KEY$VALUE#\1\2$MASK#g"
  -e "s#([\"']?($KEY_KEY)[\"']?[[:space:]]*[=:][[:space:]]*)$KEY_VALUE#\1$MASK#g"
  -e "s#([\"']?${TOKEN_KEY}[\"']?[[:space:]]*[=:][[:space:]]*)$TOKEN_VALUE#\1$MASK#g"
  -e "s#(($CYR_KEYWORDS)[[:space:]]*[=:][[:space:]]*)$CYR_VALUE#\1$MASK#g"
  -e "s#($PROSE_KEY)$PROSE_VALUE#\1$MASK#g"
  # A bare key or auth name (key=, AUTH=) with a key-shaped value; a lower-case pwd (PWD is the shell's folder).
  -e "s#(^|[^A-Za-z0-9_.-])([\"']?(AUTH|auth|Auth|KEY|key|Key)[\"']?[[:space:]]*[=:][[:space:]]*)$KEY_VALUE#\1\2$MASK#g"
  -e "s#(^|[^A-Za-z0-9_-])([\"']?(pwd|Pwd)[\"']?[[:space:]]*[=:][[:space:]]*)$VALUE#\1\2$MASK#g"
  # Credentials in command arguments: curl / lftp -u user:pw (an all-digit uid:gid is not one, and docker -u
  # name:group is a user and a group), a glued mysql -p<pw>, sshpass / docker login -p <pw>, --password <pw>.
  -e "s#(^|[^A-Za-z0-9_.-])((curl|lftp)[^;&|]*[[:space:]](-u|--user)[[:space:]]+[\"']?[^\"'[:space:]:]+:)[^\"'[:space:]]*[^0-9\"'[:space:]][^\"'[:space:]]*#\1\2$MASK#g"
  -e "s#((mysql|mariadb)[a-z]*${NOT_P}[[:space:]]+-p)(\"[^\"]+\"|'[^']+'|[^\"'[:space:]]+)#\1$MASK#g"
  -e "s#((docker|podman)[[:space:]]+login${NOT_P}[[:space:]]+-p[[:space:]]*)$ARG_VALUE#\1$MASK#g"
  -e "s#(sshpass${SSHPASS_OPTS}[[:space:]]+-p[[:space:]]*)$ARG_VALUE#\1$MASK#g"
  -e "s#(^|[[:space:]])(--password|--passwd)([[:space:]]+|=)$ARG_VALUE#\1\2\3$MASK#g"
)

degrade() { # degrade <why> - withhold the text, say why, record it; the text never passes unmasked
  cat >/dev/null 2>&1 || :
  printf '%s\n' "$FAILED"
  printf 'redact: degraded: %s\n' "$1" >&2
  bash "$HERE/telemetry.sh" record redact_degraded 1 0 >/dev/null 2>&1 || :
  exit 1
}

command -v sed >/dev/null 2>&1 && command -v awk >/dev/null 2>&1 || degrade "sed or awk is missing"
printf '' | sed ${SED_ARGS[@]+"${SED_ARGS[@]}"} >/dev/null 2>&1 || degrade "this sed rejects the expressions"

# Pass 1 (awk): PEM and PGP private key blocks - multi-line, sed can't span lines. A block runs to its
#   END line or, when no END comes (a truncated paste), to the first line that is not key body (base64,
#   an armor header, blank) - so the text after a broken key still reaches the file.
# Pass 2 (sed): single-line token shapes and key=value assignments. Pass 3 (awk): bare cloud secret keys.
# All three write into a buffer (the trailing x keeps final newlines); it reaches stdout only when every stage exits 0.
OUT="$(set -o pipefail; awk -v mask="$MASK" '
  function body(l) {
    sub(/\r$/, "", l)
    return l ~ /^[ \t]*[A-Za-z0-9+\/=]*[ \t]*$/ || l ~ /^(Proc-Type|DEK-Info|Version|Comment|Hash|Charset|MessageID): /
  }
  inkey && /-----END [A-Z0-9 ]*PRIVATE KEY( BLOCK)?-----/ { inkey=0; next }
  inkey && body($0) { next }
  { inkey=0 }
  /-----BEGIN [A-Z0-9 ]*PRIVATE KEY( BLOCK)?-----/ {
    print mask
    if ($0 !~ /-----END [A-Z0-9 ]*PRIVATE KEY( BLOCK)?-----/) inkey=1
    next
  }
  { print }
' | sed ${SED_ARGS[@]+"${SED_ARGS[@]}"} | awk -v mask="$MASK" '
  # Pass 3 (awk): a bare cloud secret key - a run of exactly 40 of [A-Za-z0-9/+] holding an upper-case letter,
  # a lower-case letter and a digit (a git SHA has no upper case, an identifier no digit), that neither starts
  # nor ends with / (an absolute path) and is not followed by .<letter> (a file name), nor glued to = _ . -.
  function key(r) {
    return length(r) == 40 && r ~ /[A-Z]/ && r ~ /[a-z]/ && r ~ /[0-9]/ && r !~ /^\// && r !~ /\/$/
  }
  {
    l = $0; out = ""
    while (match(l, /[A-Za-z0-9\/+]+/)) {
      pre = substr(l, 1, RSTART - 1); run = substr(l, RSTART, RLENGTH); l = substr(l, RSTART + RLENGTH)
      b = substr(pre, length(pre), 1); a = substr(l, 1, 1)
      if (key(run) && b !~ /[=_.-]/ && a !~ /[=_-]/ && !(a == "." && substr(l, 2, 1) ~ /[A-Za-z]/)) run = mask
      out = out pre run
    }
    print out l
  }
' && printf x)" || degrade "the awk | sed | awk filter failed"
printf '%s' "${OUT%x}"
exit 0
