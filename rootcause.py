#!/usr/bin/env python3
"""Report the source of *innermost* ERROR/MISSING nodes — the real root causes."""
import subprocess, pathlib, re, collections, sys

ROOT = pathlib.Path('/home/cerie/Documents/coralc')
GRAMMAR = pathlib.Path('/home/cerie/Documents/coral-zed/grammars/coral')
NODE = re.compile(r'\((ERROR|MISSING)[^\[]*?\[(\d+), (\d+)\] - \[(\d+), (\d+)\]')

def corpus():
    out = []
    for rel in ('lib', 'compiler'):
        d = ROOT / rel
        if d.is_dir():
            out += sorted(d.rglob('*.crl'))
    return out

def innermost(nodes):
    """Keep nodes that contain no other node."""
    keep = []
    for i, (k, r0, c0, r1, c1) in enumerate(nodes):
        r0, c0, r1, c1 = int(r0), int(c0), int(r1), int(c1)
        inner = False
        for j, (k2, s0, t0, s1, t1) in enumerate(nodes):
            if i == j:
                continue
            s0, t0, s1, t1 = int(s0), int(t0), int(s1), int(t1)
            if (s0 > r0 or (s0 == r0 and t0 >= c0)) and \
               (s1 < r1 or (s1 == r1 and t1 <= c1)):
                inner = True
                break
        if not inner:
            keep.append((k, r0, c0, r1, c1))
    return keep

def main():
    limit = int(sys.argv[1]) if len(sys.argv) > 1 else 20
    buckets = collections.Counter()
    samples = {}
    files = corpus()
    for f in files:
        r = subprocess.run(['tree-sitter', 'parse', str(f)], cwd=GRAMMAR,
                           capture_output=True, text=True)
        nodes = NODE.findall(r.stdout)
        if not nodes:
            continue
        src = f.read_text(errors='replace').split('\n')
        for (k, r0, c0, r1, c1) in innermost(nodes):
            r0, c0, r1, c1 = int(r0), int(c0), int(r1), int(c1)
            if r0 == r1:
                txt = src[r0][c0:c1].strip()
            else:
                txt = src[r0][c0:].strip() + ' …'
            txt = re.sub(r'"[^"]*"', '"…"', txt)
            key = txt[:56]
            buckets[key] += 1
            samples.setdefault(key, f'{f.relative_to(ROOT)}:{r0 + 1}')
    print(f'=== innermost error buckets, {files and len(files)} files scanned')
    for k, v in buckets.most_common(limit):
        print(f'{v:5d}  {k!r}')
        print(f'         e.g. {samples[k]}')

main()
