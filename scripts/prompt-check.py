#!/usr/bin/env python3
"""VULYK prompt check: the prose of agents, commands and templates against the scripts and agents it names.

Called by scripts/prompt-check.sh (usage and exit codes there). The repo root is this file's parent's parent, so a
fixture copy checks itself. Only backticked spans are read: prose such as "cycle.sh records" is not a command.
"""
import fnmatch
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROMPT_DIRS = (".claude/agents", ".claude/commands", "templates")
MODEL_RE = re.compile(r"^(opus|sonnet|haiku|fable|inherit|claude-[a-z0-9.\[\]-]+)$")
AGENT_SHAPE = re.compile(r"^(council|drone|lead|queen|worker|cycle)-[a-z][a-z0-9-]*$")
SCRIPT_TOK = re.compile(r"^[\w./-]*?([\w.-]+\.(?:sh|py))$")
FLAG_RE = re.compile(r"(?<![\w-])(--[a-z][a-z0-9-]*)")
VERB_RE = re.compile(r"^[a-z][a-z-]*$")
SPLIT_RE = re.compile(r"&&|\|\||\||;")

findings = []  # (file, line, rule, message, involves, hive_warn)


def add(file, line, rule, msg, involves, soft=False):
    findings.append((file, line, rule, msg, set(involves) | {file}, soft))


def read(rel):
    try:
        return (ROOT / rel).read_text(encoding="utf-8", errors="replace").replace("\r", "")
    except OSError:
        return None


def frontmatter(text):
    lines = text.split("\n")
    if not lines or lines[0].strip() != "---":
        return None
    fm = {}
    for ln in lines[1:]:
        if ln.strip() == "---":
            return fm
        m = re.match(r"^([A-Za-z][\w-]*):\s*(.*)$", ln)
        if m:
            fm[m.group(1)] = re.sub(r"\s+#.*$", "", m.group(2)).strip()
    return None


def shell_list(text, var):
    m = re.search(r'^%s="([^"]*)"' % var, text or "", re.M)
    return [w for w in m.group(1).split()] if m else None


def code_text(rel):
    """The script's lines that are not comments: a flag left only in a comment or usage header does not exist.
    A .sh wrapper's same-stem .py beside it (symbol-map, trace-autopsy) parses the flags, so it counts too."""
    t = read(rel) or ""
    if rel.endswith(".sh"):
        t += "\n" + (read(rel[:-3] + ".py") or "")
    return "\n".join(ln for ln in t.split("\n") if not ln.lstrip().startswith("#"))


def cycle_verbs():
    t = read("scripts/cycle.sh") or ""
    lines = t.split("\n")
    starts = [i for i, ln in enumerate(lines) if re.match(r'^case "\$VERB" in', ln)]
    if not starts:
        return None
    verbs = set()
    for ln in lines[starts[-1] + 1:]:
        if ln.startswith("esac"):
            break
        m = re.match(r"^  ([a-z][a-z|-]*)\)", ln)
        if m:
            verbs.update(m.group(1).split("|"))
    return verbs


def keepers():
    """Agents docs/architecture.md says keep the constitution: the backticked names between 'except' and 'carries'."""
    t = read("docs/architecture.md")
    if t is None:
        return None
    m = re.search(r"except (.*?) carries `omitClaudeMd: true`", re.sub(r"\s+", " ", t))
    return set(re.findall(r"`([a-z][a-z0-9-]*)`", m.group(1))) if m else set()


def spans(text):
    """(line number, span) for inline backticked spans and every line inside a fenced block."""
    fenced = False
    for n, ln in enumerate(text.split("\n"), 1):
        if ln.lstrip().startswith("```"):
            fenced = not fenced
            continue
        if fenced:
            yield n, ln
            continue
        for s in re.findall(r"`([^`]+)`", ln.replace("``", "")):
            yield n, s


def main(argv):
    touched = None
    args = list(argv)
    if args and args[0] in ("-h", "--help"):
        print(__doc__.strip())
        return 0
    if args and args[0] == "--touched":
        touched = []
        for a in args[1:]:
            a = a.replace("\\", "/")
            while a.startswith("./"):  # a prefix, never lstrip: `./.claude/...` keeps its own dot
                a = a[2:]
            touched.append(a)
        args = []
    if args:
        print("prompt-check: usage: bash scripts/prompt-check.sh [--touched <path>...]", file=sys.stderr)
        return 2

    hive = (ROOT / ".claude/vulyk-version").exists()
    files = []
    for d in PROMPT_DIRS:
        p = ROOT / d
        if p.is_dir():
            files += sorted(f"{d}/{f.name}" for f in p.glob("*.md"))
    agent_files = {Path(f).stem: f for f in files if f.startswith(".claude/agents/")}

    tel_text = read("scripts/telemetry.sh")
    agents = shell_list(tel_text, "AGENTS")
    retired = set(shell_list(tel_text, "RETIRED_AGENTS") or [])
    if agents is None:
        add("scripts/telemetry.sh", 1, "telemetry", "no AGENTS list found", [], soft=True)
        agents = []
    tel = "scripts/telemetry.sh"

    # Agent frontmatter, and omitClaudeMd against the architecture rule.
    keep = keepers()
    if keep is None:
        add("docs/architecture.md", 1, "omit-claude-md", "docs/architecture.md absent: the omitClaudeMd rule is not checked", [], soft=True)
    elif not keep:
        add("docs/architecture.md", 1, "omit-claude-md", "the sentence naming the agents that keep the constitution was not found", [])
    for name, f in sorted(agent_files.items()):
        fm = frontmatter(read(f) or "")
        if fm is None:
            add(f, 1, "frontmatter", "no frontmatter block", [])
            continue
        if fm.get("name") != name:
            add(f, 1, "frontmatter", f"name '{fm.get('name', '')}' is not the file name '{name}'", [])
        if not MODEL_RE.match(fm.get("model", "")):
            add(f, 1, "frontmatter", f"model '{fm.get('model', '')}' is not a family alias or a claude- id", [])
        if not re.match(r"^[1-9][0-9]*$", fm.get("maxTurns", "")):
            add(f, 1, "frontmatter", f"maxTurns '{fm.get('maxTurns', '')}' is not a positive integer", [])
        if not fm.get("tools"):
            add(f, 1, "frontmatter", "tools is missing or empty", [])
        omit = fm.get("omitClaudeMd")
        if omit is not None and omit not in ("true", "false"):
            add(f, 1, "omit-claude-md", f"omitClaudeMd '{omit}' is not true or false", [])
        elif keep and name in agents:
            want = name not in keep
            if (omit == "true") != want:
                rule = "carries" if want else "keeps the constitution and must not carry"
                add(f, 1, "omit-claude-md", f"{name} {rule} omitClaudeMd: true (docs/architecture.md)", ["docs/architecture.md"])

    # telemetry.sh AGENTS against the files: a mismatch is an error here, a warning in a hive, which may add its own
    # agents (ADR-005) and delete framework ones (an upgrade keeps host deletions).
    for name in agents:
        if name not in agent_files:
            add(tel, 1, "telemetry", f"AGENTS names {name}, but .claude/agents/{name}.md does not exist"
                + (" (deleted by the hive)" if hive else ""), [f".claude/agents/{name}.md"], soft=hive)
    for name, f in sorted(agent_files.items()):
        if name not in agents and name not in retired:
            add(f, 1, "telemetry", f"{name} is not in scripts/telemetry.sh AGENTS" + (" (a hive's own agent)" if hive else ""), [tel], soft=hive)

    # Backticked spans: scripts, cycle.sh verbs, flags, agent names.
    verbs = cycle_verbs()
    known_agents = set(agent_files) | set(agents) | retired
    code_cache = {}
    for f in files:
        for n, span in spans(read(f) or ""):
            word = span.strip()
            if re.match(r"^[a-z][a-z0-9-]*$", word) and AGENT_SHAPE.match(word) and word not in known_agents:
                add(f, n, "agent", f"`{word}` has no file in .claude/agents/", [])
            for seg in SPLIT_RE.split(span):
                toks = seg.split()
                script = None
                for i, tok in enumerate(toks):
                    m = SCRIPT_TOK.match(tok)
                    if m:
                        script = None
                        base = m.group(1)
                        if tok.startswith("scripts/"):
                            if not (ROOT / tok).is_file():
                                add(f, n, "script", f"`{tok}` does not exist", [])
                                continue
                            script = tok
                        elif "/" not in tok:
                            script = next((c for c in (f"scripts/{base}", base) if (ROOT / c).is_file()), None)
                        if script and base == "cycle.sh" and verbs is not None and i + 1 < len(toks):
                            v = toks[i + 1]
                            if VERB_RE.match(v) and v not in verbs:
                                add(f, n, "verb", f"`cycle.sh {v}`: no such verb in the dispatcher", ["scripts/cycle.sh"])
                        continue
                    if script:
                        for flag in FLAG_RE.findall(tok):
                            if script not in code_cache:
                                code_cache[script] = code_text(script)
                            if not re.search(r"(?<![\w-])%s(?![\w-])" % re.escape(flag), code_cache[script]):
                                add(f, n, "flag", f"`{flag}` is not in the code of {script}", [script])

    def blocks(fd):
        if fd[5]:
            return False
        if touched is None:
            return True
        return any(fnmatch.fnmatch(inv, pat) or inv == pat for inv in fd[4] for pat in touched)

    errors = 0
    for fd in sorted(findings, key=lambda x: (x[0], x[1], x[2], x[3])):
        b = blocks(fd)
        errors += b
        print(f"prompt-check: {'error' if b else 'warn'} {fd[0]}:{fd[1]}: {fd[2]}: {fd[3]}")
    if errors:
        print(f"prompt-check: {errors} error(s)")
        return 1
    print(f"prompt-check: ok ({len(files)} files)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
