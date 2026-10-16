#!/usr/bin/env python3
"""Show the first ERROR (with multi-line context) per failing .crl file."""
import subprocess, pathlib, re, collections

ROOT = pathlib.Path('/home/cerie/Documents/coralc')
GRAMMAR = pathlib.Path('/home/cerie/Documents/coral-zed/grammars/coral')
ERR = re.compile(r'\(ERROR \[(\d+), (\d+)\] - \[(\d+), (\d+)\]')

def corpus():
    out = []
    for rel in ('lib', 'compiler'):
        d = ROOT / rel
        if d.is_dir():
            out += sorted(d.rglob('*.crl'))
    return out

def main():
    buckets = collections.Counter()
    first = []
    for f in corpus():
        r = subprocess.run(['tree-sitter', 'parse', str(f)], cwd=GRAMMAR,
                           capture_output=True, text=True)
        if '(ERROR' not in r.stdout:
            continue
        m = ERR.search(r.stdout)
        r0, c0, _r1, _c1 = (int(x) for x in m.groups())
        src = f.read_text(errors='replace').split('\n')
        # skip over leading comment lines
        while r0 < len(src) and src[r0].strip().startswith(('//', '/*', '*')):
            r0 += 1
        if r0 >= len(src):
            continue
        snippet = src[r0].strip()
        key = re.sub(r'"[^"]*"', '"…"', snippet)
        key = re.sub(r'\b[a-z_][a-z0-9_]*\b', 'x', key, count=6)
        buckets[key] += 1
        first.append((r0 + 1, f.relative_to(ROOT), snippet[:66]))

    print('=== first-error buckets (failing files)')
    for k, v in buckets.most_common(18):
        print(f'{v:5d}  {k[:80]}')
    print(f'\n{len(first)} failing files')
    print('\n=== first 14 with paths')
    for l, f, s in first[:14]:
        print(f'  {f}:{l}  {s!r}')

main()
