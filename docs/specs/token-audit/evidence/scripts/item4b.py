"""item4b.py - hook-injected and harness-injected context in Queen sessions: chars per session and per user prompt,
classified by source from the injected text (VULYK hooks vs the owner's global hooks)."""
import json, os, re, collections, pandas as pd
ROOT = os.path.expanduser(r'C:\Users\Andrei\.claude\projects')
st = pd.read_csv('session_table.csv')
def classify(txt):
    t = txt[:400]
    if 'context-guard' in t: return 'global context_guard.py'
    if 'Skill routing hint' in t: return 'global skill_router.py'
    if re.search(r'VULYK|vulyk|Queen|top-model|TOP_MODEL|handoff|hive', t): return 'VULYK hooks'
    return 'other'
rows = []
for cls, df in (('VULYK', st[(st.vulyk == 1) & (st.recent == 1)]), ('non-VULYK', st[(st.vulyk == 0) & (st.recent == 1) & (st.n_edits >= 3) & (st.instr_vulyk != 1)])):
    for r in df.itertuples():
        f = os.path.join(ROOT, r.project, r.session + '.jsonl')
        agg = collections.Counter(); cnt = collections.Counter(); prompts = 0
        for l in open(f, encoding='utf-8', errors='replace'):
            if '"attachment"' not in l and '"user"' not in l: continue
            d = json.loads(l)
            if d.get('type') == 'attachment':
                a = d['attachment']; at = a.get('type')
                if at in ('hook_additional_context', 'hook_system_message'):
                    c = a.get('content'); txt = '\n'.join(c) if isinstance(c, list) else str(c)
                    k = at.replace('hook_', '') + ' | ' + str(a.get('hookEvent') or '') + ' | ' + classify(txt)
                    agg[k] += len(txt); cnt[k] += 1
                elif at in ('instructions', 'skill_listing', 'agent_listing_delta', 'mcp_instructions_delta', 'deferred_tools_delta', 'total_tokens_reminder', 'silent_turn_reminder'):
                    agg['harness | ' + at] += len(json.dumps(a, ensure_ascii=False)); cnt['harness | ' + at] += 1
        rows.append(dict(cls=cls, project=r.project, session=r.session, prompts=r.n_prompts, **{k: v for k, v in agg.items()}, **{'#' + k: v for k, v in cnt.items()}))
df = pd.DataFrame(rows).fillna(0)
df.to_csv('item4b_injected.csv', index=False)
cols = sorted(c for c in df.columns if ' | ' in c and not c.startswith('#'))
out = []
for c in cols:
    for cls in ('VULYK', 'non-VULYK'):
        s = df[df.cls == cls]
        out.append(dict(source=c, cls=cls, sessions_with=int((s[c] > 0).sum()), of=len(s), median_chars_per_session=round(s[s[c] > 0][c].median()) if (s[c] > 0).any() else 0,
                        total_chars=int(s[c].sum()), injections=int(s['#' + c].sum()) if '#' + c in s else 0))
o = pd.DataFrame(out)
o = o[o.total_chars > 0]
print(o.to_markdown(index=False))
