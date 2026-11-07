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


shutil.rmtree(os.path.dirname(ROOT), ignore_errors=True)
print()
if fails:
    print("FAILED %d/%d: %s" % (len(fails), count[0], ", ".join(fails)))
    sys.exit(1)
print("all %d cases passed" % count[0])
