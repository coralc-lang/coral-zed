#!/usr/bin/env python3
"""Parse every coral .crl file in the tree and report coverage."""
import subprocess, pathlib, re, sys

ROOT = pathlib.Path('/home/cerie/Documents/coralc')
GRAMMAR = pathlib.Path('/home/cerie/Documents/coral-zed/grammars/coral')
ERR = re.compile(r'\(ERROR \[(\d+), (\d+)\] - \[(\d+), (\d+)\]')

def corpus():
    for rel in ('lib', 'compiler', 'bootstrap'):
        d = ROOT / rel
        if d.is_dir():
            yield from sorted(d.rglob('*.crl'))

def main():
    files = list(corpus())
    total = bad = tot_err = 0
    details = []
    for f in files:
        total += 1
        r = subprocess.run(['tree-sitter', 'parse', str(f)], cwd=GRAMMAR,
                           capture_output=True, text=True)
        n = len(ERR.findall(r.stdout)) + r.stdout.count('(MISSING')
        if n:
            bad += 1
            tot_err += n
            src = f.read_text(errors='replace').split('\n')
            m = ERR.search(r.stdout)
            if m:
                r0, c0, _r1, _c1 = (int(x) for x in m.groups())
                line = src[r0]
                details.append((n, f.relative_to(ROOT), r0 + 1, line[c0:c0 + 58].strip()))
            else:
                details.append((n, f.relative_to(ROOT), 1, '<missing node>'))
    print(f'files={total}  clean={total - bad}  ({100 * (total - bad) // max(1, total)}%)'
          f'  error_nodes={tot_err}')
    print('\nworst offenders:')
    for n, f, l, s in sorted(details, reverse=True)[:12]:
        print(f'  {n:5d}  {f}:{l}  {s!r}')

main()
