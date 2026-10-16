#!/usr/bin/env python3
"""Aggregates CI pipeline test results into out/report.md."""
import collections, json, os, re

out = 'out'
lines = ['# Pipeline test report', '']
summary = json.load(open(f'{out}/summary.json')) if os.path.exists(f'{out}/summary.json') else {}
lines.append('## Sources')
for u, st in summary.get('sources', {}).items():
    lines.append(f'- {u.split("githubusercontent.com/")[-1]}: {st}')
lines += ['', f'Unique by protocol: {summary.get("unique_by_protocol")}', f'Build errors: {summary.get("build_errors")}', '']
for s in summary.get('build_error_samples', []):
    lines.append(f'  - {s}')
lines += ['', f'WARP: {summary.get("warp")}', '']

for name in ('configs', 'loadonly'):
    p = f'{out}/{name}_results.json'
    if not os.path.exists(p):
        lines.append(f'## {name}: no results'); continue
    res = json.load(open(p))
    groups = collections.defaultdict(lambda: {'n': 0, 'ok': 0, 'load': 0, 'errs': collections.Counter()})
    for r in res:
        m = re.match(r'(pub_[a-z0-9]+|warp|xdns)', r['file'])
        g = groups[m.group(1) if m else r['file']]
        g['n'] += 1
        if r['delay'] > 0: g['ok'] += 1
        e = r.get('error', '')
        if any(k in e for k in ('config load', 'instance creation', 'startup failed')): g['load'] += 1
        if e: g['errs'][re.sub(r'[0-9a-f:.\[\]]{6,}', '*', e)[:140]] += 1
    lines.append(f'## {name}')
    for k, g in sorted(groups.items()):
        lines.append(f'- **{k}**: {g["ok"]}/{g["n"]} ok, {g["load"]} config errors')
        for e, c in g['errs'].most_common(4):
            lines.append(f'    - {c}× {e}')
open(f'{out}/report.md', 'w').write('\n'.join(lines) + '\n')
print('\n'.join(lines))
