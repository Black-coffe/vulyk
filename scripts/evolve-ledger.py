#!/usr/bin/env python3
"""The evolve hypothesis ledger, memory/stats/evolve.jsonl (spec auto-maintenance, plan Contracts).

Append-only JSONL, one object per line, three kinds:
  proposal  {"ts","kind":"proposal","branch","component","file","hypothesis","evidence","bytes_delta"}
  run       {"ts","kind":"run","branch","commit","proposals"}   - one per /vulyk-evolve run; the
            SessionStart brief reads the newest run ts to decide whether evolve is due
  verdict   {"ts","kind":"verdict","branch","verdict":"accepted|rejected","reason"}

The owner's verdict is read from git, per changeset branch: its tip reached the default branch =
accepted; the branch is gone, its tip is not an ancestor of the default branch but every one of its
patches is (`git cherry` shows no `+`) = accepted, landed by rebase or cherry-pick; the branch is gone
and its tip never reached the default branch = rejected; the branch is still there and unmerged =
pending (no row yet). Merge or rebase the branch, do not squash it: a squash of several commits matches
none of their patches and reads as rejected.

  python scripts/evolve-ledger.py <root> add --branch B --component C --file F --hypothesis H --evidence E --bytes-delta N
  python scripts/evolve-ledger.py <root> run --branch B --commit SHA --proposals N
  python scripts/evolve-ledger.py <root> resolve [--reason-for B=TEXT ...]
  python scripts/evolve-ledger.py <root> window [--n 40]
  python scripts/evolve-ledger.py <root> last
  python scripts/evolve-ledger.py <root> pending
"""
import argparse
import json
import os
import subprocess
import sys
import time

COMPONENTS = ("constitution", "rule", "agent", "command", "hook", "skill", "defect", "memory", "script", "doc")


def now():
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def git(root, *args):
    r = subprocess.run(["git", "-C", root, *args], capture_output=True, text=True)
    return r.returncode, r.stdout.strip()


def default_branch(root):
    rc, out = git(root, "symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD")
    if rc == 0 and out:
        return out.split("/", 1)[-1]
    for b in ("main", "master"):
        if git(root, "show-ref", "--verify", "--quiet", "refs/heads/" + b)[0] == 0:
            return b
    return None


def ledger_path(root):
    return os.path.join(root, "memory", "stats", "evolve.jsonl")


def rows(root):
    p = ledger_path(root)
    if not os.path.exists(p):
        return []
    out = []
    with open(p, encoding="utf-8") as f:
        for n, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                out.append(json.loads(line))
            except ValueError:
                sys.exit("evolve-ledger: %s:%d is not JSON" % (p, n))
    return out


def append(root, row):
    p = ledger_path(root)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "a", encoding="utf-8", newline="\n") as f:
        # compact separators: the SessionStart brief greps `"kind":"run"` and `"ts":"`, like every other ledger
        f.write(json.dumps(row, ensure_ascii=False, separators=(",", ":")) + "\n")


def is_merged(root, ref, base):
    return git(root, "merge-base", "--is-ancestor", ref, base)[0] == 0


def landed_by_rebase(root, ref, base):
    # every patch of ref is already in base under another sha; a missing ref fails git cherry.
    # A changeset that changes nothing has no patch to land (empty commits share one patch-id).
    rc, mb = git(root, "merge-base", base, ref)
    if rc != 0 or git(root, "diff", "--quiet", mb, ref)[0] == 0:
        return False
    rc, out = git(root, "cherry", base, ref)
    return rc == 0 and not any(l.startswith("+") for l in out.splitlines())


def branch_exists(root, b):
    return git(root, "show-ref", "--verify", "--quiet", "refs/heads/" + b)[0] == 0


def pending_branches(root):
    base = default_branch(root)
    if not base:
        return []
    rc, out = git(root, "for-each-ref", "--format=%(refname:short)", "refs/heads/vulyk/evolve-*")
    return [b for b in out.splitlines() if b and not is_merged(root, b, base)]


def cmd_add(root, a):
    if a.component not in COMPONENTS:
        sys.exit("evolve-ledger: component must be one of: " + " ".join(COMPONENTS))
    for k in ("branch", "file", "hypothesis", "evidence"):
        if not getattr(a, k).strip():
            sys.exit("evolve-ledger: --%s is empty" % k)
    append(root, {"ts": now(), "kind": "proposal", "branch": a.branch, "component": a.component,
                  "file": a.file, "hypothesis": a.hypothesis, "evidence": a.evidence,
                  "bytes_delta": a.bytes_delta})


def cmd_run(root, a):
    append(root, {"ts": now(), "kind": "run", "branch": a.branch, "commit": a.commit, "proposals": a.proposals})


def cmd_resolve(root, a):
    base = default_branch(root)
    if not base:
        sys.exit("evolve-ledger: no default branch (origin/HEAD, main or master)")
    reasons = dict(x.split("=", 1) for x in (a.reason_for or []) if "=" in x)
    rs = rows(root)
    decided = {r["branch"] for r in rs if r.get("kind") == "verdict"}
    tips = {r["branch"]: r.get("commit") for r in rs if r.get("kind") == "run" and r.get("branch")}
    seen = []
    for r in rs:
        b = r.get("branch")
        if r.get("kind") != "proposal" or not b or b in decided or b in seen:
            continue
        seen.append(b)
        why = ""
        if branch_exists(root, b):
            if not is_merged(root, b, base):
                print("pending   %s" % b)
                continue
            verdict = "accepted"
        else:
            tip = tips.get(b)
            verdict = "accepted" if tip and is_merged(root, tip, base) else "rejected"
            if verdict == "rejected" and tip and landed_by_rebase(root, tip, base):
                verdict, why = "accepted", "landed by rebase"
        append(root, {"ts": now(), "kind": "verdict", "branch": b, "verdict": verdict,
                      "reason": reasons.get(b, why)})
        print("%-9s %s" % (verdict, b))


def cmd_window(root, a):
    rs = rows(root)
    verdict = {}
    for r in rs:
        if r.get("kind") == "verdict":
            verdict[r["branch"]] = (r["verdict"], r.get("reason", ""))
    props = [r for r in rs if r.get("kind") == "proposal"]
    recent, older = props[-a.n:], props[:-a.n] if len(props) > a.n else []
    runs = [r for r in rs if r.get("kind") == "run"]
    print("evolve ledger: %d runs, %d proposals (showing the last %d; older rejections below)"
          % (len(runs), len(props), len(recent)))

    def line(r):
        v, why = verdict.get(r["branch"], ("pending", ""))
        return "%s %-8s %-12s %s: %s | evidence: %s | %+d B%s" % (
            r["ts"][:10], v, r["component"], r["file"], r["hypothesis"], r["evidence"],
            int(r.get("bytes_delta") or 0), (" | why: " + why) if why else "")
    for r in recent:
        print(line(r))
    rej = [r for r in older if verdict.get(r["branch"], ("",))[0] == "rejected"]
    if rej:
        print("older rejections (do not re-propose without new evidence):")
        for r in rej:
            print("%s rejected %s: %s" % (r["ts"][:10], r["file"], r["hypothesis"]))


def cmd_last(root, a):
    ts = [r["ts"] for r in rows(root) if r.get("kind") == "run"]
    if ts:
        print(max(ts))


def cmd_pending(root, a):
    for b in pending_branches(root):
        print(b)


def main():
    # LF and UTF-8 on every platform: callers read this output with $(...), which strips only \n
    sys.stdout.reconfigure(encoding="utf-8", newline="\n")
    p = argparse.ArgumentParser(description="the evolve hypothesis ledger")
    p.add_argument("root")
    sub = p.add_subparsers(dest="verb", required=True)
    s = sub.add_parser("add")
    s.add_argument("--branch", required=True)
    s.add_argument("--component", required=True)
    s.add_argument("--file", required=True)
    s.add_argument("--hypothesis", required=True)
    s.add_argument("--evidence", required=True)
    s.add_argument("--bytes-delta", type=int, required=True, dest="bytes_delta")
    s = sub.add_parser("run")
    s.add_argument("--branch", default="")
    s.add_argument("--commit", default="")
    s.add_argument("--proposals", type=int, required=True)
    s = sub.add_parser("resolve")
    s.add_argument("--reason-for", action="append", dest="reason_for")
    s = sub.add_parser("window")
    s.add_argument("--n", type=int, default=40)
    sub.add_parser("last")
    sub.add_parser("pending")
    a = p.parse_args()
    {"add": cmd_add, "run": cmd_run, "resolve": cmd_resolve, "window": cmd_window,
     "last": cmd_last, "pending": cmd_pending}[a.verb](a.root, a)


if __name__ == "__main__":
    main()
