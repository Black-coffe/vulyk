# Contributing to VULYK

The most valuable contributions right now:

1. **Routing-matrix tuning from real usage** - tier signals that misclassify, posture caps that feel wrong, with examples.
2. **Memory-plane patterns from large repos** (200k+ LOC) - map granularity, wiki note shapes, staleness heuristics.
3. **/vulyk-evolve heuristics** - better friction clustering, smarter retirement rules, false-positive reports.
4. **Hook portability** - Windows (Git Bash / WSL) and macOS quirks; scripts must stay fail-open.

## Ground rules
- Native primitives only. PRs introducing proxies, SDK harnesses, or anything that touches auth will be declined - subscription safety is the project's core promise.
- Keep prompts terse. Agent and command files are loaded into context; every line costs every user tokens. Tightening is a feature; bloat is a bug.
- Docs change with behavior. A PR that changes an agent/command updates its reference doc in the same PR.
- Use the framework on itself where possible: propose config changes as an evolve-style changeset (diff + one-line rationale per change).
- Editing the `## Commands` section of `CLAUDE.md`? Leave the `VULYK:COMMANDS:START` / `END` comment markers in place. `install.sh` uses them to blank the table out when the constitution is copied into someone else's project - those rows are VULYK's own and are wrong everywhere else. Without the markers the installer warns instead of resetting, and the wrong commands ship.

## Dev quickstart
Fork -> branch -> change -> verify -> PR with a clear before/after. The verification commands are the `## Commands` table in `CLAUDE.md`; the installer has a dry run of its own:

```bash
git ls-files '*.sh' | xargs -n1 bash -n          # shell syntax
python -m py_compile .claude/hooks/*.py          # hook syntax (writes gitignored __pycache__)
git ls-files '*.json' | xargs -n1 jq -e . > /dev/null
./install.sh /tmp/testproj --check               # installer dry run
```

By contributing you agree your contributions are licensed under MIT.
