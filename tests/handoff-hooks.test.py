# -*- coding: utf-8 -*-
"""Hook-mode regressions for handoff.py (audit P10 of VULYK 0.46).

Every case builds its own HOME, project and transcript under one temp root, then runs
the real hook through a subprocess - the same way Claude Code does, payload bytes on
stdin - and asserts on what it prints or writes. Run by tests/handoff.test.sh.

    Usage: python3 tests/handoff-hooks.test.py [<handoff.py>]
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

HOOK = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else ".claude/hooks/handoff.py")
# A non-ASCII root on purpose: the owner's home on Windows is often Cyrillic (P10-01).
ROOT = tempfile.mkdtemp(prefix="vulyk-handoff-")
ROOT = os.path.join(ROOT, "Користувач")
os.makedirs(ROOT)
fails = []
count = [0]


def check(name, cond, detail=""):
    count[0] += 1
    print(("  ok    " if cond else "  FAIL  ") + name + ("" if cond else "  -> " + detail))
    if not cond:
        fails.append(name)


def fresh(tag):
    """(home, proj) for one case: empty HOME, a project with .claude/."""
    base = os.path.join(ROOT, tag)
    home, proj = os.path.join(base, "home"), os.path.join(base, "proj")
    os.makedirs(os.path.join(proj, ".claude"))
    os.makedirs(home)
    return home, proj


def env_for(home, proj, extra=None):
    e = dict(os.environ)
    for k in ("CLAUDE_CODE_AUTO_COMPACT_WINDOW", "CLAUDE_CODE_DISABLE_1M_CONTEXT",
              "CLAUDE_CONFIG_DIR", "PYTHONUTF8"):
        e.pop(k, None)
    e.update({"HOME": home, "USERPROFILE": home, "CLAUDE_PROJECT_DIR": proj,
              "PYTHONIOENCODING": "utf-8"})
    e.update(extra or {})
    return e


def write_transcript(path, tokens, prompts=(), reply=""):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    ts = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    rows = [{"type": "user", "message": {"role": "user", "content": p}} for p in prompts]
    rows.append({
        "type": "assistant", "isSidechain": False, "timestamp": ts,
        "message": {"model": "claude-opus-5", "content": [{"type": "text", "text": reply or "done"}],
                    "usage": {"input_tokens": 2, "cache_read_input_tokens": tokens - 2,
                              "cache_creation_input_tokens": 0, "output_tokens": 0}},
    })
    with open(path, "w", encoding="utf-8") as fh:
        for r in rows:
            fh.write(json.dumps(r, ensure_ascii=False) + "\n")
    return path


def run(mode, env, payload=None, args=()):
    stdin = json.dumps(payload, ensure_ascii=False).encode("utf-8") if payload is not None else b""
    r = subprocess.run([sys.executable, HOOK, mode] + list(args), input=stdin,
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env)
    return r.returncode, r.stdout.decode("utf-8", "replace"), r.stderr.decode("utf-8", "replace")


def handoffs(proj):
    d = os.path.join(proj, ".claude", "handoff")
    try:
        return sorted(os.path.join(d, f) for f in os.listdir(d) if f.endswith(".md"))
    except OSError:
        return []


def read(path):
    with open(path, "r", encoding="utf-8") as fh:
        return fh.read()


# --- P10-01: the payload is UTF-8 whatever the locale's code page ------------------------------
print("--- P10-01 stdin is read as UTF-8")
home, proj = fresh("p01")
tp = write_transcript(os.path.join(ROOT, "p01", "Сесія", "s01.jsonl"), 150000)
# cp1251 stands in for a Cyrillic Windows locale on every OS: Python decodes a piped stdin with it.
rc, out, err = run("stop", env_for(home, proj, {"PYTHONIOENCODING": "cp1251"}),
                   {"session_id": "s01", "transcript_path": tp, "cwd": proj})
check("P10-01 a Cyrillic transcript_path under a cp1251 locale still yields the Stop banner",
      rc == 0 and "systemMessage" in out and "150k" in out, "rc=%d out=%r err=%r" % (rc, out[:200], err[:200]))


# --- P10-02: redaction runs through a bash that can open the script, and the built-in pass ---
# covers what scripts/redact.sh covers -------------------------------------------------------
print("--- P10-02 redaction: the right bash, a complete built-in pass")
import importlib.util
spec = importlib.util.spec_from_file_location("handoff_under_test", HOOK)
h = importlib.util.module_from_spec(spec)
spec.loader.exec_module(h)
MASK = "[VULYK:REDACTED]"


def rep(n, c):
    return c * n  # samples are built, never literal tokens


SECRETS = [  # (label, text, the repeated character the secret is made of)
    ("bearer", "curl -H 'Authorization: Bearer " + rep(24, "a") + "' https://x", "a"),
    ("basic-header", "Authorization: Basic " + rep(20, "Q") + "==", "Q"),
    ("url-creds", "git clone https://bob:" + rep(10, "p") + "@example.com/r.git", "p"),
    ("password=", "password=" + rep(10, "s"), "s"),
    ("api_key:", '"api_key": "' + rep(12, "k") + '"', "k"),
    ("github", "gh" + "p_" + rep(36, "g"), "g"),
    ("aws", "AK" + "IA" + rep(16, "B"), "B"),
]
KEEP = ["Basic configuration is fine", "see https://example.com/a:b path", "sk-learn"]
nobash = os.path.join(ROOT, "nobash")  # no scripts/redact.sh: the built-in pass alone
os.makedirs(nobash)
for label, s, c in SECRETS:
    got = h.redact_text(nobash, "note " + s + " end")
    check("P10-02 built-in pass masks %s" % label, MASK in got and rep(8, c) not in got, got)
for s in KEEP:
    check("P10-02 built-in pass leaves %r alone" % s, h.redact_text(nobash, s) == s, h.redact_text(nobash, s))

if os.name == "nt":
    b = getattr(h, "redact_bash", lambda: None)()
    windir = os.path.normcase(os.environ.get("SystemRoot") or r"C:\Windows")
    check("P10-02 Windows: the bash picked is not WSL's launcher under %s" % windir,
          bool(b) and not os.path.normcase(b).startswith(windir), repr(b))
# The hook's own path to redact.sh: a stand-in script that tags each line proves bash ran it.
home, proj = fresh("p02")
os.makedirs(os.path.join(proj, "scripts"))
with open(os.path.join(proj, "scripts", "redact.sh"), "w", encoding="utf-8", newline="\n") as fh:
    fh.write("#!/usr/bin/env bash\nsed 's/^/BASHED /'\n")
got = h.redact_text(proj, "line " + "gh" + "p_" + rep(36, "z"))
check("P10-02 redact.sh at a native path runs, then the built-in pass", got.startswith("BASHED line ")
      and MASK in got and "zzzzzzzz" not in got, repr(got))


# --- P10-02 / P9-04: the built-in pass masks what scripts/redact.sh masks, word for word, with no bash ---
# (review of the audit fixes: the fallback missed rk_test_, accessToken, refresh_token, bare TOKEN keys,
# Authorization: token, PGP blocks, URL passwords with '/', and cut quoted values at the first space)
print("--- P10-02 built-in pass = redact.sh P9-04 table")
b64, val, nl = "dXNlcjpw" + rep(16, "Y") + "==", rep(10, "q") + "42" + rep(8, "Z"), "\n"
PARITY = [  # (label, input, expected) - the same rows as tests/maintenance.test.sh "redact.sh P9-04"
    ("Authorization: Basic", "Authorization: Basic " + b64, "Authorization: Basic " + MASK),
    ("quoted Authorization: token", '-H "Authorization: token ' + val + '"', '-H "Authorization: token ' + MASK + '"'),
    ("camelCase apiKey", 'apiKey = "' + val + '"', "apiKey = " + MASK),
    ("camelCase accessToken", "accessToken: " + val, "accessToken: " + MASK),
    ("refresh_token", "refresh_token=" + val, "refresh_token=" + MASK),
    ("bare TOKEN", "TOKEN=" + val, "TOKEN=" + MASK),
    ("env-style GH_TOKEN", "export GH_TOKEN=" + val, "export GH_TOKEN=" + MASK),
    ('JSON "token"', '{"token": "' + val + '"}', '{"token": ' + MASK + "}"),
    ("Stripe test key", "key r" + "k_test_" + rep(24, "j") + " end", "key " + MASK + " end"),
    ("URL password holding a /", "postgres://app:pa/ss" + val + "@db/x", "postgres://" + MASK + "@db/x"),
    ("whole quoted value", 'password = "correct horse battery staple" tail', "password = " + MASK + " tail"),
    ("single-quoted value with spaces", "secret='two words here' tail", "secret=" + MASK + " tail"),
    ("token counters", "max_tokens: 4096000, input_tokens=123456", None),
    ("token_budget and tokenizer", "token_budget=200000 tokenizer: cl100k_base", None),
    ("prose about a token", "the token: see below, a token = `agentType`", None),
    ("a code constant", "SLUG_TOKEN = re.compile(r'^[a-z]')", None),
    ("Rust paths", "let k = token::Identifier; secret::Name", None),
    ("a port before an @scope path", "https://registry.npmjs.org:443/@scope/pkg", None),
    ("prose Authorization and basic", "Authorization: required. Basic auth is a basic understanding", None),
    ("a git remote", "git@github.com:owner/repo.git ssh://git@host:22/x@y", None),
    ("PGP private key block, keeps what follows",
     nl.join(["a", "-----BEGIN PGP PRIVATE KEY BLOCK-----", "Version: GnuPG v2", "", "lQOYBF" + rep(40, "x") + "+/=",
              "=AbCd", "-----END PGP PRIVATE KEY BLOCK-----", "after"]), nl.join(["a", MASK, "after"])),
    ("unterminated PEM block ends at the first non-key line",
     nl.join(["a", "-----BEGIN RSA PRIVATE KEY-----", "MIIE" + rep(60, "x"), rep(20, "y") + "==",
              "next line of prose", "more"]), nl.join(["a", MASK, "next line of prose", "more"])),
    ("one-line JSON key with its END on the BEGIN line",
     '{"private_key": "-----BEGIN PRIVATE KEY-----\\nMIIE\\n-----END PRIVATE KEY-----\\n",' + nl + '"client_email": "x@y"}',
     MASK + nl + '"client_email": "x@y"}'),
]
for label, s, want in PARITY:
    want = s if want is None else want
    got = h.redact_builtin(s)
    check("built-in pass: %s" % label, got == want, "got %r want %r" % (got, want))
RSH = os.path.join(os.path.dirname(HOOK), "..", "..", "scripts", "redact.sh")
rbash = h.redact_bash() if os.path.isfile(RSH) else None
if rbash:
    for label, s, want in PARITY:
        p = subprocess.run([rbash, RSH], input=(s + "\n").encode("utf-8"), stdout=subprocess.PIPE)
        sh = p.stdout.decode("utf-8", "replace").rstrip("\n").replace("\r\n", "\n")
        check("redact.sh then the built-in pass leave the same text: %s" % label,
              h.redact_builtin(sh) == sh == h.redact_builtin(s), "sh %r py %r" % (sh, h.redact_builtin(s)))


# --- P10-13: a token cut by the 500/1500-char truncation is masked, not left as a prefix ------
print("--- P10-13 redact first, then truncate")
home, proj = fresh("p13")
tok_p, tok_r = "gh" + "p_" + rep(36, "y"), "gh" + "p_" + rep(36, "z")
tp = write_transcript(os.path.join(ROOT, "p13", "tr", "s13.jsonl"), 30000,
                      prompts=[rep(490, "a") + " " + tok_p], reply=rep(1490, "b") + " " + tok_r)
rc, out, err = run("precompact", env_for(home, proj), {"session_id": "s13", "transcript_path": tp, "cwd": proj})
docs = handoffs(proj)
doc = read(docs[0]) if docs else ""
check("P10-13 the precompact dump is written", rc == 0 and len(docs) == 1,
      "rc=%d docs=%r err=%r" % (rc, docs, err[:200]))
check("P10-13 no token prefix survives the prompt cut", "yyyyy" not in doc, doc[-2500:-1800])
check("P10-13 no token prefix survives the reply cut", "zzzzz" not in doc, doc[-700:])


# --- P10-04: a normal /exit (reason prompt_input_exit) dumps a handoff -------------------------
print("--- P10-04 SessionEnd on /exit")
for reason, wanted in (("prompt_input_exit", 1), ("clear", 1), ("resume", 0)):
    home, proj = fresh("p04-" + reason)
    tp = write_transcript(os.path.join(ROOT, "p04-" + reason, "tr", "s04.jsonl"), 150000)
    rc, out, err = run("sessionend", env_for(home, proj),
                       {"session_id": "s04", "transcript_path": tp, "cwd": proj, "reason": reason})
    check("P10-04 SessionEnd reason %s -> %d handoff(s)" % (reason, wanted),
          rc == 0 and len(handoffs(proj)) == wanted, "rc=%d out=%r err=%r" % (rc, out[:160], err[:160]))


# --- mass-audit 10: a /clear dump never repoints index.json away from an enriched handoff --------
print("--- /clear dump keeps index.json on the session's enriched handoff")
for enriched in ("true", "false"):
    tag = "clr-" + enriched
    home, proj = fresh(tag)
    d = os.path.join(proj, ".claude", "handoff")
    os.makedirs(d)
    kept = os.path.join(d, "enriched-s10.md")
    with open(kept, "w", encoding="utf-8") as fh:
        fh.write("---\nhandoff: true\nsession_id: s10\nenriched: %s\n---\n\n# Handoff\n\n## Summary\n\nnext\n" % enriched)
    with open(os.path.join(d, "index.json"), "w", encoding="utf-8") as fh:
        json.dump({"path": kept, "session_id": "s10", "reason": "manual", "ts": time.time()}, fh)
    tp = write_transcript(os.path.join(ROOT, tag, "tr", "s10.jsonl"), 150000)
    rc, out, err = run("sessionend", env_for(home, proj),
                       {"session_id": "s10", "transcript_path": tp, "cwd": proj, "reason": "clear"})
    with open(os.path.join(d, "index.json"), "r", encoding="utf-8") as fh:
        now = json.load(fh).get("path")
    check("a /clear dump with an enriched=%s handoff indexed still writes its file" % enriched,
          rc == 0 and len(handoffs(proj)) == 2, "rc=%d docs=%r err=%r" % (rc, handoffs(proj), err[:200]))
    if enriched == "true":
        check("... and leaves index.json on the enriched handoff", now == kept, "index -> %r" % now)
    else:
        check("... and repoints index.json to the new dump when nothing is enriched",
              now != kept and now in handoffs(proj), "index -> %r" % now)


# --- P10-14: transcripts are found under CLAUDE_CONFIG_DIR -------------------------------------
print("--- P10-14 CLAUDE_CONFIG_DIR")
home, proj = fresh("p14")
cfgdir = os.path.join(ROOT, "p14", "claude-config")
sid = "0000aaaa-1414-1414-1414-000000000014"
write_transcript(os.path.join(cfgdir, "projects", "some-project", sid + ".jsonl"), 150000)
rc, out, err = run("dump", env_for(home, proj, {"CLAUDE_CONFIG_DIR": cfgdir}), args=[sid])
check("P10-14 dump <session-id> reads the transcript under CLAUDE_CONFIG_DIR",
      rc == 0 and "context_tokens=150000" in out, "rc=%d out=%r err=%r" % (rc, out[:200], err[:200]))


# --- P10-05: a handoff is restored once, while fresh, and after compaction only its own session's ---
print("--- P10-05 restore once, fresh, own session")


def seed_handoff(proj, sid, age_h=0.0, consumed=False, body=None):
    d = os.path.join(proj, ".claude", "handoff")
    os.makedirs(d, exist_ok=True)
    path = os.path.join(d, "seed-%s.md" % sid)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(body if body is not None else "---\nhandoff: true\n---\n\n# Handoff\n\nSEED-%s\n" % sid)
    meta = {"path": path, "session_id": sid, "reason": "sessionend-clear", "ts": time.time() - age_h * 3600}
    if consumed:
        meta["consumed_by_startup"] = True
    with open(os.path.join(d, "index.json"), "w", encoding="utf-8") as fh:
        json.dump(meta, fh)
    return path


def restore(proj, home, source, sid):
    rc, out, err = run("sessionstart", env_for(home, proj), {"session_id": sid, "cwd": proj, "source": source})
    return rc, out


home, proj = fresh("p05a")
seed_handoff(proj, "old-1")
rc, out = restore(proj, home, "clear", "new-1")
check("P10-05 /clear restores a fresh handoff", rc == 0 and "SEED-old-1" in out, out[:200])
rc, out = restore(proj, home, "clear", "new-2")
check("P10-05 a second /clear does not inject the same handoff again", rc == 0 and out == "", out[:200])
home, proj = fresh("p05b")
seed_handoff(proj, "old-2", age_h=48)
rc, out = restore(proj, home, "clear", "new-3")
check("P10-05 /clear does not restore a two-day-old handoff", rc == 0 and out == "", out[:200])
home, proj = fresh("p05c")
seed_handoff(proj, "other-window")
rc, out = restore(proj, home, "compact", "this-window")
check("P10-05 compaction does not restore another session's handoff", rc == 0 and out == "", out[:200])
rc, out = restore(proj, home, "compact", "other-window")
check("P10-05 compaction restores its own session's handoff", rc == 0 and "SEED-other-window" in out, out[:200])


# --- P10-06: the restore cut keeps the `## Summary` at the end of the document -----------------
print("--- P10-06 restore keeps ## Summary")
home, proj = fresh("p06")
long_body = ("---\nhandoff: true\n---\n\n# Handoff\n\n## Recent user prompts\n\n"
             + "".join("%d. %s\n" % (i, rep(90, "x")) for i in range(60))
             + "\n## Summary\n\nSUMMARY-NEXT-STEP: run the migration\n")
seed_handoff(proj, "s06", body=long_body)
rc, out = restore(proj, home, "compact", "s06")
ctx = json.loads(out)["hookSpecificOutput"]["additionalContext"] if out else ""
check("P10-06 a handoff over restore_max_chars still carries its ## Summary",
      "SUMMARY-NEXT-STEP" in ctx and "## Summary" in ctx, ctx[-300:])
check("P10-06 ... and is still cut near the cap", len(long_body) > 5000 and len(ctx) < 4000 + 800, str(len(ctx)))


# --- P10-07: compaction resets the Stop / prompt warning levels ---------------------------------
print("--- P10-07 warning levels reset after compaction")
home, proj = fresh("p07")
sid = "s07"
tp = write_transcript(os.path.join(ROOT, "p07", "tr", sid + ".jsonl"), 150000)  # 75% of 200k: level 2
pl = {"session_id": sid, "transcript_path": tp, "cwd": proj}
first = run("stop", env_for(home, proj), pl)[1]
again = run("stop", env_for(home, proj), pl)[1]
check("P10-07 a level warns once (baseline)", "systemMessage" in first and again == "", repr((first[:80], again[:80])))
run("prompt", env_for(home, proj), pl)
run("sessionstart", env_for(home, proj), {"session_id": sid, "cwd": proj, "source": "compact"})
after_stop = run("stop", env_for(home, proj), pl)[1]
after_prompt = run("prompt", env_for(home, proj), pl)[1]
check("P10-07 after compaction the Stop banner fires again", "systemMessage" in after_stop, repr(after_stop[:120]))
check("P10-07 after compaction the prompt nudge fires again", "additionalContext" in after_prompt,
      repr(after_prompt[:120]))


shutil.rmtree(os.path.dirname(ROOT), ignore_errors=True)
print()
if fails:
    print("FAILED %d/%d: %s" % (len(fails), count[0], ", ".join(fails)))
    sys.exit(1)
print("all %d cases passed" % count[0])
